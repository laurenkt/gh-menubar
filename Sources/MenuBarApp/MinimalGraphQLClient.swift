import Foundation

// Minimal GraphQL client implementation without Apollo for now
// This allows the project to build while we work on Apollo integration

struct GraphQLResponse<T: Codable>: Codable {
    let data: T?
    let errors: [GraphQLErrorMessage]?
}

struct GraphQLErrorMessage: Codable {
    let message: String
}

class MinimalGraphQLClient {
    private let endpoint = "https://api.github.com/graphql"
    
    func execute<T>(query: String, variables: [String: Any] = [:], token: String) async throws -> T where T: Codable {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "query": query,
            "variables": variables
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GraphQLError.httpError(httpResponse.statusCode)
        }
        
        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
        
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GraphQLError.graphQLErrors(errors.map { $0.message })
        }
        
        guard let data = graphQLResponse.data else {
            throw GraphQLError.noData
        }
        
        return data
    }
}

enum GraphQLError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case graphQLErrors([String])
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GraphQL server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .graphQLErrors(let messages):
            return "GraphQL errors: \(messages.joined(separator: ", "))"
        case .noData:
            return "No data received from GraphQL server"
        }
    }
}
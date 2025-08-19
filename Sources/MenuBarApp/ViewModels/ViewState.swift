import Foundation

enum ViewState: Equatable {
    case idle
    case loading
    case loaded([QueryResult])
    case error(String)
    
    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case let (.loaded(lhsResults), .loaded(rhsResults)):
            return lhsResults.count == rhsResults.count // Simple comparison for now
        case let (.error(lhsMessage), .error(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
    
    var queryResults: [QueryResult] {
        if case .loaded(let results) = self {
            return results
        }
        return []
    }
}
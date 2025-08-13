import PackagePlugin
import Foundation

@main
struct ApolloPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let configPath = context.package.directory.appending(["apollo-codegen-config.json"])
        let outputPath = target.directory.appending(["GraphQL", "Generated"])
        
        return [
            .buildCommand(
                displayName: "Apollo Code Generation",
                executable: try context.tool(named: "apollo-ios-cli").path,
                arguments: [
                    "generate",
                    "--config", configPath.string,
                    "--output", outputPath.string
                ],
                environment: [:],
                outputFiles: [outputPath]
            )
        ]
    }
}
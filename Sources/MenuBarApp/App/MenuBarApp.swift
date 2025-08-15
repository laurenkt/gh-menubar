import SwiftUI

private enum UIConstants {
    static let menuBarWidth: CGFloat = 320
    static let scrollViewMaxHeight: CGFloat = 400
}

@main
struct MenuBarApp: App {
    private static let dependencies = DefaultDependencyContainer()
    @StateObject private var viewModel = PullRequestViewModel(dependencies: Self.dependencies)
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(viewModel: viewModel, dependencies: Self.dependencies)
        } label: {
            if viewModel.pendingActionsCount > 0 {
                Text("\(viewModel.pendingActionsCount) PRs")
                    .font(.system(size: 12, weight: .medium))
            } else {
                Image(systemName: "arrow.triangle.pull")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
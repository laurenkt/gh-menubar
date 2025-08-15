import SwiftUI

struct CheckStatusIcon: View {
    let status: CheckStatus
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(statusColor)
            .font(.caption)
    }
    
    private var iconName: String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .inProgress:
            return "clock.fill"
        case .unknown:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .inProgress:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}

struct CheckRunStatusIcon: View {
    let checkRun: GitHubCheckRun
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(statusColor)
            .font(.caption)
    }
    
    private var iconName: String {
        if checkRun.isSuccessful {
            return "checkmark.circle.fill"
        } else if checkRun.isFailed {
            return "xmark.circle.fill"
        } else if checkRun.isInProgress {
            return "clock.fill"
        } else {
            return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        if checkRun.isSuccessful {
            return .green
        } else if checkRun.isFailed {
            return .red
        } else if checkRun.isInProgress {
            return .orange
        } else {
            return .secondary
        }
    }
}
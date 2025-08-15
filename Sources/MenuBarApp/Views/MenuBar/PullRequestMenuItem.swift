import SwiftUI

struct PullRequestMenuItem: View {
    let pullRequest: GitHubPullRequest
    let queryConfig: QueryConfiguration
    
    private var statusSymbol: String {
        if pullRequest.needsReview {
            return "👀"
        }
        
        if pullRequest.isReadyToMerge {
            return "✅"
        }
        
        switch pullRequest.checkStatus {
        case .success:
            return "✅"
        case .failed:
            return "❌"
        case .inProgress:
            return "⏳"
        case .unknown:
            return pullRequest.draft ? "📝" : ""
        }
    }
    
    var body: some View {
        if !pullRequest.checkRuns.isEmpty || !pullRequest.commitStatuses.isEmpty || pullRequest.hasBranchConflicts {
            Menu {
                Button(action: {
                    if let url = URL(string: pullRequest.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Open Pull Request")
                }
                
                Divider()
                
                if pullRequest.hasBranchConflicts {
                    Text("❌ Branch conflicts prevent checks from running")
                        .disabled(true)
                    
                    if !pullRequest.checkRuns.isEmpty || !pullRequest.commitStatuses.isEmpty {
                        Divider()
                    }
                }
                
                ForEach(pullRequest.commitStatuses) { status in
                    Button(action: {
                        if let targetUrl = status.targetUrl, let url = URL(string: targetUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("\(commitStatusSymbol(status)) \(status.displayName)")
                    }
                    .disabled(status.targetUrl == nil)
                }
                
                if !pullRequest.commitStatuses.isEmpty && !pullRequest.checkRuns.isEmpty {
                    Divider()
                }
                
                ForEach(pullRequest.checkRuns) { checkRun in
                    if checkRun.isGitHubActions && !checkRun.jobs.isEmpty {
                        Menu {
                            Button(action: {
                                openCheckRun(checkRun)
                            }) {
                                Text("Open Check Run")
                            }
                            
                            Divider()
                            
                            ForEach(checkRun.jobs) { job in
                                if !job.steps.isEmpty {
                                    Menu {
                                        Button(action: {
                                            openWorkflowJob(job)
                                        }) {
                                            Text("Open Job")
                                        }
                                        
                                        Divider()
                                        
                                        ForEach(job.steps) { step in
                                            Button(action: {
                                                openWorkflowJob(job)
                                            }) {
                                                Text("\(stepStatusSymbol(step)) \(step.name)")
                                            }
                                            .disabled(true)
                                        }
                                    } label: {
                                        Text("\(jobStatusSymbol(job)) \(job.name)")
                                    } primaryAction: {
                                        openWorkflowJob(job)
                                    }
                                } else {
                                    Button(action: {
                                        openWorkflowJob(job)
                                    }) {
                                        Text("\(jobStatusSymbol(job)) \(job.name)")
                                    }
                                }
                            }
                        } label: {
                            Text("\(checkRunStatusSymbol(checkRun)) \(checkRun.name)")
                        } primaryAction: {
                            openCheckRun(checkRun)
                        }
                    } else {
                        Button(action: {
                            openCheckRun(checkRun)
                        }) {
                            Text("\(checkRunStatusSymbol(checkRun)) \(checkRun.name)")
                        }
                    }
                }
            } label: {
                Text(buildCompleteText())
            } primaryAction: {
                if let url = URL(string: pullRequest.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            Button(action: {
                if let url = URL(string: pullRequest.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(buildCompleteText())
            }
        }
    }
    
    private func openCheckRun(_ checkRun: GitHubCheckRun) {
        if let htmlUrl = checkRun.htmlUrl, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        } else if let detailsUrl = checkRun.detailsUrl, let url = URL(string: detailsUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openWorkflowJob(_ job: GitHubWorkflowJob) {
        if let htmlUrl = job.htmlUrl, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkRunStatusSymbol(_ checkRun: GitHubCheckRun) -> String {
        if checkRun.isSuccessful {
            return "✅"
        } else if checkRun.isFailed {
            return "❌"
        } else if checkRun.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func jobStatusSymbol(_ job: GitHubWorkflowJob) -> String {
        if job.isSuccessful {
            return "✅"
        } else if job.isFailed {
            return "❌"
        } else if job.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func stepStatusSymbol(_ step: GitHubWorkflowStep) -> String {
        if step.isSuccessful {
            return "✅"
        } else if step.isFailed {
            return "❌"
        } else if step.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func commitStatusSymbol(_ status: GitHubCommitStatus) -> String {
        if status.isSuccess {
            return "✅"
        } else if status.isFailure {
            return "❌"
        } else if status.isPending {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func buildCompleteText() -> String {
        var result: [String] = []
        
        for element in queryConfig.displayLayout {
            switch element {
            case .text(let text):
                if !text.isEmpty {
                    result.append(text)
                }
                
            case .component(let component):
                switch component {
                case .statusSymbol:
                    result.append(statusSymbol)
                    
                case .title:
                    result.append(pullRequest.title)
                    
                case .orgName:
                    if let orgName = pullRequest.repositoryOwner, !orgName.isEmpty {
                        result.append(orgName)
                    }
                    
                case .projectName:
                    if let repoName = pullRequest.repositoryName, !repoName.isEmpty {
                        result.append(repoName)
                    }
                    
                case .prNumber:
                    result.append("#\(pullRequest.number)")
                    
                case .authorName:
                    if !pullRequest.user.login.isEmpty {
                        result.append("@\(pullRequest.user.login)")
                    }
                    
                case .lastModified:
                    result.append(pullRequest.updatedAt.shortTimeAgoDisplay())
                }
            }
        }
        
        return result.joined(separator: " ")
    }
}
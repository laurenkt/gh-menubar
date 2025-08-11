import SwiftUI

extension Notification.Name {
    static let queriesUpdated = Notification.Name("queriesUpdated")
}

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var githubService = GitHubAPIService.shared
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var saveSuccess: Bool = false
    @State private var selectedTab: SettingsTab = .api
    
    enum SettingsTab: String, CaseIterable {
        case api = "API"
        case queries = "Queries"  
        case general = "General"
        
        var icon: String {
            switch self {
            case .api: return "key.fill"
            case .queries: return "magnifyingglass"
            case .general: return "gearshape.fill"
            }
        }
        
        var displayName: String {
            switch self {
            case .api: return "API"
            case .queries: return "Queries"
            case .general: return "General"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label {
                    Text(tab.displayName)
                        .font(.system(.body))
                } icon: {
                    Image(systemName: tab.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 16, height: 16)
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(ideal: 200)
            .listStyle(.sidebar)
        } detail: {
            // Detail view
            Group {
                switch selectedTab {
                case .api:
                    APISettingsView(
                        apiKey: $apiKey,
                        showAPIKey: $showAPIKey,
                        showSaveAlert: $showSaveAlert,
                        saveSuccess: $saveSuccess,
                        saveAPIKey: saveAPIKey,
                        removeAPIKey: removeAPIKey
                    )
                case .queries:
                    QueriesSettingsView()
                case .general:
                    GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 700, height: 500)
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text(saveSuccess ? "Success" : "Error"),
                message: Text(saveSuccess ? "API key saved successfully" : "Failed to save API key"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadExistingAPIKey()
            validateExistingToken()
        }
    }
    
    private func loadExistingAPIKey() {
        if let existingKey = appSettings.getAPIKey() {
            apiKey = existingKey
        }
    }
    
    private func saveAPIKey() {
        let success = appSettings.saveAPIKey(apiKey)
        saveSuccess = success
        showSaveAlert = true
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let window = NSApp.keyWindow {
                    window.close()
                }
            }
        }
    }
    
    private func removeAPIKey() {
        _ = appSettings.deleteAPIKey()
        apiKey = ""
        githubService.clearValidation()
    }
    
    private func validateExistingToken() {
        if let existingKey = appSettings.getAPIKey() {
            Task {
                await githubService.validateToken(existingKey)
            }
        }
    }
}

struct TokenValidationResultView: View {
    @StateObject private var githubService = GitHubAPIService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if githubService.isValidating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing GitHub connection...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let result = githubService.validationResult {
                if result.isValid {
                    validTokenView(result: result)
                } else {
                    invalidTokenView(result: result)
                }
            }
        }
    }
    
    private func validTokenView(result: GitHubValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connection successful", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
                .bold()
            
            if let user = result.user {
                Text("Authenticated as: \(user.login)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Repositories section
            VStack(alignment: .leading, spacing: 4) {
                Text("Accessible Repositories:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.primary)
                
                if result.repositories.isEmpty {
                    Text("No repositories accessible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.displayedRepositories) { repo in
                            HStack {
                                Image(systemName: repo.private ? "lock.fill" : "globe")
                                    .font(.caption2)
                                    .foregroundColor(repo.private ? .orange : .blue)
                                Text(repo.fullName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        
                        if result.remainingReposCount > 0 {
                            Text("and \(result.remainingReposCount) more...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            }
            
            Divider()
            
            // Organizations section
            VStack(alignment: .leading, spacing: 4) {
                Text("Organizations:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.primary)
                
                if result.organizations.isEmpty {
                    Text("No organizations accessible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.organizations) { org in
                            HStack {
                                Image(systemName: "building.2")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text(org.login)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func invalidTokenView(result: GitHubValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connection failed", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
                .bold()
            
            if let error = result.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct APISettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var githubService = GitHubAPIService.shared
    
    @Binding var apiKey: String
    @Binding var showAPIKey: Bool
    @Binding var showSaveAlert: Bool
    @Binding var saveSuccess: Bool
    
    let saveAPIKey: () -> Void
    let removeAPIKey: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("GitHub API Settings")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Personal Access Token")
                    .font(.headline)
                
                HStack {
                    if showAPIKey {
                        TextField("Enter your GitHub personal access token", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter your GitHub personal access token", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("You can create a personal access token at github.com/settings/tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Save") {
                    saveAPIKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty)
                
                Button("Test Token") {
                    Task {
                        await githubService.validateToken(apiKey)
                    }
                }
                .disabled(apiKey.isEmpty || githubService.isValidating)
                
                if appSettings.hasAPIKey {
                    Button("Remove Saved Token") {
                        removeAPIKey()
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            
            if appSettings.hasAPIKey && apiKey.isEmpty {
                Label("API key is already saved in Keychain", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            TokenValidationResultView()
        }
    }
}

struct QueriesSettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @State private var editingQuery: QueryConfiguration?
    @State private var showingSuggestions = false
    @State private var newQueryTitle = ""
    @State private var newQueryText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Search Queries")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Menu {
                    ForEach(QueryConfiguration.suggestedQueries) { suggestion in
                        Button(suggestion.title) {
                            appSettings.addQuery(suggestion)
                        }
                        .disabled(appSettings.queries.contains(where: { $0.query == suggestion.query }))
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .menuStyle(.borderlessButton)
            }
            
            Text("Configure custom search queries to organize your pull requests")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(appSettings.queries.enumerated()), id: \.element.id) { index, query in
                        QueryRowView(
                            query: query,
                            onEdit: { editingQuery = query },
                            onDelete: { appSettings.removeQuery(at: index) }
                        )
                    }
                    
                    if appSettings.queries.isEmpty {
                        Text("No queries configured")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .sheet(item: $editingQuery) { query in
            QueryEditSheet(
                query: query,
                onSave: { updatedQuery in
                    if let index = appSettings.queries.firstIndex(where: { $0.id == query.id }) {
                        appSettings.updateQuery(at: index, with: updatedQuery)
                        // Trigger a notification that queries have been updated
                        NotificationCenter.default.post(name: .queriesUpdated, object: nil)
                    }
                    editingQuery = nil
                }
            )
        }
    }
}

struct QueryRowView: View {
    let query: QueryConfiguration
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(query.title)
                    .font(.headline)
                
                Text(query.query)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Edit") { onEdit() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                
                Button("Delete") { onDelete() }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QueryEditSheet: View {
    @State private var title: String
    @State private var query: String
    @State private var componentOrder: [PRDisplayComponent]
    @State private var showOrgName: Bool
    @State private var showProjectName: Bool
    @State private var showPRNumber: Bool
    @State private var showAuthorName: Bool
    @State private var includeInFailingChecksCount: Bool
    @State private var includeInPendingReviewsCount: Bool
    @Environment(\.dismiss) private var dismiss
    
    let originalQuery: QueryConfiguration
    let onSave: (QueryConfiguration) -> Void
    
    init(query: QueryConfiguration, onSave: @escaping (QueryConfiguration) -> Void) {
        self.originalQuery = query
        self._title = State(initialValue: query.title)
        self._query = State(initialValue: query.query)
        self._componentOrder = State(initialValue: query.componentOrder)
        self._showOrgName = State(initialValue: query.showOrgName)
        self._showProjectName = State(initialValue: query.showProjectName)
        self._showPRNumber = State(initialValue: query.showPRNumber)
        self._showAuthorName = State(initialValue: query.showAuthorName)
        self._includeInFailingChecksCount = State(initialValue: query.includeInFailingChecksCount)
        self._includeInPendingReviewsCount = State(initialValue: query.includeInPendingReviewsCount)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Query")
                .font(.title2)
                .bold()
            VStack(alignment: .leading, spacing: 8) {
                Text("Title:")
                    .font(.headline)
                TextField("Query title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Query:")
                    .font(.headline)
                TextField("GitHub search query", text: $query)
                    .textFieldStyle(.roundedBorder)
                
                Text("Examples: is:open is:pr author:@me, is:open is:pr review-requested:@me")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("GitHub search syntax documentation", destination: URL(string: "https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .underline()
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Display Options:")
                    .font(.headline)
                
                Text("Drag components to rearrange or remove from layout:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HorizontalDragDropEditor(
                    componentOrder: $componentOrder
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar Count Options:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include in failing PR checks count", isOn: $includeInFailingChecksCount)
                    Toggle("Include PRs pending review in count", isOn: $includeInPendingReviewsCount)
                }
                
                Text("Controls whether PRs from this query contribute to the menu bar notification count")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    let updatedQuery = originalQuery.updated(
                        title: title,
                        query: query,
                        componentOrder: componentOrder,
                        showOrgName: showOrgName,
                        showProjectName: showProjectName,
                        showPRNumber: showPRNumber,
                        showAuthorName: showAuthorName,
                        includeInFailingChecksCount: includeInFailingChecksCount,
                        includeInPendingReviewsCount: includeInPendingReviewsCount
                    )
                    onSave(updatedQuery)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || query.isEmpty)
            }
        }
        .padding(20)
    }
}

struct PreviewPRItem: View {
    let showOrgName: Bool
    let showProjectName: Bool
    let showPRNumber: Bool
    let showAuthorName: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Menu item will look like:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(buildCompleteText())
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private func buildCompleteText() -> String {
        var parts: [String] = []
        
        // Always add the status symbol and title
        parts.append("✓ Fix login validation bug")
        
        // Build the info part
        var infoParts: [String] = []
        
        if showOrgName {
            infoParts.append("acme-corp")
        }
        
        if showProjectName {
            infoParts.append("mobile-app")
        }
        
        if showPRNumber {
            infoParts.append("#1234")
        }
        
        if showAuthorName {
            infoParts.append("@johndoe")
        }
        
        // Join info parts and add to main parts if not empty
        if !infoParts.isEmpty {
            parts.append(infoParts.joined(separator: " "))
        }
        
        return parts.joined(separator: " - ")
    }
}

struct HorizontalDragDropEditor: View {
    @Binding var componentOrder: [PRDisplayComponent]
    @State private var availableComponents: [PRDisplayComponent] = []
    @State private var draggedComponent: PRDisplayComponent?
    @State private var dropTargetIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Layout editor with horizontal draggable components
            VStack(alignment: .leading, spacing: 6) {
                Text("Layout:")
                    .font(.subheadline)
                    .bold()
                
                // Interactive draggable preview with drop indicators
                HStack(spacing: 0) {
                    // Leading drop zone
                    DropZoneIndicator(
                        isActive: dropTargetIndex == 0,
                        index: 0,
                        componentOrder: $componentOrder,
                        availableComponents: $availableComponents,
                        draggedComponent: $draggedComponent,
                        dropTargetIndex: $dropTargetIndex
                    )
                    
                    ForEach(Array(componentOrder.enumerated()), id: \.element.id) { index, component in
                        HStack(spacing: 0) {
                            HorizontalDragChip(
                                component: component,
                                isInPreview: true,
                                draggedComponent: $draggedComponent
                            )
                            
                            // Drop zone after each component
                            DropZoneIndicator(
                                isActive: dropTargetIndex == index + 1,
                                index: index + 1,
                                componentOrder: $componentOrder,
                                availableComponents: $availableComponents,
                                draggedComponent: $draggedComponent,
                                dropTargetIndex: $dropTargetIndex
                            )
                        }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .onDrop(of: [.text], delegate: PreviewAreaDropDelegate(
                    componentOrder: $componentOrder,
                    availableComponents: $availableComponents,
                    draggedComponent: $draggedComponent,
                    dropTargetIndex: $dropTargetIndex
                ))
            }
            
            // Palette of available components
            VStack(alignment: .leading, spacing: 6) {
                Text("Available Components:")
                    .font(.subheadline)
                    .bold()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(availableComponents, id: \.id) { component in
                            HorizontalDragChip(
                                component: component,
                                isInPreview: false,
                                draggedComponent: $draggedComponent
                            )
                            .onTapGesture(count: 2) {
                                addToLayout(component)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 36)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onDrop(of: [.text], delegate: PaletteDropDelegate(
                    componentOrder: $componentOrder,
                    draggedComponent: $draggedComponent
                ))
            }
            
            HStack {
                Button("Reset to Default") {
                    resetToDefault()
                }
                .font(.caption)
                
                Spacer()
                
                Text("Drag to rearrange • Double-click to add • Drag back to palette to remove")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            updateAvailableComponents()
        }
        .onChange(of: componentOrder) { _ in
            updateAvailableComponents()
        }
    }
    
    private func updateAvailableComponents() {
        availableComponents = PRDisplayComponent.allCases.filter { component in
            // Separators can always be added (multiple allowed)
            if component == .separator {
                return true
            }
            // Other components can only be added if not already in use
            return !componentOrder.contains(component)
        }
    }
    
    private func addToLayout(_ component: PRDisplayComponent) {
        // Separators can be added multiple times, others only if not already present
        if component == .separator || !componentOrder.contains(component) {
            componentOrder.append(component)
        }
    }
    
    private func removeFromLayout(_ component: PRDisplayComponent) {
        componentOrder.removeAll { $0 == component }
    }
    
    private func resetToDefault() {
        componentOrder = [.statusSymbol, .title, .orgName, .projectName, .prNumber, .authorName]
    }
}

struct HorizontalDragChip: View {
    let component: PRDisplayComponent
    let isInPreview: Bool
    @Binding var draggedComponent: PRDisplayComponent?
    
    var body: some View {
        Text(component.displayName)
            .font(.system(.body))
            .foregroundColor(isInPreview ? .primary : .secondary)
            .padding(.horizontal, isInPreview ? 6 : 8)
            .padding(.vertical, isInPreview ? 3 : 4)
            .background(isInPreview ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
            .cornerRadius(isInPreview ? 4 : 6)
            .overlay(
                RoundedRectangle(cornerRadius: isInPreview ? 4 : 6)
                    .stroke(isInPreview ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .onDrag {
                draggedComponent = component
                return NSItemProvider(object: component.rawValue as NSString)
            }
            .scaleEffect(draggedComponent == component ? 0.95 : 1.0)
            .opacity(draggedComponent == component ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: draggedComponent == component)
    }
}


struct PreviewAreaDropDelegate: DropDelegate {
    @Binding var componentOrder: [PRDisplayComponent]
    @Binding var availableComponents: [PRDisplayComponent]
    @Binding var draggedComponent: PRDisplayComponent?
    @Binding var dropTargetIndex: Int?
    
    func dropExited(info: DropInfo) {
        dropTargetIndex = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedComponent = nil
            dropTargetIndex = nil
        }
        
        guard let draggedComponent = draggedComponent else { return false }
        
        // If adding from palette to end of preview
        if availableComponents.contains(draggedComponent) || draggedComponent == .separator {
            componentOrder.append(draggedComponent)
        }
        
        return true
    }
}

struct PaletteDropDelegate: DropDelegate {
    @Binding var componentOrder: [PRDisplayComponent]
    @Binding var draggedComponent: PRDisplayComponent?
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedComponent = nil
        }
        
        guard let draggedComponent = draggedComponent else { return false }
        
        // If removing from preview back to palette
        if componentOrder.contains(draggedComponent) {
            componentOrder.removeAll { $0 == draggedComponent }
        }
        
        return true
    }
}

struct DropZoneIndicator: View {
    let isActive: Bool
    let index: Int
    @Binding var componentOrder: [PRDisplayComponent]
    @Binding var availableComponents: [PRDisplayComponent]
    @Binding var draggedComponent: PRDisplayComponent?
    @Binding var dropTargetIndex: Int?
    
    var body: some View {
        Rectangle()
            .fill(isActive ? Color.blue : Color.clear)
            .frame(width: isActive ? 2 : 4, height: 20)
            .animation(.easeInOut(duration: 0.15), value: isActive)
            .onDrop(of: [.text], delegate: DropZoneDelegate(
                targetIndex: index,
                componentOrder: $componentOrder,
                availableComponents: $availableComponents,
                draggedComponent: $draggedComponent,
                dropTargetIndex: $dropTargetIndex
            ))
    }
}

struct DropZoneDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var componentOrder: [PRDisplayComponent]
    @Binding var availableComponents: [PRDisplayComponent]
    @Binding var draggedComponent: PRDisplayComponent?
    @Binding var dropTargetIndex: Int?
    
    func dropEntered(info: DropInfo) {
        dropTargetIndex = targetIndex
    }
    
    func dropExited(info: DropInfo) {
        dropTargetIndex = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedComponent = nil
            dropTargetIndex = nil
        }
        
        guard let draggedComponent = draggedComponent else { return false }
        
        // If reordering within preview
        if let currentIndex = componentOrder.firstIndex(of: draggedComponent) {
            // Only move if the target position is different
            if currentIndex != targetIndex && targetIndex != currentIndex + 1 {
                // Remove from current position
                let component = componentOrder.remove(at: currentIndex)
                
                // Calculate adjusted target index
                let adjustedTargetIndex: Int
                if targetIndex > currentIndex {
                    // Moving forward - target index needs adjustment since we removed an element before it
                    adjustedTargetIndex = targetIndex - 1
                } else {
                    // Moving backward - target index stays the same
                    adjustedTargetIndex = targetIndex
                }
                
                // Insert at the correct position
                let finalIndex = min(adjustedTargetIndex, componentOrder.count)
                componentOrder.insert(component, at: finalIndex)
            }
        }
        // If adding from palette
        else if availableComponents.contains(draggedComponent) || draggedComponent == .separator {
            let adjustedIndex = min(targetIndex, componentOrder.count)
            componentOrder.insert(draggedComponent, at: adjustedIndex)
        }
        
        return true
    }
}

struct DragDropPreviewPRItem: View {
    let componentOrder: [PRDisplayComponent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Menu item will look like:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(buildCompleteText())
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private func buildCompleteText() -> String {
        var parts: [String] = []
        var currentGroup: [String] = []
        
        for component in componentOrder {
            switch component {
            case .statusSymbol:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                parts.append(component.exampleText)
                
            case .title:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                parts.append(component.exampleText)
                
            case .separator:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                // Separator is handled by joining with " – "
                
            case .orgName, .projectName, .prNumber, .authorName:
                currentGroup.append(component.exampleText)
            }
        }
        
        if !currentGroup.isEmpty {
            parts.append(currentGroup.joined(separator: " "))
        }
        
        return parts.joined(separator: " – ")
    }
}

struct GeneralSettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var viewModel = PullRequestViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Refresh Interval")
                    .font(.headline)
                
                Text("How often to automatically check for pull request updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Refresh Interval", selection: Binding(
                    get: { appSettings.refreshInterval },
                    set: { newInterval in
                        appSettings.setRefreshInterval(newInterval)
                        viewModel.startAutoRefresh()
                    }
                )) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.interval) { option in
                        Text(option.title).tag(option.interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200, alignment: .leading)
            }
            
            Spacer()
        }
    }
}
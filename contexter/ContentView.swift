import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ContextManager()
    @State private var selection: URL?
    
    var body: some View {
        NavigationView {
            SidebarView(manager: manager, selection: $selection)
            
            if let selection,
               let page = manager.page(for: selection) {
                PageView(page: page, manager: manager)
            } else {
                Text("Select a Page")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            setupDemoData()
        }
    }
    
    private func setupDemoData() {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("ContextRoot")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        manager.loadPages(from: root)
    }
}

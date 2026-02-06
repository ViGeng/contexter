import SwiftUI

struct SidebarView: View {
    @ObservedObject var manager: ContextManager
    @Binding var selection: URL?
    
    var body: some View {
        List(selection: $selection) {
            Section(header: Text("Library").font(.caption.bold())) {
                OutlineGroup(manager.pageTree, children: \.children) { node in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(node.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                    .tag(node.url)
                    .contextMenu {
                        Button(role: .destructive) {
                            if let page = manager.page(for: node.url) {
                                manager.deletePage(page)
                            }
                        } label: {
                            Label("Delete Page", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addPage) {
                    Label("Add Page", systemImage: "plus")
                }
            }
        }
    }
    
    private func addPage() {
        manager.addPage(in: selection)
    }
}

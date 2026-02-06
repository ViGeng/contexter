import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PageView: View {
    let page: Page
    @ObservedObject var manager: ContextManager
    @State private var showingFileImporter = false
    @State private var isTargeted = false
    @State private var selectedFileID: UUID?
    @State private var draggingItemID: UUID?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(page.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(breadcrumbText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Last modified: \(lastModifiedText)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
                
                if page.content.items.isEmpty {
                    EmptyStateView()
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(page.content.items) { item in
                            switch item {
                            case .text(let uuid, let text):
                                TextBlockView(text: text) { newText in
                                    manager.updateText(at: uuid, in: page, newText: newText)
                                }
                                .onTapGesture {
                                    selectedFileID = nil
                                }
                                .onDrag {
                                    draggingItemID = uuid
                                    return NSItemProvider(object: uuid.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: PageItemDropDelegate(
                                    targetItem: item,
                                    page: page,
                                    manager: manager,
                                    draggingItemID: $draggingItemID
                                ))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        manager.deleteItem(at: uuid, in: page)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            case .file(let uuid, let filename, _):
                                FileBlockView(
                                    pageURL: page.url,
                                    filename: filename,
                                    isSelected: selectedFileID == uuid
                                ) {
                                    selectedFileID = uuid
                                }
                                .onDrag {
                                    draggingItemID = uuid
                                    return NSItemProvider(object: uuid.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: PageItemDropDelegate(
                                    targetItem: item,
                                    page: page,
                                    manager: manager,
                                    draggingItemID: $draggingItemID
                                ))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            manager.deleteItem(at: uuid, in: page)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .onDrop(of: [UTType.text], delegate: PageItemDropToEndDelegate(
                        page: page,
                        manager: manager,
                        draggingItemID: $draggingItemID
                    ))
                }
            }
            .padding(40)
        }
        .background(Color(NSColor.textBackgroundColor))
        .background(KeyCaptureView { event in
            if event.keyCode == 49 {
                showQuickLookIfPossible()
            }
        })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(action: { manager.addTextBlock(to: page) }) {
                        Label("Add Text", systemImage: "text.badge.plus")
                    }
                    Button(action: { showingFileImporter = true }) {
                        Label("Import File", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result: result)
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
            // Handle drag and drop
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, error in
                    if let data = data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            manager.importFile(at: url, to: page)
                        }
                    }
                }
            }
            return true
        }
    }
    
    private func showQuickLookIfPossible() {
        guard let selectedFileID else { return }
        let fileItems = page.content.items.compactMap { item -> (UUID, URL)? in
            if case .file(_, let filename, _) = item {
                let url = page.url.appendingPathComponent(filename)
                return (item.id, url)
            }
            return nil
        }
        guard let selectedIndex = fileItems.firstIndex(where: { $0.0 == selectedFileID }) else { return }
        let urls = fileItems.map { $0.1 }
        QuickLookPreviewer.shared.preview(urls: urls, selectedIndex: selectedIndex)
    }
    
    private var lastModifiedText: String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: page.url.path),
           let date = attrs[.modificationDate] as? Date {
            return Self.dateFormatter.string(from: date)
        }
        return "Unknown"
    }
    
    private var breadcrumbText: String {
        guard let rootURL = manager.rootURL else { return "" }
        let rootPath = rootURL.standardizedFileURL.pathComponents
        let pagePath = page.url.standardizedFileURL.pathComponents
        let relativeComponents = Array(pagePath.dropFirst(rootPath.count))
        if relativeComponents.isEmpty {
            return rootURL.lastPathComponent
        }
        return ([rootURL.lastPathComponent] + relativeComponents).joined(separator: " > ")
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for srcURL in urls {
                manager.importFile(at: srcURL, to: page)
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

// MARK: - Components

struct TextBlockView: View {
    let text: String
    let onUpdate: (String) -> Void
    @State private var localText: String
    
    init(text: String, onUpdate: @escaping (String) -> Void) {
        self.text = text
        self.onUpdate = onUpdate
        _localText = State(initialValue: text)
    }
    
    var body: some View {
        TextEditor(text: $localText)
            .font(.body)
            .lineSpacing(6)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 100) // Minimum height for editor
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .onChange(of: localText) { newValue in
                onUpdate(newValue)
            }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("Start Building Context")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Drag and drop files here or use the import button.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .opacity(0.7)
    }
}

struct FileBlockView: View {
    let pageURL: URL
    let filename: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var fileURL: URL {
        pageURL.appendingPathComponent(filename)
    }
    
    var isImage: Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isImage, let nsImage = NSImage(contentsOf: fileURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "doc.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filename)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(fileURL.pathExtension.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
        }
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor.opacity(0.9) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(fileURL)
        }
    }
}

// MARK: - Drag and Drop

struct PageItemDropDelegate: DropDelegate {
    let targetItem: PageItem
    let page: Page
    let manager: ContextManager
    @Binding var draggingItemID: UUID?
    
    func dropEntered(info: DropInfo) {
        guard let draggingItemID, draggingItemID != targetItem.id else { return }
        manager.moveItem(in: page, from: draggingItemID, to: targetItem.id)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }
}

struct PageItemDropToEndDelegate: DropDelegate {
    let page: Page
    let manager: ContextManager
    @Binding var draggingItemID: UUID?
    
    func performDrop(info: DropInfo) -> Bool {
        if let draggingItemID {
            manager.moveItemToEnd(in: page, from: draggingItemID)
        }
        draggingItemID = nil
        return true
    }
}

// MARK: - Key Handling

struct KeyCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class KeyCaptureNSView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}

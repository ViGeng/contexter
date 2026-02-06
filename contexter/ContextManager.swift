import Foundation
import SwiftUI
import Combine

class ContextManager: ObservableObject {
    @Published var pages: [Page] = []
    @Published var pageTree: [PageNode] = []
    
    private let fileManager = FileManager.default
    private let sidecarFilename = "._context_layout.json"
    
    // Monitor for the root directory to detect new folders
    private var rootMonitor: FolderMonitor?
    // Monitor individual pages
    private var pageMonitors: [URL: FolderMonitor] = [:]
    
    var rootURL: URL? 
    
    func loadPages(from url: URL) {
        self.rootURL = url
        
        // Start monitoring the root folder
        self.rootMonitor = FolderMonitor(url: url)
        self.rootMonitor?.folderDidChange = { [weak self] in
            print("Root folder changed, reloading...")
            self?.reload(from: url)
        }
        
        reload(from: url)
    }
    
    private func reload(from url: URL) {
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
            let directoryContents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
            
            var newPages: [Page] = []
            var seenPageURLs: Set<URL> = []
            var newTree: [PageNode] = []
            
            func loadNode(at folderURL: URL) -> PageNode {
                let page = loadPage(from: folderURL)
                newPages.append(page)
                seenPageURLs.insert(folderURL)
                
                let childDirs = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])) ?? []
                let childFolders = childDirs.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
                
                var children = childFolders.map { loadNode(at: $0) }
                children.sort { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                
                let childNodes: [PageNode]? = children.isEmpty ? nil : children
                return PageNode(url: folderURL, children: childNodes)
            }
            
            for folderURL in directoryContents {
                let resourceValues = try? folderURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues?.isDirectory == true {
                    let node = loadNode(at: folderURL)
                    newTree.append(node)
                }
            }
            
            // Ensure we are monitoring all page folders
            for folderURL in seenPageURLs {
                if pageMonitors[folderURL] == nil {
                    let monitor = FolderMonitor(url: folderURL)
                    monitor?.folderDidChange = { [weak self] in
                        print("Page folder \(folderURL.lastPathComponent) changed, reloading...")
                        self?.reload(from: url)
                    }
                    pageMonitors[folderURL] = monitor
                }
            }
            
            // Prune monitors for pages that no longer exist.
            pageMonitors = pageMonitors.filter { seenPageURLs.contains($0.key) }
            
            newPages.sort { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            newTree.sort { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            
            DispatchQueue.main.async {
                self.pages = newPages
                self.pageTree = newTree
            }
        } catch {
            print("Error loading pages: \(error)")
        }
    }
    
    func importFile(at srcURL: URL, to page: Page) {
        if srcURL.deletingLastPathComponent().standardizedFileURL == page.url.standardizedFileURL {
            return
        }
        
        let destURL = uniqueDestinationURL(for: srcURL.lastPathComponent, in: page.url)
        do {
            try fileManager.copyItem(at: srcURL, to: destURL)
            // The FolderMonitor will pick this up and reload the page automatically
        } catch {
            print("Failed to import file: \(error)")
        }
    }
    
    private func loadPage(from url: URL) -> Page {
        let sidecarURL = url.appendingPathComponent(sidecarFilename)
        var content: PageContent
        
        if fileManager.fileExists(atPath: sidecarURL.path) {
            do {
                let data = try Data(contentsOf: sidecarURL)
                content = try JSONDecoder().decode(PageContent.self, from: data)
            } catch {
                print("Error parsing sidecar for \(url.lastPathComponent): \(error)")
                content = PageContent(items: [])
            }
        } else {
            content = PageContent(items: [])
        }
        
        // Merge Logic: Check for files in the directory that are NOT in the content items
        mergeFiles(into: &content, at: url)
        
        return Page(url: url, content: content)
    }
    
    private func mergeFiles(into content: inout PageContent, at url: URL) {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            let existingFileNamesOnDisk = Set(fileURLs.map { $0.lastPathComponent })
            
            // Remove file items that no longer exist on disk.
            content.items.removeAll { item in
                if case .file(_, let name, _) = item {
                    return !existingFileNamesOnDisk.contains(name)
                }
                return false
            }
            
            // Collect existing file names from content
            let existingFileNames: Set<String> = Set(content.items.compactMap { item in
                if case .file(_, let name, _) = item {
                    return name
                }
                return nil
            })
            
            // Find new files
            for fileURL in fileURLs {
                let filename = fileURL.lastPathComponent
                if filename == sidecarFilename { continue } // explicit check just in case
                
                if !existingFileNames.contains(filename) {
                    // It's a new file! Append it.
                    let metadata = DiskFileMetadata(createdAt: Date())
                    content.items.append(.file(UUID(), filename, metadata))
                    print("Merged new file: \(filename)")
                }
            }
            
        } catch {
            print("Error merging files: \(error)")
        }
    }
    
    func savePage(_ page: Page) {
        let sidecarURL = page.url.appendingPathComponent(sidecarFilename)
        do {
            let data = try JSONEncoder().encode(page.content)
            try data.write(to: sidecarURL)
        } catch {
            print("Error saving page: \(error)")
        }
    }
    func updateText(at id: UUID, in page: Page, newText: String) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == page.id }) else { return }
        guard let itemIndex = pages[pageIndex].content.items.firstIndex(where: { $0.id == id }) else { return }
        
        if case .text(let uuid, _) = pages[pageIndex].content.items[itemIndex] {
            pages[pageIndex].content.items[itemIndex] = .text(uuid, newText)
            savePage(pages[pageIndex])
        }
    }
    
    func addTextBlock(to page: Page) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == page.id }) else { return }
        let newBlock = PageItem.text(UUID(), "New Text Block")
        pages[pageIndex].content.items.append(newBlock)
        savePage(pages[pageIndex])
    }
    
    func moveItem(in page: Page, from sourceID: UUID, to destinationID: UUID) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == page.id }) else { return }
        guard let fromIndex = pages[pageIndex].content.items.firstIndex(where: { $0.id == sourceID }) else { return }
        guard let toIndex = pages[pageIndex].content.items.firstIndex(where: { $0.id == destinationID }) else { return }
        if fromIndex == toIndex { return }
        
        var items = pages[pageIndex].content.items
        let moved = items.remove(at: fromIndex)
        let adjustedIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        items.insert(moved, at: adjustedIndex)
        pages[pageIndex].content.items = items
        savePage(pages[pageIndex])
    }
    
    func moveItemToEnd(in page: Page, from sourceID: UUID) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == page.id }) else { return }
        guard let fromIndex = pages[pageIndex].content.items.firstIndex(where: { $0.id == sourceID }) else { return }
        var items = pages[pageIndex].content.items
        let moved = items.remove(at: fromIndex)
        items.append(moved)
        pages[pageIndex].content.items = items
        savePage(pages[pageIndex])
    }
    
    func deleteItem(at id: UUID, in page: Page) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == page.id }) else { return }
        if let itemIndex = pages[pageIndex].content.items.firstIndex(where: { $0.id == id }) {
            if case .file(_, let filename, _) = pages[pageIndex].content.items[itemIndex] {
                let fileURL = page.url.appendingPathComponent(filename)
                try? fileManager.removeItem(at: fileURL)
            }
            pages[pageIndex].content.items.remove(at: itemIndex)
            savePage(pages[pageIndex])
        }
    }
    
    func deletePage(_ page: Page) {
        do {
            try fileManager.removeItem(at: page.url)
        } catch {
            print("Error deleting page: \(error)")
        }
    }
    
    func addPage(in parentURL: URL?) {
        guard let rootURL else { return }
        let baseURL = parentURL ?? rootURL
        let newName = "Page \(Int(Date().timeIntervalSince1970))"
        let newPageURL = uniqueDestinationURL(for: newName, in: baseURL)
        do {
            try FileManager.default.createDirectory(at: newPageURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create page: \(error)")
        }
    }
    
    func page(for url: URL) -> Page? {
        pages.first { $0.url == url }
    }
    
    private func uniqueDestinationURL(for filename: String, in folderURL: URL) -> URL {
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        
        var candidate = folderURL.appendingPathComponent(filename)
        var counter = 1
        
        while fileManager.fileExists(atPath: candidate.path) {
            let newName: String
            if ext.isEmpty {
                newName = "\(base) (\(counter))"
            } else {
                newName = "\(base) (\(counter)).\(ext)"
            }
            candidate = folderURL.appendingPathComponent(newName)
            counter += 1
        }
        
        return candidate
    }
}

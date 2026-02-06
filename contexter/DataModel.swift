import Foundation

struct Page: Identifiable {
    var id: URL { url }
    let url: URL
    var content: PageContent
    
    var name: String {
        url.lastPathComponent
    }
}

struct PageNode: Identifiable {
    var id: URL { url }
    let url: URL
    var children: [PageNode]?
    
    var name: String {
        url.lastPathComponent
    }
}

struct PageContent: Codable {
    var items: [PageItem]
}

enum PageItem: Codable, Identifiable {
    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .file(let id, _, _): return id
        }
    }
    
    case text(UUID, String)
    case file(UUID, String, DiskFileMetadata)
    
    // Custom Codable implementation could be added here if needed for clean JSON,
    // but default auto-synthesis works fine for Swift 5.5+
}

struct DiskFileMetadata: Codable {
    var createdAt: Date
    // Add other metadata as needed
}

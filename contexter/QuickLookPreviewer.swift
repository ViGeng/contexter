import Foundation
import QuickLookUI

final class QuickLookPreviewer: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewer()
    
    private var urls: [URL] = []
    private var selectedIndex: Int = 0
    
    func preview(urls: [URL], selectedIndex: Int) {
        self.urls = urls
        self.selectedIndex = selectedIndex
        
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = selectedIndex
        panel.makeKeyAndOrderFront(nil)
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }
}

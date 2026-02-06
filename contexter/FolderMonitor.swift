import Foundation

class FolderMonitor {
    private var monitor: DispatchSourceFileSystemObject?
    private let fileDescriptor: CInt
    var folderDidChange: (() -> Void)?

    init?(url: URL) {
        self.fileDescriptor = open(url.path, O_EVTONLY)
        guard self.fileDescriptor != -1 else { return nil }
        
        self.monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: DispatchQueue.main
        )
        
        self.monitor?.setEventHandler { [weak self] in
            self?.folderDidChange?()
        }
        
        self.monitor?.resume()
    }

    deinit {
        monitor?.cancel()
        close(fileDescriptor)
    }
}

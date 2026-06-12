import Foundation

/// Ghi log gõ phím ra file để tiện soi bug, song song với NSLog (Console.app).
/// File: ~/Library/Logs/Govi/typing.log — tail -f để xem realtime.
final class DebugLog {
    static let shared = DebugLog()

    private let queue = DispatchQueue(label: "org.govi.debuglog")
    private let url: URL
    private var handle: FileHandle?
    private let formatter: DateFormatter

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Govi", isDirectory: true)
        url = dir.appendingPathComponent("typing.log")
        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
    }

    /// Đường dẫn file log (để hiển thị cho người dùng).
    var path: String { url.path }

    /// Mở file (tạo nếu chưa có) và ghi 1 dòng header khi bật debug.
    func start() {
        queue.async { [self] in
            let fm = FileManager.default
            try? fm.createDirectory(at: url.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
            handle = try? FileHandle(forWritingTo: url)
            handle?.seekToEndOfFile()
            write(line: "==== Govi debug log bật lúc \(formatter.string(from: Date())) ====")
        }
    }

    /// Đóng file khi tắt debug.
    func stop() {
        queue.async { [self] in
            write(line: "==== Govi debug log tắt ====")
            try? handle?.close()
            handle = nil
        }
    }

    /// Ghi 1 dòng log (thread-safe, không chặn thread gõ phím).
    func log(_ message: String) {
        queue.async { [self] in write(line: "[\(formatter.string(from: Date()))] \(message)") }
    }

    private func write(line: String) {
        guard let handle, let data = (line + "\n").data(using: .utf8) else { return }
        handle.write(data)
    }
}

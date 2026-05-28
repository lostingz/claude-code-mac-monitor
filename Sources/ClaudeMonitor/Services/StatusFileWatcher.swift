import Foundation

final class StatusFileWatcher {
    private let filePath: String
    private let appState: AppState
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.claudemonitor.filewatcher")
    private var timer: DispatchSourceTimer?

    init(appState: AppState) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.filePath = "\(home)/.claude/monitor-status.json"
        self.appState = appState
    }

    func start() {
        ensureFileExists()
        readFile()
        startWatching()
        startPolling()
    }

    func stop() {
        source?.cancel()
        source = nil
        timer?.cancel()
        timer = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func ensureFileExists() {
        if !FileManager.default.fileExists(atPath: filePath) {
            FileManager.default.createFile(atPath: filePath, contents: "{}".data(using: .utf8))
        }
    }

    private func startWatching() {
        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("StatusFileWatcher: cannot open \(filePath)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.readFile()
        }

        source?.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
    }

    private func startPolling() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + 5, repeating: 5)
        timer?.setEventHandler { [weak self] in
            self?.readFile()
        }
        timer?.resume()
    }

    private func readFile() {
        guard let data = FileManager.default.contents(atPath: filePath),
              !data.isEmpty else { return }

        do {
            let statusData = try JSONDecoder().decode(StatusLineData.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.appState.updateFromStatusLine(statusData)
            }
        } catch {
            // silently ignore parse errors from partial writes
        }
    }
}

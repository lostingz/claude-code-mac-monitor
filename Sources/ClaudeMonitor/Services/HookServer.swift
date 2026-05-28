import Foundation
import Network

func debugLog(_ msg: String) {
    let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(msg)\n"
    let path = FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/monitor-debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

final class HookServer {
    private var listener: NWListener?
    private let port: UInt16
    private let appState: AppState
    private let queue = DispatchQueue(label: "com.claudemonitor.hookserver")

    init(port: UInt16 = 19806, appState: AppState) {
        self.port = port
        self.appState = appState
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("HookServer: failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("HookServer: listening on port \(self.port)")
            case .failed(let error):
                print("HookServer: failed: \(error)")
                self.listener?.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.start()
                }
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        debugLog("[HookServer] New connection")
        connection.start(queue: queue)
        receiveFullRequest(connection: connection, accumulated: Data())
    }

    private func receiveFullRequest(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data { buffer.append(data) }

            if let error {
                print("HookServer: receive error: \(error)")
                connection.cancel()
                return
            }

            if let request = self.tryParseHTTPRequest(buffer) {
                self.processRequest(request, connection: connection)
            } else if isComplete {
                if let request = self.tryParseHTTPRequest(buffer, lenient: true) {
                    self.processRequest(request, connection: connection)
                } else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "{}")
                }
            } else {
                self.receiveFullRequest(connection: connection, accumulated: buffer)
            }
        }
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private func tryParseHTTPRequest(_ data: Data, lenient: Bool = false) -> HTTPRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }

        let separator = Data("\r\n\r\n".utf8)
        guard let separatorRange = data.range(of: separator) else {
            if lenient { return parseWithoutContentLength(str, data: data) }
            return nil
        }

        let headerData = data[data.startIndex..<separatorRange.lowerBound]
        guard let headerSection = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let bodyStart = separatorRange.upperBound

        if let contentLengthStr = headers["content-length"],
           let contentLength = Int(contentLengthStr) {
            let bodyData = data[bodyStart...]
            if bodyData.count >= contentLength {
                let body = Data(bodyData.prefix(contentLength))
                return HTTPRequest(method: method, path: path, headers: headers, body: body)
            } else if lenient {
                return HTTPRequest(method: method, path: path, headers: headers, body: Data(bodyData))
            }
            return nil
        }

        let body = Data(data[bodyStart...])
        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }

    private func parseWithoutContentLength(_ str: String, data: Data) -> HTTPRequest? {
        let lines = str.split(separator: "\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        return HTTPRequest(method: String(parts[0]), path: String(parts[1]), headers: [:], body: data)
    }

    private func processRequest(_ request: HTTPRequest, connection: NWConnection) {
        guard request.method == "POST" else {
            debugLog("[HookServer] Not POST")
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let decoder = JSONDecoder()
        let event: HookEvent
        do {
            event = try decoder.decode(HookEvent.self, from: request.body)
        } catch {
            debugLog("[HookServer] JSON decode error")
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let eventName = event.hookEventName ?? ""
        debugLog("[HookServer] Event: \(eventName) tool: \(event.toolName ?? "-")")

        if eventName == "PermissionRequest" {
            handlePermissionRequest(event: event, connection: connection)
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.appState.handleHookEvent(event)
        }

        sendResponse(connection: connection, statusCode: 200, body: "{}")
    }

    private var pendingConnections: [UUID: NWConnection] = [:]

    private func handlePermissionRequest(event: HookEvent, connection: NWConnection) {
        let toolName = event.toolName ?? "Unknown"
        let toolInput = event.toolInput
        let sessionId = event.sessionId ?? ""
        debugLog("[HookServer] PermissionRequest for: \(toolName)")

        let request = ApprovalRequest(
            toolName: toolName,
            toolInput: toolInput,
            sessionId: sessionId,
            timestamp: Date()
        ) { [weak self] allowed in
            debugLog("[HookServer] User decided: \(allowed ? "ALLOW" : "DENY")")
            let behavior = allowed ? "allow" : "deny"
            let response = PermissionResponse(
                hookSpecificOutput: PermissionHookOutput(
                    hookEventName: "PermissionRequest",
                    decision: PermissionDecision(behavior: behavior)
                )
            )

            if let jsonData = try? JSONEncoder().encode(response),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                self?.sendResponse(connection: connection, statusCode: 200, body: jsonStr)
            } else {
                self?.sendResponse(connection: connection, statusCode: 200, body: "{}")
            }

            DispatchQueue.main.async {
                self?.appState.status = .working
                self?.appState.pendingApproval = nil
            }
        }

        pendingConnections[request.id] = connection

        DispatchQueue.main.async { [weak self] in
            self?.appState.status = .waitingApproval
            self?.appState.pendingApproval = request
            ClaudeMonitorApp.showApproval(request)
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        default: statusText = "Error"
        }

        let response = "HTTP/1.1 \(statusCode) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"

        connection.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

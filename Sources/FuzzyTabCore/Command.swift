import Foundation

public struct CommandError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
}

enum Command {
    /// Runs an executable and returns its stdout. Throws with stderr on a non-zero exit.
    static func run(_ executable: URL, _ arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(with: Result { try runBlocking(executable, arguments) })
            }
        }
    }

    private static func runBlocking(_ executable: URL, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()

        // Drain stderr concurrently so a full pipe buffer cannot block the child.
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errBox.data = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let out = stdout.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let text = String(decoding: errBox.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw CommandError(message: text.isEmpty ? "\(executable.lastPathComponent) exited with status \(process.terminationStatus)" : text)
        }
        return out
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

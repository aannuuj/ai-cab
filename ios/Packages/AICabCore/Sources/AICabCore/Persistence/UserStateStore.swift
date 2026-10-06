import Foundation

/// Abstracts where learner state lives, so the app model can be tested with an in-memory store.
public protocol UserStateStoring: Sendable {
    func load() -> UserState?
    func save(_ state: UserState) throws
}

public struct FileUserStateStore: UserStateStoring {
    private let file: JSONFile<UserState>

    public init(directory: URL = SharedContainer.url) {
        file = JSONFile(url: directory.appendingPathComponent("user-state.json"))
    }

    public func load() -> UserState? { file.read() }

    public func save(_ state: UserState) throws { try file.write(state) }
}

public final class InMemoryUserStateStore: UserStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var state: UserState?

    public init(state: UserState? = nil) {
        self.state = state
    }

    public func load() -> UserState? {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func save(_ state: UserState) throws {
        lock.lock()
        defer { lock.unlock() }
        self.state = state
    }
}

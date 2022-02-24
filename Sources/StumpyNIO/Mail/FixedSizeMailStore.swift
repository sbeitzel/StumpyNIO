//
//  FixedSizeMailStore.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 12/31/20.
//

#if os(macOS)
import Foundation
#else
import Foundation
import OpenCombineShim
#endif

/// A `MailStore` implementation that holds up to a specified number of messages
/// in memory. Once the limit is reached, adding a new message will evict the oldest
/// message.
public actor FixedSizeMailStore: MailStore, ObservableObject, Identifiable {
    nonisolated public let id: String

    private var maxSize: Int
    private var messages = [MailMessage]()

    /// Creates a FixedSizeMailStore configured to hold up to the given number of messages.
    /// - Parameter size: the maximum number of messages this store will contain
    public init(size: Int, id: String = UUID().uuidString) {
        maxSize = size
        self.id = id
    }

    public func messageCount() async -> Int {
        return messages.count
    }

    public func adjustSize(to size: Int) {
        guard size > 0 else { return }
        maxSize = size
        while messages.count > maxSize {
            messages.remove(at: 0)
        }
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    /// Appends a new message to the store. If this would result in the store
    /// holding more than its maximum number of messages, the oldest message
    /// in the store will be evicted at the same time, making room for the new one.
    /// - Parameter message: the new message to add to the store
    public func add(message: MailMessage) async {
        messages.append(message)
        while messages.count > maxSize {
            messages.remove(at: 0)
        }
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func list() async -> [MailMessage] {
        let messagesCopy = messages
        return messagesCopy
    }

    public func get(message: Int) async throws -> MailMessage {
        guard message >= 0 && message < messages.count else { throw MailStoreError.invalidIndex }
        return messages[message]
    }

    public func clear() async {
        messages.removeAll()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func delete(message: Int) async throws {
        guard message >= 0 && message < messages.count else { throw MailStoreError.invalidIndex }
        _ = messages.remove(at: message)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

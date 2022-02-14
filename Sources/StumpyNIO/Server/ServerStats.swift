//
//  ServerStats.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/22/22.
//

#if os(macOS)
import Foundation
#else
import Foundation
import OpenCombineShim
#endif

public class ServerStats: ObservableObject {
    private var numConnections: Int = 0
    private let connectionLock = NSLock()
    public var connections: Int {
        defer { connectionLock.unlock() }
        connectionLock.lock()
        return numConnections
    }

    func increaseConnectionCount() {
        defer { connectionLock.unlock() }
        connectionLock.lock()
        numConnections += 1
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func decreaseConnectionCount() {
        defer { connectionLock.unlock() }
        connectionLock.lock()
        numConnections -= 1
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

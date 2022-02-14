//
//  BaseServer.swift
//  
//
//  Created by Stephen Beitzel on 1/26/22.
//

#if os(macOS)
import Foundation
#else
import Foundation
import OpenCombineShim
#endif
import Logging
import NIO

public class BaseServer: ObservableObject {
    private var logger: Logger
    private let mailStore: MailStore
    private var port: Int
    public var serverPort: Int {
        get {
            port
        }
        set {
            if isRunning == false {
                port = newValue
            } else {
                logger.warning("Attempted to change port while server is running! Port not changed.")
            }
        }
    }
    private let label: String
    private let bootstrap: ServerBootstrap
    private var serverChannel: Channel?

    @Published public var isRunning: Bool = false
    public let serverStats: ServerStats

    public init(group: EventLoopGroup,
                port: Int,
                store: MailStore = FixedSizeMailStore(size: 10),
                label: String,
                stats: ServerStats,
                handlers: [ChannelHandler]) {
        self.label = label
        logger = Logger(label: label)
        logger[metadataKey: "origin"] = "[\(label)]"
        serverStats = stats
        self.port = port
        self.mailStore = store
        self.bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers(handlers)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    }

    public func run() {
        if !isRunning {
            isRunning = true
            Task {
                do {
                    serverChannel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
                    logger.info("Server started, listening on address: \(serverChannel!.localAddress!.description)")
                    try serverChannel!.closeFuture.wait()
                    logger.info("Server stopped.")
                    DispatchQueue.main.async {
                        self.isRunning = false
                    }
                } catch {
                    logger.critical("Error running \(label) server: \(error.localizedDescription)")
                }
            }
        }
    }

    public func runReturning() throws -> EventLoopFuture<Void> {
        DispatchQueue.main.async {
            self.isRunning = true
        }
        serverChannel = try bootstrap.bind(host: "0.0.0.0", port: serverPort).wait()
        logger.info("Server started, listening on address: \(serverChannel!.localAddress!.description)")
        serverChannel!.closeFuture.whenComplete({ _ in
            DispatchQueue.main.async {
                self.logger.info("Server stopped.")
                self.isRunning = false
            }
        })
        return serverChannel!.closeFuture
    }

    public func stop() {
        if let channel = serverChannel {
            self.logger.info("\(label) server shutting down")
            _ = channel.close(mode: CloseMode.all)
            self.serverChannel = nil
        }
    }
}

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
    private let group: EventLoopGroup
    private var handlers: [ChannelHandler]
    private var serverChannels: [Channel] = []

    @Published public var isRunning: Bool = false
    public let serverStats: ServerStats

    public init(group: EventLoopGroup,
                port: Int,
                store: MailStore = FixedSizeMailStore(size: 10),
                label: String,
                stats: ServerStats,
                handlers: [ChannelHandler]) {
        self.handlers = handlers
        self.label = label
        self.group = group
        self.serverStats = stats
        self.port = port
        self.mailStore = store
        self.logger = Logger(label: label)
        logger[metadataKey: "origin"] = "[\(label)]"
    }

    public func setHandlers(to handlerList: [ChannelHandler]) -> Bool {
        guard isRunning == false else { return false }
        handlers = handlerList
        return true
    }

    func makeBootstrap() -> ServerBootstrap {
        return ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers(self.handlers)
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
                    let bootstrap = makeBootstrap()
                    var success = false
                    for address in ["::", "0.0.0.0"] {
                        logger.info("Trying to start on host: \(address)")
                        do {
                            if !success {
                                let serverChannel = try bootstrap.bind(host: address, port: port).wait()
                                self.serverChannels.append(serverChannel)
                                logger.info("Server started, listening on address: \(serverChannel.localAddress!.description)")
                                success = true
                            }
                        } catch {
                            // unable to bind to that address. Oh well.
                            logger.debug("Unable to bind to \(address): \(error.localizedDescription)")
                        }
                    }
                    if !serverChannels.isEmpty {
                        try serverChannels.first!.closeFuture.wait()
                        logger.info("Server stopped.")
                        DispatchQueue.main.async {
                            self.isRunning = false
                        }
                    } else {
                        logger.critical("Unable to start a server!")
                        throw ServerError.errorStarting
                    }
                } catch {
                    logger.critical("Error running \(label) server: \(error.localizedDescription)")
                    for channel in serverChannels {
                        do {
                            try await channel.close()
                        } catch {
                            self.logger.info("Error closing channel: \(error.localizedDescription)")
                        }
                    }
                    serverChannels.removeAll()
                    DispatchQueue.main.async {
                        self.isRunning = false
                    }
                }
            }
        }
    }

    public func runReturning() throws -> EventLoopFuture<Void> {
        DispatchQueue.main.async {
            self.isRunning = true
        }
        let bootstrap = makeBootstrap()
        for address in ["0.0.0.0", "::"] {
            let serverChannel = try bootstrap.bind(host: address, port: port).wait()
            serverChannels.append(serverChannel)
            logger.info("Server started, listening on address: \(serverChannel.localAddress!.description)")
        }
        if let channel = serverChannels.first {
            channel.closeFuture.whenComplete({ _ in
                DispatchQueue.main.async {
                    self.logger.info("Server stopped.")
                    self.serverChannels.removeAll()
                    self.isRunning = false
                }
            })
            return channel.closeFuture
        }
        throw ServerError.errorStarting
    }

    public func stop() {
        for channel in serverChannels {
            logger.info("\(label) server shutting down")
            _ = channel.close(mode: CloseMode.all)
        }
        serverChannels.removeAll()
    }
}

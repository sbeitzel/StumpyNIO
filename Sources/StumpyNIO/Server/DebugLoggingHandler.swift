//
//  DebugLoggingHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/21/22.
//

import Foundation
import Logging
import NIOCore

final class DebugLoggingHandler: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer

    let logger: Logger

    init() {
        var aLogger = Logger(label: "DebugLogging")
        aLogger.logLevel = .trace
        aLogger[metadataKey: "origin"] = "[DebugLoggingHandler]"
        logger = aLogger
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inBuffer = unwrapInboundIn(data)
        let inString = inBuffer.getString(at: 0, length: inBuffer.readableBytes) ?? ""
        logger.trace("Read", metadata: ["data": "\(inString)"])
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let inBuffer = unwrapOutboundIn(data)
        let inString = inBuffer.getString(at: 0, length: inBuffer.readableBytes) ?? ""
        logger.trace("Write", metadata: ["data": "\(inString)"])
        _ = context.write(data)
    }
}

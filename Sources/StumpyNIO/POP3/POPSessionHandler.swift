//
//  POPSessionHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/18/22.
//

import Foundation
import NIO

final class POPSessionHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = POPSessionState

    let sessionState: POPSessionState

    init(with store: MailStore,
         hostName: String) {
        sessionState = POPSessionState(with: store, hostName: hostName)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // this is how you turn a buffer into a string
        // first, get the buffer -- unwrapInboundIn does typecasting
        let inBuffer = unwrapInboundIn(data)
        let inString = inBuffer.getString(at: 0, length: inBuffer.readableBytes) ?? ""

        sessionState.inputLine = inString
        sessionState.action = nil

        context.fireChannelRead(wrapInboundOut(sessionState))
    }

    func channelActive(context: ChannelHandlerContext) {
        // The format of this banner advertises that this server is capable of APOP
        // authentication.
        let now = Date()
        // string of the form "<sessionID.timestamp@host>"
        // If we were writing a server that actually implemented multi-mailbox and user security
        // then we'd care more about this. The one thing we should care about is that this string
        // is different for each request.
        // swiftlint:disable:next line_length
        let message = "+OK Stumpy POP3 server ready <\(sessionState.sessionID).\(now.timeIntervalSinceReferenceDate)@\(sessionState.hostName)>\n"
        var outBuff = context.channel.allocator.buffer(capacity: message.count)
        outBuff.writeString(message)

        context.writeAndFlush(NIOAny(outBuff), promise: nil)
        sessionState.popState = .authorization
        context.fireChannelActive()
    }
}

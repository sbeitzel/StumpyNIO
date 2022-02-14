//
//  SMTPSessionHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/16/22.
//

import Foundation
import NIO

final class SMTPSessionHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = SMTPSessionState

    let sessionState: SMTPSessionState

    init(with store: MailStore, acceptMultipleMails: Bool) {
        sessionState = SMTPSessionState(with: store, allowMultipleMail: acceptMultipleMails)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // this is how you turn a buffer into a string
        // first, get the buffer -- unwrapInboundIn does typecasting
        let inBuffer = unwrapInboundIn(data)
        let inString = inBuffer.getString(at: 0, length: inBuffer.readableBytes) ?? ""

        sessionState.inputLine = inString

        context.fireChannelRead(wrapInboundOut(sessionState))
    }

    func channelActive(context: ChannelHandlerContext) {
        let banner = "220 Stumpy SMTP service ready\r\n"
        var outBuff = context.channel.allocator.buffer(capacity: banner.count)
        outBuff.writeString(banner)

        context.writeAndFlush(NIOAny(outBuff), promise: nil)
        sessionState.smtpState = .greet
        context.fireChannelActive()
    }
}

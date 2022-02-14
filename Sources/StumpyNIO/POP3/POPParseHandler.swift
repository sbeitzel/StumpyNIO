//
//  POPParseHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/18/22.
//

import Foundation
import NIO

final class POPParseHandler: ChannelInboundHandler {
    typealias InboundIn = POPSessionState
    typealias InboundOut = POPSessionState

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let sessionState = unwrapInboundIn(data)

        parseIncoming(state: sessionState)

        context.fireChannelRead(wrapInboundOut(sessionState))
    }

    // swiftlint:disable:next function_body_length
    func parseIncoming(state: POPSessionState) {
        let ucLine = state.inputLine.uppercased()
        var params = state.inputLine
        switch state.popState {
        case .quit:
            state.params = ""
            state.action = .quit
        case .authorization:
            if ucLine.hasPrefix("USER") {
                state.action = .user
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if ucLine.hasPrefix("PASS") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .password
            } else if ucLine.hasPrefix("APOP") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .apop
            } else if ucLine.hasPrefix("QUIT") {
                state.params = ""
                state.action = .quit
            } else if ucLine.hasPrefix("CAPA") {
                state.params = ""
                state.action = .capa
            } else {
                state.params = ""
                state.action = .invalid
            }
        case .transaction:
            if ucLine.hasPrefix("CAPA") {
                state.params = ""
                state.action = .capa
            } else if ucLine.hasPrefix("STAT") {
                state.params = ""
                state.action = .status
            } else if ucLine.hasPrefix("LIST") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .list
            } else if ucLine.hasPrefix("RETR") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .retrieve
            } else if ucLine.hasPrefix("DELE") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .delete
            } else if ucLine.hasPrefix("NOOP") {
                state.params = ""
                state.action = .noop
            } else if ucLine.hasPrefix("QUIT") {
                state.params = ""
                state.action = .quit
            } else if ucLine.hasPrefix("RSET") {
                state.params = ""
                state.action = .reset
            } else if ucLine.hasPrefix("TOP") {
                params.removeFirst(3)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .top
            } else if ucLine.hasPrefix("UIDL") {
                params.removeFirst(4)
                state.params = params.trimmingCharacters(in: .whitespacesAndNewlines)
                state.action = .uidl
            } else {
                state.params = ""
                state.action = .invalid
            }
        }
    }

}

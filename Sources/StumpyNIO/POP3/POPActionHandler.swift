//
//  POPActionHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/18/22.
//

import Foundation
import Logging
import NIO

final class POPActionHandler: ChannelInboundHandler {
    typealias InboundIn = POPSessionState
    typealias InboundOut = ByteBuffer

    var logger: Logger

    init() {
        logger = Logger(label: "POPActionHandler")
        logger[metadataKey: "origin"] = "[POP]"
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let sessionState = unwrapInboundIn(data)

        Task {
            var response = await performAction(sessionState)
            if !response.hasSuffix("\r\n") {
                response.append("\r\n")
            }

            context.eventLoop.execute {
                var outBuffer = context.channel.allocator.buffer(capacity: response.count)
                outBuffer.writeString(response)
                context.writeAndFlush(self.wrapInboundOut(outBuffer), promise: nil)
                if sessionState.popState == .quit {
                    _ = context.close()
                }
            }
        }
    }

    private func scanListing(_ index: Int, _ message: MailMessage) -> String {
        let messageBytes = message.toString().lengthOfBytes(using: .utf8)
        return "\(index) \(messageBytes)\r\n"
    }

    func delete(_ state: POPSessionState) async -> String {
        var response: String
        do {
            if let index = Int(state.params) {
                // here's something weird: list index is 0 based, but delete index is 1 based
                try await state.mailStore.delete(message: index - 1)
                response = "+OK Message deleted\r\n"
            } else {
                response = "-ERR Invalid message index\r\n"
            }
        } catch {
            response = "-ERR Invalid message index\r\n"
        }
        return response
    }

    func list(_ state: POPSessionState) async -> String {
        var response: String
        do {
            if let index = Int(state.params) {
                let message = try await state.mailStore.get(message: index)
                response = "+OK "+scanListing(index+1, message)
            } else {
                let messages = await state.mailStore.list()
                let count = messages.count
                response = "+OK \(count) messages\r\n"
                for index in 0 ..< count {
                    response.append(scanListing(index + 1, messages[index]))
                }
                response.append(".\r\n")
            }
        } catch {
            logger.error("Error generating listing: \(error.localizedDescription)",
                         metadata: ["params": "\(state.params)"])
            response = "-ERR Server error while generating listing\r\n"
        }
        return response
    }

    func retrieve(_ state: POPSessionState) async -> String {
        var response: String
        if let index = Int(state.params.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let messageCount = await state.mailStore.messageCount()
            if index > 0 && index <= messageCount {
                do {
                    let message = try await state.mailStore.get(message: index-1)
                    var messageString = message.byteStuff()
                    let bytes = messageString.maximumLengthOfBytes(using: .utf8)
                    messageString.append("\r\n.\r\n")
                    response = "+OK \(bytes) octets\r\n\(messageString)"
                } catch {
                    logger.error("Error retrieving message: \(error.localizedDescription)")
                    response = "-ERR Server error retrieving message\r\n"
                }
            } else {
                response = "-ERR No message at index \(index)\r\n"
            }
        } else {
            response = "-ERR No such message\r\n"
        }
        return response
    }

    func uidl(_ state: POPSessionState) async -> String {
        var response: String
        if let index = Int(state.params.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let messageCount = await state.mailStore.messageCount()
            if index > 0 && index < messageCount {
                do {
                    let message = try await state.mailStore.get(message: index - 1)
                    response = "+OK \(index) \(message.uid)\r\n.\r\n"
                } catch {
                    logger.error("Error getting message: \(error.localizedDescription)",
                                 metadata: ["index": "\(index - 1)"])
                    response = "-ERR Server error while getting message"
                }
            } else {
                response = "-ERR Invalid message index"
            }
        } else {
            // all messages
            response = "+OK\r\n"
            let messages = await state.mailStore.list()
            for index in 0 ..< messages.count {
                let message = messages[index]
                response.append("\(index + 1) \(message.uid)\r\n")
            }
            response.append(".\r\n")
        }
        return response
    }

    // swiftlint:disable:next function_body_length
    func performAction(_ state: POPSessionState) async -> String {
        var response = ""
        if let action = state.action {
            switch action {
            case .apop:
                state.popState = .transaction
                response = "+OK You're okay\r\n"
            case .capa:
                response = """
+OK List of capabilities follows\r\nUSER PASS\r\nUIDL\r\nIMPLEMENTATION Stumpy POP3 v1.1\r\n.\r\n
"""
            case .invalid:
                response = "-ERR Unknown/invalid command\r\n"
            case .delete:
                if state.popState != .transaction {
                    response = "-ERR Invalid command for state\r\n"
                } else {
                    response = await delete(state)
                }
            case .list:
                if state.popState != .transaction {
                    response = "-ERR Invalid command for state\r\n"
                } else {
                    response = await list(state)
                }
            case .noop:
                response = "+OK\r\n"
            case .password:
                if state.popState == .authorization {
                    response = "+OK mailbox ready\r\n"
                    state.popState = .transaction
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            case .quit:
                state.popState = .quit
                response = "+OK Goodbye\r\n"
            case .reset:
                // If this were a real POP3 server, this action would undelete any messages marked for deletion during
                // this session. Rather that do that, we're just saying, sure, it's been undeleted. This might
                // (probably will) confuse email clients that try to be clever about maintaining state on their side.
                if state.popState == .transaction {
                    response = "+OK Stumpy doesn't really undelete\r\n"
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            case .retrieve:
                if state.popState == .transaction {
                    response = await retrieve(state)
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            case .status:
                if state.popState == .transaction {
                    let messages = await state.mailStore.list()
                    var size: UInt64 = 0
                    for message in messages {
                        size += UInt64(message.byteStuff().maximumLengthOfBytes(using: .utf8))
                    }
                    response = "+OK \(messages.count) \(size)\r\n"
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            case .top:
                // not yet implemented
                response = "-ERR Unsupported command\r\n"
            case .uidl:
                if state.popState == .transaction {
                    response = await uidl(state)
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            case .user:
                if state.popState == .authorization {
                    response = "+OK\r\n"
                } else {
                    response = "-ERR Invalid command for this state\r\n"
                }
            }
        }
        return response
    }
}

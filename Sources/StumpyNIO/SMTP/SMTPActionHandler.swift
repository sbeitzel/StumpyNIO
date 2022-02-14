//
//  SMTPActionHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/17/22.
//

import Foundation
import Logging
import NIO

// This is the big state machine, where we look at the current state,
// what the incoming action is, and how we should mutate the state
// and what message we should send back to the client.

// swiftlint:disable:next type_body_length
final class SMTPActionHandler: ChannelInboundHandler {
    typealias InboundIn = SMTPSessionState
    typealias InboundOut = ByteBuffer

    var logger: Logger

    init() {
        logger = Logger(label: "SMTPActionHandler")
        logger.logLevel = .info
        logger[metadataKey: "origin"] = "[SMTP]"
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let currentState = unwrapInboundIn(data)
        var gotTermination = false

        // now, we look at the line that came in and turn it into an action
        if currentState.smtpState != .dataBody && currentState.smtpState != .dataHeader {
            processMessage(currentState)
        } else {
            // we need to buffer all the incoming data until we get the termination sequence.
            // Once we get that, *then* we can process the message data.
            currentState.accumulatedData.append(currentState.inputLine)
            // check for termination
            gotTermination = currentState.accumulatedData
                .data(using: .utf8)?.lines().contains(where: { $0 == "." }) ?? false
        }

        // Figuring out what comes next might take some time. We're going
        // to go async and do that work, and the rest of the pipeline
        // will just wait for us.
        if gotTermination || (currentState.smtpState != .dataHeader && currentState.smtpState != .dataBody) {
            spinTask(context: context, currentState: currentState)
        }
    }

    private func spinTask(context: ChannelHandlerContext, currentState: SMTPSessionState) {
        Task {
            var response: SMTPResponse = .badSequence
            if currentState.smtpState == .dataHeader || currentState.smtpState == .dataBody {
                // this could be a multi-line sequence. The whole message, in fact.
                // SO we need to split it up and process line by line.
                let lines = currentState.accumulatedData.data(using: .utf8)?.lines() ?? []
                if lines.isEmpty {
                    logger.trace("Only one line incoming", metadata: ["line": "\(currentState.inputLine)"])
                    response = await doAThing(currentState: currentState)
                } else {
                    for line in lines {
                        logger.trace("Processing line", metadata: ["line": "\(line)"])
                        currentState.inputLine = String(line)
                        if currentState.smtpState == .dataHeader {
                            logger.trace("It's a header")
                            processDataHeaderMessage(currentState)
                        } else if currentState.smtpState == .dataBody {
                            logger.trace("It's a body line")
                            processDataBodyMessage(currentState)
                        }
                        response = await doAThing(currentState: currentState)
                        if currentState.smtpState == .quit || // session end
                            currentState.smtpState == .mail || // done with the message
                            response.code > 299 // error condition
                        { break }
                    }
                }
                // and finally, we send a response message back to the client
                if currentState.smtpState != .dataBody &&
                    currentState.smtpState != .dataHeader {
                    sendResponse(context: context, currentState: currentState, response: response)
                }
            } else {
                response = await doAThing(currentState: currentState)
                sendResponse(context: context, currentState: currentState, response: response)
            }
        }
    }

    private func sendResponse(context: ChannelHandlerContext,
                              currentState: SMTPSessionState,
                              response: SMTPResponse) {
        var respMessage = ""
        if response.code > 0 {
            // we send back the numeric code -- unless we're just accepting
            // data for a mail message
            respMessage.append("\(response.code) \(response.message)")
        }
        context.eventLoop.execute {
            if !(respMessage.hasSuffix("\r\n") || respMessage.hasSuffix("\n") || respMessage.isEmpty) {
                respMessage.append("\n")
            }
            var outBuffer = context.channel.allocator.buffer(capacity: respMessage.count)
            outBuffer.writeString(respMessage)
            context.writeAndFlush(self.wrapInboundOut(outBuffer), promise: nil)
            if currentState.smtpState == .quit {
                _ = context.close()
            }
        }
    }

    private func doAThing(currentState: SMTPSessionState) async -> SMTPResponse {
        let response = await computeResponse(currentState)
        // now, we *might* want to mutate the current message
        store(currentState)
        // and we *might* want to put the message into the mail store
        if currentState.smtpState == .quit // end session
            || currentState.smtpState == .mail // end of message
        {
            if hasMessageIDHeader(currentState.workingMessage) {
                let saveMessage = currentState.workingMessage
                currentState.workingMessage = MemoryMessage()
                currentState.accumulatedData = ""
                Task {
                    await currentState.mailstore.add(message: saveMessage)
                }
            } else {
                logger.info("No message-id header, so not saving the working message")
            }
        }
        return response
    }

    /// The RFC states that there should be a message-id header, but it neglects to
    /// specify the capitalization. Apple Mail creates "Message-Id" while Thunderbird
    /// creates "Message-ID". So this method just uppercases all the headers and
    /// returns true if any of them are "MESSAGE-ID", since apparently the Internet
    /// doesn't care.
    /// - Returns: true if there's a message ID
    private func hasMessageIDHeader(_ message: MailMessage) -> Bool {
        for header in message.headers.keys {
            if header.uppercased() == "MESSAGE-ID" {
                logger.trace("Found a message ID header: \(header)")
                return true
            }
        }
        return false
    }

    func store(_ state: SMTPSessionState) {
        if let input = state.command?.parameters {
            if !input.isEmpty {
                logger.trace("storing input to message", metadata: ["input": "\(input)"])
                if state.smtpState == .dataHeader {
                    logger.trace("storing a header")
                    // this is either a header ('X-Sender: foo@mx.place') or it's
                    // a header continuation (that is, it's a second value that we should add
                    // to the last header we processed)
                    let isNewHeader = input.contains(":")
                    if isNewHeader {
                        logger.trace("new header")
                        let start = input.firstIndex(of: ":")
                        let header = String(input[input.startIndex ..< start!])
                        var value: String
                        value = String(input[start! ..< input.endIndex])
                        value.removeFirst()
                        state.workingMessage.set(value: value, for: header)
                        state.lastHeader = header
                    } else {
                        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.workingMessage.appendHeader(value: value, to: state.lastHeader)
                    }
                } else if state.smtpState == .dataBody {
                    logger.trace("appending line to message", metadata: ["line": "\(input)"])
                    state.workingMessage.append(line: input)
                } else {
                    logger.trace("SMTP state is: \(state.smtpState); no input stored to message")
                }
            } else {
                logger.trace("input line is empty, not writing to message")
            }
        } else {
            // we don't have a command at all
            logger.warning("No command to act on!", metadata: ["input": "\(state.inputLine)"])
        }
    }

    // swiftlint:disable:next function_body_length
    func computeResponse(_ state: SMTPSessionState) async -> SMTPResponse {
        if let command = state.command {
            switch command.action {
            case .blankLine:
                if state.smtpState == .dataHeader {
                    // blank line separates headers from body
                    state.smtpState = .dataBody
                    return SMTPResponse(code: -1, message: "")
                } else if state.smtpState == .dataBody {
                    return SMTPResponse(code: -1, message: "")
                } else {
                    return .badSequence
                }

            case .data:
                if state.smtpState == .rcpt {
                    state.smtpState = .dataHeader
                    return SMTPResponse(code: 354,
                                        message: "Start mail input; end with <CRLF>.<CRLF>")
                } else {
                    return .badSequence
                }

            case .dataEnd:
                if state.smtpState == .dataBody || state.smtpState == .dataHeader {
                    state.smtpState = state.mailEndState
                    return SMTPResponse(code: 250,
                                        message: "OK, message accepted for delivery")
                } else {
                    return .badSequence
                }

            case .helo:
                if state.smtpState == .greet {
                    state.smtpState = .mail
                    return SMTPResponse(code: 250,
                                        message: "Hello \(command.parameters)")
                } else {
                    return .badSequence
                }

            case .ehlo:
                if state.smtpState == .greet {
                    state.clear()
                    state.smtpState = .mail
                    return SMTPResponse(code: 250,
                                        message: "local.stumpy Hello \(command.parameters)\n250 OK")
                } else {
                    return .badSequence
                }

            case .expn:
                return SMTPResponse(code: 252,
                                    message: "Not supported")

            case .help:
                return SMTPResponse(code: 211,
                                    message: "No help available")

            case .list: // not an SMTP command, this is to allow for inspection of the mailstore
                var messageIndex: Int?
                if !command.parameters.isEmpty {
                    messageIndex = Int(command.parameters.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                var result = ""
                let messages = await state.mailstore.list()
                // swiftlint:disable:next identifier_name
                if let mi = messageIndex {
                    if mi > -1 && mi < messages.count-1 {
                        result.append("\n-------------------------------------------\n")
                        result.append(messages[mi].toString())
                    }
                }
                result.append("There are \(messages.count) messages")
                return SMTPResponse(code: 250,
                                    message: result)

            case .mail:
                if state.smtpState == .mail || state.smtpState == .quit {
                    state.smtpState = .rcpt
                    return SMTPResponse(code: 250, message: "OK")
                } else {
                    return .badSequence
                }

            case .noop:
                return SMTPResponse(code: 250, message: "OK")

            case .quit:
                state.smtpState = .quit
                return SMTPResponse(code: 221,
                                    message: "Stumpy SMTP service closing transmission channel")

            case .rcpt:
                if state.smtpState == .rcpt {
                    return SMTPResponse(code: 250, message: "OK")
                } else {
                    return .badSequence
                }

            case .rset:
                state.clear()
                if state.smtpState != .greet {
                    state.smtpState = .mail
                }
                return SMTPResponse(code: 250, message: "OK")

            case .vrfy:
                return SMTPResponse(code: 252, message: "Not Supported")

            case .unknown:
                if state.smtpState == .dataHeader || state.smtpState == .dataBody {
                    return SMTPResponse(code: -1, message: "")
                } else {
                    return SMTPResponse(code: 500, message: "Command not recognized")
                }
            }
        } else {
            logger.critical("There's no command!!!")
            return .badSequence
        }
    }

    // swiftlint:disable:next function_body_length
    func processMessage(_ state: SMTPSessionState) {
        let allCaps = state.inputLine.uppercased()
        var params = state.inputLine
        if allCaps.hasPrefix("EHLO ") {
            if params.count > 5 {
                params.removeFirst(5)
            } else {
                params = ""
            }
            state.command = SMTPCommand(action: .ehlo,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("HELO") {
            if params.count > 5 {
                params.removeFirst(5)
            } else {
                params = ""
            }
            state.command = SMTPCommand(action: .helo,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("MAIL FROM:") {
            params.removeFirst(10)
            state.command = SMTPCommand(action: .mail,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("RCPT TO:") {
            params.removeFirst(8)
            state.command = SMTPCommand(action: .rcpt,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("DATA") {
            state.command = SMTPCommand(action: .data, parameters: "")
        } else if allCaps.hasPrefix("QUIT") {
            state.command = SMTPCommand(action: .quit, parameters: "")
        } else if allCaps.hasPrefix("RSET") {
            state.command = SMTPCommand(action: .rset, parameters: "")
        } else if allCaps.hasPrefix("NOOP") {
            state.command = SMTPCommand(action: .noop, parameters: "")
        } else if allCaps.hasPrefix("EXPN") {
            params.removeFirst(4)
            state.command = SMTPCommand(action: .expn,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("VRFY") {
            params.removeFirst(4)
            state.command = SMTPCommand(action: .vrfy,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if allCaps.hasPrefix("HELP") {
            state.command = SMTPCommand(action: .help, parameters: "")
        } else if allCaps.hasPrefix("XLIST") { // not actually an SMTP command; allows inspecting the mail store
            params.removeFirst(5)
            state.command = SMTPCommand(action: .list,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            state.command = SMTPCommand(action: .unknown,
                                        parameters: params.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func processDataHeaderMessage(_ state: SMTPSessionState) {
        if state.inputLine.trimmingCharacters(in: .whitespacesAndNewlines) == "." {
            state.command = SMTPCommand(action: .dataEnd, parameters: "")
        } else if state.inputLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.command = SMTPCommand(action: .blankLine, parameters: "")
        } else {
            state.command = SMTPCommand(action: .unknown,
                                        parameters: state.inputLine.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func processDataBodyMessage(_ state: SMTPSessionState) {
        if state.inputLine.trimmingCharacters(in: .whitespacesAndNewlines) == "." {
            state.command = SMTPCommand(action: .dataEnd, parameters: "")
        } else if state.inputLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.command = SMTPCommand(action: .unknown, parameters: "\n")
        } else {
            state.command = SMTPCommand(action: .unknown, parameters: state.inputLine)
        }
    }
}

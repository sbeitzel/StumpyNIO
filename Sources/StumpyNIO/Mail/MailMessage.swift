//
//  MailMessage.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 12/31/20.
//

import Foundation

/// Protocol defining how an email message must behave
public protocol MailMessage {
    /// Dictionary of header name to list of one or more values
    var headers: [String: [String]] { get }

    /// Set the value of the specified header
    /// - Parameters:
    ///   - value: the value to set
    ///   - header: the header to set
    func set(value: String, for header: String)

    /// Add a given value to the specified header. If the header already has
    /// a value, the new value will be added; if the header does not have a value,
    /// it will be created.
    /// - Parameters:
    ///   - value: the value to set
    ///   - header: the header
    func add(value: String, to header: String)

    /// If a header already has value(s), then the provided value will be appended to the last
    /// value the header contains. If the header has no values, then the one provided will
    /// be the first.
    /// - Parameters:
    ///   - value: the value to append to the header's last value
    ///   - header: the header to modify
    func appendHeader(value: String, to header: String)

    /// The body of the message
    var body: String { get }

    /// Append a line of text to the message body.
    /// - Parameter line: the line to add
    func append(line: String)

    /// Message UUID. This is required by the POP3 protocol.
    var uid: String { get }

    /// The complete message, both headers and body, appropriately formatted
    /// for POP3.
    ///
    /// The POP3 protocol requires that the message body be 'byte stuffed'
    /// to escape the termination sequence: `\r\n.\r\n`
    func byteStuff() -> String

    /// Render the message as a string, with no special escaping.
    func toString() -> String
}

// MARK: Rendering the complete message to text
extension MailMessage {
    public func byteStuff() -> String {
        // start off with the headers, each header separated by CRLF
        var messageString: String = headers.map { key, values in
            let valueString = values.joined(separator: ", ")
            return "\(key): \(valueString)"
        }
        .joined(separator: "\r\n")

        // the headers are separated from the body by a CRLF
        messageString += "\r\n\r\n"

        messageString += body.replacingOccurrences(of: "\r\n.\r\n", with: "\r\n..\r\n")

        return messageString
    }

    public func toString() -> String {
        var msg: String = headers.map { key, values in
            let valueString = values.joined(separator: ", ")
            return "\(key): \(valueString)"
        }
        .joined(separator: "\n")

        msg.append("\n\n\(body)\n")

        return msg
    }
}

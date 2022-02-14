//
//  MemoryMessage.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 12/31/20.
//

import Foundation

/// An implementation of the `MailMessage` protocol that resides
/// entirely in memory.
public class MemoryMessage: MailMessage {
    private let uuid: UUID = UUID()
    private var headerDict = [String: [String]]()
    private var messageBody = ""

    public var uid: String { uuid.uuidString }

    public var headers: [String: [String]] { headerDict }

    public var body: String { messageBody }

    public init() {}

    public func set(value: String, for header: String) {
        var valueArray = [String]()
        valueArray.append(value)
        headerDict[header] = valueArray
    }

    public func add(value: String, to header: String) {
        if let values = headerDict[header] {
            var updatedValues = [String]()
            updatedValues.append(contentsOf: values)
            updatedValues.append(value)
            headerDict[header] = updatedValues
        } else {
            set(value: value, for: header)
        }
    }

    public func appendHeader(value: String, to header: String) {
        if var values = headerDict[header] {
            // this test is dumb, because if values exists, then there's at least one element in it
            // however, the contract of popLast says that it returns an optional. Tried using
            // removeLast, but Xcode was getting very confused about whether or not updatedValues
            // should be modifiable. This code, while ugly and unnecessarily verbose, at least
            // builds. Fundamentally, all we want to do is remove the last value from the list,
            // concatenate it with the incoming value, and put that concatenated value back at the
            // end of the list.
            if let oldValue = values.popLast() {
                let newValue = oldValue + value
                var updatedValues = [String]()
                for v in values { // swiftlint:disable:this identifier_name
                    updatedValues.append(v)
                }
                updatedValues.append(newValue)
                headerDict[header] = updatedValues
            } else {
                set(value: value, for: header)
            }
        } else {
            set(value: value, for: header)
        }
    }

    public func append(line: String) {
        if !messageBody.isEmpty && !line.isEmpty && line != "\n" {
            messageBody += "\n"
        }
        messageBody += line
    }

    public static func example() -> MailMessage {
        let message = MemoryMessage()
        message.append(line: "Sample message for preview purposes.")
        message.add(value: "test@localhost", to: "Sender")
        message.add(value: "Sample message", to: "Subject")
        message.add(value: "<\(message.uid)@localhost>", to: "Message-Id")
        return message
    }
}

//
//  MailTests.swift
//  MailTests
//
//  Created by Stephen Beitzel on 12/31/20.
//

import XCTest
@testable import StumpyNIO

class MailTests: XCTestCase {

    /// Be sure that adding lines to a message results in the correct message body
    func testAppend() {
        let message = MemoryMessage()
        message.set(value: "test@localhost", for: "Sender")
        message.append(line: "Hello, world!")
        message.append(line: "Second line")
        message.append(line: "\n")
        message.append(line: "Second paragraph")

        XCTAssert(message.body == "Hello, world!\nSecond line\n\nSecond paragraph")
    }

    /// Be sure that we're properly escaping POP3 termination sequence
    func testByteStuff() {
        let message = MemoryMessage()
        message.set(value: "test@localhost", for: "Sender")
        message.append(line: "Hello, world!")
        message.append(line: "\r\n.\r\n")
        message.append(line: "Second line")
        let stuffed = message.byteStuff()
        XCTAssert(stuffed == "Sender: test@localhost\r\n\r\nHello, world!\n\r\n..\r\n\nSecond line\r\n.\r\n")
    }

    /// Be sure that setting a header value actually stores that value
    func testSetHeader() {
        let message = MemoryMessage()

        message.set(value: "someValue", for: "X-Test-Header")

        XCTAssert(message.headers.count == 1)

        let valueList = message.headers["X-Test-Header"]
        XCTAssert(valueList?.joined(separator: ", ") == "someValue")
    }

    /// Be sure that calling set and then add stores both values and they're in the right order
    func testSetAndAdd() {
        let message = MemoryMessage()
        message.set(value: "firstValue", for: "X-Test-Header")
        message.add(value: "secondValue", to: "X-Test-Header")

        XCTAssert(message.headers.count == 1)

        let valueList = message.headers["X-Test-Header"]
        XCTAssert(valueList?.count == 2)

        XCTAssert(valueList?.joined(separator: ", ") == "firstValue, secondValue")
    }

}

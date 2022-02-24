//
//  MailStoreTests.swift
//  MailTests
//
//  Created by Stephen Beitzel on 12/31/20.
//

import XCTest
@testable import StumpyNIO

class MailStoreTests: XCTestCase {

    var store: FixedSizeMailStore = FixedSizeMailStore(size: 10)

    override func setUpWithError() throws {
        store = FixedSizeMailStore(size: 10)
    }

    func testInitialStoreIsEmpty() async {
        let count = await store.messageCount()
        XCTAssertEqual(count, 0)
    }

    func testAddActuallyAdds() async throws {
        let message = createMessage("Test message body")
        await store.add(message: message)

        let count = await store.messageCount()
        XCTAssertEqual(count, 1)
        let retrievedMessage = try await store.get(message: 0)
        XCTAssertEqual(message.uid, retrievedMessage.uid)
        XCTAssertEqual(message.byteStuff(), retrievedMessage.byteStuff())
    }

    func createMessage(_ body: String, subject: String = "Test subject") -> MailMessage {
        let message = MemoryMessage()
        message.append(line: body)
        message.add(value: "test@localhost", to: "Sender")
        message.add(value: "Test message", to: "Subject")
        message.add(value: "<\(message.uid)@localhost>", to: "Message-Id")
        return message
    }

    func testAddElevenYieldsTen() async throws {
        for i in 0...11 { // swiftlint:disable:this identifier_name
            await store.add(message: createMessage("Message number \(i)"))
        }
        let count = await store.messageCount()
        XCTAssertEqual(count, 10)
    }
}

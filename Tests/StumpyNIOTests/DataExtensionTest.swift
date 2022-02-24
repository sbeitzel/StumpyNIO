//
//  DataExtensionTest.swift
//  MailTests
//
//  Created by Stephen Beitzel on 1/5/21.
//

import XCTest
@testable import StumpyNIO

class DataExtensionTest: XCTestCase {
    private var testData: Data = Data()

    override func setUpWithError() throws {
        testData.removeAll(keepingCapacity: true)
    }

    func testReadLines() {
        let multilineString = "First line\r\nSecond line\r\n\r\nFourth line\r\n.\r\n"
        testData.append(contentsOf: multilineString.utf8)

        let lines: [String] = testData.lines()
        XCTAssert(lines.count == 5, "Expected 5 lines but got \(lines.count)")
        XCTAssertEqual(lines.last, ".")
    }
}

//
//  POPResponse.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/4/21.
//

import Foundation

struct POPResponse {
    // swiftlint:disable:next identifier_name
    static let OK = "+OK"
    static let ERROR = "-ERR"

    let code: String
    let message: String
}

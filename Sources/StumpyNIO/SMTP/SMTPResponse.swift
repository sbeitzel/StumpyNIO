//
//  SMTPResponse.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/1/21.
//

import Foundation

/// The result of a client request being processed by the SMTP server.
///
/// Some responses may be more than a single line; for example, the
/// response to EHLO could be multiple lines, as could the response
/// to HELP.
struct SMTPResponse {
    /// Numeric response code  [see RFC-5321](https://tools.ietf.org/html/rfc5321)
    let code: Int

    /// Human readable message describing the response
    let message: String

    static let badSequence = SMTPResponse(code: 503, message: "Bad sequence of commands")
}

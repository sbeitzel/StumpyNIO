//
//  SMTPAction.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/1/21.
//

import Foundation

/// A command in an SMTP session
enum SMTPAction {
    case blankLine, data, dataEnd, helo, ehlo, expn, help, list, mail, noop,
         quit, rcpt, rset, vrfy, unknown
}

//
//  POPAction.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/3/21.
//

import Foundation

/// See [RFC 1939](https://tools.ietf.org/html/rfc1939) for the basic commands, as
/// well as [RFC 2449](https://tools.ietf.org/html/rfc2449) for the extension mechanism (including the CAPA command)
/// and [RFC 5034](https://tools.ietf.org/html/rfc5034) for discussion of authentication.
enum POPAction {
    case apop, capa, invalid, delete, list, noop, password, quit, reset,
         retrieve, status, top, uidl, user
}

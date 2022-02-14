//
//  POPSessionState.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/18/22.
//

import Foundation

class POPSessionState {
    let sessionID = UUID()
    let mailStore: MailStore
    var popState: POPState = .authorization
    let hostName: String
    var inputLine: String = ""
    var action: POPAction?
    var params: String = ""

    init(with store: MailStore, hostName: String) {
        self.hostName = hostName
        self.mailStore = store
    }
}

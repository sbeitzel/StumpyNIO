//  Created by Stephen Beitzel on 12/21/20.
//

import NIO

/// The server part of the POP3 server that we implement.
public class NPOPServer: BaseServer {
    public init(group: EventLoopGroup, port: Int, store: MailStore = FixedSizeMailStore(size: 10)) {
        let label = "POP3"
        let stats = ServerStats()
        let handlers: [ChannelHandler] = [
                    BackPressureHandler(),
                    StatsHandler(stats),
                    DebugLoggingHandler(),
                    POPSessionHandler(with: store,
                                      hostName: "stumpy.local"), // hostname is for the APOP header
                    POPParseHandler(),
                    POPActionHandler()
                ]
        super.init(group: group,
                   port: port,
                   store: store,
                   label: label,
                   stats: stats,
                   handlers: handlers)
    }
}

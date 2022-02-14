//  Created by Stephen Beitzel on 12/21/20.
//

import NIO

public class NSMTPServer: BaseServer {

    /// Create a new NIO-based dummy SMTP server
    ///
    /// - Parameters:
    ///   - group: the eventloopgroup that the server bootstrap will use
    ///   - port: the port on which to listen
    ///   - store: the backing mail store
    ///   - acceptMultipleMails: if true, the server will follow the RFC and allow multiple messages to
    ///   be sent in a single session. If false, the server will quit the session after the first message, violating the
    ///   standard but behaving as Thunderbird wants it to.
    public init(group: EventLoopGroup,
                port: Int,
                store: MailStore = FixedSizeMailStore(size: 10),
                acceptMultipleMails: Bool = true) {
        let label = "SMTP"
        let stats = ServerStats()
        let handlers: [ChannelHandler] = [
            BackPressureHandler(),
            StatsHandler(stats),
            DebugLoggingHandler(),
            SMTPSessionHandler(with: store, acceptMultipleMails: acceptMultipleMails),
            SMTPActionHandler()
        ]
        super.init(group: group,
                   port: port,
                   store: store,
                   label: label,
                   stats: stats,
                   handlers: handlers)
    }
}

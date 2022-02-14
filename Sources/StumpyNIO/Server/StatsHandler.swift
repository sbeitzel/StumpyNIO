//
//  StatsHandler.swift
//  Stumpy
//
//  Created by Stephen Beitzel on 1/23/22.
//

#if os(macOS)
import Foundation
#else
import Foundation
import OpenCombineShim
#endif
import NIO

final class StatsHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    let stats: ServerStats

    init(_ serverStats: ServerStats) {
        self.stats = serverStats
    }

    func channelActive(context: ChannelHandlerContext) {
        Task {
            stats.increaseConnectionCount()
        }
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        Task {
            stats.decreaseConnectionCount()
        }
        context.fireChannelInactive()
    }
}

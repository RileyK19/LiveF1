//
//  F1DataSource.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//

import Foundation

enum DataSourceState: Sendable {
    case disconnected, connecting, connected
    case error(String)
}

protocol F1DataSource: AnyObject {
//    var onMessage: ((String, [String: Any]) -> Void)? { get set }
//    var onStateChange: ((DataSourceState) -> Void)? { get set }
    var stream: AsyncStream<F1LiveEvent> { get }
}

enum F1LiveEvent: @unchecked Sendable {
    case state(DataSourceState)
    case message(topic: String, payload: [String: Any])
}

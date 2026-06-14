//
//  F1DataSource.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//

import Foundation

enum DataSourceState {
    case disconnected, connecting, connected
    case error(String)
}

protocol F1DataSource: AnyObject {
    var onMessage: ((String, [String: Any]) -> Void)? { get set }
    var onStateChange: ((DataSourceState) -> Void)? { get set }
}

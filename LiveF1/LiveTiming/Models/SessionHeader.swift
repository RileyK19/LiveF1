//
//  SessionHeader.swift
//  Redline
//
//  Created by Riley Koo on 10/19/26.
//

import Foundation

struct SessionHeader: Equatable {
    var sessionName = ""
    var sessionPath: String?
    var lapText = ""
    var flagStatus = ""
    var remainingText: String?
    var remainingBase: TimeInterval?
    var extrapolating = false
    var clockUtc: Date?
}

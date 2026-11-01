//
//  DebugPrintToggle.swift
//  Redline
//
//  Created by Riley Koo on 8/21/26.
//

import Foundation
import SwiftUI

private var isDebugTagEnabled = false //toggle

func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {
    guard isDebugTagEnabled else { return }
    
    PrintLog.append(
        items.map { "\($0)" }.joined(separator: separator)
    )

    Swift.print(
        items.map { "\($0)" }.joined(separator: separator),
        terminator: terminator
    )
}

struct DebugPrintToggle: View {
    var body: some View {
        Toggle(
            "Debug",
            isOn: Binding(
                get: { isDebugTagEnabled },
                set: { isDebugTagEnabled = $0 }
            )
        )
    }
}

struct PrintLog {
    private static let key = "printLog"

    static var log: [String] = {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }()

    static func append(_ str: String) {
        log.append(str)
        UserDefaults.standard.set(log, forKey: key)
    }

    static func clear() {
        log.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}


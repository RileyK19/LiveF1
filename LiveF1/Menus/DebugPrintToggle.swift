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

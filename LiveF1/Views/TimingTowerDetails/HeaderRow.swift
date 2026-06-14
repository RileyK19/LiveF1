//
//  HeaderRow.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

// MARK: - Header

struct HeaderRow: View {
    @AppStorage("isDark") private var isDark = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("P").frame(width: 20, alignment: .center)
            Text("Driver").frame(width: 36, alignment: .leading)
            Text("Best").frame(width: 100, alignment: .trailing)
            Text("Last").frame(width: 100, alignment: .trailing)
            Text("Gap").frame(width: 60, alignment: .trailing)
            Text("Sectors").frame(width: 150, alignment: .leading)
            Text("Tyre").frame(width: 52, alignment: .center)
        }
        .font(.system(.caption2, design: .monospaced).bold())
        .foregroundStyle(.gray)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

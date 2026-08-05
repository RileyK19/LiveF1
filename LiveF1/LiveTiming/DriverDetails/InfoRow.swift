//
//  InfoRow.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct InfoRow: View {
    @AppStorage("isDark") private var isDark = false

    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(isDark ? .white : .black).bold()
        }
        .font(.caption)
    }
}

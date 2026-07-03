//
//  NextSessionInlineView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI

struct NextSessionInlineView: View {
    let entry: NextSessionEntry

    var body: some View {
        if let session = entry.session, let dt = session.dateTime {
            Text("\(entry.sessionName ?? "Session") in \(dt, style: .relative)")
        } else {
            Text("No upcoming session")
        }
    }
}

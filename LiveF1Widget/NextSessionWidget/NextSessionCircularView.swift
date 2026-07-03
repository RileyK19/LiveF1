//
//  NextSessionCircularView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI

struct NextSessionCircularView: View {
    let entry: NextSessionEntry

    var body: some View {
        if let session = entry.session, let dt = session.dateTime {
            VStack(spacing: 0) {
                Text(entry.sessionName ?? "")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Text(dt, style: .relative)
                    .font(.system(size: 12, weight: .bold))
                    .minimumScaleFactor(0.6)
            }
        } else {
            Text("No data")
                .font(.system(size: 10))
        }
    }
}

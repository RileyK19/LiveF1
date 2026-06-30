//
//  CreditsView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/28/26.
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("F1 Signal R Websocket Stream")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("FIA Documents")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Link("fia.com/documents", destination: URL(string: "https://fia.com/documents")!)
                        .font(.title3)
                }
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Predictor Data, Schedule Data, and Championship Standings Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Link("OpenF1", destination: URL(string: "https://openf1.org/")!)
                        .font(.title3)
                }
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Track SVG Maps")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Link("F1DB Github", destination: URL(string: "https://github.com/f1db/f1db/tree/main/src/assets/circuits/black")!)
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Credits")
    }
}

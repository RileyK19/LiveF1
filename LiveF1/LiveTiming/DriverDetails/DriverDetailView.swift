//
//  DriverDetailView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/5/26.
//


import SwiftUI

struct DriverDetailView: View {
    let driverID: String
    @ObservedObject var store: F1SessionStore
    @AppStorage("isDark") private var isDark = false
    
    var driver: Driver {
        store.drivers.first(where: { $0.id == driverID }) ?? Driver(
            id: "",
            position: 0,
            tla: "",
            fullName: "",
            teamName: "",
            teamColour: .white,
            gap: "",
            interval: "",
            lastLap: "",
            isPersonalBest: false,
            sector1: "",
            sector2: "",
            sector3: "",
            compound: "",
            tyreAge: 0,
            pits: 0,
            inPit: false,
            bestLap: "",
            isBestLap: false,
            segments: [],
//            sectorDelta: ""
            sectorDeltas: []
        )
    }

    var telemetry: CarTelemetry? {
        store.carTelemetry[driver.id]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Rectangle()
                        .fill(driver.teamColour)
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                    VStack(alignment: .leading) {
                        Text(driver.tla).font(.title.bold()).foregroundStyle(isDark ? .white : .black)
                        Text(driver.teamName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("P\(driver.position)").font(.title.bold()).foregroundStyle(isDark ? .white : .black)
                        Text(driver.gap).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .cornerRadius(12)

                if let t = telemetry {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        TelemetryCard(label: "Speed", value: "\(t.speed)", unit: "km/h", colour: .blue)
                        TelemetryCard(label: "Gear", value: "\(t.gear)", unit: "", colour: isDark ? .white : .black)
                        TelemetryCard(label: "RPM", value: "\(t.rpm)", unit: "", colour: .orange)
                        TelemetryCard(label: "DRS", value: t.drs ? "OPEN" : "CLOSED", unit: "", colour: t.drs ? .green : .gray)
                    }

                    TelemetryBar(label: "Throttle", value: Double(t.throttle) / 100, colour: .green)
                    TelemetryBar(label: "Brake", value: t.brake ? 1 : 0, colour: .red)
                } else {
                    Text("No telemetry — requires F1TV connection and live session")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding()
                }
                
//                MiniSectors(segments: driver.segments, delta: driver.sectorDelta)
                MiniSectors(segments: driver.segments, sectorDeltas: driver.sectorDeltas)
                    .frame(alignment: .leading)
                    .padding()
                    .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .cornerRadius(12)

                VStack(spacing: 8) {
                    InfoRow(label: "Last Lap", value: driver.lastLap)
                    InfoRow(label: "Tyre", value: "\(driver.compound) (Lap \(driver.tyreAge))")
                    InfoRow(label: "Pits", value: "\(driver.pits)")
                    InfoRow(label: "S1", value: driver.sector1.isEmpty ? "—" : driver.sector1)
                    InfoRow(label: "S2", value: driver.sector2.isEmpty ? "—" : driver.sector2)
                    InfoRow(label: "S3", value: driver.sector3.isEmpty ? "—" : driver.sector3)
                }
                .padding()
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(isDark ? Color.black : Color.white)
        .navigationTitle(driver.fullName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

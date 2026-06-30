//
//  ChampionshipTrackView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/28/26.
//

import SwiftUI
import PocketSVG

struct ChampionshipTrackView: View {
    var trackName: String
    @State private var path: CGPath? = nil

    var body: some View {
        VStack {

            if let path = path {
                ChampionshipTrackShape(cgPath: path)
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 35, height: 35)
            }
        }
        .onAppear {
            path = loadTrackPath(from: trackName)
        }
    }
    
    func loadTrackPath(from name: String) -> CGPath? {
        var revisedName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        guard let url = Bundle.main.url(forResource: revisedName, withExtension: "svg") else {
            return nil
        }

        guard let svgString = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        print(svgString)

        let paths = SVGBezierPath.paths(fromSVGString: svgString)
        return paths.first?.cgPath
    }
}

private struct ChampionshipTrackShape: Shape {
    let cgPath: CGPath

    func path(in rect: CGRect) -> Path {
        let boundingBox = cgPath.boundingBox
        guard boundingBox.width > 0, boundingBox.height > 0 else {
            return Path(cgPath)
        }

        let scaleX = rect.width / boundingBox.width
        let scaleY = rect.height / boundingBox.height
        let scale = min(scaleX, scaleY)

        var transform = CGAffineTransform(translationX: -boundingBox.minX, y: -boundingBox.minY)
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        guard let scaledPath = cgPath.copy(using: &transform) else {
            return Path(cgPath)
        }
        return Path(scaledPath)
    }
}

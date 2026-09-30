//
//  Exportable.swift
//  Redline
//
//  Created by Riley Koo on 9/25/26.
//

import SwiftUI

protocol Exportable {
    associatedtype ExportContent: View
    var exportContent: ExportContent { get }
    var exportSize: CGSize { get }
    var exportFilename: String { get }
}

extension Exportable {
    var exportSize: CGSize { CGSize(width: 800, height: 900) } // sensible default
}

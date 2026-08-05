//
//  Router.swift
//  LiveF1
//
//  Created by Riley Koo on 8/4/26.
//


import SwiftUI

@Observable
final class Router {
    var path: [Destination] = []

    func push(_ destination: Destination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
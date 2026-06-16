//
//  ScheduleResponse.swift
//  LiveF1
//
//  Created by Riley Koo on 6/16/26.
//

import Foundation
import Combine

struct ChampionshipScheduleResponse: Codable {
    let mrData: ChampionshipMRDataSchedule
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct ChampionshipMRDataSchedule: Codable {
    let raceTable: ChampionshipRaceTable
    enum CodingKeys: String, CodingKey { case raceTable = "RaceTable" }
}

struct ChampionshipRaceTable: Codable {
    let season: String
    let races: [ChampionshipRace]
    enum CodingKeys: String, CodingKey { case season; case races = "Races" }
}

struct ChampionshipRace: Codable, Identifiable {
    var id: String { round }
    let round: String
    let raceName: String
    let date: String
    let time: String?
    let circuit: ChampionshipCircuit
    let firstPractice: ChampionshipSession?
    let secondPractice: ChampionshipSession?
    let thirdPractice: ChampionshipSession?
    let qualifying: ChampionshipSession?
    let sprint: ChampionshipSession?
    let sprintQualifying: ChampionshipSession?

    enum CodingKeys: String, CodingKey {
        case round, raceName, date, time
        case circuit = "Circuit"
        case firstPractice = "FirstPractice"
        case secondPractice = "SecondPractice"
        case thirdPractice = "ThirdPractice"
        case qualifying = "Qualifying"
        case sprint = "Sprint"
        case sprintQualifying = "SprintQualifying"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: d)
    }

    var raceDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var isPast: Bool {
        guard let d = raceDate else { return false }
        return d < Date()
    }

    var isNext: Bool {
        guard let d = raceDate else { return false }
        return d >= Date()
    }

    var flagEmoji: String {
        let flags: [String: String] = [
            "Australia": "🇦🇺", "Bahrain": "🇧🇭", "Saudi Arabia": "🇸🇦",
            "Japan": "🇯🇵", "China": "🇨🇳", "Miami": "🇺🇸", "United States": "🇺🇸",
            "Italy": "🇮🇹", "Monaco": "🇲🇨", "Canada": "🇨🇦", "Spain": "🇪🇸",
            "Austria": "🇦🇹", "Great Britain": "🇬🇧", "Hungary": "🇭🇺",
            "Belgium": "🇧🇪", "Netherlands": "🇳🇱", "Singapore": "🇸🇬",
            "Mexico": "🇲🇽", "Brazil": "🇧🇷", "Las Vegas": "🇺🇸",
            "Qatar": "🇶🇦", "Abu Dhabi": "🇦🇪", "Azerbaijan": "🇦🇿"
        ]
        for (key, flag) in flags {
            if raceName.contains(key) { return flag }
        }
        return "🏁"
    }
    
    var allSessions: [(name: String, session: ChampionshipSession)] {
        var result: [(String, ChampionshipSession)] = []
        if let s = firstPractice        { result.append(("FP1", s)) }
        if let s = secondPractice       { result.append(("FP2", s)) }
        if let s = sprint               { result.append(("Sprint", s)) }
        if let s = thirdPractice        { result.append(("FP3", s)) }
        if let s = qualifying           { result.append(("Quali", s)) }
        if let s = sprintQualifying     { result.append(("SQ", s)) }
        // Race itself
        result.append(("Race", ChampionshipSession(date: date, time: time)))
        return result.sorted { ($0.1.dateTime ?? .distantPast) < ($1.1.dateTime ?? .distantPast) }
    }
}

struct ChampionshipCircuit: Codable {
    let circuitName: String
    let location: ChampionshipLocation
    enum CodingKeys: String, CodingKey {
        case circuitName
        case location = "Location"
    }
}

struct ChampionshipLocation: Codable {
    let locality: String
    let country: String
}

struct ChampionshipSession: Codable {
    let date: String
    let time: String?

    var dateTime: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let time {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
            return formatter.date(from: "\(date) \(time)")
        } else {
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: date)
        }
    }

    var formattedDateTime: String {
        guard let dt = dateTime else { return date }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · HH:mm"
        f.timeZone = TimeZone.current
        return f.string(from: dt)
    }

    var isPast: Bool { (dateTime ?? .distantPast) < Date() }
}

// MARK: - Standings Models

struct ChampionshipStandingsResponse: Codable {
    let mrData: ChampionshipMRDataStandings
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct ChampionshipMRDataStandings: Codable {
    let standingsTable: ChampionshipStandingsTable
    enum CodingKeys: String, CodingKey { case standingsTable = "StandingsTable" }
}

struct ChampionshipStandingsTable: Codable {
    let season: String
    let standingsLists: [ChampionshipStandingsList]
    enum CodingKeys: String, CodingKey { case season; case standingsLists = "StandingsLists" }
}

struct ChampionshipStandingsList: Codable {
    let round: String
    let driverStandings: [ChampionshipDriverStanding]?
    let constructorStandings: [ChampionshipConstructorStanding]?
    enum CodingKeys: String, CodingKey {
        case round
        case driverStandings = "DriverStandings"
        case constructorStandings = "ConstructorStandings"
    }
}

struct ChampionshipDriverStanding: Codable, Identifiable {
    var id: String { driver.driverId }
    let position: String
    let points: String
    let wins: String
    let driver: ChampionshipDriver
    let constructors: [ChampionshipConstructor]

    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case driver = "Driver"
        case constructors = "Constructors"
    }

    var teamColor: String {
        let colors: [String: String] = [
            "red_bull": "#3671C6", "ferrari": "#E8002D", "mercedes": "#27F4D2",
            "mclaren": "#FF8000", "aston_martin": "#229971", "alpine": "#FF87BC",
            "williams": "#64C4FF", "rb": "#6692FF", "kick_sauber": "#52E252",
            "haas": "#B6BABD"
        ]
        return colors[constructors.first?.constructorId ?? ""] ?? "#888888"
    }
}

struct ChampionshipDriver: Codable {
    let driverId: String
    let permanentNumber: String?
    let code: String?
    let givenName: String
    let familyName: String
    let nationality: String

    var fullName: String { "\(givenName) \(familyName)" }
    var initials: String {
        let f = givenName.prefix(1)
        let l = familyName.prefix(3).uppercased()
        return "\(f). \(l)"
    }
}

struct ChampionshipConstructorStanding: Codable, Identifiable {
    var id: String { constructor.constructorId }
    let position: String
    let points: String
    let wins: String
    let constructor: ChampionshipConstructor

    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case constructor = "Constructor"
    }

    var teamColor: String {
        let colors: [String: String] = [
            "red_bull": "#3671C6", "ferrari": "#E8002D", "mercedes": "#27F4D2",
            "mclaren": "#FF8000", "aston_martin": "#229971", "alpine": "#FF87BC",
            "williams": "#64C4FF", "rb": "#6692FF", "kick_sauber": "#52E252",
            "haas": "#B6BABD"
        ]
        return colors[constructor.constructorId] ?? "#888888"
    }
}

struct ChampionshipConstructor: Codable {
    let constructorId: String
    let name: String
    let nationality: String
}

struct ChampionshipCacheEntry<T: Codable>: Codable {
    let data: T
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

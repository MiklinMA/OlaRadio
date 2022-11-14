//
//  Track.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation


let CACHE_DIR = (
    ProcessInfo.processInfo.environment["YANDEX_CACHE_DIR"] ??
    ProcessInfo.processInfo.environment["TMPDIR"] ??
    "/tmp"
)

struct Album: Codable {
    let id: Int
    let title: String
}

struct Artist: Codable {
    let id: Int
    let name: String
}

public struct Track: Codable {
    let id: String
    let title: String
    let albums: [Album]
    let artists: [Artist]
    let durationMs: Int
    let coverUri: String
    let lyricsAvailable: Bool
    
    var liked = false
    let play_id = String(
        format: "%d-%d-%d",
        Int.random(in: 1...1000),
        Int.random(in: 1...1000),
        Int.random(in: 1...1000)
    )
    var album: String { albums.first!.title }
    var album_id: Int { albums.first!.id }
    var artist: String { artists.first!.name }
    var name: String { "\(artist) - \(title)".replacingOccurrences(of: "/", with: "") }
    var path: String { "\(CACHE_DIR)/\(name).mp3" }
    var artwork: String { "https://\(coverUri.replacingOccurrences(of: "%%", with: "200x200"))" }
    
    var duration: Int { durationMs / 1000 }
    var position: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, title, albums, artists, durationMs, coverUri, lyricsAvailable
    }
}


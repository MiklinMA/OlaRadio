//
//  Track.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation

final public class Track: ObservableObject {
    let packet: TrackPacket
    let station: Station

    let id: String
    let title: String
    var liked = false
    var cached = false
    @Published private var _lyrics: String? = nil
    private var lyricsAvailable: Bool = false
    var task: Task<(), Error>?
    var cache: String {
        UserDefaults.standard.string(forKey: "cache")
            ?? ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"
    }

    let playId = String(
        format: "%d-%d-%d",
        Int.random(in: 1...1000),
        Int.random(in: 1...1000),
        Int.random(in: 1...1000)
    )
    var album: String { packet.albums.first!.title }
    var albumId: Int { packet.albums.first!.id }
    var artist: String { packet.artists.first!.name }
    var name: String { "\(artist) - \(title)".replacingOccurrences(of: "/", with: "") }
    var path: String { "\(cache)/\(name).mp3" }
    var artwork: String {
        "https://\(packet.coverUri.replacingOccurrences(of: "%%", with: "200x200"))"
    }
    private static let sessionProcessingQueue = DispatchQueue(label: "SessionProcessingQueue")

    var duration: Int { packet.durationMs / 1000 }
    var position: Int = 0
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var lyrics: String? {
        get {
            if _lyrics == nil && lyricsAvailable {
                Task { try await getLyrics() }
            }
            return _lyrics
        }
        set {
            _lyrics = newValue
        }
    }
    func getLyrics() async throws {
        let lyrics = try await station.client.getLyrics(trackId: id)
        DispatchQueue.main.sync {
            self.lyrics = lyrics
        }
    }

    init(_ packet: TrackPacket, _ station: Station) {
        self.station = station
        self.packet = packet
        id = packet.id
        title = packet.title
        liked = packet.liked
        lyricsAvailable = packet.lyricsAvailable
        cached = exists
    }

    func download() async throws {
        if !exists {
            print("Downloading \(name)...")
            try FileManager.default.createDirectory(
                atPath: path.split(separator: "/").dropLast().joined(separator: "/"),
                withIntermediateDirectories: true
            )
            try await station.client.download(trackId: id, filename: path)
        }

        // self.__reload_tags()
    }

    func trace() async throws {
        try await station.eventTrackTrace(track: self)
    }

    func skip() async throws {
        try await station.eventTrackSkip(track: self)
    }

    func like() async throws {
        try await station.eventTrackLike(track: self, remove: liked)
        DispatchQueue.main.sync {
            self.liked.toggle()
        }
    }

    func dislike() async throws {
        try await station.eventTrackDislike(track: self)
        try FileManager.default.removeItem(atPath: path)
    }
}

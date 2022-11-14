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

final public class Track {
    let packet: TrackPacket
    let station: Station
    
    let id: String
    let title: String
    var liked = false
    var cached = false
    private var _lyrics: String? = nil
    private var _lyrics_available: Bool = false
    
    let play_id = String(
        format: "%d-%d-%d",
        Int.random(in: 1...1000),
        Int.random(in: 1...1000),
        Int.random(in: 1...1000)
    )
    var album: String { packet.albums.first!.title }
    var album_id: Int { packet.albums.first!.id }
    var artist: String { packet.artists.first!.name }
    var name: String { "\(artist) - \(title)".replacingOccurrences(of: "/", with: "") }
    var path: String { "\(CACHE_DIR)/\(name).mp3" }
    var artwork: String { "https://\(packet.coverUri.replacingOccurrences(of: "%%", with: "200x200"))" }
    
    var duration: Int { packet.durationMs / 1000 }
    var position: Int = 0
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    var lyrics: String? {
        get async throws {
            if (_lyrics == nil && _lyrics_available) {
                _lyrics = try await station.client.get_lyrics(track_id: id)
            }
            return _lyrics
        }
    }
    
    init(_ packet: TrackPacket, _ station: Station) {
        self.station = station
        self.packet = packet
        id = packet.id
        title = packet.title
        liked = packet.liked
        _lyrics_available = packet.lyricsAvailable
        cached = exists
    }
    
    func download() async throws {
        if !exists {
            print("Downloading \(name)...")
            try FileManager.default.createDirectory(
                atPath: path.split(separator: "/").dropLast().joined(separator: "/"),
                withIntermediateDirectories: true
            )
            try await station.client.download(track_id: id, filename: path)
        }
            
        // self.__reload_tags()
    }
    
    func trace() async throws {
        try await station.event_track_trace(track: self)
    }

    func skip() async throws {
        try await station.event_track_skip(track: self)
    }

    func like() async throws {
        try await station.event_track_like(track: self, remove: liked)
    }

    func dislike() async throws {
        try await station.event_track_dislike(track: self)
        try FileManager.default.removeItem(atPath: path)
    }
    
    /*
     def __reload_tags(self):
         if not self.exists:
             return
         try:
             tags = id3.ID3(self.path)
         except id3.ID3NoHeaderError:
             tags = id3.ID3()

         changed = False

         if not tags.get('TIT2'):
             tags.add(id3.TIT2(encoding=3, text=self.title))
             tags.add(id3.TALB(encoding=3, text=self.album))
             tags.add(id3.TPE1(encoding=3, text=self.artist))
             changed = True

         if tags.get('USLT::eng'):
             self._lyrics = tags['USLT::eng'].text
         elif self.lyrics is not None:
             tags.add(id3.USLT(encoding=3, lang='eng', text=self.lyrics))
             changed = True

         if not tags.get('APIC'):
             art = urllib.request.urlopen(self.artwork)
             tags.add(id3.APIC(
                 encoding=0,
                 mime=art.headers['Content-Type'],
                 type=3,  # cover front
                 data=art.read(),
             ))
             changed = True

         if changed:
             tags.save(self.path)

     */
}


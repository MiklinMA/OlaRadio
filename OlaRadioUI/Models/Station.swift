//
//  Station.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation


final public class Station {
    let client: Client
    let id: String
    var tracks: [TrackPacket] = []
    var current_track: Track? = nil
    var next_track: Track? = nil
    
    init(token: String, station_id: String) {
        client = Client(token)
        id = station_id
    }
    
    func event_track_trace(track: Track? = nil) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        try await client.event_play_audio(
            track_id: track.id,
            from_cache: track.cached,
            play_id: track.play_id,
            duration: track.duration,
            played: track.position,
            album_id: track.album_id
        )
         print("Trace:", track.position, "/", track.duration)
    }
    
    func event_track_skip(track: Track? = nil) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        try await client.event_track_skip(track_id: track.id, played: track.position)
    }
    
    func event_track_like(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        try await client.event_like(track_id: track.id, remove: remove)
    }
    
    func event_track_dislike(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        try await client.event_like(track_id: track.id, remove: remove, dislike: true)
    }
    
    func get_track_packet() async throws -> TrackPacket {
        if tracks.isEmpty { tracks = try await client.get_tracks(trackId: current_track?.id) }
        return tracks.removeFirst()
    }
    
    func get_track() async throws -> Track {
        if next_track == nil {
            let track = Track(try await get_track_packet(), self)
            track.task = Task { try await track.download() }
            current_track = track

            let _ = try await client.event_radio_started()
        } else {
            try await event_track_trace(track: current_track)
            let _ = try await client.event_track_finished(
                track_id: current_track!.id,
                played: current_track!.duration
            )
            current_track = next_track
        }

        let next_track = Track(try await get_track_packet(), self)
        next_track.task = Task { try await next_track.download() }
        self.next_track = next_track

        guard let current_track = self.current_track else {
            throw ClientError.UndefinedValue("current_track")
        }

        try await event_track_trace(track: current_track)
        let _ = try await client.event_track_started(track_id: current_track.id)

        return current_track
    }
}

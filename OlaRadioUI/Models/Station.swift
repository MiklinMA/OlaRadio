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
    var current_track: Track? = nil
    var next_track: Track? = nil
    
    init(token: String, station_id: String) async throws {
        client = try await Client(token)
        id = station_id
    }
    
    func event_track_trace(track: Track? = nil) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        let _ = try await client.event_play_audio(
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
        let _ = try await client.event_track_skip(track_id: track.id, played: track.position)
    }
    
    func event_track_like(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        let _ = try await client.event_like(track_id: track.id, remove: remove)
    }
    
    func event_track_dislike(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? current_track else {
            throw ClientError.UndefinedValue("track")
        }
        let _ = try await client.event_dislike(track_id: track.id, remove: remove)
    }
    
    func tracks(closure: (_ track: Track) async throws -> Bool) async throws {
        while true {
            var tracks = try await client.get_tracks(trackId: current_track?.id)
            
            if current_track == nil {
                let _ = try await client.event_radio_started()
                current_track = Track(tracks.removeFirst(), self)
                try await current_track?.download()
            }
            guard let current_track = current_track else {
                throw ClientError.UndefinedValue("current_track")
            }
            
            for track in tracks {
                next_track = Track(track, self)
                guard let next_track = next_track else {
                    throw ClientError.UndefinedValue("next_track")
                }
                
                try await event_track_trace(track: current_track)
                let _ = try await client.event_track_started(track_id: current_track.id)
                
                let t = Task { try await next_track.download() }
                
                if try await closure(current_track) == false {
                    return
                }
                
                try await event_track_trace(track: current_track)
                let _ = try await client.event_track_finished(track_id: current_track.id, played: current_track.duration)
                
                let _ = await t.result
                
                self.current_track = next_track
            }
        }
    }
}

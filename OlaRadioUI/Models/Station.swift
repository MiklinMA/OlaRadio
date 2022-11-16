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
    var currentTrack: Track? = nil
    var nextTrack: Track? = nil

    init(token: String, stationId: String) {
        client = Client(token)
        id = stationId
    }

    func eventTrackTrace(track: Track? = nil) async throws {
        guard let track = track ?? currentTrack else {
            throw ClientError.undefinedValue("track")
        }
        try await client.eventPlayAudio(
            trackId: track.id,
            fromCache: track.cached,
            playId: track.playId,
            duration: track.duration,
            played: track.position,
            albumId: track.albumId
        )
        print("Trace:", track.position, "/", track.duration)
    }

    func eventTrackSkip(track: Track? = nil) async throws {
        guard let track = track ?? currentTrack else {
            throw ClientError.undefinedValue("track")
        }
        try await client.eventTrackSkip(trackId: track.id, played: track.position)
    }

    func eventTrackLike(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? currentTrack else {
            throw ClientError.undefinedValue("track")
        }
        try await client.eventTrackLike(trackId: track.id, remove: remove)
    }

    func eventTrackDislike(track: Track? = nil, remove: Bool = false) async throws {
        guard let track = track ?? currentTrack else {
            throw ClientError.undefinedValue("track")
        }
        try await client.eventTrackLike(trackId: track.id, remove: remove, dislike: true)
    }

    func getTrackPacket() async throws -> TrackPacket {
        if tracks.isEmpty { tracks = try await client.getTracks(trackId: currentTrack?.id) }
        return tracks.removeFirst()
    }

    func getTrack() async throws -> Track {
        if nextTrack == nil {
            let track = Track(try await getTrackPacket(), self)
            track.task = Task { try await track.download() }
            currentTrack = track

            let _ = try await client.eventRadioStarted()
        } else {
            try await eventTrackTrace(track: currentTrack)
            let _ = try await client.eventTrackFinished(
                trackId: currentTrack!.id,
                played: currentTrack!.duration
            )
            currentTrack = nextTrack
        }

        let nextTrack = Track(try await getTrackPacket(), self)
        nextTrack.task = Task { try await nextTrack.download() }
        self.nextTrack = nextTrack

        guard let currentTrack = self.currentTrack else {
            throw ClientError.undefinedValue("currentTrack")
        }

        try await eventTrackTrace(track: currentTrack)
        let _ = try await client.eventTrackStarted(trackId: currentTrack.id)

        return currentTrack
    }
}

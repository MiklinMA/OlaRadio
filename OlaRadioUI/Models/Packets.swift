//
//  Packets.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation

public struct StatusPacket: Codable {
    let result: Result

    public struct Result: Codable {
        let account: Account
        
        public struct Account: Codable {
            let now: String
            let region: Int
            let serviceAvailable: Bool

            let uid: Int
            let login: String
            let firstName: String
            let secondName: String
            let fullName: String
            let displayName: String
        }
    }
}

public struct SequencePacket: Codable {
    let result: Result

    public struct Result: Codable {
        let sequence: [Sequence]
        let batchId: String

        public struct Sequence: Codable {
            var track: TrackPacket
            let liked: Bool
            
        }
    }
}

public struct TrackPacket: Codable {
    let id: String
    let title: String
    let albums: [Album]
    let artists: [Artist]
    let durationMs: Int
    let coverUri: String
    let lyricsAvailable: Bool
    var liked = false
    
    enum CodingKeys: String, CodingKey {
        case id, title, albums, artists, durationMs, coverUri, lyricsAvailable
    }

    struct Album: Codable {
        let id: Int
        let title: String
    }

    struct Artist: Codable {
        let id: Int
        let name: String
    }
}

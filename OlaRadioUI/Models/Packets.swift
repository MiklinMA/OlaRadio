//
//  Packets.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation

struct ErrorPacket: Codable {
    let name: String
    let message: String
}

struct BasePacket: Codable {
    var result: String?
    var error: ErrorPacket?
}

public struct LikePacket: Codable {
    let result: Result?
    var error: ErrorPacket?

    public struct Result: Codable {
        let revision: Int?
    }
}

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

struct LyricsPacket: Codable {
    let result: Result

    public struct Result: Codable {
        let lyrics: Lyrics

        public struct Lyrics: Codable {
            let fullLyrics: String
        }
    }
}

struct DownloadInfoPacket: Codable {
    let result: [Info]

    public struct Info: Codable {
        let codec: String
        let bitrateInKbps: Int
        let downloadInfoUrl: String
    }
}

class DownloadInfoXmlPacket: XMLParser, XMLParserDelegate {
    var host: String = ""
    var path: String = ""
    var ts: String = ""
    var region: Int = 0
    var s: String = ""

    private var buffer: String = ""
    override init(data: Data) {
        super.init(data: data)
        self.delegate = self
        self.parse()
    }
    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        buffer = ""
    }
    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "host":
            host = buffer
        case "path":
            path = buffer
        case "ts":
            ts = buffer
        case "region":
            region = Int(buffer) ?? 0
        case "s":
            s = buffer
        default:
            break
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
        print("on:", parser.lineNumber, "at:", parser.columnNumber)
    }
}

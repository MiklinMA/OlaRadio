//
//  Client.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import CryptoKit
import Foundation

enum ClientError: LocalizedError {
    case invalidUrl(String)
    case invalidPacket(String)
    case undefinedValue(String)
    case invalidDownloadInfo
    case dataError

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let url):
            return NSLocalizedString("Invalid URL: \(url)", comment: "invalid url")
        case .invalidPacket(let packet):
            return NSLocalizedString("Invalid packet: \(packet)", comment: "invalid packet")
        case .undefinedValue(let value):
            return NSLocalizedString("Undefined value: \(value)", comment: "undefined value")
        case .invalidDownloadInfo:
            return NSLocalizedString("Invalid download info:", comment: "invalid download info")
        case .dataError:
            return NSLocalizedString("Data error", comment: "data error")
        }
    }
}

class Session {
    private let baseUrl: String = "https://api.music.yandex.net"
    private var session = URLSession(configuration: .default)
    private let token: String

    init(token: String) {
        self.token = token
    }

    private func call(
        url: URL,
        method: String,
        data: [String: Any?],
        json: Bool = false
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("YandexMusicAndroid/23020251", forHTTPHeaderField: "X-Yandex-Music-Client")
        request.setValue("ru", forHTTPHeaderField: "Accept-Language")
        request.setValue("Yandex-Music-API", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !data.isEmpty {
            if json {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: data)
            } else {
                request.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "Content-Type"
                )
                func percentEscapeString(_ string: String) -> String {
                    var characterSet = CharacterSet.alphanumerics
                    characterSet.insert(charactersIn: "-._* ")
                    return
                        string
                        .addingPercentEncoding(withAllowedCharacters: characterSet)!
                        .replacingOccurrences(of: " ", with: "+")
                        .replacingOccurrences(of: " ", with: "+", options: [], range: nil)
                }
                let bodyArray = data.map { (k, v) -> String in
                    let value = String(describing: v ?? "")
                    return "\(k)=\(percentEscapeString(value))"
                }
                request.httpBody = bodyArray.joined(separator: "&").data(using: .utf8)
            }
        }
        print(
            method, url,
            data.isEmpty
                ? ""
                : String(decoding: try! JSONSerialization.data(withJSONObject: data), as: UTF8.self)
        )
        let (data, _) = try await session.data(for: request)
        return data
    }

    private func call(
        path: String,
        method: String,
        params: [String: Any],
        data: [String: Any?],
        json: Bool = false
    ) async throws -> Data {
        let urls = path.hasPrefix("/") ? "\(baseUrl)\(path)" : path
        guard var urlc = URLComponents(string: urls) else { throw ClientError.invalidUrl(urls) }
        for param in params {
            urlc.queryItems?.append(
                URLQueryItem(name: param.key, value: String(describing: param.value)))
        }
        guard let url = urlc.url?.absoluteURL else { throw ClientError.invalidUrl(urls) }
        return try await call(url: url, method: method, data: data, json: json)
    }

    func get(_ path: String, params: [String: Any] = [:]) async throws -> Data {
        return try await call(path: path, method: "GET", params: params, data: [:])
    }

    func get<T: Decodable>(_ path: String, params: [String: Any] = [:], packet: T.Type) async throws
        -> T
    {
        let data = try await get(path, params: params)

        guard let packet = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClientError.invalidPacket(String(describing: T.self))
        }
        return packet
    }

    func post(
        _ path: String, params: [String: Any] = [:], data: [String: Any?] = [:], json: Bool = false
    ) async throws -> Data {
        return try await call(path: path, method: "POST", params: params, data: data, json: json)
    }

    func post<T: Decodable>(
        _ path: String, params: [String: Any] = [:], data: [String: Any?] = [:], json: Bool = false,
        packet: T.Type
    ) async throws -> T {
        let data = try await post(path, params: params, data: data, json: json)

        guard let packet = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClientError.invalidPacket(String(describing: T.self))
        }
        return packet
    }
}

final public class Client: ObservableObject {
    private let session: Session
    private var batchId: String?
    public let id: String
    @Published var account: StatusPacket.Result.Account?

    private var from: String { id.replacingOccurrences(of: ":", with: "-") }

    init(_ token: String, _ stationId: String = "user:onyourwave") {
        self.session = Session(token: token)
        self.id = stationId
    }

    var ready: Bool {
        if account != nil { return true }
        Task {
            let account = try await self.getStatus()
            DispatchQueue.main.sync {
                self.account = account
            }
        }
        return false
    }

    func getStatus() async throws -> StatusPacket.Result.Account {
        let packet = try await session.get(
            "/account/status",
            packet: StatusPacket.self)
        return packet.result.account
    }

    func getTracks(trackId: String? = nil) async throws -> [TrackPacket] {
        var params: [String: Any] = ["settings2": true]
        if let trackId = trackId {
            params["trackId"] = trackId
        }
        let packet = try await session.get(
            "/rotor/station/\(self.id)/tracks",
            params: params,
            packet: SequencePacket.self)
        var tracks = [TrackPacket]()
        for var t in packet.result.sequence {
            t.track.liked = t.liked
            tracks.append(t.track)
        }
        self.batchId = packet.result.batchId
        return tracks
    }

    func feedback(type: String, json: [String: Any]) async throws {
        guard let batchId = self.batchId else {
            throw ClientError.undefinedValue("batchId")
        }
        var data: [String: Any] = [
            "type": type,
            "timestamp": Date().timeIntervalSince1970,
        ]
        for (key, value) in json { data[key] = value }

        let packet = try await session.post(
            "/rotor/station/\(self.id)/feedback",
            params: ["batch-id": batchId],
            data: data,
            json: true,
            packet: BasePacket.self
        )

        if let error = packet.error {
            throw ClientError.invalidPacket("feedback -> " + error.message)
        }
    }

    func eventRadioStarted() async throws {
        try await feedback(type: "radioStarted", json: ["from": self.from])
    }

    func eventTrackStarted(trackId: String) async throws {
        try await feedback(type: "trackStarted", json: ["trackId": trackId])
    }

    func eventTrackFinished(trackId: String, played: Int) async throws {
        try await feedback(
            type: "trackStarted",
            json: [
                "trackId": trackId,
                "totalPlayedSeconds": played,
            ])
    }

    func eventTrackSkip(trackId: String, played: Int) async throws {
        try await feedback(
            type: "skip",
            json: [
                "trackId": trackId,
                "totalPlayedSeconds": played,
            ])
    }

    func eventTrackLike(trackId: String, remove: Bool = false, dislike: Bool = false) async throws {
        let collection = dislike ? "dislikes" : "likes"
        let action = remove ? "remove" : "add-multiple"

        guard let uid = self.account?.uid else {
            throw ClientError.undefinedValue("account.uid")
        }
        let packet = try await session.post(
            "/users/\(uid)/\(collection)/tracks/\(action)",
            data: ["track-ids": trackId],
            packet: LikePacket.self
        )
        if let error = packet.error {
            throw ClientError.invalidPacket("\(collection) -> " + error.message)
        }
    }

    func getLyrics(trackId: String) async throws -> String {
        let packet = try await session.get(
            "/tracks/\(trackId)/supplement",
            packet: LyricsPacket.self)
        return packet.result.lyrics.fullLyrics
    }

    func eventPlayAudio(
        trackId: String, fromCache: Bool,
        playId: String, duration: Int,
        played: Int, albumId: Int
    ) async throws {
        guard let uid = self.account?.uid else {
            throw ClientError.undefinedValue("account.uid")
        }

        func getTimestamp(date: Date = Date()) -> String {
            let timestamp = DateFormatter()
            timestamp.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let nano =
                (Calendar.current.dateComponents([.nanosecond], from: date)).nanosecond! / 1000
            return String(format: "%@.%06ldZ", timestamp.string(from: date), nano)
        }

        let packet = try await session.post(
            "/play-audio",
            data: [
                "track-id": trackId,
                "from-cache": fromCache,
                "from": "desktop_win-home-playlist_of_the_day-playlist-default",
                "play-id": playId,
                "uid": uid,
                "timestamp": getTimestamp(),
                "track-length-seconds": duration,
                "total-played-seconds": played,
                "end-position-seconds": played,
                "album-id": albumId,
                "playlist-id": nil,
                "client-now": getTimestamp(),
            ], packet: BasePacket.self)

        if let error = packet.error {
            throw ClientError.invalidPacket("play audio -> " + error.message)
        }
    }

    func download(trackId: String, filename: String) async throws {
        let packet = try await self.session.get(
            "/tracks/\(trackId)/download-info",
            packet: DownloadInfoPacket.self)
        var br = 0
        var info: DownloadInfoPacket.Info?
        for di in packet.result {
            if di.codec == "mp3" {
                if di.bitrateInKbps > br {
                    info = di
                    br = di.bitrateInKbps
                }
            }
        }
        guard let info = info else {
            throw ClientError.invalidDownloadInfo
        }

        let response = try await self.session.get(info.downloadInfoUrl)

        let xml = DownloadInfoXmlPacket(data: response)
        let src = "XGRlBW9FXlekgbPrRHuSiA" + String(xml.path.dropFirst()) + xml.s
        guard let data = src.data(using: .utf8) else {
            throw ClientError.dataError
        }
        let sign = Insecure.MD5
            .hash(data: data)
            .map { String(format: "%02hhx", $0) }
            .joined()
        let file = try await self.session.get(
            "https://\(xml.host)/get-mp3/\(sign)/\(xml.ts)\(xml.path)")

        try file.write(to: NSURL.fileURL(withPath: filename))
    }
}

//
//  Client.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 14.11.2022.
//

import Foundation

enum ClientError: String, Error {
    case InvalidURL = "Invalid URL"
    case InvalidPacket = "Invalid packet"
    case UndefinedValue = "Value is not defined"
}

struct Session {
    private let base_url: String = "https://api.music.yandex.net"
    private var session = URLSession(configuration: .default)
    private let token: String
    
    init(token: String) {
        self.token = token
    }


    private func call(url: URL,
                      method: String = "GET",
                      json: [String:Any] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("YandexMusicAndroid/23020251", forHTTPHeaderField: "X-Yandex-Music-Client")
        request.setValue("ru", forHTTPHeaderField: "Accept-Language")
        request.setValue("Yandex-Music-API", forHTTPHeaderField: "User-Agent")
        
        if !json.isEmpty {
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        print(method, url, json)
        let (data, _) = try await session.data(for: request)
        return data
    }
    
    private func call(path: String,
                      method: String = "GET",
                      params: [String:Any] = [:],
                      json: [String:Any] = [:],
                      raw: Bool = false
    ) async throws -> Data {
        let urls = raw ? path : "\(base_url)\(path)"
        guard var urlc = URLComponents(string: urls) else { throw ClientError.InvalidURL }
        for param in params {
            urlc.queryItems?.append(URLQueryItem(name: param.key, value: String(describing: param.value)))
        }
        guard let url = urlc.url?.absoluteURL else { throw ClientError.InvalidURL }
        return try await call(url: url, method: method, json: json)
    }
    
    func get(_ path: String, params: [String:Any] = [:], raw: Bool = false) async throws -> Data {
        return try await call(path: path, method: "GET", params: params, raw: raw)
    }

    func get<T: Decodable>(_ path: String, params: [String:Any] = [:], raw: Bool = false, packet: T.Type) async throws -> T {
        let data = try await call(path: path, method: "GET", params: params, raw: raw)
        
        guard let packet = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClientError.InvalidPacket
        }
        return packet
    }
    
    func post(_ path: String, params: [String:Any] = [:], json: [String:Any] = [:]) async throws -> Data {
        return try await call(path: path, method: "POST", params: params, json: json)
    }
}


final public class Client {
    private let session: Session
    private var batch_id: String?
    public let id: String
    public var account: StatusPacket.Result.Account?
    
    private var from: String { id.replacingOccurrences(of: ":", with: "-") }
    
    init(_ token: String, _ station_id: String = "user:onyourwave") async throws {
        self.session = Session(token: token)
        self.id = station_id
        self.account = try await self.get_status()
    }
    
    func get_status() async throws -> StatusPacket.Result.Account {
        let packet = try await session.get("/account/status",
                                           packet: StatusPacket.self)
        self.account = packet.result.account
        guard let account = self.account else {
            throw ClientError.UndefinedValue
        }
        return account
    }
    
    func get_tracks(trackId: String? = nil) async throws -> [TrackPacket] {
        var params: [String:Any] = ["settings2": true]
        if let trackId = trackId {
            params["trackId"] = trackId
        }
        let packet = try await session.get("/rotor/station/\(self.id)/tracks",
                                           params: params,
                                           packet: SequencePacket.self)
        var tracks = [TrackPacket]()
        for var t in packet.result.sequence {
            t.track.liked = t.liked
            tracks.append(t.track)
        }
        self.batch_id = packet.result.batchId
        return tracks
    }
    
    func feedback(type: String, json: [String:Any]) async throws -> Bool {
        guard let batch_id = self.batch_id else {
            throw ClientError.UndefinedValue
        }
        var data: [String: Any] = [
            "type": type,
            "timestamp": Date().timeIntervalSince1970
        ]
        for (key, value) in json { data[key] = value }
        
        let response = try await session.post(
            "/rotor/station/\(self.id)/feedback",
            params: ["batch-id": batch_id],
            json: data
        )
        guard let result = String(data: response, encoding: .utf8) else {
            throw ClientError.InvalidPacket
        }
        return result == "ok"
    }
    
    func event_radio_started() async throws -> Bool {
        return try await feedback(type: "radioStarted", json: ["from": self.from])
    }
    
    func event_track_started(track_id: Int) async throws -> Bool {
        return try await feedback(type: "trackStarted", json: ["trackId": track_id])
    }
    
    func event_track_finished(track_id: Int, played: Int) async throws -> Bool {
        return try await feedback(type: "trackStarted", json: [
            "trackId": track_id,
            "totalPlayedSeconds": played
        ])
    }
    
    func event_track_skip(track_id: Int, played: Int) async throws -> Bool {
        return try await feedback(type: "skip", json: [
            "trackId": track_id,
            "totalPlayedSeconds": played
        ])
    }
    
    func event_like(track_id: Int, remove: Bool = false) async throws {
        let action = remove ? "remove" : "add-multiple"
        guard let uid = self.account?.uid else {
            throw ClientError.UndefinedValue
        }
        let _ = try await session.post(
            "/users/\(uid)/likes/tracks/\(action)",
            json: ["track-ids": track_id]
        )
    }
    
    func event_dislike(track_id: Int, remove: Bool = false) async throws {
        let action = remove ? "remove" : "add-multiple"
        guard let uid = self.account?.uid else {
            throw ClientError.UndefinedValue
        }
        let _ = try await session.post(
            "/users/\(uid)/dislikes/tracks/\(action)",
            json: ["track-ids": track_id]
        )
    }
}

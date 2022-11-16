//
//  Player.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 13.11.2022.
//

import AVKit
import Combine
import Foundation

enum PlayerError: Error {
    case noAccess
    case noStation
    case taskError
}

class Player: NSObject, ObservableObject {
    @Published var track: Track?
    @Published var errorMessage: String?
    @Published var isError: Bool = false
    @Published var station: Station?

    private var token: String? {
        UserDefaults.standard.string(forKey: "token")
    }
    private var stationId: String {
        UserDefaults.standard.string(forKey: "station") ?? "user:onyourwave"
    }

    private var player: AVAudioPlayer!
    private var url: URL!
    private var stationBinding: AnyCancellable? = nil
    private var trackBinding: AnyCancellable? = nil

    // private var queue = DispatchQueue(label: "ru.olasoft.olaradio.player")

    override init() {
        super.init()
        guard let token = token else {
            showError("Token not found")
            return
        }
        let station = Station(token: token, stationId: stationId)
        stationBinding = station.client.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.station = station
        self.station = station
    }

    func showError(_ message: String) {
        DispatchQueue.main.sync {
            self.errorMessage = message
            self.isError = true
        }
    }
    func showError(_ error: Error) {
        showError(error.localizedDescription)
    }

    var ready: Bool {
        station != nil && station!.client.ready
    }
    var playing: Bool {
        if url == nil { return false }
        guard let player = player else { return false }
        return player.isPlaying
    }
    var position: Int {
        if url == nil { return -1 }
        guard let player = player else { return -1 }
        return Int(player.currentTime)
    }

    func play() {
        guard ready else { return }
        guard let player = player else {
            loadTrack()
            return
        }
        player.play()
    }
    func pause() { player?.pause() }
    func toggle() { playing ? pause() : play() }
    func skip() {
        Task {
            guard let track = track else { return }
            track.position = position

            do { try await track.skip() } catch {
                self.showError(error)
            }
            loadTrack()
        }
    }
    func like() {
        Task {
            guard let track = track else { return }
            do {
                try await track.like()
                DispatchQueue.main.sync {
                    self.track = track
                }
            } catch {
                self.showError(error)
            }
        }
    }
    func dislike() {
        Task {
            guard let track = track else { return }
            do { try await track.dislike() } catch {
                self.showError(error)
            }
            skip()
        }
    }
    func loadTrack() {
        print("next track")
        Task {
            guard ready else { return }
            if playing { player?.stop() }
            if let url = url { url.stopAccessingSecurityScopedResource() }

            do {
                guard let station = station else {
                    throw PlayerError.noStation
                }
                let track = try await station.getTrack()
                try await track.task?.value  // wait for downloading

                url = URL(filePath: track.path)
                guard url.startAccessingSecurityScopedResource() else {
                    throw PlayerError.noAccess
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.play()

                DispatchQueue.main.sync {
                    self.player = player
                    self.track = track
                    trackBinding = track.objectWillChange.sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                }
            } catch {
                self.showError(error)
            }
        }
    }
}

extension Player: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let track = track {
            if track.position == 0 {
                track.position = track.duration
            }
        }
        loadTrack()
    }
}

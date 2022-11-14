//
//  Player.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 13.11.2022.
//

import Foundation
import AVKit

final public class Player: ObservableObject {
    var player: AVAudioPlayer

    init() {
        player = AVAudioPlayer()
    }

    var playing: Bool { player.isPlaying }

    func play(_ file: String = "song") {
        if player.data == nil {
            let sound = Bundle.main.path(forResource: file, ofType: "mp3")
            let url = URL(filePath: sound!)
            player = try! AVAudioPlayer(contentsOf: url)
        }
        player.play()
    }
    
    func pause() {
        player.pause()
    }

    func play_toggle() {
        playing ? pause() : play()
    }

    func next_track() {

    }
}


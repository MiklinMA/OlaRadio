//
//  UIControls.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 13.11.2022.
//

import SwiftUI


struct PlayControls: View {
    @Namespace var ns
    @StateObject var player: Player = Player()
    @State var title = "Song title"
    
    private let bsz: CGFloat = 40
    private let bpd: CGFloat = 5

    var body: some View {
        ZStack {
            VStack {
                Text(title).padding(bpd).font(.title2)

                HStack {
                    Spacer()

                    Button(action: {
                        player.next_track()
                    }) {
                        Image(systemName: (
                            "heart.circle.fill"
                        )).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)

                    Button(action: {
                        player.play_toggle()
                    }) {
                        Image(systemName: (
                            player.playing ? "pause.circle.fill" : "play.circle.fill"
                        )).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)
                    .prefersDefaultFocus(true, in: ns)

                    Button(action: {
                        player.next_track()
                    }) {
                        Image(systemName: (
                            "forward.circle.fill"
                        )).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)

                    Button(action: {
                        player.next_track()
                    }) {
                        Image(systemName: (
                            "heart.slash.circle.fill"
                        )).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)

                    Spacer()

                }
            }
        }
        .environmentObject(player)
        .focusScope(ns)
    }
}

struct LyricsBrowser: View {
    @State var text = "Lyrics will be here"

    var body: some View {
        Text(text)
            .frame(minHeight: 50)
    }
}

struct ArtworkPreview: View {
    var body: some View {
        Image(systemName: (
            "heart.circle.fill"
        )).resizable()
            .frame(width: 200, height: 200)
            .aspectRatio(contentMode: .fit)
    }
}


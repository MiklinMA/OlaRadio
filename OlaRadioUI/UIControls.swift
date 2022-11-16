//
//  UIControls.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 13.11.2022.
//

import SwiftUI

struct PlayControls: View {
    // @Namespace var ns
    @EnvironmentObject var player: Player

    private let bsz: CGFloat = 40
    private let bpd: CGFloat = 5

    private var disabled: Bool {
        player.track == nil || player.isError
    }

    var body: some View {
        ZStack {
            VStack {
                Text(player.track?.name ?? "").padding(bpd).font(.title3)

                HStack {
                    Spacer()

                    Button {
                        player.like()
                    } label: {
                        Image(systemName: ("heart.circle.fill")).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(player.track?.liked ?? false ? .red : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)
                    .disabled(disabled)

                    Button {
                        player.toggle()
                    } label: {
                        Image(
                            systemName: (player.playing
                                ? "pause.circle.fill"
                                : "play.circle.fill")
                        ).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)
                    .disabled(!player.ready)
                    // .prefersDefaultFocus(true, in: ns)

                    Button {
                        player.skip()
                    } label: {
                        Image(systemName: ("forward.circle.fill")).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)
                    .disabled(disabled)

                    Button {
                        player.dislike()
                    } label: {
                        Image(systemName: ("heart.slash.circle.fill")).resizable()
                            .frame(width: bsz, height: bsz)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(bpd)
                    .disabled(disabled)

                    Spacer()

                }
            }
        }
        // .focusScope(ns)
    }
}

struct LyricsBrowser: View {
    @EnvironmentObject var player: Player
    var lyrics: String {
        if let track = player.track {
            return track.lyrics ?? "No lyrics..."
        }
        return ""
    }

    var body: some View {
        ScrollView {
            Text(lyrics)
                .frame(minHeight: 50)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 7)
    }
}

struct ArtworkPreview: View {
    @EnvironmentObject var player: Player

    var body: some View {
        if player.track?.artwork == nil {
            Image(systemName: "heart.circle.fill")
                .resizable()
                .frame(width: 200, height: 200)
                .aspectRatio(contentMode: .fit)
        } else {
            AsyncImage(url: URL(string: player.track!.artwork))
                .frame(width: 200, height: 200)
                .aspectRatio(contentMode: .fit)
        }
    }
}

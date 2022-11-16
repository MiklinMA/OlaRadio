//
//  ContentView.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 12.11.2022.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var player: Player = Player()

    var body: some View {
        VStack {
            ArtworkPreview()
            PlayControls()
            LyricsBrowser()
            Spacer()
        }
        .padding(.vertical)
        .frame(maxWidth: 300)
        .environmentObject(player)
        .alert(isPresented: $player.isError) {
            Alert(title: Text(player.errorMessage ?? "Unknown error"))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

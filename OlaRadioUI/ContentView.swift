//
//  ContentView.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 12.11.2022.
//

import SwiftUI


struct ContentView: View {
    var body: some View {
        VStack {
            ArtworkPreview()
            PlayControls()
            LyricsBrowser()
            Spacer()
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

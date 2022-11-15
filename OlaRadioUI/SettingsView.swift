//
//  SettingsView.swift
//  OlaRadioUI
//
//  Created by Mike Miklin on 15.11.2022.
//

import SwiftUI

let DEFAULT_CACHE = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"

struct GeneralSettingsView: View {
    @AppStorage("token") private var token: String = ""
    @AppStorage("cache") private var cache: String = DEFAULT_CACHE
    @AppStorage("station") private var station: String = "user:onyourwave"
    
    @State var showFileChooser = false
    
    var body: some View {
        Form {
            TextField("Yandex-Music Token:", text: $token)
            HStack {
                TextField("File download location:", text: $cache)
                Button("...") {
                    print(DEFAULT_CACHE)
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK {
                        cache = panel.url?.path ?? cache
                    }
                }
            }
            TextField("Radio station:", text: $station)
        }
        .padding(20)
        .frame(width: 375, height: 150)
    }
}

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general
    }
    var body: some View {
        GeneralSettingsView()
//        TabView {
//            GeneralSettingsView()
//                .tabItem {
//                    Label("General", systemImage: "gear")
//                }
//                .tag(Tabs.general)
//        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

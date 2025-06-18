//
//  music_playerApp.swift
//  music_player
//
//  Created by Ps Bharath Kumar Achari on 18/06/25.
//

import SwiftUI

@main
struct music_playerApp: App {
    @StateObject private var songManager = SongManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(songManager)
        }
    }
}

//
//  ContentView.swift
//  music_player
//
//  Created by Ps Bharath Kumar Achari on 18/06/25.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer

// Song model
struct Song: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let artwork: String // System image name for demo
    let url: URL?
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    @EnvironmentObject var songManager: SongManager
    @State private var showFilePicker = false
    @State private var isNowPlayingPresented = false
    @State private var searchText = ""
    @State private var showSearchBar = false
    @State private var showDeleteSheet = false
    @State private var showCreatePlaylist = false
    @State private var showViewPlaylists = false

    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songManager.songs
        } else {
            return songManager.songs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar with close icon, shown only if showSearchBar is true
                if showSearchBar {
                    HStack {
                        TextField("Search songs...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            searchText = ""
                            showSearchBar = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding([.horizontal, .top])
                }
                List {
                    Section(header: Text("Your Songs")) {
                        ForEach(filteredSongs) { song in
                            Button(action: {
                                songManager.selectedSong = song
                                isNowPlayingPresented = true
                            }) {
                                SongRow(song: song)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    // TODO: Implement add to playlist logic
                                    songManager.addToPlaylist(song)
                                } label: {
                                    Label("Add to Playlist", systemImage: "text.badge.plus")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    songManager.deleteSong(song)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    songManager.playNext(song)
                                } label: {
                                    Label("Play Next", systemImage: "text.insert")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Hamburger menu
                    Menu {
                        Button("Choose MP3", action: { showFilePicker = true })
                        Button("Delete any MP3", action: { showDeleteSheet = true })
                        Button("Search", action: { showSearchBar = true })
                        Divider()
                        Button("Create Playlist", action: { showCreatePlaylist = true })
                        Button("View Playlists", action: { showViewPlaylists = true })
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                            .padding(.trailing, 8)
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                MP3FilePicker { urls in
                    guard let urls = urls else { return }
                    importMP3Files(urls)
                    loadSongsFromDocuments()
                }
            }
            .sheet(isPresented: $isNowPlayingPresented) {
                NowPlayingView(isPresented: $isNowPlayingPresented)
                    .environmentObject(songManager)
            }
            .sheet(isPresented: $showDeleteSheet) {
                DeleteMP3Sheet(isPresented: $showDeleteSheet)
                    .environmentObject(songManager)
            }
            .sheet(isPresented: $showCreatePlaylist) {
                CreatePlaylistSheet(isPresented: $showCreatePlaylist)
                    .environmentObject(songManager)
            }
            .sheet(isPresented: $showViewPlaylists) {
                ViewPlaylistsSheet(isPresented: $showViewPlaylists)
                    .environmentObject(songManager)
            }
            .onAppear {
                loadSongsFromDocuments()
            }
        }
    }
    
    // Copy picked files into app's Documents directory
    func importMP3Files(_ urls: [URL]) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for url in urls {
            let destURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            do {
                // If file already exists, skip
                if !fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.copyItem(at: url, to: destURL)
                }
            } catch {
                print("Failed to copy file: \(error)")
            }
        }
    }
    
    // Load all mp3s from Documents directory
    func loadSongsFromDocuments() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let mp3s = files.filter { $0.pathExtension.lowercased() == "mp3" }
            songManager.songs = mp3s.map { url in
                Song(title: url.deletingPathExtension().lastPathComponent, artist: "Unknown Artist", album: "", artwork: "music.note", url: url)
            }
        } catch {
            print("Failed to load songs: \(error)")
        }
    }
}

struct SongRow: View {
    let song: Song
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: song.artwork)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .cornerRadius(8)
                .padding(.vertical, 4)
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// SongManager to manage song selection and navigation
class SongManager: ObservableObject {
    @Published var songs: [Song] = []
    @Published var selectedSong: Song? = nil
    @Published var isShuffle: Bool = false

    private var shuffledIndices: [Int] = []
    private var currentShuffleIndex: Int = 0

    func isFirst(song: Song) -> Bool {
        guard let idx = songs.firstIndex(of: song) else { return true }
        return idx == 0
    }
    func isLast(song: Song) -> Bool {
        guard let idx = songs.firstIndex(of: song) else { return true }
        return idx == songs.count - 1
    }
    func selectPrevious(current: Song) {
        if isShuffle {
            guard !shuffledIndices.isEmpty, let currentIdx = songs.firstIndex(of: current) else { return }
            if let shufflePos = shuffledIndices.firstIndex(of: currentIdx), shufflePos > 0 {
                selectedSong = songs[shuffledIndices[shufflePos - 1]]
            }
        } else {
            guard let idx = songs.firstIndex(of: current), idx > 0 else { return }
            selectedSong = songs[idx - 1]
        }
    }
    func selectNext(current: Song) {
        if isShuffle {
            guard !shuffledIndices.isEmpty, let currentIdx = songs.firstIndex(of: current) else { return }
            if let shufflePos = shuffledIndices.firstIndex(of: currentIdx), shufflePos < shuffledIndices.count - 1 {
                selectedSong = songs[shuffledIndices[shufflePos + 1]]
            }
        } else {
            guard let idx = songs.firstIndex(of: current), idx < songs.count - 1 else { return }
            selectedSong = songs[idx + 1]
        }
    }
    func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            shuffledIndices = Array(songs.indices).shuffled()
            if let current = selectedSong, let idx = songs.firstIndex(of: current) {
                if let shufflePos = shuffledIndices.firstIndex(of: idx) {
                    // Move current song to the start of the shuffle
                    shuffledIndices.remove(at: shufflePos)
                    shuffledIndices.insert(idx, at: 0)
                }
            }
        } else {
            shuffledIndices = []
        }
    }
}

struct NowPlayingView: View {
    @EnvironmentObject var songManager: SongManager
    @Binding var isPresented: Bool // NEW: controls dismissal
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var timer: Timer? = nil

    var body: some View {
        let song = songManager.selectedSong
        VStack(spacing: 32) {
            Spacer()
            if let song = song {
                Image(systemName: song.artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                Text(song.title)
                    .font(.title)
                    .bold()
                Text(song.artist)
                    .font(.title3)
                    .foregroundColor(.secondary)
                if let url = song.url {
                    Slider(value: $progress, in: 0...(audioPlayer?.duration ?? 1), onEditingChanged: { editing in
                        if !editing {
                            audioPlayer?.currentTime = progress
                        }
                    })
                    .padding(.horizontal)
                }
                HStack(spacing: 40) {
                    Button(action: previousSong) {
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                    }.disabled(songManager.isFirst(song: song) && !songManager.isShuffle)
                    Button(action: togglePlay) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 44))
                    }.disabled(song.url == nil)
                    Button(action: nextSong) {
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                    }.disabled(songManager.isLast(song: song) && !songManager.isShuffle)
                }
                // Shuffle button
                Button(action: {
                    songManager.toggleShuffle()
                }) {
                    Image(systemName: "shuffle")
                        .font(.title)
                        .foregroundColor(songManager.isShuffle ? .blue : .primary)
                        .padding(8)
                        .background(songManager.isShuffle ? Color.blue.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                }
                .accessibilityLabel(songManager.isShuffle ? "Disable Shuffle" : "Enable Shuffle")
            }
            Spacer()
            Button("Dismiss") {
                isPresented = false // Dismiss the sheet
            }
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            setupAudioSession()
            setupRemoteTransportControls()
            playCurrentSong()
        }
        .onChange(of: songManager.selectedSong) { _ in
            playCurrentSong()
        }
        .onDisappear {
            timer?.invalidate()
            audioPlayer?.stop()
        }
    }

    func setupAudioSession() {
        // Set audio session for background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }

    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            if let player = audioPlayer, !player.isPlaying {
                player.play()
                isPlaying = true
                updateNowPlayingInfo()
                return .success
            }
            return .commandFailed
        }
        commandCenter.pauseCommand.addTarget { _ in
            if let player = audioPlayer, player.isPlaying {
                player.pause()
                isPlaying = false
                updateNowPlayingInfo()
                return .success
            }
            return .commandFailed
        }
        // --- Add these for next/previous track support ---
        commandCenter.nextTrackCommand.addTarget { _ in
            if let song = songManager.selectedSong {
                songManager.selectNext(current: song)
                // playCurrentSong() will be called by .onChange(of: songManager.selectedSong)
                return .success
            }
            return .commandFailed
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            if let song = songManager.selectedSong {
                songManager.selectPrevious(current: song)
                // playCurrentSong() will be called by .onChange(of: songManager.selectedSong)
                return .success
            }
            return .commandFailed
        }
    }

    func updateNowPlayingInfo() {
        guard let song = songManager.selectedSong else { return }
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer?.currentTime ?? 0,
            MPMediaItemPropertyPlaybackDuration: audioPlayer?.duration ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        // Optionally add artwork if you have it
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func playCurrentSong() {
        timer?.invalidate()
        audioPlayer?.stop()
        isPlaying = false
        progress = 0
        guard let song = songManager.selectedSong, let url = song.url else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            updateNowPlayingInfo()
            startTimer()
        } catch {
            print("Error loading audio: \(error)")
        }
    }

    func togglePlay() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
        updateNowPlayingInfo()
    }
    
    func previousSong() {
        if let song = songManager.selectedSong {
            songManager.selectPrevious(current: song)
        }
    }
    
    func nextSong() {
        if let song = songManager.selectedSong {
            songManager.selectNext(current: song)
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if let player = audioPlayer {
                progress = player.currentTime
                if !player.isPlaying {
                    isPlaying = false
                }
            }
        }
    }
}

// MP3FilePicker for picking multiple mp3 files
import UniformTypeIdentifiers
struct MP3FilePicker: UIViewControllerRepresentable {
    var onPick: ([URL]?) -> Void
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.mp3], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]?) -> Void
        init(onPick: @escaping ([URL]?) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

struct DeleteMP3Sheet: View {
    @EnvironmentObject var songManager: SongManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(songManager.songs) { song in
                    HStack {
                        Text(song.title)
                        Spacer()
                        Button(role: .destructive) {
                            songManager.deleteSong(song)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let song = songManager.songs[index]
                        songManager.deleteSong(song)
                    }
                }
            }
            .navigationTitle("Delete MP3s")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct CreatePlaylistSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationStack {
            Text("Create Playlist (stub)")
                .padding()
            Button("Done") { isPresented = false }
                .padding()
        }
    }
}

struct ViewPlaylistsSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationStack {
            Text("View Playlists (stub)")
                .padding()
            Button("Done") { isPresented = false }
                .padding()
        }
    }
}

extension SongManager {
    func deleteSong(_ song: Song) {
        if let url = song.url {
            try? FileManager.default.removeItem(at: url)
        }
        songs.removeAll { $0.id == song.id }
        if selectedSong == song {
            selectedSong = nil
        }
    }
    
    func addToPlaylist(_ song: Song) {
        // Implement your playlist logic here
        print("Add \(song.title) to playlist")
    }

    func playNext(_ song: Song) {
        // Implement your play next logic here
        print("Play \(song.title) next")
    }
}

#Preview {
    ContentView()
}

import SwiftUI

/// ტელეფონზე ნაჩვენები მარტივი ეკრანი: ძებნა, სადგურები, რჩეულები, პლეერი.
struct PhoneView: View {
    @ObservedObject private var store = StationStore.shared
    @ObservedObject private var player = AudioPlayer.shared
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("მიაერთე CarPlay (სიმულატორში: I/O → External Displays → CarPlay), და აპლიკაცია მანქანის ეკრანზე გამოჩნდება.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("სადგურები") {
                    ForEach(store.search(query)) { station in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(station.name)
                                Text(station.genre).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if player.current == station && player.isPlaying {
                                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
                            }
                            Button {
                                store.toggleFavorite(station)
                            } label: {
                                Image(systemName: store.isFavorite(station) ? "star.fill" : "star")
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.play(station, queue: store.stations) }
                    }
                }
            }
            .searchable(text: $query, prompt: "ძებნა სახელით ან ჟანრით")
            .navigationTitle("CarPlay Demo")
            .safeAreaInset(edge: .bottom) { miniPlayer }
        }
    }

    @ViewBuilder
    private var miniPlayer: some View {
        if let current = player.current {
            VStack(spacing: 4) {
                if let error = player.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                HStack(spacing: 24) {
                    Text(current.name).font(.headline).lineLimit(1)
                    Spacer()
                    Button { player.previous() } label: { Image(systemName: "backward.fill") }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button { player.next() } label: { Image(systemName: "forward.fill") }
                }
                .font(.title3)
            }
            .padding()
            .background(.bar)
        }
    }
}

import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// საერთო პლეერი ტელეფონისა და CarPlay-ისთვის.
/// CarPlay-ის Now Playing ეკრანი ინფორმაციას MPNowPlayingInfoCenter-იდან კითხულობს,
/// ღილაკები კი MPRemoteCommandCenter-ით მუშაობს.
final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    @Published private(set) var current: Station?
    @Published private(set) var isPlaying = false
    @Published private(set) var lastError: String?

    private let player = AVPlayer()
    private var queue: [Station] = []
    private var cancellables = Set<AnyCancellable>()
    private var itemStatusObservation: NSKeyValueObservation?

    private init() {
        configureAudioSession()
        configureRemoteCommands()

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status != .paused)
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)
    }

    // MARK: Public

    /// ჩართავს სადგურს; `queue` განსაზღვრავს, რა იყოს „შემდეგი/წინა“.
    func play(_ station: Station, queue: [Station]? = nil) {
        if let queue { self.queue = queue }
        if self.queue.isEmpty { self.queue = StationStore.shared.stations }

        lastError = nil
        current = station
        let item = AVPlayerItem(url: station.url)
        itemStatusObservation = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                self?.lastError = item.error?.localizedDescription ?? "ნაკადი ვერ ჩაირთო"
            }
        }
        player.replaceCurrentItem(with: item)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        guard current != nil else { return }
        isPlaying ? player.pause() : player.play()
    }

    func next() { step(by: 1) }
    func previous() { step(by: -1) }

    // MARK: Private

    private func step(by offset: Int) {
        guard let current, !queue.isEmpty,
              let index = queue.firstIndex(of: current) else { return }
        let newIndex = (index + offset + queue.count) % queue.count
        play(queue[newIndex])
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success
        }
        // პირდაპირ ეთერში გადახვევა არ გვაქვს
        center.changePlaybackPositionCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.name,
            MPMediaItemPropertyArtist: current.genre,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

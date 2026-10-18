import UIKit
import CarPlay
import MapKit
import Combine

/// CarPlay-ის ეკრანი. მხოლოდ Apple-ის ოფიციალურ შაბლონებს იყენებს:
///  • CPTabBarTemplate          — ჩანართები ზემოთ
///  • CPListTemplate            — რადიოსადგურების სია (რჩეულები + ყველა)
///  • CPGridTemplate            — ჟანრების ბადე
///  • CPNowPlayingTemplate      — Now Playing (პაუზა, შემდეგი/წინა, რჩეულებში დამატება)
///  • CPPointOfInterestTemplate — EV დამტენები რუკაზე
///  • CPInformationTemplate     — ინფორმაცია და სწრაფი მოქმედებები
///  • CPAlertTemplate           — შეცდომის შეტყობინება
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private weak var scene: CPTemplateApplicationScene?
    private var cancellables = Set<AnyCancellable>()

    private let store = StationStore.shared
    private let player = AudioPlayer.shared

    private var stationsTemplate: CPListTemplate!
    private var infoTemplate: CPInformationTemplate!
    /// station.id → ყველა CPListItem, რომელიც ამ სადგურს აჩვენებს (isPlaying-ის განახლებისთვის)
    private var listItems: [String: [CPListItem]] = [:]

    // MARK: - დაკავშირება / გათიშვა

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.scene = templateApplicationScene

        configureNowPlaying()

        stationsTemplate = makeStationsTemplate()
        let genresTemplate = makeGenresTemplate()
        let chargersTemplate = makeChargersTemplate()
        infoTemplate = makeInfoTemplate()

        let tabs = CPTabBarTemplate(templates: [stationsTemplate, genresTemplate, chargersTemplate, infoTemplate])
        interfaceController.setRootTemplate(tabs, animated: true, completion: nil)

        observeState()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        cancellables.removeAll()
        listItems.removeAll()
        self.interfaceController = nil
    }

    // MARK: - ჩანართი 1: სადგურები

    private func makeStationsTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "რადიო", sections: stationSections())
        template.tabTitle = "რადიო"
        template.tabImage = UIImage(systemName: "radio")
        template.emptyViewTitleVariants = ["სადგურები არ არის"]
        return template
    }

    private func stationSections() -> [CPListSection] {
        listItems.removeAll()
        var sections: [CPListSection] = []
        let favorites = store.favorites
        if !favorites.isEmpty {
            sections.append(CPListSection(items: favorites.map { makeItem(for: $0, queue: favorites) },
                                          header: "რჩეულები", sectionIndexTitle: nil))
        }
        let all = store.stations
        sections.append(CPListSection(items: all.map { makeItem(for: $0, queue: all) },
                                      header: "ყველა სადგური", sectionIndexTitle: nil))
        return sections
    }

    private func makeItem(for station: Station, queue: [Station]) -> CPListItem {
        let star = store.isFavorite(station) ? " ★" : ""
        let item = CPListItem(text: station.name + star,
                              detailText: station.genre,
                              image: UIImage(systemName: "dot.radiowaves.left.and.right"))
        item.playingIndicatorLocation = .trailing
        item.isPlaying = (player.current == station && player.isPlaying)
        item.handler = { [weak self] _, completion in
            self?.player.play(station, queue: queue)
            self?.showNowPlaying()
            completion()
        }
        listItems[station.id, default: []].append(item)
        return item
    }

    // MARK: - ჩანართი 2: ჟანრები (ბადე)

    private func makeGenresTemplate() -> CPGridTemplate {
        let icons = ["music.note", "guitars", "pianokeys", "headphones",
                     "music.mic", "music.quarternote.3", "sparkles", "waveform"]
        // CPGridTemplate მაქსიმუმ 8 ღილაკს აჩვენებს
        let buttons = store.genres.prefix(8).enumerated().map { index, genre in
            CPGridButton(titleVariants: [genre],
                         image: UIImage(systemName: icons[index % icons.count])!) { [weak self] _ in
                self?.pushGenre(genre)
            }
        }
        let template = CPGridTemplate(title: "ჟანრები", gridButtons: Array(buttons))
        template.tabTitle = "ჟანრები"
        template.tabImage = UIImage(systemName: "square.grid.2x2")
        return template
    }

    private func pushGenre(_ genre: String) {
        let stations = store.stations(inGenre: genre)
        let section = CPListSection(items: stations.map { makeItem(for: $0, queue: stations) })
        let template = CPListTemplate(title: genre, sections: [section])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - ჩანართი 3: EV დამტენები (რუკა)

    private func makeChargersTemplate() -> CPPointOfInterestTemplate {
        let points: [CPPointOfInterest] = ChargerData.sample.prefix(12).map { charger in
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: charger.coordinate))
            mapItem.name = charger.name
            let poi = CPPointOfInterest(location: mapItem,
                                        title: charger.name,
                                        subtitle: "\(charger.powerKW) kW",
                                        summary: charger.connector,
                                        detailTitle: charger.name,
                                        detailSubtitle: charger.address,
                                        detailSummary: "\(charger.connector) • \(charger.powerKW) kW",
                                        pinImage: nil)
            poi.primaryButton = CPTextButton(title: "მარშრუტი", textStyle: .confirm) { [weak self] _ in
                self?.openInMaps(charger.coordinate)
            }
            return poi
        }
        let template = CPPointOfInterestTemplate(title: "დამტენები",
                                                 pointsOfInterest: points,
                                                 selectedIndex: NSNotFound)
        template.pointOfInterestDelegate = self
        template.tabTitle = "დამტენები"
        template.tabImage = UIImage(systemName: "bolt.car")
        return template
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        guard let url = URL(string: "maps://?daddr=\(coordinate.latitude),\(coordinate.longitude)") else { return }
        scene?.open(url, options: nil, completionHandler: nil)
    }

    // MARK: - ჩანართი 4: ინფორმაცია

    private func makeInfoTemplate() -> CPInformationTemplate {
        let template = CPInformationTemplate(title: "ინფორმაცია", layout: .leading,
                                             items: infoItems(), actions: infoActions())
        template.tabTitle = "ინფო"
        template.tabImage = UIImage(systemName: "info.circle")
        return template
    }

    private func infoItems() -> [CPInformationItem] {
        [
            CPInformationItem(title: "ახლა უკრავს", detail: player.current?.name ?? "—"),
            CPInformationItem(title: "მდგომარეობა", detail: player.isPlaying ? "ჩართულია" : "პაუზა"),
            CPInformationItem(title: "სადგურები", detail: "\(store.stations.count) (რჩეული: \(store.favorites.count))"),
        ]
    }

    private func infoActions() -> [CPTextButton] {
        [
            CPTextButton(title: player.isPlaying ? "პაუზა" : "ჩართვა", textStyle: .confirm) { [weak self] _ in
                self?.handlePlayPauseFromInfo()
            },
            CPTextButton(title: "შემთხვევითი", textStyle: .normal) { [weak self] _ in
                guard let self, let station = self.store.stations.randomElement() else { return }
                self.player.play(station, queue: self.store.stations)
                self.showNowPlaying()
            },
        ]
    }

    private func handlePlayPauseFromInfo() {
        if player.current == nil, let first = store.favorites.first ?? store.stations.first {
            player.play(first, queue: store.stations)
        } else {
            player.togglePlayPause()
        }
    }

    // MARK: - Now Playing

    private func configureNowPlaying() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = false
        nowPlaying.isAlbumArtistButtonEnabled = false
        updateNowPlayingButtons()
    }

    private func updateNowPlayingButtons() {
        let isFav = player.current.map(store.isFavorite) ?? false
        let star = CPNowPlayingImageButton(image: UIImage(systemName: isFav ? "star.fill" : "star")!) { [weak self] _ in
            guard let self, let current = self.player.current else { return }
            self.store.toggleFavorite(current)
        }
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([star])
    }

    private func showNowPlaying() {
        guard let controller = interfaceController else { return }
        if controller.topTemplate === CPNowPlayingTemplate.shared { return }
        controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    // MARK: - მდგომარეობის დაკვირვება

    private func observeState() {
        Publishers.CombineLatest(player.$current, player.$isPlaying)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current, isPlaying in
                guard let self else { return }
                for (id, items) in self.listItems {
                    let playing = (current?.id == id) && isPlaying
                    items.forEach { $0.isPlaying = playing }
                }
                self.infoTemplate.items = self.infoItems()
                self.infoTemplate.actions = self.infoActions()
                self.updateNowPlayingButtons()
            }
            .store(in: &cancellables)

        store.$favoriteIDs
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // @Published აგზავნის ცვლილებამდე — ერთი ციკლით ვაგვიანებთ
                DispatchQueue.main.async {
                    self.stationsTemplate.updateSections(self.stationSections())
                    self.infoTemplate.items = self.infoItems()
                    self.updateNowPlayingButtons()
                }
            }
            .store(in: &cancellables)

        player.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.showError(message) }
            .store(in: &cancellables)
    }

    private func showError(_ message: String) {
        guard let controller = interfaceController, controller.presentedTemplate == nil else { return }
        let ok = CPAlertAction(title: "კარგი", style: .cancel) { _ in
            controller.dismissTemplate(animated: true, completion: nil)
        }
        let alert = CPAlertTemplate(titleVariants: ["სადგური ვერ ჩაირთო", message], actions: [ok])
        controller.presentTemplate(alert, animated: true, completion: nil)
    }
}

// MARK: - რუკის დელეგატი

extension CarPlaySceneDelegate: CPPointOfInterestTemplateDelegate {
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate,
                                 didChangeMapRegion region: MKCoordinateRegion) {
        // აქ შეიძლება ახალი რეგიონის დამტენების ჩატვირთვა (მაქს. 12 წერტილი)
    }
}

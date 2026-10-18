import Foundation
import CoreLocation

// MARK: - რადიოსადგური

struct Station: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let genre: String
    let url: URL
}

/// სადგურების სია (stations.json-იდან) და რჩეულები (UserDefaults-ში).
final class StationStore: ObservableObject {
    static let shared = StationStore()

    @Published private(set) var stations: [Station] = []
    @Published private(set) var favoriteIDs: Set<String> = []

    private let favoritesKey = "favoriteStationIDs"

    private init() {
        if let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Station].self, from: data) {
            stations = decoded
        }
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favoriteIDs = Set(saved)
    }

    var genres: [String] {
        Array(Set(stations.map(\.genre))).sorted()
    }

    var favorites: [Station] {
        stations.filter { favoriteIDs.contains($0.id) }
    }

    func stations(inGenre genre: String) -> [Station] {
        stations.filter { $0.genre == genre }
    }

    func search(_ text: String) -> [Station] {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return stations }
        return stations.filter {
            $0.name.lowercased().contains(q) || $0.genre.lowercased().contains(q)
        }
    }

    func isFavorite(_ station: Station) -> Bool {
        favoriteIDs.contains(station.id)
    }

    func toggleFavorite(_ station: Station) {
        if favoriteIDs.contains(station.id) {
            favoriteIDs.remove(station.id)
        } else {
            favoriteIDs.insert(station.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
    }
}

// MARK: - EV დამტენი (სატესტო მონაცემები)

struct Charger: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let connector: String
    let powerKW: Int
    let coordinate: CLLocationCoordinate2D
}

enum ChargerData {
    /// სატესტო, გამოგონილი წერტილები თბილისში — რეალური მონაცემებით ჩაანაცვლე.
    static let sample: [Charger] = [
        Charger(name: "სატესტო დამტენი 1", address: "რუსთაველის გამზ. (ტესტი)",
                connector: "J1772 / Type 1", powerKW: 7,
                coordinate: .init(latitude: 41.6995, longitude: 44.7966)),
        Charger(name: "სატესტო დამტენი 2", address: "ვაკე (ტესტი)",
                connector: "CCS / Type 2", powerKW: 50,
                coordinate: .init(latitude: 41.7090, longitude: 44.7580)),
        Charger(name: "სატესტო დამტენი 3", address: "საბურთალო (ტესტი)",
                connector: "J1772 / Type 1", powerKW: 11,
                coordinate: .init(latitude: 41.7250, longitude: 44.7550)),
        Charger(name: "სატესტო დამტენი 4", address: "დიდუბე (ტესტი)",
                connector: "CCS / Type 2", powerKW: 60,
                coordinate: .init(latitude: 41.7360, longitude: 44.7800)),
    ]
}

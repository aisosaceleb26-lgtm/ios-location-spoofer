import Foundation

@MainActor
public final class FavoritesStore: ObservableObject {
    @Published public private(set) var favorites: [SavedLocation] = []
    @Published public private(set) var recents: [SavedLocation] = []

    private let favoritesKey = "opengps.favorites"
    private let recentsKey = "opengps.recents"
    private let defaults: UserDefaults
    private let maxRecents = 20

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load(key: favoritesKey, from: defaults)
        recents = Self.load(key: recentsKey, from: defaults)
    }

    public func addFavorite(name: String, latitude: Double, longitude: Double) throws {
        try CoordinateValidation.validate(latitude: latitude, longitude: longitude)
        let item = SavedLocation(name: name, latitude: latitude, longitude: longitude)
        favorites.removeAll { $0.latitude == latitude && $0.longitude == longitude }
        favorites.insert(item, at: 0)
        persist()
    }

    public func removeFavorite(_ item: SavedLocation) {
        favorites.removeAll { $0.id == item.id }
        persist()
    }

    public func recordRecent(name: String, latitude: Double, longitude: Double) throws {
        try CoordinateValidation.validate(latitude: latitude, longitude: longitude)
        let item = SavedLocation(name: name, latitude: latitude, longitude: longitude)
        recents.removeAll { abs($0.latitude - latitude) < 1e-7 && abs($0.longitude - longitude) < 1e-7 }
        recents.insert(item, at: 0)
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: favoritesKey)
        }
        if let data = try? JSONEncoder().encode(recents) {
            defaults.set(data, forKey: recentsKey)
        }
    }

    private static func load(key: String, from defaults: UserDefaults) -> [SavedLocation] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedLocation].self, from: data)) ?? []
    }
}

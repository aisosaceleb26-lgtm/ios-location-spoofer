import Foundation
import CoreLocation
import Combine
import MapKit

public enum SimulationBackend: String, CaseIterable, Identifiable {
    case preview
    case gpx
    case appleDeveloper

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preview: return "In-App Preview"
        case .gpx: return "GPX Route"
        case .appleDeveloper: return "Apple Developer Host"
        }
    }
}

@MainActor
public final class SimulationSessionViewModel: ObservableObject {
    @Published public var selectedCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
    @Published public var latitudeText = "37.3349"
    @Published public var longitudeText = "-122.00902"
    @Published public var searchQuery = ""
    @Published public var statusMessage = SimulationStatus.inactive.userFacingMessage
    @Published public var simulationStatus: SimulationStatus = .inactive
    @Published public var backend: SimulationBackend = .preview
    @Published public var route = SimulationRoute(name: "Untitled Route", waypoints: [])
    @Published public var routeSpeedMps: Double = 5
    @Published public var routeProgressFraction: Double = 0
    @Published public var simulatedLocation: SimulatedLocation?
    @Published public var cameraPosition: MapCameraPosition
    @Published public var errorMessage: String?
    @Published public var gpxExportText: String?
    @Published public var developerHostConnectedFlag = false

    public let favoritesStore: FavoritesStore
    public let permissionService: LocationPermissionService

    private let previewProvider = PreviewLocationProvider()
    private let gpxProvider = GPXRouteProvider()
    private let developerProvider: AppleDeveloperSimulationProvider
    private var updateTask: Task<Void, Never>?

    public init(
        favoritesStore: FavoritesStore = FavoritesStore(),
        permissionService: LocationPermissionService = LocationPermissionService(),
        developerProvider: AppleDeveloperSimulationProvider = AppleDeveloperSimulationProvider()
    ) {
        self.favoritesStore = favoritesStore
        self.permissionService = permissionService
        self.developerProvider = developerProvider
        self.cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
        refreshStatusMessage()
    }

    public var activeProvider: any LocationSimulationProvider {
        switch backend {
        case .preview: return previewProvider
        case .gpx: return gpxProvider
        case .appleDeveloper: return developerProvider
        }
    }

    public func applyCoordinateFromFields() {
        do {
            let parsed = try CoordinateValidation.parse(
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            selectedCoordinate = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
            syncTexts()
            recenter()
            try favoritesStore.recordRecent(
                name: "Manual \(String(format: "%.5f", parsed.lat)), \(String(format: "%.5f", parsed.lon))",
                latitude: parsed.lat,
                longitude: parsed.lon
            )
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func updatePin(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        syncTexts()
    }

    public func addWaypointAtSelection() {
        do {
            try CoordinateValidation.validate(
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude
            )
            route.waypoints.append(
                RouteWaypoint(
                    latitude: selectedCoordinate.latitude,
                    longitude: selectedCoordinate.longitude,
                    name: "WP\(route.waypoints.count + 1)"
                )
            )
            route.speedMetersPerSecond = routeSpeedMps
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func clearRoute() {
        route.waypoints = []
        routeProgressFraction = 0
    }

    public func importGPX(string: String) {
        do {
            let imported = try gpxProvider.loadGPX(string: string)
            route = imported
            routeSpeedMps = imported.speedMetersPerSecond
            if let first = imported.waypoints.first {
                selectedCoordinate = first.coordinate
                syncTexts()
                recenter()
            }
            backend = .gpx
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func exportGPX() {
        do {
            route.speedMetersPerSecond = routeSpeedMps
            let text = try GPXService.exportXcodeCompatibleGPX(route: route.isEmptyRoute ? pointRoute : route)
            gpxExportText = text
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func start() async {
        errorMessage = nil
        do {
            let configuration = makeConfiguration()
            try await activeProvider.prepare(configuration: configuration)
            try await activeProvider.start()
            simulationStatus = activeProvider.status
            refreshStatusMessage()
            listenForUpdates()
            try favoritesStore.recordRecent(
                name: "Sim \(latitudeText), \(longitudeText)",
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude
            )
        } catch {
            simulationStatus = activeProvider.status
            errorMessage = String(describing: error)
            refreshStatusMessage()
        }
    }

    public func pause() async {
        do {
            try await activeProvider.pause()
            simulationStatus = activeProvider.status
            refreshStatusMessage()
        } catch {
            errorMessage = String(describing: error)
            simulationStatus = activeProvider.status
            refreshStatusMessage()
        }
    }

    public func resume() async {
        do {
            try await activeProvider.resume()
            simulationStatus = activeProvider.status
            refreshStatusMessage()
        } catch {
            errorMessage = String(describing: error)
            simulationStatus = activeProvider.status
            refreshStatusMessage()
        }
    }

    public func stop() async {
        do {
            try await activeProvider.stop()
            simulationStatus = activeProvider.status
            routeProgressFraction = 0
            refreshStatusMessage()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func restoreRealLocation() async {
        do {
            try await activeProvider.restoreRealLocation()
            simulationStatus = activeProvider.status
            simulatedLocation = nil
            refreshStatusMessage()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func useRealLocation() {
        permissionService.requestWhenInUseIfNeeded()
        permissionService.startUpdating()
        if let location = permissionService.lastRealLocation {
            selectedCoordinate = location.coordinate
            syncTexts()
            recenter()
        }
    }

    public func saveFavorite(named name: String) {
        do {
            try favoritesStore.addFavorite(
                name: name,
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func selectSaved(_ item: SavedLocation) {
        selectedCoordinate = item.coordinate
        syncTexts()
        recenter()
    }

    public func noteDeveloperHostConnected(_ connected: Bool) {
        developerHostConnectedFlag = connected
        developerProvider.noteDeveloperHostConnected(connected)
        if backend == .appleDeveloper {
            simulationStatus = developerProvider.status
            refreshStatusMessage()
        }
    }

    public func confirmDeveloperHost(_ confirmed: Bool) {
        developerProvider.confirmHostSimulationFromExternalCheck(confirmed)
        simulationStatus = developerProvider.status
        refreshStatusMessage()
    }

    public func searchPlaces() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let item = response.mapItems.first, let coord = item.placemark.location?.coordinate {
                selectedCoordinate = coord
                syncTexts()
                recenter()
                try? favoritesStore.recordRecent(
                    name: item.name ?? query,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            } else {
                errorMessage = "No places found for “\(query)”."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeConfiguration() -> SimulationConfiguration {
        route.speedMetersPerSecond = routeSpeedMps
        if backend == .gpx || route.waypoints.count >= 2 {
            return SimulationConfiguration(coordinate: selectedCoordinate, route: route)
        }
        return SimulationConfiguration(coordinate: selectedCoordinate, route: nil)
    }

    private var pointRoute: SimulationRoute {
        SimulationRoute(
            name: "Point",
            waypoints: [
                RouteWaypoint(
                    latitude: selectedCoordinate.latitude,
                    longitude: selectedCoordinate.longitude
                )
            ],
            speedMetersPerSecond: routeSpeedMps
        )
    }

    private func listenForUpdates() {
        updateTask?.cancel()
        let stream = activeProvider.locationUpdates
        updateTask = Task { [weak self] in
            for await location in stream {
                guard let self else { return }
                self.simulatedLocation = location
                self.selectedCoordinate = location.coordinate
                self.syncTexts()
                self.simulationStatus = self.activeProvider.status
                self.refreshStatusMessage()
            }
        }
    }

    private func syncTexts() {
        latitudeText = String(format: "%.6f", selectedCoordinate.latitude)
        longitudeText = String(format: "%.6f", selectedCoordinate.longitude)
    }

    private func recenter() {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: selectedCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )
        )
    }

    private func refreshStatusMessage() {
        statusMessage = simulationStatus.userFacingMessage
        if simulationStatus.mayClaimSystemWideSimulation {
            // Still avoid the forbidden absolute claim; message already qualifies confirmation.
            statusMessage = simulationStatus.userFacingMessage
        }
    }
}

private extension SimulationRoute {
    var isEmptyRoute: Bool { waypoints.isEmpty }
}

import Foundation
import CoreLocation

/// Reads/validates GPX and generates paced routes for testing (in-app or export).
@MainActor
public final class GPXRouteProvider: LocationSimulationProvider {
    public let id = "gpx-route"
    public let displayName = "GPX Route"
    public let capabilities: SimulationCapabilities = [.inAppPreview, .gpxImportExport, .routePlayback]

    public private(set) var status: SimulationStatus = .inactive
    public private(set) var loadedRoute: SimulationRoute?
    public private(set) var lastProgress: RouteProgress?

    private let preview = PreviewLocationProvider()
    private var prepared = false

    public var locationUpdates: AsyncStream<SimulatedLocation> {
        preview.locationUpdates
    }

    public init() {}

    public func loadGPX(data: Data) throws -> SimulationRoute {
        let route = try GPXService.parse(data: data)
        loadedRoute = route
        return route
    }

    public func loadGPX(string: String) throws -> SimulationRoute {
        let route = try GPXService.parse(string: string)
        loadedRoute = route
        return route
    }

    public func exportLoadedRoute() throws -> String {
        guard let loadedRoute else { throw ProviderError.notPrepared }
        return try GPXService.exportXcodeCompatibleGPX(route: loadedRoute)
    }

    public func prepare(configuration: SimulationConfiguration) async throws {
        var config = configuration
        if config.route == nil {
            config.route = loadedRoute
        }
        guard let route = config.route, route.waypoints.count >= 2 else {
            throw ProviderError.invalidRoute
        }
        for wp in route.waypoints {
            try CoordinateValidation.validate(latitude: wp.latitude, longitude: wp.longitude)
        }
        loadedRoute = route
        try await preview.prepare(configuration: config)
        prepared = true
        status = .inactive
    }

    public func start() async throws {
        guard prepared else { throw ProviderError.notPrepared }
        try await preview.start()
        status = preview.status
        Task { [weak self] in
            guard let self else { return }
            for await location in self.preview.locationUpdates {
                self.status = self.preview.status
                _ = location
            }
        }
    }

    public func pause() async throws {
        try await preview.pause()
        status = .paused
    }

    public func resume() async throws {
        try await preview.resume()
        status = .previewActive
    }

    public func stop() async throws {
        try await preview.stop()
        status = .inactive
    }

    public func restoreRealLocation() async throws {
        try await stop()
    }
}

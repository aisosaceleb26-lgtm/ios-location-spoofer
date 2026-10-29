import Foundation
import CoreLocation

/// Simulates selected coordinates inside OpenGPS only (UI / demo / local testing).
@MainActor
public final class PreviewLocationProvider: LocationSimulationProvider {
    public let id = "preview"
    public let displayName = "In-App Preview"
    public let capabilities: SimulationCapabilities = [.inAppPreview, .routePlayback]

    public private(set) var status: SimulationStatus = .inactive

    private var configuration: SimulationConfiguration?
    private var interpolator: RouteInterpolator?
    private var timerTask: Task<Void, Never>?
    private var continuation: AsyncStream<SimulatedLocation>.Continuation?
    private var staticCoordinate: CLLocationCoordinate2D?

    public private(set) lazy var locationUpdates: AsyncStream<SimulatedLocation> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    public init() {}

    public func prepare(configuration: SimulationConfiguration) async throws {
        self.configuration = configuration
        if let route = configuration.route, route.waypoints.count >= 2 {
            let coords = route.waypoints.map(\.coordinate)
            interpolator = RouteInterpolator(
                waypoints: coords,
                speedMetersPerSecond: route.speedMetersPerSecond
            )
            staticCoordinate = nil
        } else if let coordinate = configuration.coordinate {
            try CoordinateValidation.validate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            staticCoordinate = coordinate
            interpolator = nil
        } else {
            throw ProviderError.missingConfiguration
        }
        status = .inactive
    }

    public func start() async throws {
        guard configuration != nil else { throw ProviderError.notPrepared }
        timerTask?.cancel()
        status = .previewActive
        let interval = configuration?.updateInterval ?? 1.0
        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.emitTick(delta: interval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func pause() async throws {
        interpolator?.pause()
        status = .paused
    }

    public func resume() async throws {
        interpolator?.resume()
        status = .previewActive
        if timerTask == nil {
            try await start()
        }
    }

    public func stop() async throws {
        timerTask?.cancel()
        timerTask = nil
        interpolator?.reset()
        status = .inactive
    }

    public func restoreRealLocation() async throws {
        try await stop()
        status = .inactive
    }

    private func emitTick(delta: TimeInterval) {
        let accuracy = configuration?.horizontalAccuracy ?? 5
        if let interpolator {
            let progress = interpolator.advance(by: delta)
            let location = SimulatedLocation(
                coordinate: progress.coordinate,
                horizontalAccuracy: accuracy,
                speed: progress.speed,
                course: progress.course,
                timestamp: Date()
            )
            continuation?.yield(location)
            if progress.isComplete {
                status = .paused
                timerTask?.cancel()
                timerTask = nil
            }
        } else if let staticCoordinate {
            continuation?.yield(
                SimulatedLocation(
                    coordinate: staticCoordinate,
                    horizontalAccuracy: accuracy,
                    timestamp: Date()
                )
            )
        }
    }
}

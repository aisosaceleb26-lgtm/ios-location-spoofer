import Foundation
import CoreLocation

/// Integrates with **documented / authorized host-side** Apple developer location simulation only.
///
/// Verified facts:
/// - There is no public App Store API for an iPhone app to inject system-wide Core Location.
/// - Apple documents Xcode Simulate Location, test-plan GPX, and `XCUILocation` (requires Xcode / test host).
/// - Host tools that talk to developer services (Developer Mode + DDI/Cryptex) require a computer.
///
/// This provider:
/// 1. Prepares Xcode-compatible GPX for handoff.
/// 2. Reports `.requiresDeveloperHost` until an external confirmation is recorded.
/// 3. Never claims system-wide spoofing from the phone process alone.
@MainActor
public final class AppleDeveloperSimulationProvider: LocationSimulationProvider {
    public let id = "apple-developer"
    public let displayName = "Apple Developer Simulation"
    public let capabilities: SimulationCapabilities = [
        .gpxImportExport,
        .routePlayback,
        .developerHostHandoff
        // `.systemWideCoreLocation` is intentionally NOT advertised as an in-app capability.
    ]

    public private(set) var status: SimulationStatus
    public private(set) var preparedGPX: String?
    public private(set) var lastExportedURL: URL?

    private var configuration: SimulationConfiguration?
    private var hostConnected: Bool
    private var continuation: AsyncStream<SimulatedLocation>.Continuation?

    public private(set) lazy var locationUpdates: AsyncStream<SimulatedLocation> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    public init(
        iosMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        initiallyHostConnected: Bool = false
    ) {
        self.hostConnected = initiallyHostConnected
        if let reason = IOSVersionSupport.unsupportedReason(majorVersion: iosMajorVersion) {
            status = .unavailable(reason: reason)
        } else {
            status = .requiresDeveloperHost(
                message: Self.hostRequiredMessage
            )
        }
    }

    public static let hostRequiredMessage = """
        Apple developer location simulation cannot be started from OpenGPS alone. \
        Use a Mac with Xcode (Debug → Simulate Location / GPX) or another development host \
        with Developer Mode and a mounted developer disk image / Cryptex. \
        iPhone-only pairing for this mechanism is not supported.
        """

    public func prepare(configuration: SimulationConfiguration) async throws {
        if case .unavailable = status { throw ProviderError.unsupportedOnThisDevice(status.userFacingMessage) }

        self.configuration = configuration
        let route: SimulationRoute
        if let existing = configuration.route, !existing.waypoints.isEmpty {
            route = existing
        } else if let coordinate = configuration.coordinate {
            try CoordinateValidation.validate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            route = SimulationRoute(
                name: "OpenGPS Point",
                waypoints: [
                    RouteWaypoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                ]
            )
        } else {
            throw ProviderError.missingConfiguration
        }

        preparedGPX = try GPXService.exportXcodeCompatibleGPX(route: route)
        status = hostConnected
            ? .developerHostActive(userConfirmed: false)
            : .requiresDeveloperHost(message: Self.hostRequiredMessage)
    }

    public func start() async throws {
        guard preparedGPX != nil else { throw ProviderError.notPrepared }
        guard hostConnected else {
            status = .requiresDeveloperHost(message: Self.hostRequiredMessage)
            throw ProviderError.developerHostRequired
        }
        status = .developerHostActive(userConfirmed: false)
    }

    public func pause() async throws {
        guard hostConnected else {
            status = .connectionLost(reason: "Cannot pause host simulation without an active developer connection.")
            throw ProviderError.connectionLost
        }
        status = .paused
    }

    public func resume() async throws {
        guard hostConnected else {
            status = .connectionLost(reason: "Developer host disconnected.")
            throw ProviderError.connectionLost
        }
        status = .developerHostActive(userConfirmed: false)
    }

    public func stop() async throws {
        status = hostConnected
            ? .requiresDeveloperHost(message: "Host still connected; clear Simulate Location / host clear command to restore GNSS.")
            : .inactive
    }

    public func restoreRealLocation() async throws {
        // Phone cannot clear Xcode/DVT simulation by itself.
        hostConnected = false
        status = .requiresDeveloperHost(
            message: """
            To restore real location: in Xcode choose Debug → Simulate Location → Don't Simulate Location, \
            or run your host tool's clear command, then disable Developer Mode if desired \
            (Settings → Privacy & Security → Developer Mode).
            """
        )
    }

    /// Called when a development host is detected/paired (USB/tunnel). Does not prove location injection succeeded.
    public func noteDeveloperHostConnected(_ connected: Bool) {
        hostConnected = connected
        if !connected {
            status = .connectionLost(reason: "USB/tunnel or debug session ended.")
        } else if preparedGPX != nil {
            status = .developerHostActive(userConfirmed: false)
        } else {
            status = .requiresDeveloperHost(message: Self.hostRequiredMessage)
        }
    }

    /// User acknowledges they verified host simulation in a separate controlled test app.
    /// Still does not let OpenGPS prove system-wide state from public APIs.
    public func confirmHostSimulationFromExternalCheck(_ confirmed: Bool) {
        guard hostConnected else {
            status = .connectionLost(reason: "No developer host connection to confirm.")
            return
        }
        status = .developerHostActive(userConfirmed: confirmed)
    }

    public func writePreparedGPX(to directory: URL) throws -> URL {
        guard let preparedGPX else { throw ProviderError.notPrepared }
        let url = directory.appendingPathComponent("OpenGPS-Developer.gpx")
        try preparedGPX.data(using: .utf8)?.write(to: url, options: .atomic)
        lastExportedURL = url
        return url
    }
}

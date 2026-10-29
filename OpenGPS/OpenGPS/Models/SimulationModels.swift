import Foundation
import CoreLocation

public struct SimulatedLocation: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var altitude: CLLocationDistance
    public var horizontalAccuracy: CLLocationAccuracy
    public var verticalAccuracy: CLLocationAccuracy
    public var speed: CLLocationSpeed
    public var course: CLLocationDirection
    public var timestamp: Date

    public init(
        coordinate: CLLocationCoordinate2D,
        altitude: CLLocationDistance = 0,
        horizontalAccuracy: CLLocationAccuracy = 5,
        verticalAccuracy: CLLocationAccuracy = 5,
        speed: CLLocationSpeed = -1,
        course: CLLocationDirection = -1,
        timestamp: Date = Date()
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }

    public static func == (lhs: SimulatedLocation, rhs: SimulatedLocation) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.altitude == rhs.altitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.verticalAccuracy == rhs.verticalAccuracy
            && lhs.speed == rhs.speed
            && lhs.course == rhs.course
            && lhs.timestamp == rhs.timestamp
    }

    public var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}

public struct RouteWaypoint: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?
    public var name: String?
    public var timeOffset: TimeInterval?

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        name: String? = nil,
        timeOffset: TimeInterval? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.name = name
        self.timeOffset = timeOffset
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct SimulationRoute: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var waypoints: [RouteWaypoint]
    public var speedMetersPerSecond: Double

    public init(
        id: UUID = UUID(),
        name: String = "Route",
        waypoints: [RouteWaypoint] = [],
        speedMetersPerSecond: Double = 5
    ) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.speedMetersPerSecond = speedMetersPerSecond
    }
}

public struct SavedLocation: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct SimulationConfiguration: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D?
    public var route: SimulationRoute?
    public var horizontalAccuracy: CLLocationAccuracy
    public var updateInterval: TimeInterval

    public init(
        coordinate: CLLocationCoordinate2D? = nil,
        route: SimulationRoute? = nil,
        horizontalAccuracy: CLLocationAccuracy = 5,
        updateInterval: TimeInterval = 1.0
    ) {
        self.coordinate = coordinate
        self.route = route
        self.horizontalAccuracy = horizontalAccuracy
        self.updateInterval = updateInterval
    }
}

public struct SimulationCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let inAppPreview = SimulationCapabilities(rawValue: 1 << 0)
    public static let gpxImportExport = SimulationCapabilities(rawValue: 1 << 1)
    public static let routePlayback = SimulationCapabilities(rawValue: 1 << 2)
    public static let developerHostHandoff = SimulationCapabilities(rawValue: 1 << 3)
    public static let systemWideCoreLocation = SimulationCapabilities(rawValue: 1 << 4)
}

public enum SimulationStatus: Equatable, Sendable {
    case inactive
    case previewActive
    case paused
    case requiresDeveloperHost(message: String)
    case developerHostActive(userConfirmed: Bool)
    case unavailable(reason: String)
    case connectionLost(reason: String)

    public var isActivelySimulatingInApp: Bool {
        switch self {
        case .previewActive: return true
        default: return false
        }
    }

    /// Only true when a supported external host confirmation path was used.
    public var mayClaimSystemWideSimulation: Bool {
        if case .developerHostActive(let confirmed) = self {
            return confirmed
        }
        return false
    }

    public var userFacingMessage: String {
        switch self {
        case .inactive:
            return "Simulation inactive. Showing map selection only."
        case .previewActive:
            return "In-app preview active. Other apps still use real device location."
        case .paused:
            return "Simulation paused."
        case .requiresDeveloperHost(let message):
            return message
        case .developerHostActive(let userConfirmed):
            if userConfirmed {
                return "Developer host simulation marked active by user confirmation. Verify in a separate test app."
            }
            return "Waiting for developer host confirmation."
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        case .connectionLost(let reason):
            return "Developer connection lost: \(reason)"
        }
    }
}

public enum IOSVersionSupport {
    /// OpenGPS supports iOS 17+. Callers pass ProcessInfo-derived major version in tests.
    public static func isSupported(majorVersion: Int) -> Bool {
        majorVersion >= 17
    }

    public static func unsupportedReason(majorVersion: Int) -> String? {
        guard !isSupported(majorVersion: majorVersion) else { return nil }
        return "OpenGPS requires iOS 17 or later (detected major version \(majorVersion))."
    }
}

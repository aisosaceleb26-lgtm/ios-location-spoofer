import Foundation
import CoreLocation

public struct RouteProgress: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var distanceTraveled: CLLocationDistance
    public var totalDistance: CLLocationDistance
    public var fractionComplete: Double
    public var speed: CLLocationSpeed
    public var course: CLLocationDirection
    public var isComplete: Bool

    public static func == (lhs: RouteProgress, rhs: RouteProgress) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.distanceTraveled == rhs.distanceTraveled
            && lhs.totalDistance == rhs.totalDistance
            && lhs.fractionComplete == rhs.fractionComplete
            && lhs.speed == rhs.speed
            && lhs.course == rhs.course
            && lhs.isComplete == rhs.isComplete
    }
}

public final class RouteInterpolator: @unchecked Sendable {
    public private(set) var waypoints: [CLLocationCoordinate2D]
    public private(set) var speedMetersPerSecond: Double
    public private(set) var distanceTraveled: CLLocationDistance = 0
    public private(set) var isPaused: Bool = false

    private var segmentLengths: [CLLocationDistance] = []
    private var totalDistance: CLLocationDistance = 0

    public init(waypoints: [CLLocationCoordinate2D], speedMetersPerSecond: Double) {
        self.waypoints = waypoints
        self.speedMetersPerSecond = max(0.1, speedMetersPerSecond)
        recompute()
    }

    public func update(waypoints: [CLLocationCoordinate2D], speedMetersPerSecond: Double) {
        self.waypoints = waypoints
        self.speedMetersPerSecond = max(0.1, speedMetersPerSecond)
        distanceTraveled = 0
        isPaused = false
        recompute()
    }

    public func pause() { isPaused = true }
    public func resume() { isPaused = false }

    public func reset() {
        distanceTraveled = 0
        isPaused = false
    }

    @discardableResult
    public func advance(by deltaTime: TimeInterval) -> RouteProgress {
        if !isPaused && totalDistance > 0 {
            distanceTraveled = min(totalDistance, distanceTraveled + speedMetersPerSecond * max(0, deltaTime))
        }
        return currentProgress()
    }

    public func currentProgress() -> RouteProgress {
        guard waypoints.count >= 2, totalDistance > 0 else {
            let coord = waypoints.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            return RouteProgress(
                coordinate: coord,
                distanceTraveled: 0,
                totalDistance: 0,
                fractionComplete: 1,
                speed: 0,
                course: -1,
                isComplete: true
            )
        }

        var remaining = distanceTraveled
        for index in 0..<(waypoints.count - 1) {
            let length = segmentLengths[index]
            if remaining <= length || index == waypoints.count - 2 {
                let fraction = length > 0 ? min(1, remaining / length) : 1
                let coord = GeoMath.interpolate(from: waypoints[index], to: waypoints[index + 1], fraction: fraction)
                let course = GeoMath.bearing(from: waypoints[index], to: waypoints[index + 1])
                let complete = distanceTraveled >= totalDistance
                return RouteProgress(
                    coordinate: coord,
                    distanceTraveled: distanceTraveled,
                    totalDistance: totalDistance,
                    fractionComplete: distanceTraveled / totalDistance,
                    speed: isPaused ? 0 : speedMetersPerSecond,
                    course: course,
                    isComplete: complete
                )
            }
            remaining -= length
        }

        let last = waypoints.last!
        return RouteProgress(
            coordinate: last,
            distanceTraveled: totalDistance,
            totalDistance: totalDistance,
            fractionComplete: 1,
            speed: 0,
            course: -1,
            isComplete: true
        )
    }

    private func recompute() {
        segmentLengths = []
        totalDistance = 0
        guard waypoints.count >= 2 else { return }
        for index in 0..<(waypoints.count - 1) {
            let d = GeoMath.haversineDistance(from: waypoints[index], to: waypoints[index + 1])
            segmentLengths.append(d)
            totalDistance += d
        }
    }
}

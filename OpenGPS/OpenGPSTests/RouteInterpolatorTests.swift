import XCTest
import CoreLocation
@testable import OpenGPS

final class RouteInterpolatorTests: XCTestCase {
    func testInterpolationMidpoint() {
        let start = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let end = CLLocationCoordinate2D(latitude: 10, longitude: 20)
        let mid = GeoMath.interpolate(from: start, to: end, fraction: 0.5)
        XCTAssertEqual(mid.latitude, 5, accuracy: 1e-9)
        XCTAssertEqual(mid.longitude, 10, accuracy: 1e-9)
    }

    func testRouteAdvanceAndPauseResume() {
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        let interpolator = RouteInterpolator(waypoints: points, speedMetersPerSecond: 100)
        let first = interpolator.advance(by: 1)
        XCTAssertGreaterThan(first.distanceTraveled, 0)
        XCTAssertFalse(first.isComplete)

        interpolator.pause()
        let pausedDistance = interpolator.distanceTraveled
        let whilePaused = interpolator.advance(by: 5)
        XCTAssertEqual(whilePaused.distanceTraveled, pausedDistance, accuracy: 1e-9)
        XCTAssertEqual(whilePaused.speed, 0, accuracy: 1e-9)

        interpolator.resume()
        let resumed = interpolator.advance(by: 1)
        XCTAssertGreaterThan(resumed.distanceTraveled, pausedDistance)
    }

    func testRouteCompletes() {
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.0001)
        ]
        let interpolator = RouteInterpolator(waypoints: points, speedMetersPerSecond: 1000)
        let progress = interpolator.advance(by: 60)
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.fractionComplete, 1, accuracy: 1e-9)
    }
}

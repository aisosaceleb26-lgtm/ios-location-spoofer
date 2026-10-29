import XCTest
@testable import OpenGPS

final class GPXServiceTests: XCTestCase {
    func testParseValidWaypoints() throws {
        let gpx = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="test">
          <wpt lat="37.3349" lon="-122.00902"><name>A</name></wpt>
          <wpt lat="37.3317" lon="-122.0301"><name>B</name></wpt>
        </gpx>
        """
        let route = try GPXService.parse(string: gpx)
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertEqual(route.waypoints[0].latitude, 37.3349, accuracy: 0.00001)
        XCTAssertEqual(route.waypoints[1].name, "B")
    }

    func testParseTrackPoints() throws {
        let gpx = """
        <gpx><trk><trkseg>
          <trkpt lat="1" lon="2"/>
          <trkpt lat="1.1" lon="2.1"/>
        </trkseg></trk></gpx>
        """
        let route = try GPXService.parse(string: gpx)
        XCTAssertEqual(route.waypoints.count, 2)
    }

    func testEmptyDocument() {
        XCTAssertThrowsError(try GPXService.parse(data: Data())) { error in
            XCTAssertEqual(error as? GPXError, .emptyDocument)
        }
    }

    func testMalformedXML() {
        XCTAssertThrowsError(try GPXService.parse(string: "<gpx><wpt lat='1'")) { error in
            XCTAssertEqual(error as? GPXError, .malformedXML)
        }
    }

    func testNoCoordinates() {
        XCTAssertThrowsError(try GPXService.parse(string: "<gpx></gpx>")) { error in
            XCTAssertEqual(error as? GPXError, .noCoordinates)
        }
    }

    func testInvalidCoordinateInGPX() {
        XCTAssertThrowsError(try GPXService.parse(string: #"<gpx><wpt lat="999" lon="0"/></gpx>"#)) { error in
            guard case GPXError.invalidCoordinate = error as? GPXError else {
                return XCTFail("Expected invalidCoordinate")
            }
        }
    }

    func testExportRoundTrip() throws {
        let route = SimulationRoute(
            name: "Test",
            waypoints: [
                RouteWaypoint(latitude: 46.95, longitude: 7.45, name: "Bern"),
                RouteWaypoint(latitude: 47.37, longitude: 8.54, name: "Zurich")
            ],
            speedMetersPerSecond: 10
        )
        let exported = try GPXService.exportXcodeCompatibleGPX(route: route)
        XCTAssertTrue(exported.contains("<wpt lat="))
        XCTAssertFalse(exported.contains("<trkpt"))
        let parsed = try GPXService.parse(string: exported)
        XCTAssertEqual(parsed.waypoints.count, 2)
    }
}

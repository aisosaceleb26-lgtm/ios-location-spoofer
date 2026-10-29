import XCTest
@testable import OpenGPS

final class CoordinateValidationTests: XCTestCase {
    func testValidCoordinates() throws {
        try CoordinateValidation.validate(latitude: 0, longitude: 0)
        try CoordinateValidation.validate(latitude: 90, longitude: 180)
        try CoordinateValidation.validate(latitude: -90, longitude: -180)
        try CoordinateValidation.validate(latitude: 37.3349, longitude: -122.00902)
    }

    func testLatitudeOutOfRange() {
        XCTAssertThrowsError(try CoordinateValidation.validate(latitude: 90.1, longitude: 0)) { error in
            XCTAssertEqual(error as? CoordinateValidationError, .latitudeOutOfRange(90.1))
        }
        XCTAssertThrowsError(try CoordinateValidation.validate(latitude: -91, longitude: 0))
    }

    func testLongitudeOutOfRange() {
        XCTAssertThrowsError(try CoordinateValidation.validate(latitude: 0, longitude: 181)) { error in
            XCTAssertEqual(error as? CoordinateValidationError, .longitudeOutOfRange(181))
        }
    }

    func testNonFinite() {
        XCTAssertThrowsError(try CoordinateValidation.validate(latitude: .nan, longitude: 0))
        XCTAssertThrowsError(try CoordinateValidation.validate(latitude: 0, longitude: .infinity))
    }

    func testParseEmpty() {
        XCTAssertThrowsError(try CoordinateValidation.parse(latitudeText: " ", longitudeText: "1")) { error in
            XCTAssertEqual(error as? CoordinateValidationError, .emptyInput)
        }
    }

    func testParseText() throws {
        let parsed = try CoordinateValidation.parse(latitudeText: "46.9480", longitudeText: "7.4474")
        XCTAssertEqual(parsed.lat, 46.9480, accuracy: 0.0001)
        XCTAssertEqual(parsed.lon, 7.4474, accuracy: 0.0001)
    }
}

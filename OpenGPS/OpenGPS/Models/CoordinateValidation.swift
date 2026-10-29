import Foundation

public enum CoordinateValidationError: Error, Equatable, CustomStringConvertible {
    case latitudeOutOfRange(Double)
    case longitudeOutOfRange(Double)
    case notFinite
    case emptyInput

    public var description: String {
        switch self {
        case .latitudeOutOfRange(let v):
            return "Latitude \(v) is outside [-90, 90]."
        case .longitudeOutOfRange(let v):
            return "Longitude \(v) is outside [-180, 180]."
        case .notFinite:
            return "Coordinate components must be finite numbers."
        case .emptyInput:
            return "Latitude and longitude are required."
        }
    }
}

public enum CoordinateValidation {
    public static func validate(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite, longitude.isFinite else {
            throw CoordinateValidationError.notFinite
        }
        guard (-90.0...90.0).contains(latitude) else {
            throw CoordinateValidationError.latitudeOutOfRange(latitude)
        }
        guard (-180.0...180.0).contains(longitude) else {
            throw CoordinateValidationError.longitudeOutOfRange(longitude)
        }
    }

    public static func parse(latitudeText: String, longitudeText: String) throws -> (lat: Double, lon: Double) {
        let latTrim = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lonTrim = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latTrim.isEmpty, !lonTrim.isEmpty else {
            throw CoordinateValidationError.emptyInput
        }
        guard let lat = Double(latTrim), let lon = Double(lonTrim) else {
            throw CoordinateValidationError.notFinite
        }
        try validate(latitude: lat, longitude: lon)
        return (lat, lon)
    }
}

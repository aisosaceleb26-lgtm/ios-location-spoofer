import Foundation
import CoreLocation

public enum GPXError: Error, Equatable, CustomStringConvertible {
    case emptyDocument
    case malformedXML
    case noCoordinates
    case invalidCoordinate(lat: String, lon: String)

    public var description: String {
        switch self {
        case .emptyDocument: return "GPX document is empty."
        case .malformedXML: return "GPX XML is malformed."
        case .noCoordinates: return "GPX contained no usable waypoints, track points, or route points."
        case .invalidCoordinate(let lat, let lon): return "Invalid GPX coordinate lat=\(lat) lon=\(lon)."
        }
    }
}

public enum GPXService {
    public static func parse(data: Data) throws -> SimulationRoute {
        guard !data.isEmpty else { throw GPXError.emptyDocument }
        let parser = GPXXMLParser()
        return try parser.parse(data: data)
    }

    public static func parse(string: String) throws -> SimulationRoute {
        guard let data = string.data(using: .utf8) else { throw GPXError.malformedXML }
        return try parse(data: data)
    }

    /// Exports Xcode-compatible GPX using `<wpt>` only (Apple does not use `<rte>`/`<trk>` for Simulate Location).
    public static func exportXcodeCompatibleGPX(
        route: SimulationRoute,
        creator: String = "OpenGPS"
    ) throws -> String {
        guard !route.waypoints.isEmpty else { throw GPXError.noCoordinates }
        for wp in route.waypoints {
            try CoordinateValidation.validate(latitude: wp.latitude, longitude: wp.longitude)
        }

        var lines: [String] = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="\#(xmlEscape(creator))" xmlns="http://www.topografix.com/GPX/1/1">"#
        ]

        let baseDate = Date()
        for (index, wp) in route.waypoints.enumerated() {
            lines.append(#"  <wpt lat="\#(wp.latitude)" lon="\#(wp.longitude)">"#)
            if let name = wp.name, !name.isEmpty {
                lines.append("    <name>\(xmlEscape(name))</name>")
            } else {
                lines.append("    <name>\(xmlEscape(route.name))-\(index + 1)</name>")
            }
            let offset = wp.timeOffset ?? estimatedOffset(for: index, in: route)
            let date = baseDate.addingTimeInterval(offset)
            lines.append("    <time>\(iso8601(date))</time>")
            if let alt = wp.altitude {
                lines.append("    <ele>\(alt)</ele>")
            }
            lines.append("  </wpt>")
        }
        lines.append("</gpx>")
        return lines.joined(separator: "\n")
    }

    private static func estimatedOffset(for index: Int, in route: SimulationRoute) -> TimeInterval {
        guard index > 0 else { return 0 }
        var distance: CLLocationDistance = 0
        for i in 1...index {
            let a = route.waypoints[i - 1].coordinate
            let b = route.waypoints[i].coordinate
            distance += GeoMath.haversineDistance(from: a, to: b)
        }
        return distance / max(0.1, route.speedMetersPerSecond)
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private final class GPXXMLParser: NSObject, XMLParserDelegate {
    private var waypoints: [RouteWaypoint] = []
    private var currentElement = ""
    private var currentLat: String?
    private var currentLon: String?
    private var currentName: String?
    private var currentEle: String?
    private var currentTime: String?
    private var textBuffer = ""
    private var parseError: Error?
    private var routeName = "Imported GPX"
    private var firstTime: Date?

    func parse(data: Data) throws -> SimulationRoute {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parseError ?? GPXError.malformedXML
        }
        if let parseError { throw parseError }
        guard !waypoints.isEmpty else { throw GPXError.noCoordinates }
        return SimulationRoute(name: routeName, waypoints: waypoints)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()
        textBuffer = ""
        if ["wpt", "trkpt", "rtept"].contains(currentElement) {
            currentLat = attributeDict["lat"]
            currentLon = attributeDict["lon"]
            currentName = nil
            currentEle = nil
            currentTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "name":
            if currentLat != nil {
                currentName = trimmed
            } else if !trimmed.isEmpty {
                routeName = trimmed
            }
        case "ele":
            currentEle = trimmed
        case "time":
            currentTime = trimmed
        case "wpt", "trkpt", "rtept":
            appendPoint()
        default:
            break
        }
        currentElement = ""
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = GPXError.malformedXML
    }

    private func appendPoint() {
        guard let latText = currentLat, let lonText = currentLon else { return }
        guard let lat = Double(latText), let lon = Double(lonText) else {
            parseError = GPXError.invalidCoordinate(lat: latText, lon: lonText)
            return
        }
        do {
            try CoordinateValidation.validate(latitude: lat, longitude: lon)
        } catch {
            parseError = GPXError.invalidCoordinate(lat: latText, lon: lonText)
            return
        }
        var offset: TimeInterval?
        if let currentTime, let date = ISO8601DateFormatter().date(from: currentTime) {
            if firstTime == nil { firstTime = date }
            if let firstTime {
                offset = date.timeIntervalSince(firstTime)
            }
        }
        waypoints.append(
            RouteWaypoint(
                latitude: lat,
                longitude: lon,
                altitude: currentEle.flatMap(Double.init),
                name: currentName,
                timeOffset: offset
            )
        )
    }
}

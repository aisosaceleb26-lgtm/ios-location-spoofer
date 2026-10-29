import Foundation

/// Modular simulation backend. Implementations must not invent public Apple APIs.
public protocol LocationSimulationProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var capabilities: SimulationCapabilities { get }
    var status: SimulationStatus { get }

    func prepare(configuration: SimulationConfiguration) async throws
    func start() async throws
    func pause() async throws
    func resume() async throws
    func stop() async throws
    func restoreRealLocation() async throws

    var locationUpdates: AsyncStream<SimulatedLocation> { get }
}

public enum ProviderError: Error, Equatable, CustomStringConvertible {
    case missingConfiguration
    case invalidRoute
    case notPrepared
    case unsupportedOnThisDevice(String)
    case developerHostRequired
    case connectionLost

    public var description: String {
        switch self {
        case .missingConfiguration: return "Missing simulation configuration."
        case .invalidRoute: return "Route must contain at least two valid waypoints."
        case .notPrepared: return "Provider was not prepared."
        case .unsupportedOnThisDevice(let reason): return reason
        case .developerHostRequired:
            return "Apple developer location simulation requires a development host (Mac/Xcode or equivalent)."
        case .connectionLost: return "Developer host connection was lost."
        }
    }
}

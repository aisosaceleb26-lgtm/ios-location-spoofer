import XCTest
import CoreLocation
@testable import OpenGPS

@MainActor
final class ProviderStatusTests: XCTestCase {
    func testPreviewDoesNotClaimSystemWide() async throws {
        let provider = PreviewLocationProvider()
        try await provider.prepare(
            configuration: SimulationConfiguration(
                coordinate: CLLocationCoordinate2D(latitude: 37.33, longitude: -122.03)
            )
        )
        try await provider.start()
        XCTAssertEqual(provider.status, .previewActive)
        XCTAssertFalse(provider.status.mayClaimSystemWideSimulation)
        XCTAssertFalse(provider.status.userFacingMessage.lowercased().contains("system-wide gps spoofing active"))
    }

    func testAppleDeveloperRequiresHost() async throws {
        let provider = AppleDeveloperSimulationProvider(iosMajorVersion: 27, initiallyHostConnected: false)
        try await provider.prepare(
            configuration: SimulationConfiguration(
                coordinate: CLLocationCoordinate2D(latitude: 46.95, longitude: 7.45)
            )
        )
        XCTAssertNotNil(provider.preparedGPX)
        do {
            try await provider.start()
            XCTFail("Expected developerHostRequired")
        } catch {
            XCTAssertEqual(error as? ProviderError, .developerHostRequired)
        }
        XCTAssertFalse(provider.status.mayClaimSystemWideSimulation)
        if case .requiresDeveloperHost = provider.status {
            // expected
        } else {
            XCTFail("Expected requiresDeveloperHost, got \(provider.status)")
        }
    }

    func testUnsupportedIOSVersion() {
        let provider = AppleDeveloperSimulationProvider(iosMajorVersion: 15, initiallyHostConnected: false)
        if case .unavailable = provider.status {
            // expected
        } else {
            XCTFail("Expected unavailable for iOS 15")
        }
        XCTAssertFalse(IOSVersionSupport.isSupported(majorVersion: 15))
        XCTAssertTrue(IOSVersionSupport.isSupported(majorVersion: 27))
    }

    func testDeveloperConnectionLoss() async throws {
        let provider = AppleDeveloperSimulationProvider(iosMajorVersion: 27, initiallyHostConnected: true)
        try await provider.prepare(
            configuration: SimulationConfiguration(
                coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2)
            )
        )
        try await provider.start()
        provider.noteDeveloperHostConnected(false)
        if case .connectionLost = provider.status {
            // expected
        } else {
            XCTFail("Expected connectionLost")
        }
        do {
            try await provider.resume()
            XCTFail("Expected connectionLost error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .connectionLost)
        }
    }

    func testHostConfirmationGate() async throws {
        let provider = AppleDeveloperSimulationProvider(iosMajorVersion: 27, initiallyHostConnected: true)
        try await provider.prepare(
            configuration: SimulationConfiguration(
                coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 20)
            )
        )
        try await provider.start()
        XCTAssertFalse(provider.status.mayClaimSystemWideSimulation)
        provider.confirmHostSimulationFromExternalCheck(true)
        XCTAssertTrue(provider.status.mayClaimSystemWideSimulation)
        XCTAssertFalse(provider.status.userFacingMessage.lowercased().contains("system-wide gps spoofing active"))
    }

    func testPermissionDenialSeam() {
        let service = LocationPermissionService()
        service.simulatePermissionDenialForTests()
        service.startUpdating()
        XCTAssertEqual(service.authorizationStatus, .denied)
        XCTAssertEqual(service.lastError, "Location permission denied.")
    }

    func testAccurateStatusReportingMessages() {
        XCTAssertTrue(SimulationStatus.previewActive.userFacingMessage.contains("Other apps"))
        XCTAssertTrue(
            SimulationStatus.requiresDeveloperHost(message: "need host").userFacingMessage.contains("need host")
        )
    }
}

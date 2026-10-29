import SwiftUI
import MapKit

public struct ContentView: View {
    @StateObject private var model: SimulationSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var favoriteName = ""
    @State private var showGPXImporter = false
    @State private var gpxImportText = ""
    @State private var showExport = false

    public init(model: SimulationSessionViewModel = SimulationSessionViewModel()) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanner
                    mapSection
                    coordinateSection
                    realAndSimulatedSection
                    routeSection
                    controlsSection
                    favoritesSection
                    developerHostSection
                }
                .padding()
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationTitle("OpenGPS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("GPX") {
                        Button("Import GPX Text…") { showGPXImporter = true }
                        Button("Export Xcode GPX") {
                            model.exportGPX()
                            showExport = true
                        }
                    }
                    .accessibilityLabel("GPX import and export")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .sheet(isPresented: $showGPXImporter) {
                NavigationStack {
                    TextEditor(text: $gpxImportText)
                        .padding()
                        .navigationTitle("Paste GPX")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showGPXImporter = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Import") {
                                    model.importGPX(string: gpxImportText)
                                    showGPXImporter = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showExport) {
                NavigationStack {
                    ScrollView {
                        Text(model.gpxExportText ?? "")
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .navigationTitle("Exported GPX")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showExport = false }
                        }
                    }
                }
            }
        }
    }

    private var pageBackground: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.09, blue: 0.11) : Color(red: 0.94, green: 0.96, blue: 0.98)
    }

    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.simulationStatus.mayClaimSystemWideSimulation {
                Text("Host confirmation recorded — still verify with your own test app. OpenGPS cannot prove other apps’ Core Location from public APIs.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch model.simulationStatus {
        case .previewActive: return "Preview active"
        case .paused: return "Paused"
        case .developerHostActive: return "Developer host session"
        case .requiresDeveloperHost: return "Developer host required"
        case .connectionLost: return "Connection lost"
        case .unavailable: return "Unavailable"
        case .inactive: return "Inactive"
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Map")
                .font(.headline)
            MapReader { proxy in
                Map(position: $model.cameraPosition) {
                    Marker("Selected", coordinate: model.selectedCoordinate)
                        .tint(.blue)
                    if let sim = model.simulatedLocation {
                        Marker("Simulated", coordinate: sim.coordinate)
                            .tint(.orange)
                    }
                    if model.route.waypoints.count >= 2 {
                        MapPolyline(coordinates: model.route.waypoints.map(\.coordinate))
                            .stroke(.blue.opacity(0.7), lineWidth: 3)
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Interactive map")
                .gesture(
                    LongPressGesture(minimumDuration: 0.25).sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { value in
                            if case .second(true, let drag?) = value {
                                if let coord = proxy.convert(drag.location, from: .local) {
                                    model.updatePin(coord)
                                }
                            }
                        }
                )
            }
            HStack {
                TextField("Search places", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.searchPlaces() } }
                Button("Search") { Task { await model.searchPlaces() } }
                    .buttonStyle(.bordered)
            }
            Text("Long-press the map to move the pin.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var coordinateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coordinates")
                .font(.headline)
            HStack {
                TextField("Latitude", text: $model.latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Latitude")
                TextField("Longitude", text: $model.longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Longitude")
            }
            Button("Apply latitude / longitude") {
                model.applyCoordinateFromFields()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var realAndSimulatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Locations")
                .font(.headline)
            Button("Use current real location") {
                model.useRealLocation()
            }
            .buttonStyle(.bordered)
            if let real = model.permissionService.lastRealLocation {
                labeledValue("Real location", "\(fmt(real.coordinate.latitude)), \(fmt(real.coordinate.longitude)) ±\(Int(real.horizontalAccuracy)) m @ \(real.timestamp.formatted())")
            } else if let err = model.permissionService.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            } else {
                Text("Real location not available yet. Permission is requested only when you tap the button above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let sim = model.simulatedLocation {
                labeledValue(
                    "Selected simulated",
                    "\(fmt(sim.coordinate.latitude)), \(fmt(sim.coordinate.longitude)) ±\(Int(sim.horizontalAccuracy)) m @ \(sim.timestamp.formatted())"
                )
            } else {
                labeledValue(
                    "Selected",
                    "\(fmt(model.selectedCoordinate.latitude)), \(fmt(model.selectedCoordinate.longitude))"
                )
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)
            HStack {
                Button("Add waypoint") { model.addWaypointAtSelection() }
                Button("Clear route", role: .destructive) { model.clearRoute() }
            }
            .buttonStyle(.bordered)
            Text("Waypoints: \(model.route.waypoints.count)")
                .font(.subheadline)
            HStack {
                Text("Speed \(String(format: "%.1f", model.routeSpeedMps)) m/s")
                Slider(value: $model.routeSpeedMps, in: 0.5...40, step: 0.5)
                    .accessibilityLabel("Route speed meters per second")
            }
            ProgressView(value: model.routeProgressFraction)
                .accessibilityLabel("Route progress")
            ForEach(model.route.waypoints) { wp in
                Text("• \(wp.name ?? "WP") \(fmt(wp.latitude)), \(fmt(wp.longitude))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Simulation controls")
                .font(.headline)
            Picker("Backend", selection: $model.backend) {
                ForEach(SimulationBackend.allCases) { backend in
                    Text(backend.title).tag(backend)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Simulation backend")
            HStack {
                Button("Start") { Task { await model.start() } }
                Button("Pause") { Task { await model.pause() } }
                Button("Resume") { Task { await model.resume() } }
                Button("Stop") { Task { await model.stop() } }
            }
            .buttonStyle(.borderedProminent)
            Button("Restore real location guidance") {
                Task { await model.restoreRealLocation() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites & recent")
                .font(.headline)
            HStack {
                TextField("Favorite name", text: $favoriteName)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    let name = favoriteName.isEmpty ? "Favorite" : favoriteName
                    model.saveFavorite(named: name)
                    favoriteName = ""
                }
                .buttonStyle(.bordered)
            }
            if !model.favoritesStore.favorites.isEmpty {
                Text("Favorites").font(.subheadline)
                ForEach(model.favoritesStore.favorites) { item in
                    Button("\(item.name) — \(fmt(item.latitude)), \(fmt(item.longitude))") {
                        model.selectSaved(item)
                    }
                }
            }
            if !model.favoritesStore.recents.isEmpty {
                Text("Recent").font(.subheadline)
                ForEach(model.favoritesStore.recents.prefix(8)) { item in
                    Button("\(item.name)") { model.selectSaved(item) }
                        .font(.caption)
                }
            }
        }
    }

    private var developerHostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Developer host")
                .font(.headline)
            Text("These toggles model host connection for testing. They do not enable GPS override by themselves.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(
                "Developer host connected (test)",
                isOn: Binding(
                    get: { model.developerHostConnectedFlag },
                    set: { model.noteDeveloperHostConnected($0) }
                )
            )
            .accessibilityHint("Simulates whether a Mac or development host is paired")
            Button("Confirm host simulation after external verification") {
                model.confirmDeveloperHost(true)
            }
            .buttonStyle(.bordered)
        }
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

#Preview {
    ContentView()
}

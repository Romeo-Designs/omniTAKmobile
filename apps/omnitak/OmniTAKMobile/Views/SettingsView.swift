//
//  SettingsView.swift
//  OmniTAKMobile
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userCallsign") private var userCallsign = "R06"
    @AppStorage("userName") private var userName = "Roe iPhone"
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("sendPositionInterval") private var sendPositionInterval = 5.0
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("darkMode") private var darkMode = true
    @AppStorage("showTrafficOverlay") private var showTrafficOverlay = false
    @AppStorage("enableLocationSharing") private var enableLocationSharing = true
    @AppStorage("batteryOptimization") private var batteryOptimization = false

    // Map Overlay Settings
    @AppStorage("mgrsGridEnabled") private var mgrsGridEnabled = false
    @AppStorage("mgrsGridDensity") private var mgrsGridDensityString = "1km"
    @AppStorage("showMGRSLabels") private var showMGRSLabels = true
    @AppStorage("coordinateDisplayFormat") private var coordinateFormatString = "MGRS"
    @AppStorage("breadcrumbTrailsEnabled") private var breadcrumbTrailsEnabled = true
    @AppStorage("trailMaxLength") private var trailMaxLength = 100
    @AppStorage("trailColorName") private var trailColorName = "cyan"

    @ObservedObject private var broadcastService = PositionBroadcastService.shared
    @State private var showNetworkPreferences = true
    
    private func getDisplayName(for cotType: String) -> String {
        let props = MilStdCoTParser.parse(cotType: cotType)
        return "\(props.affiliation.displayName) \(props.unitType.displayName)"
    }

    var body: some View {
        NavigationView {
            List {
                // User Profile
                Section("USER PROFILE") {
                    HStack {
                        Text("Callsign")
                        Spacer()
                        TextField("Callsign", text: $userCallsign)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }
                    
                    NavigationLink(destination: UnitTypeSelectionView()) {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.blue)
                            Text("Unit Type")
                            Spacer()
                            Text(getDisplayName(for: broadcastService.userUnitType))
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                // Network Preferences (ATAK Style)
                Section("NETWORK") {
                    NavigationLink(destination: NetworkPreferencesView()) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            Text("Network Preferences")
                        }
                    }
                }

                // Connection Settings
                Section("CONNECTION") {
                    Toggle("Auto-connect on Launch", isOn: $autoConnect)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Position Update Interval")
                            Spacer()
                            Text("\(Int(sendPositionInterval))s")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $sendPositionInterval, in: 5...120, step: 5)
                    }

                    Toggle("Enable Location Sharing", isOn: $enableLocationSharing)
                }

                // Map Overlay Settings
                Section("MAP OVERLAYS") {
                    // MGRS Grid Settings
                    Toggle("MGRS Grid Overlay", isOn: $mgrsGridEnabled)

                    if mgrsGridEnabled {
                        Picker("Grid Density", selection: $mgrsGridDensityString) {
                            Text("100km").tag("100km")
                            Text("10km").tag("10km")
                            Text("1km").tag("1km")
                        }

                        Toggle("Show Grid Labels", isOn: $showMGRSLabels)
                    }

                    // Coordinate Display Format
                    Picker("Coordinate Format", selection: $coordinateFormatString) {
                        Text("Decimal Degrees (DD)").tag("DD")
                        Text("Degrees Minutes (DM)").tag("DM")
                        Text("Degrees Minutes Seconds (DMS)").tag("DMS")
                        Text("MGRS").tag("MGRS")
                        Text("UTM").tag("UTM")
                        Text("British National Grid (BNG)").tag("BNG")
                    }

                    // Help text for coordinate formats
                    if coordinateFormatString == "BNG" {
                        Text("BNG is optimized for UK/Ireland (49°N-61°N, 9°W-2°E). Uses OSGB36 datum with grid squares like SU, TQ, NT.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }

                // Trail Settings
                Section("BREADCRUMB TRAILS") {
                    Toggle("Enable Trails", isOn: $breadcrumbTrailsEnabled)

                    if breadcrumbTrailsEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Trail Length")
                                Spacer()
                                Text("\(trailMaxLength) points")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: Binding(
                                get: { Double(trailMaxLength) },
                                set: { trailMaxLength = Int($0) }
                            ), in: 10...500, step: 10)
                        }

                        Picker("Trail Color", selection: $trailColorName) {
                            Text("Cyan").tag("cyan")
                            Text("Green").tag("green")
                            Text("Orange").tag("orange")
                            Text("Red").tag("red")
                            Text("Blue").tag("blue")
                        }
                    }
                }

                // Display Settings
                Section("DISPLAY") {
                    Toggle("Dark Mode", isOn: $darkMode)
                    Toggle("Show Traffic Overlay", isOn: $showTrafficOverlay)
                    Toggle("Enable Haptic Feedback", isOn: $enableHaptics)
                }

                // Performance
                Section("PERFORMANCE") {
                    Toggle("Battery Optimization", isOn: $batteryOptimization)

                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text("127 MB")
                            .foregroundColor(.gray)
                    }

                    Button("Clear Cache") {
                        // Clear cache
                    }
                    .foregroundColor(.red)
                }

                // Data Management
                Section("DATA MANAGEMENT") {
                    Button("Export All Data") {
                        // Export
                    }

                    Button("Import Data Package") {
                        // Import
                    }

                    Button("Reset to Defaults") {
                        userCallsign = "R06"
                        userName = "Roe iPhone"
                        autoConnect = true
                        sendPositionInterval = 5.0
                        enableHaptics = true
                        darkMode = true
                        showTrafficOverlay = false
                        enableLocationSharing = true
                        batteryOptimization = false
                        // Map overlay defaults
                        mgrsGridEnabled = false
                        mgrsGridDensityString = "1km"
                        showMGRSLabels = true
                        coordinateFormatString = "MGRS"
                        breadcrumbTrailsEnabled = true
                        trailMaxLength = 100
                        trailColorName = "cyan"
                    }
                    .foregroundColor(.orange)
                }

                // Danger Zone
                Section("DANGER ZONE") {
                    Button("Clear All Team Data") {
                        TeamService.shared.clearAllTeamData()
                    }
                    .foregroundColor(.red)

                    Button("Reset App") {
                        // Reset everything
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Unit Type Selection View

struct UnitTypeSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var broadcastService = PositionBroadcastService.shared
    @State private var selectedAffiliation: MilStdAffiliation = .friendly
    @State private var selectedDimension: MilStdBattleDimension = .ground
    @State private var selectedUnitType: MilStdUnitType = .infantry
    @State private var searchText = ""
    @State private var showingFavorites = false
    @AppStorage("favoriteUnitTypes") private var favoriteUnitTypesData: Foundation.Data = Foundation.Data()
    @AppStorage("recentUnitTypes") private var recentUnitTypesData: Foundation.Data = Foundation.Data()
    
    private var favoriteUnitTypes: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: favoriteUnitTypesData)) ?? []
        }
    }
    
    private var recentUnitTypes: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: recentUnitTypesData)) ?? []
        }
    }
    
    private var filteredUnitTypes: [MilStdUnitType] {
        if searchText.isEmpty {
            return Array(MilStdUnitType.allCases)
        }
        return MilStdUnitType.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            // Preview Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Preview marker
                        MilStdPreviewMarker(
                            affiliation: selectedAffiliation,
                            dimension: selectedDimension,
                            unitType: selectedUnitType
                        )
                        .frame(width: 100, height: 120)
                        
                        Text(generateCoTType())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    .padding(.vertical)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
            
            // Affiliation
            Section("AFFILIATION") {
                ForEach(MilStdAffiliation.allCases, id: \.rawValue) { affiliation in
                    Button(action: {
                        selectedAffiliation = affiliation
                    }) {
                        HStack {
                            Image(systemName: affiliation == selectedAffiliation ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(affiliation == selectedAffiliation ? .blue : .gray)
                            
                            Circle()
                                .fill(affiliation.color)
                                .frame(width: 16, height: 16)
                            
                            Text(affiliation.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Battle Dimension
            Section("BATTLE DIMENSION") {
                ForEach(MilStdBattleDimension.allCases, id: \.rawValue) { dimension in
                    Button(action: {
                        selectedDimension = dimension
                    }) {
                        HStack {
                            Image(systemName: dimension == selectedDimension ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(dimension == selectedDimension ? .blue : .gray)
                            
                            Image(systemName: dimension.defaultIcon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(dimension.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Recent selections
            if !showingFavorites && !recentUnitTypes.isEmpty && searchText.isEmpty {
                Section("RECENT") {
                    ForEach(recentUnitTypes.prefix(5), id: \.self) { cotType in
                        if let unitType = parseUnitTypeFromCoT(cotType) {
                            unitTypeRow(unitType, showCategory: true)
                        }
                    }
                }
            }
            
            // Favorites or all unit types
            if showingFavorites {
                Section("FAVORITES") {
                    if favoriteUnitTypes.isEmpty {
                        Text("No favorites yet. Tap the star icon on any unit type to add it.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(MilStdUnitType.allCases.filter { favoriteUnitTypes.contains($0.rawValue) }, id: \.rawValue) { unitType in
                            unitTypeRow(unitType, showCategory: true)
                        }
                    }
                }
            } else {
                // Combat Units
                Section("COMBAT UNITS") {
                    ForEach(filteredUnitTypes.filter { isCombatUnit($0) }, id: \.rawValue) { unitType in
                        unitTypeRow(unitType)
                    }
                }
                
                // Support Units
                Section("SUPPORT UNITS") {
                    ForEach(filteredUnitTypes.filter { isSupportUnit($0) }, id: \.rawValue) { unitType in
                        unitTypeRow(unitType)
                    }
                }
                
                // Service Support
                Section("SERVICE SUPPORT") {
                    ForEach(filteredUnitTypes.filter { isServiceSupport($0) }, id: \.rawValue) { unitType in
                        unitTypeRow(unitType)
                    }
                }
                
                // Other Units
                if filteredUnitTypes.contains(where: { !isCombatUnit($0) && !isSupportUnit($0) && !isServiceSupport($0) }) {
                    Section("OTHER") {
                        ForEach(filteredUnitTypes.filter { !isCombatUnit($0) && !isSupportUnit($0) && !isServiceSupport($0) }, id: \.rawValue) { unitType in
                            unitTypeRow(unitType)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Unit Type")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search unit types...")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingFavorites.toggle() }) {
                    Image(systemName: showingFavorites ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveUnitType()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func generateCoTType() -> String {
        return "a-\(selectedAffiliation.rawValue)-\(selectedDimension.rawValue)-\(selectedUnitType.rawValue)"
    }
    
    private func saveUnitType() {
        let cotType = generateCoTType()
        broadcastService.userUnitType = cotType
        
        // Add to recent selections
        addToRecent(cotType)
        
        // Force immediate save to UserDefaults
        UserDefaults.standard.set(cotType, forKey: "userUnitType")
        UserDefaults.standard.synchronize()
        
        // Immediately broadcast new position with updated unit type
        broadcastService.broadcastPosition()
    }
    
    private func loadCurrentSettings() {
        let currentType = broadcastService.userUnitType
        let props = MilStdCoTParser.parse(cotType: currentType)
        selectedAffiliation = props.affiliation
        selectedDimension = props.battleDimension
        selectedUnitType = props.unitType
    }
    
    @ViewBuilder
    private func unitTypeRow(_ unitType: MilStdUnitType, showCategory: Bool = false) -> some View {
        Button(action: {
            selectedUnitType = unitType
        }) {
            HStack {
                Image(systemName: unitType == selectedUnitType ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(unitType == selectedUnitType ? .blue : .gray)
                
                Image(systemName: unitType.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(unitType.displayName)
                        .foregroundColor(.primary)
                    if showCategory {
                        Text(getCategoryName(for: unitType))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    toggleFavorite(unitType)
                }) {
                    Image(systemName: favoriteUnitTypes.contains(unitType.rawValue) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func toggleFavorite(_ unitType: MilStdUnitType) {
        var favorites = favoriteUnitTypes
        if favorites.contains(unitType.rawValue) {
            favorites.remove(unitType.rawValue)
        } else {
            favorites.insert(unitType.rawValue)
        }
        favoriteUnitTypesData = (try? JSONEncoder().encode(favorites)) ?? Foundation.Data()
    }
    
    private func addToRecent(_ cotType: String) {
        var recent = recentUnitTypes
        recent.removeAll { $0 == cotType }
        recent.insert(cotType, at: 0)
        recent = Array(recent.prefix(10))
        recentUnitTypesData = (try? JSONEncoder().encode(recent)) ?? Foundation.Data()
    }
    
    private func parseUnitTypeFromCoT(_ cotType: String) -> MilStdUnitType? {
        let props = MilStdCoTParser.parse(cotType: cotType)
        return props.unitType
    }
    
    private func isCombatUnit(_ unitType: MilStdUnitType) -> Bool {
        [.infantry, .mechanizedInfantry, .armor, .cavalry, .artillery, .airDefense, .engineer, .reconnaissance, .specialForces].contains(unitType)
    }
    
    private func isSupportUnit(_ unitType: MilStdUnitType) -> Bool {
        [.signal, .militaryIntelligence, .chemicalBiological, .militaryPolice, .civilAffairs].contains(unitType)
    }
    
    private func isServiceSupport(_ unitType: MilStdUnitType) -> Bool {
        [.supply, .transportation, .maintenance, .medical].contains(unitType)
    }
    
    private func getCategoryName(for unitType: MilStdUnitType) -> String {
        if isCombatUnit(unitType) { return "Combat" }
        if isSupportUnit(unitType) { return "Support" }
        if isServiceSupport(unitType) { return "Service Support" }
        return "Other"
    }
}

// MARK: - Preview Marker

struct MilStdPreviewMarker: View {
    let affiliation: MilStdAffiliation
    let dimension: MilStdBattleDimension
    let unitType: MilStdUnitType
    
    private var affiliationShape: UnitTypeAnyShape {
        switch affiliation {
        case .friendly, .assumed:
            return UnitTypeAnyShape(RoundedRectangle(cornerRadius: 2))
        case .hostile, .suspect, .joker, .faker:
            return UnitTypeAnyShape(UnitTypeRotatedSquare())
        case .neutral:
            return UnitTypeAnyShape(Rectangle())
        case .unknown, .pending:
            return UnitTypeAnyShape(UnitTypeQuatrefoilShape())
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Main affiliation shape with fill
                affiliationShape
                    .fill(affiliation.fillColor)
                    .frame(width: 80, height: 80)
                
                // Shape outline
                affiliationShape
                    .stroke(affiliation.color, lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                // Unit type icon
                Image(systemName: unitType.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(affiliation.color)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Dimension badge
            Text(dimension.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(affiliation.color.opacity(0.8))
                )
        }
    }
}

// MARK: - Supporting Shapes

struct UnitTypeRotatedSquare: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2
        
        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y))
        path.closeSubpath()
        
        return path
    }
}

struct UnitTypeQuatrefoilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3.2
        
        let offsets: [(CGFloat, CGFloat)] = [
            (0, -radius * 0.65),
            (radius * 0.65, 0),
            (0, radius * 0.65),
            (-radius * 0.65, 0)
        ]
        
        for (dx, dy) in offsets {
            let circleCenter = CGPoint(x: center.x + dx, y: center.y + dy)
            path.addEllipse(in: CGRect(
                x: circleCenter.x - radius,
                y: circleCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        return path
    }
}

struct UnitTypeAnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

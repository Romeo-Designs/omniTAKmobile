#!/usr/bin/env ruby
require 'xcodeproj'

# File reorganization mapping
FILE_MOVES = {
  # Core
  'OmniTAKMobileApp.swift' => 'Core/OmniTAKMobileApp.swift',
  'ContentView.swift' => 'Core/ContentView.swift',
  'OmniTAKMobile-Bridging-Header.h' => 'Core/OmniTAKMobile-Bridging-Header.h',

  # Models - all *Models.swift files
  'ArcGISModels.swift' => 'Models/ArcGISModels.swift',
  'CASRequestModels.swift' => 'Models/CASRequestModels.swift',
  'ChatModels.swift' => 'Models/ChatModels.swift',
  'CoTFilterModel.swift' => 'Models/CoTFilterModel.swift',
  'DataPackageModels.swift' => 'Models/DataPackageModels.swift',
  'DrawingModels.swift' => 'Models/DrawingModels.swift',
  'EchelonModels.swift' => 'Models/EchelonModels.swift',
  'ElevationProfileModels.swift' => 'Models/ElevationProfileModels.swift',
  'GeofenceModels.swift' => 'Models/GeofenceModels.swift',
  'LineOfSightModels.swift' => 'Models/LineOfSightModels.swift',
  'MeasurementModels.swift' => 'Models/MeasurementModels.swift',
  'MEDEVACModels.swift' => 'Models/MEDEVACModels.swift',
  'MissionPackageModels.swift' => 'Models/MissionPackageModels.swift',
  'OfflineMapModels.swift' => 'Models/OfflineMapModels.swift',
  'PointMarkerModels.swift' => 'Models/PointMarkerModels.swift',
  'RadialMenuModels.swift' => 'Models/RadialMenuModels.swift',
  'RouteModels.swift' => 'Models/RouteModels.swift',
  'SPOTREPModels.swift' => 'Models/SPOTREPModels.swift',
  'TeamModels.swift' => 'Models/TeamModels.swift',
  'TrackModels.swift' => 'Models/TrackModels.swift',
  'VideoStreamModels.swift' => 'Models/VideoStreamModels.swift',
  'WaypointModels.swift' => 'Models/WaypointModels.swift',

  # Services
  'ArcGISFeatureService.swift' => 'Services/ArcGISFeatureService.swift',
  'ArcGISPortalService.swift' => 'Services/ArcGISPortalService.swift',
  'BloodhoundService.swift' => 'Services/BloodhoundService.swift',
  'BreadcrumbTrailService.swift' => 'Services/BreadcrumbTrailService.swift',
  'CertificateEnrollmentService.swift' => 'Services/CertificateEnrollmentService.swift',
  'ChatService.swift' => 'Services/ChatService.swift',
  'DigitalPointerService.swift' => 'Services/DigitalPointerService.swift',
  'EchelonService.swift' => 'Services/EchelonService.swift',
  'ElevationProfileService.swift' => 'Services/ElevationProfileService.swift',
  'EmergencyBeaconService.swift' => 'Services/EmergencyBeaconService.swift',
  'GeofenceService.swift' => 'Services/GeofenceService.swift',
  'LineOfSightService.swift' => 'Services/LineOfSightService.swift',
  'MeasurementService.swift' => 'Services/MeasurementService.swift',
  'MissionPackageSyncService.swift' => 'Services/MissionPackageSyncService.swift',
  'NavigationService.swift' => 'Services/NavigationService.swift',
  'PhotoAttachmentService.swift' => 'Services/PhotoAttachmentService.swift',
  'PointDropperService.swift' => 'Services/PointDropperService.swift',
  'PositionBroadcastService.swift' => 'Services/PositionBroadcastService.swift',
  'RangeBearingService.swift' => 'Services/RangeBearingService.swift',
  'RoutePlanningService.swift' => 'Services/RoutePlanningService.swift',
  'TAKService.swift' => 'Services/TAKService.swift',
  'TeamService.swift' => 'Services/TeamService.swift',
  'TerrainVisualizationService.swift' => 'Services/TerrainVisualizationService.swift',
  'TrackRecordingService.swift' => 'Services/TrackRecordingService.swift',
  'TurnByTurnNavigationService.swift' => 'Services/TurnByTurnNavigationService.swift',
  'VideoStreamService.swift' => 'Services/VideoStreamService.swift',

  # Managers
  'CertificateManager.swift' => 'Managers/CertificateManager.swift',
  'ChatManager.swift' => 'Managers/ChatManager.swift',
  'DataPackageManager.swift' => 'Managers/DataPackageManager.swift',
  'DrawingToolsManager.swift' => 'Managers/DrawingToolsManager.swift',
  'GeofenceManager.swift' => 'Managers/GeofenceManager.swift',
  'MeasurementManager.swift' => 'Managers/MeasurementManager.swift',
  'MeshtasticManager.swift' => 'Managers/MeshtasticManager.swift',
  'OfflineMapManager.swift' => 'Managers/OfflineMapManager.swift',
  'ServerManager.swift' => 'Managers/ServerManager.swift',
  'WaypointManager.swift' => 'Managers/WaypointManager.swift',
  'CoTFilterManager.swift' => 'Managers/CoTFilterManager.swift',

  # Storage
  'ChatPersistence.swift' => 'Storage/ChatPersistence.swift',
  'ChatStorageManager.swift' => 'Storage/ChatStorageManager.swift',
  'DrawingPersistence.swift' => 'Storage/DrawingPersistence.swift',
  'RouteStorageManager.swift' => 'Storage/RouteStorageManager.swift',
  'TeamStorageManager.swift' => 'Storage/TeamStorageManager.swift',

  # Map Controllers
  'MapViewController.swift' => 'Map/Controllers/MapViewController.swift',
  'MapViewController_Enhanced.swift' => 'Map/Controllers/MapViewController_Enhanced.swift',
  'MapViewController_FilterIntegration.swift' => 'Map/Controllers/MapViewController_FilterIntegration.swift',
  'MapViewController_Modified.swift' => 'Map/Controllers/MapViewController_Modified.swift',
  'EnhancedMapViewController.swift' => 'Map/Controllers/EnhancedMapViewController.swift',
  'EnhancedMapViewRepresentable.swift' => 'Map/Controllers/EnhancedMapViewRepresentable.swift',
  'IntegratedMapView.swift' => 'Map/Controllers/IntegratedMapView.swift',
  'MapViewIntegrationExample.swift' => 'Map/Controllers/MapViewIntegrationExample.swift',
  'Map3DViewController.swift' => 'Map/Controllers/Map3DViewController.swift',
  'MapContextMenus.swift' => 'Map/Controllers/MapContextMenus.swift',
  'MapCursorMode.swift' => 'Map/Controllers/MapCursorMode.swift',
  'MapOverlayCoordinator.swift' => 'Map/Controllers/MapOverlayCoordinator.swift',
  'MapStateManager.swift' => 'Map/Controllers/MapStateManager.swift',

  # Map Overlays
  'BreadcrumbTrailOverlay.swift' => 'Map/Overlays/BreadcrumbTrailOverlay.swift',
  'CompassOverlay.swift' => 'Map/Overlays/CompassOverlay.swift',
  'MGRSGridOverlay.swift' => 'Map/Overlays/MGRSGridOverlay.swift',
  'MeasurementOverlay.swift' => 'Map/Overlays/MeasurementOverlay.swift',
  'RadialMenuMapOverlay.swift' => 'Map/Overlays/RadialMenuMapOverlay.swift',
  'RangeBearingOverlay.swift' => 'Map/Overlays/RangeBearingOverlay.swift',
  'TrackOverlayRenderer.swift' => 'Map/Overlays/TrackOverlayRenderer.swift',
  'UnitTrailOverlay.swift' => 'Map/Overlays/UnitTrailOverlay.swift',
  'VideoMapOverlay.swift' => 'Map/Overlays/VideoMapOverlay.swift',
  'OfflineTileOverlay.swift' => 'Map/Overlays/OfflineTileOverlay.swift',

  # Map Markers
  'CustomMarkerAnnotation.swift' => 'Map/Markers/CustomMarkerAnnotation.swift',
  'EnhancedCoTMarker.swift' => 'Map/Markers/EnhancedCoTMarker.swift',
  'MarkerAnnotationView.swift' => 'Map/Markers/MarkerAnnotationView.swift',

  # Map TileSources
  'ArcGISTileSource.swift' => 'Map/TileSources/ArcGISTileSource.swift',
  'OfflineTileCache.swift' => 'Map/TileSources/OfflineTileCache.swift',
  'TileDownloader.swift' => 'Map/TileSources/TileDownloader.swift',

  # CoT
  'CoTEventHandler.swift' => 'CoT/CoTEventHandler.swift',
  'CoTFilterCriteria.swift' => 'CoT/CoTFilterCriteria.swift',
  'CoTMessageParser.swift' => 'CoT/CoTMessageParser.swift',
  'ChatCoTGenerator.swift' => 'CoT/Generators/ChatCoTGenerator.swift',
  'GeofenceCoTGenerator.swift' => 'CoT/Generators/GeofenceCoTGenerator.swift',
  'MarkerCoTGenerator.swift' => 'CoT/Generators/MarkerCoTGenerator.swift',
  'TeamCoTGenerator.swift' => 'CoT/Generators/TeamCoTGenerator.swift',
  'ChatXMLParser.swift' => 'CoT/Parsers/ChatXMLParser.swift',
  'ChatXMLGenerator.swift' => 'CoT/Parsers/ChatXMLGenerator.swift',

  # Utilities
  'MGRSConverter.swift' => 'Utilities/Converters/MGRSConverter.swift',
  'BNGConverter.swift' => 'Utilities/Converters/BNGConverter.swift',
  'KMLParser.swift' => 'Utilities/Parsers/KMLParser.swift',
  'KMZHandler.swift' => 'Utilities/Parsers/KMZHandler.swift',
  'KMLMapIntegration.swift' => 'Utilities/Integration/KMLMapIntegration.swift',
  'KMLOverlayManager.swift' => 'Utilities/Integration/KMLOverlayManager.swift',
  'NetworkMonitor.swift' => 'Utilities/Network/NetworkMonitor.swift',
  'MultiServerFederation.swift' => 'Utilities/Network/MultiServerFederation.swift',
  'MeasurementCalculator.swift' => 'Utilities/Calculators/MeasurementCalculator.swift',

  # UI Components
  'ATAKBottomToolbar_Modified.swift' => 'UI/Components/ATAKBottomToolbar_Modified.swift',
  'ConnectionStatusWidget.swift' => 'UI/Components/ConnectionStatusWidget.swift',
  'DataPackageButton.swift' => 'UI/Components/DataPackageButton.swift',
  'MeasurementButton.swift' => 'UI/Components/MeasurementButton.swift',
  'QuickActionToolbar.swift' => 'UI/Components/QuickActionToolbar.swift',
  'TrackRecordingButton.swift' => 'UI/Components/TrackRecordingButton.swift',
  'VideoStreamButton.swift' => 'UI/Components/VideoStreamButton.swift',
  'SharedUIComponents.swift' => 'UI/Components/SharedUIComponents.swift',

  # UI RadialMenu
  'RadialMenuActionExecutor.swift' => 'UI/RadialMenu/RadialMenuActionExecutor.swift',
  'RadialMenuAnimations.swift' => 'UI/RadialMenu/RadialMenuAnimations.swift',
  'RadialMenuButton.swift' => 'UI/RadialMenu/RadialMenuButton.swift',
  'RadialMenuGestureHandler.swift' => 'UI/RadialMenu/RadialMenuGestureHandler.swift',
  'RadialMenuItemView.swift' => 'UI/RadialMenu/RadialMenuItemView.swift',
  'RadialMenuMapCoordinator.swift' => 'UI/RadialMenu/RadialMenuMapCoordinator.swift',
  'RadialMenuPresets.swift' => 'UI/RadialMenu/RadialMenuPresets.swift',

  # UI MilStd2525
  'MilStd2525Symbols.swift' => 'UI/MilStd2525/MilStd2525Symbols.swift',

  # Resources
  'Info.plist' => 'Resources/Info.plist',
  'omnitak-mobile.p12' => 'Resources/omnitak-mobile.p12',
  'CHAT_FEATURE_README.md' => 'Resources/Documentation/CHAT_FEATURE_README.md',
  'FILTER_INTEGRATION_GUIDE.md' => 'Resources/Documentation/FILTER_INTEGRATION_GUIDE.md',
  'KML_INTEGRATION_GUIDE.md' => 'Resources/Documentation/KML_INTEGRATION_GUIDE.md',
  'OFFLINE_MAPS_INTEGRATION.md' => 'Resources/Documentation/OFFLINE_MAPS_INTEGRATION.md',
  'RADIAL_MENU_INTEGRATION_GUIDE.md' => 'Resources/Documentation/RADIAL_MENU_INTEGRATION_GUIDE.md',
  'UI_LAYOUT_REFERENCE.md' => 'Resources/Documentation/UI_LAYOUT_REFERENCE.md',
  'WAYPOINT_INTEGRATION_GUIDE.md' => 'Resources/Documentation/WAYPOINT_INTEGRATION_GUIDE.md',
  'USAGE_EXAMPLES.swift' => 'Resources/Documentation/USAGE_EXAMPLES.swift',
  'SHARED_INTERFACES.swift' => 'Resources/Documentation/SHARED_INTERFACES.swift',
}

# Add all View files
VIEW_FILES = [
  'AboutView.swift', 'ArcGISPortalView.swift', 'ATAKLoadingScreen.swift', 'ATAKToolsView.swift',
  'BloodhoundView.swift', 'CASRequestView.swift', 'CertificateEnrollmentView.swift',
  'CertificateManagementView.swift', 'CertificateSelectionView.swift', 'ChatView.swift',
  'CompassOverlayView.swift', 'ContactDetailView.swift', 'ContactListView.swift',
  'ConversationView.swift', 'CoordinateDisplayView.swift', 'CoTFilterPanel.swift',
  'CoTUnitListView.swift', 'DataPackageView.swift', 'DigitalPointerView.swift',
  'DrawingPropertiesView.swift', 'DrawingToolsPanel.swift', 'EchelonHierarchyView.swift',
  'ElevationProfileView.swift', 'EmergencyBeaconView.swift', 'FirstTimeOnboarding.swift',
  'GeofenceManagementView.swift', 'KMLImportView.swift', 'LineOfSightView.swift',
  'Map3DSettingsView.swift', 'MarkerInfoPanel.swift', 'MeasurementToolView.swift',
  'MEDEVACRequestView.swift', 'MeshtasticConnectionView.swift', 'MeshtasticDevicePickerView.swift',
  'MeshTopologyView.swift', 'MGRSGridToggleView.swift', 'MilStd2525MarkerView.swift',
  'MilStd2525SymbolView.swift', 'MissionPackageSyncView.swift', 'NavigationDrawer.swift',
  'OfflineMapsView.swift', 'PhotoPickerView.swift', 'PluginsListView.swift',
  'PointDropperView.swift', 'PositionBroadcastView.swift', 'QuickConnectView.swift',
  'RadialMenuView.swift', 'RangeRingConfigView.swift', 'RegionSelectionView.swift',
  'RoutePlanningView.swift', 'SALUTEReportView.swift', 'ScaleBarView.swift',
  'SettingsView.swift', 'SignalHistoryView.swift', 'SPOTREPView.swift',
  'TeamManagementView.swift', 'TrackListView.swift', 'TrackRecordingView.swift',
  'TurnByTurnNavigationView.swift', 'VideoFeedListView.swift', 'VideoPlayerView.swift',
  'WaypointListView.swift'
]

VIEW_FILES.each do |file|
  FILE_MOVES[file] = "Views/#{file}"
end

project_path = './OmniTAKMobile.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Updating Xcode project file references..."

# Find all file references and update their paths
project.files.each do |file_ref|
  filename = file_ref.path
  if FILE_MOVES.key?(filename)
    new_path = FILE_MOVES[filename]
    puts "Updating: #{filename} -> #{new_path}"
    file_ref.set_path(new_path)
  end
end

project.save
puts "Done! Project file updated."
puts "\nPlease open the project in Xcode and verify everything builds correctly."

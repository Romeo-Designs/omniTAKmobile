# OmniTAK Mobile - OOP Restructuring Guide

## Overview

This iOS application has been restructured from a flat 200+ file structure into a proper Object-Oriented Programming (OOP) architecture with logical separation of concerns.

## New Directory Structure

```
OmniTAKMobile/
├── Core/                          # Application entry point and core files
│   ├── OmniTAKMobileApp.swift    # App entry point
│   ├── ContentView.swift          # Main content view
│   └── OmniTAKMobile-Bridging-Header.h
│
├── Models/                        # Data models and structures (22 files)
│   ├── ArcGISModels.swift
│   ├── ChatModels.swift
│   ├── CoTFilterModel.swift
│   ├── TeamModels.swift
│   └── ... (all *Models.swift files)
│
├── Views/                         # SwiftUI views and UI screens (62 files)
│   ├── AboutView.swift
│   ├── ChatView.swift
│   ├── MapView variants
│   └── ... (all *View.swift files)
│
├── Services/                      # Business logic services (26 files)
│   ├── TAKService.swift
│   ├── ChatService.swift
│   ├── BloodhoundService.swift
│   └── ... (all *Service.swift files)
│
├── Managers/                      # State and resource managers (11 files)
│   ├── ChatManager.swift
│   ├── DataPackageManager.swift
│   ├── GeofenceManager.swift
│   └── ... (all *Manager.swift files)
│
├── Storage/                       # Data persistence layer (5 files)
│   ├── ChatPersistence.swift
│   ├── ChatStorageManager.swift
│   └── ... (persistence-related files)
│
├── Map/                          # Map-related components (29 files)
│   ├── Controllers/              # Map view controllers
│   │   ├── MapViewController.swift
│   │   ├── Map3DViewController.swift
│   │   └── ...
│   ├── Overlays/                 # Map overlay renderers
│   │   ├── CompassOverlay.swift
│   │   ├── MGRSGridOverlay.swift
│   │   └── ...
│   ├── Markers/                  # Map marker annotations
│   │   ├── CustomMarkerAnnotation.swift
│   │   └── ...
│   └── TileSources/             # Tile providers
│       ├── ArcGISTileSource.swift
│       └── ...
│
├── CoT/                          # Cursor on Target functionality (9 files)
│   ├── CoTEventHandler.swift
│   ├── CoTFilterCriteria.swift
│   ├── CoTMessageParser.swift
│   ├── Generators/              # CoT message generators
│   │   ├── ChatCoTGenerator.swift
│   │   ├── MarkerCoTGenerator.swift
│   │   └── ...
│   └── Parsers/                 # CoT XML parsers
│       ├── ChatXMLParser.swift
│       └── ...
│
├── Utilities/                    # Helper classes and utilities (9 files)
│   ├── Converters/              # Coordinate converters
│   │   ├── MGRSConverter.swift
│   │   └── BNGConverter.swift
│   ├── Parsers/                 # File parsers
│   │   ├── KMLParser.swift
│   │   └── KMZHandler.swift
│   ├── Integration/             # Integration helpers
│   │   ├── KMLMapIntegration.swift
│   │   └── ...
│   ├── Network/                 # Network utilities
│   │   ├── NetworkMonitor.swift
│   │   └── MultiServerFederation.swift
│   └── Calculators/             # Calculation utilities
│       └── MeasurementCalculator.swift
│
├── UI/                           # Reusable UI components (16 files)
│   ├── Components/              # Generic UI components
│   │   ├── DataPackageButton.swift
│   │   ├── QuickActionToolbar.swift
│   │   └── ...
│   ├── RadialMenu/              # Radial menu system
│   │   ├── RadialMenuView.swift
│   │   ├── RadialMenuActionExecutor.swift
│   │   └── ...
│   └── MilStd2525/             # Military standard symbols
│       └── MilStd2525Symbols.swift
│
├── Resources/                    # Resources and documentation
│   ├── Info.plist
│   ├── omnitak-mobile.p12
│   └── Documentation/           # Technical documentation
│       ├── CHAT_FEATURE_README.md
│       ├── KML_INTEGRATION_GUIDE.md
│       └── ...
│
└── Assets.xcassets/             # Image and color assets
```

## File Counts by Category

- **Core**: 2 Swift files (+ 1 header)
- **Models**: 22 Swift files
- **Views**: 62 Swift files
- **Services**: 26 Swift files
- **Managers**: 11 Swift files
- **Storage**: 5 Swift files
- **Map**: 29 Swift files (across 4 subdirectories)
- **CoT**: 9 Swift files (across 3 subdirectories)
- **Utilities**: 9 Swift files (across 5 subdirectories)
- **UI**: 16 Swift files (across 3 subdirectories)
- **Resources**: Documentation and config files

**Total**: ~193 Swift files organized into proper OOP structure

## Benefits of New Structure

### 1. **Separation of Concerns**

- Each directory has a specific responsibility
- Easy to locate files based on their function
- Clear boundaries between different layers

### 2. **Scalability**

- New features can be added without cluttering existing code
- Clear patterns for where new files should go
- Easier to navigate for new team members

### 3. **Maintainability**

- Related files are grouped together
- Easier to find and fix bugs
- Better code organization for refactoring

### 4. **Testing**

- Clear boundaries make unit testing easier
- Can test layers independently
- Mock dependencies more easily

### 5. **Build Performance**

- Better dependency management
- Xcode can better optimize builds with organized structure
- Easier to identify compilation dependencies

## Architecture Patterns

### MVVM Pattern

- **Models/**: Data structures and business entities
- **Views/**: SwiftUI views (presentation layer)
- **Services/** + **Managers/**: ViewModels and business logic

### Repository Pattern

- **Storage/**: Data persistence layer
- **Services/**: Abstracts data access from business logic

### Coordinator Pattern

- **Map/Controllers/**: Manages map-related navigation and state
- **UI/RadialMenu/**: Radial menu coordination

## Migration Notes

### What Changed

1. All files moved from flat structure to organized directories
2. Xcode project file references automatically updated
3. Build settings and configurations unchanged
4. No code changes required (only file locations)

### What Stayed the Same

- Import statements (Swift handles this automatically)
- Asset references
- Build configurations
- Signing & certificates
- Dependencies & frameworks

## Next Steps

### 1. Verify Build

```bash
cd /Users/iesouskurios/omniTAK-mobile/apps/omnitak
xcodebuild -project OmniTAKMobile.xcodeproj -scheme OmniTAKMobile clean build
```

### 2. Open in Xcode

```bash
open OmniTAKMobile.xcodeproj
```

### 3. Check File References

- In Xcode, verify all files show correct paths
- Look for any red (missing) files in the navigator
- If any files show as missing, right-click → "Show in Finder" to relocate

### 4. Build and Test

- Run the app on simulator
- Test major features
- Check for any import errors (unlikely)

## Troubleshooting

### Missing File References

If Xcode shows red files:

1. Select the file in Xcode navigator
2. Open File Inspector (⌘⌥1)
3. Click folder icon next to path
4. Navigate to correct location

### Build Errors

If you encounter build errors:

1. Clean build folder (⌘⇧K)
2. Delete derived data
3. Restart Xcode
4. Rebuild project

### Import Errors

Swift uses module-based imports, so file location doesn't affect imports. If you see import errors:

1. Check that all files are included in build target
2. Verify module name hasn't changed

## Backup

A backup of the original Xcode project was created at:

```
/Users/iesouskurios/omniTAK-mobile/apps/omnitak/OmniTAKMobile.xcodeproj.backup
```

If needed, you can restore by:

```bash
rm -rf OmniTAKMobile.xcodeproj
mv OmniTAKMobile.xcodeproj.backup OmniTAKMobile.xcodeproj
```

## Contributing

When adding new files, follow this structure:

- **Models**: Add new data structures here
- **Views**: Add new SwiftUI views here
- **Services**: Add new business logic services here
- **Managers**: Add new state managers here
- **Map/**: Add map-related components in appropriate subdirectory
- **UI/**: Add reusable UI components here

## Questions?

Refer to the individual integration guides in `Resources/Documentation/` for feature-specific documentation.

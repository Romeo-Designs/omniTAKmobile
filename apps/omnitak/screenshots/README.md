# Screenshots Directory

This directory contains screenshots of the OmniTAKMobile app for documentation.

## Required Screenshots

1. **main_map_view.png** - Main map view in portrait mode showing:
   - Compact translucent status bar
   - Satellite map view
   - Bottom toolbar
   - GPS location indicator

2. **tools_menu.png** - Tools menu showing:
   - Grid of all available tools
   - Teams, Chat, Routes, Geofence, etc.
   - Settings and Plugins options

3. **drawing_tools.png** - Drawing interface showing:
   - Drawing panel (polygon mode)
   - Color picker
   - Cancel/Undo/Done buttons

4. **drawings_list.png** - Drawings list showing:
   - List of saved drawings
   - Drawing categories (Circles, Lines, etc.)
   - Clear All option

## Screenshot Guidelines

- **Resolution**: Native iPhone resolution (1170x2532 for iPhone 14 Pro)
- **Format**: PNG (preferred) or JPG
- **Naming**: Use lowercase with underscores (e.g., `main_map_view.png`)
- **Size**: Keep under 500KB per image for fast loading

## How to Take Screenshots on iPhone

1. Press **Volume Up + Side Button** simultaneously
2. Screenshot saves to Photos
3. AirDrop or email to your Mac
4. Rename and place in this directory

## How to Take Screenshots in Simulator

```bash
# Method 1: Simulator menu
Device → Screenshot (⌘ + S)

# Method 2: Command line
xcrun simctl io booted screenshot screenshot_name.png
```

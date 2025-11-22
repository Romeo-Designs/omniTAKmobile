# Android App Icon Assets

## Required Icons

The following PNG icon files need to be created for the OmniTAK Android app. Place them in the specified directories:

### App Icons (Launcher)

- `app_assets/android/mipmap-mdpi/app_icon.png` - 48x48 px
- `app_assets/android/mipmap-hdpi/app_icon.png` - 72x72 px
- `app_assets/android/mipmap-xhdpi/app_icon.png` - 96x96 px
- `app_assets/android/mipmap-xxhdpi/app_icon.png` - 144x144 px
- `app_assets/android/mipmap-xxxhdpi/app_icon.png` - 192x192 px

### Design Guidelines

**Theme:** Tactical/Military
**Colors:**
- Primary: Dark Green (#1B5E20)
- Accent: Bright Green (#4CAF50)
- Background: Dark Green (#0D3818)

**Suggested Design:**
- Crosshair or tactical reticle symbol
- Map pin with military star
- Radio tower with signal waves
- Combination of map + communication icon

### Design Tools

You can use:
- Adobe Illustrator/Photoshop
- Figma
- Android Asset Studio: https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html
- Online Icon Generators

### Quick Setup (Placeholder)

For development/testing, you can use the Hello World app icons temporarily:

```bash
cp apps/helloworld/app_assets/android/mipmap-*/app_icon.png apps/omnitak_android/app_assets/android/mipmap-*/
```

Then replace with proper OmniTAK branded icons before release.

### Icon Checklist

- [ ] Design base icon in vector format (SVG/AI)
- [ ] Export to all required densities
- [ ] Test on different Android versions
- [ ] Verify adaptive icon support (Android 8.0+)
- [ ] Create foreground/background layers for adaptive icons
- [ ] Review on dark/light wallpapers
- [ ] Submit for brand approval

## Adaptive Icons (Optional - Android 8.0+)

For better Android 8.0+ support, consider creating:
- `app_assets/android/mipmap-anydpi-v26/app_icon.xml`
- Foreground layer PNG or vector
- Background layer (solid color or PNG)

This allows the system to mask and animate your icon.

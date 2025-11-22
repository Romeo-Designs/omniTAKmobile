//
//  MilStd2525MarkerView.swift
//  OmniTAKMobile
//
//  MIL-STD-2525B compliant map marker annotation view with proper affiliation shapes
//

import MapKit
import SwiftUI
import UIKit

// MARK: - MIL-STD-2525 Map Annotation View

/// Custom MKAnnotationView that displays MIL-STD-2525B military symbols
class MilStd2525MapAnnotationView: MKAnnotationView {
    private let markerSize: CGFloat = 60  // Optimal size for visibility
    private let callsignHeight: CGFloat = 24
    private var symbolImageView: UIImageView?
    private var glowLayer: CALayer?

    var cotType: String = "a-u-G" {
        didSet {
            if oldValue != cotType {
                updateMarkerImage()
            }
        }
    }

    var callsign: String = "UNKNOWN" {
        didSet {
            if oldValue != callsign {
                updateMarkerImage()
            }
        }
    }

    var echelon: MilStdEchelon? = nil {
        didSet {
            updateMarkerImage()
        }
    }

    var isMarkerSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        // Extract data from annotation if available
        if let markerAnnotation = annotation as? EnhancedCoTMarkerAnnotation {
            cotType = markerAnnotation.marker.type
            callsign = markerAnnotation.marker.callsign
        }
        
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = false
        centerOffset = CGPoint(x: 0, y: -markerSize / 2)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        
        // Setup image view for marker rendering
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.backgroundColor = .clear
        addSubview(imageView)
        symbolImageView = imageView
        
        // Add glow layer for selection effect
        let glow = CALayer()
        glow.shadowColor = UIColor.yellow.cgColor
        glow.shadowOffset = .zero
        glow.shadowRadius = 0
        glow.shadowOpacity = 0
        layer.insertSublayer(glow, at: 0)
        glowLayer = glow
        
        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.5
        
        updateMarkerImage()
    }

    private func updateMarkerImage() {
        let viewSize = CGSize(width: markerSize * 1.8, height: markerSize + callsignHeight + 16)
        
        print("🖼️ Rendering marker image for \(callsign) with type \(cotType)")
        
        // Create SwiftUI view
        let swiftUIView = MilStdMarkerSymbolView(
            cotType: cotType,
            callsign: callsign,
            echelon: echelon,
            size: markerSize,
            isSelected: false
        )
        
        // Use hosting controller for proper rendering
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(origin: .zero, size: viewSize)
        
        // Force layout
        hostingController.view.layoutIfNeeded()
        
        // Render to image
        let renderer = UIGraphicsImageRenderer(size: viewSize)
        let markerImage = renderer.image { context in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: viewSize), afterScreenUpdates: true)
        }
        
        print("✅ Image rendered: \(markerImage.size)")
        
        // Update image view
        symbolImageView?.image = markerImage
        symbolImageView?.frame = CGRect(origin: .zero, size: viewSize)
        
        // Update annotation view frame
        frame = CGRect(origin: .zero, size: viewSize)
        bounds = CGRect(origin: .zero, size: viewSize)
        
        // Set as annotation image for proper MapKit handling
        image = markerImage
    }
    
    private func updateSelectionState() {
        if isMarkerSelected {
            // Animate glow effect
            let animation = CABasicAnimation(keyPath: "shadowRadius")
            animation.fromValue = 8
            animation.toValue = 20
            animation.duration = 0.8
            animation.autoreverses = true
            animation.repeatCount = .infinity
            
            glowLayer?.shadowOpacity = 0.8
            glowLayer?.shadowRadius = 8
            glowLayer?.add(animation, forKey: "pulse")
        } else {
            // Remove glow
            glowLayer?.removeAllAnimations()
            glowLayer?.shadowOpacity = 0
        }
    }

    func configure(cotType: String, callsign: String, echelon: MilStdEchelon? = nil) {
        let needsUpdate = self.cotType != cotType || self.callsign != callsign || self.echelon != echelon
        
        self.cotType = cotType
        self.callsign = callsign
        self.echelon = echelon
        
        if needsUpdate {
            updateMarkerImage()
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        isMarkerSelected = selected
    }
}

// MARK: - SwiftUI Marker Symbol View

/// SwiftUI view for the marker symbol with proper MIL-STD-2525B shapes
struct MilStdMarkerSymbolView: View {
    let cotType: String
    let callsign: String
    let echelon: MilStdEchelon?
    let size: CGFloat
    let isSelected: Bool
    
    // Cache parsed properties to break AttributeGraph cycles
    private let properties: MilStdSymbolProperties
    
    init(cotType: String, callsign: String, echelon: MilStdEchelon?, size: CGFloat, isSelected: Bool) {
        self.cotType = cotType
        self.callsign = callsign
        self.echelon = echelon
        self.size = size
        self.isSelected = isSelected
        
        // Parse once during initialization
        var props = MilStdCoTParser.parse(cotType: cotType)
        if let echelonOverride = echelon {
            props = MilStdSymbolProperties(
                affiliation: props.affiliation,
                battleDimension: props.battleDimension,
                unitType: props.unitType,
                status: props.status,
                echelon: echelonOverride,
                modifiers: props.modifiers
            )
        }
        self.properties = props
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Main affiliation shape with solid fill
                affiliationShape
                    .fill(properties.affiliation.fillColor)
                    .frame(width: size, height: size)

                // Shape outline - bold and clear
                affiliationShape
                    .stroke(properties.affiliation.color, lineWidth: 3.5)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Unit type icon - crisp and centered
                Image(systemName: properties.unitType.icon)
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundColor(properties.affiliation.color)
                    .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                
                // Echelon indicator
                if let echelonSymbol = echelon?.symbol, !echelonSymbol.isEmpty {
                    VStack {
                        Spacer()
                        Text(echelonSymbol)
                            .font(.system(size: size * 0.2, weight: .bold))
                            .foregroundColor(properties.affiliation.color)
                            .padding(.bottom, 2)
                    }
                    .frame(height: size)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 3)

            // Callsign label - military-grade visibility
            Text(callsign.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(properties.affiliation.color.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                )
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)
        }
        .frame(maxWidth: size * 1.6)
    }

    private var affiliationShape: AnyShape {
        switch properties.affiliation {
        case .friendly, .assumed:
            // Rectangle for friendly (blue)
            return AnyShape(RoundedRectangle(cornerRadius: 2))
        case .hostile, .suspect, .joker, .faker:
            // Diamond for hostile (red)
            return AnyShape(RotatedSquare())
        case .neutral:
            // Square for neutral (green)
            return AnyShape(Rectangle())
        case .unknown, .pending:
            // Quatrefoil/Cloverleaf for unknown (yellow)
            return AnyShape(QuatrefoilShape())
        }
    }
}

// MARK: - Custom Shapes for Affiliation

/// Diamond shape (45-degree rotated square) for hostile units
struct RotatedSquare: Shape {
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

/// Quatrefoil/Cloverleaf shape for unknown units
struct QuatrefoilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3.2

        // Create four overlapping circles
        let offsets: [(CGFloat, CGFloat)] = [
            (0, -radius * 0.65),   // Top
            (radius * 0.65, 0),     // Right
            (0, radius * 0.65),     // Bottom
            (-radius * 0.65, 0)     // Left
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

// MARK: - Compact Marker Symbol (Icon Only)

/// Smaller version showing just the shape without callsign
struct CompactMilStdMarkerView: View {
    let cotType: String
    let size: CGFloat

    private var properties: MilStdSymbolProperties {
        MilStdCoTParser.parse(cotType: cotType)
    }

    var body: some View {
        ZStack {
            affiliationShape
                .fill(properties.affiliation.fillColor)
                .frame(width: size, height: size)

            affiliationShape
                .stroke(properties.affiliation.color, lineWidth: 2)
                .frame(width: size, height: size)

            Image(systemName: properties.unitType.icon)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(properties.affiliation.color)
        }
    }

    private var affiliationShape: AnyShape {
        switch properties.affiliation {
        case .friendly, .assumed:
            return AnyShape(RoundedRectangle(cornerRadius: 2))
        case .hostile, .suspect, .joker, .faker:
            return AnyShape(RotatedSquare())
        case .neutral:
            return AnyShape(Rectangle())
        case .unknown, .pending:
            return AnyShape(QuatrefoilShape())
        }
    }
}

// MARK: - MIL-STD Symbol Legend

/// Visual legend showing all affiliation shapes
struct MilStdAffiliationLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIT AFFILIATIONS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFF00"))

            ForEach([
                ("Friendly", "a-f-G-U-C-I", "Blue Rectangle"),
                ("Hostile", "a-h-G-U-C-I", "Red Diamond"),
                ("Neutral", "a-n-G-U-C-I", "Green Square"),
                ("Unknown", "a-u-G-U-C-I", "Yellow Quatrefoil")
            ], id: \.0) { name, type, shape in
                HStack(spacing: 12) {
                    CompactMilStdMarkerView(cotType: type, size: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        Text(shape)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
    }
}

// MARK: - UIKit Integration Helper

/// Helper to create annotation views for MapKit
extension MilStd2525MapAnnotationView {
    static func create(
        for annotation: MKAnnotation,
        cotType: String,
        callsign: String,
        echelon: MilStdEchelon? = nil
    ) -> MilStd2525MapAnnotationView {
        let view = MilStd2525MapAnnotationView(annotation: annotation, reuseIdentifier: "MilStd2525Marker")
        view.configure(cotType: cotType, callsign: callsign, echelon: echelon)
        return view
    }
}

// MARK: - CoT Marker Annotation

/// Custom annotation class that holds CoT marker data
class CoTMarkerAnnotation: NSObject, MKAnnotation {
    let cotMarker: CoTMarker
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(marker: CoTMarker) {
        self.cotMarker = marker
        self.coordinate = marker.coordinate
        self.title = marker.callsign
        self.subtitle = marker.type
        super.init()
    }
}

// MARK: - Preview

struct MilStd2525MarkerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("MIL-STD-2525B Map Markers")
                    .font(.title2)
                    .foregroundColor(.white)

                HStack(spacing: 30) {
                    MilStdMarkerSymbolView(
                        cotType: "a-f-G-U-C-I",
                        callsign: "R06",
                        echelon: .platoon,
                        size: 40,
                        isSelected: false
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-h-G-U-C-A",
                        callsign: "HOSTILE-3",
                        echelon: .company,
                        size: 40,
                        isSelected: true
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-n-G-U-C",
                        callsign: "NEUTRAL",
                        echelon: nil,
                        size: 40,
                        isSelected: false
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-u-G",
                        callsign: "UNKNOWN",
                        echelon: nil,
                        size: 40,
                        isSelected: false
                    )
                }

                MilStdAffiliationLegend()
                    .frame(width: 280)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}

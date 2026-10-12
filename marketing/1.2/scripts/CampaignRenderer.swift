import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

// Offline, editable campaign composition. Screen content is captured from the
// app; the renderer never recreates controls or edits the example conversations.
@main
@MainActor
struct CampaignRenderer {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 5 else { throw CocoaError(.fileReadUnknown) }
        let assets = try CampaignAssets(captures: args[1], bezels: args[2], photo: args[3])
        let output = URL(filePath: args[4])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for family in CampaignFamily.allCases {
            let folder = output.appending(path: "screenshots/\(family.rawValue)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, scene) in CampaignScene.allCases.enumerated() {
                if family == .mac && scene == .privacy { continue }
                let devices = try assets.devices(family: family, scene: scene)
                let view = CampaignSlide(family: family, scene: scene, devices: devices)
                let number = family == .duo && index > 0 ? index + 2 : index + 1
                let name = family == .duo && scene == .writing ? "writing-outer" : scene.rawValue
                try render(view, size: family.size, to: folder.appending(path: String(format: "%02d-%@.png", number, name)))
            }
            if family == .duo, let inner = try assets.devices(family: .duo, scene: .writing).secondary {
                try render(CampaignDuoInner(device: inner), size: CGSize(width: 2853, height: 2007), to: folder.appending(path: "02-writing-inner.png"))
            }
        }
        let creative = output.appending(path: "creative")
        try FileManager.default.createDirectory(at: creative, withIntermediateDirectories: true)
        for audience in CampaignAudience.allCases {
            let devices = try assets.devices(family: .iphone, scene: audience.scene)
            let secondary = try assets.devices(family: .ipad, scene: audience == .default ? .study : audience == .writing ? .outputs : audience.scene)
            for header in [true, false] {
                let size = header ? CGSize(width: 3840, height: 1646) : CGSize(width: 1920, height: 1280)
                let view = CampaignCreative(audience: audience, devices: devices, secondary: secondary, header: header)
                try render(view, size: size, to: creative.appending(path: "\(audience.rawValue)-\(header ? "header" : "search").png"))
            }
        }
        print("Exported 24 screenshots and 8 creative assets")
    }

    static func render<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light).frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        guard let image = renderer.cgImage, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        guard let opaque = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, opaque, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

enum CampaignFamily: String, CaseIterable {
    case iphone, duo, ipad, mac
    var size: CGSize {
        switch self {
        case .iphone: CGSize(width: 1206, height: 2622)
        case .duo: CGSize(width: 1398, height: 2034)
        case .ipad: CGSize(width: 2064, height: 2752)
        case .mac: CGSize(width: 2880, height: 1800)
        }
    }
}

enum CampaignScene: String, CaseIterable {
    case writing, planning, outputs, library, study, privacy
    var title: String {
        switch self {
        case .writing: "Big ideas.\nBetter words."
        case .planning: "A clear plan.\nA calmer week."
        case .outputs: "Good ideas.\nReady to use."
        case .library: "Your notes.\nNew possibilities."
        case .study: "Less cramming.\nMore learning."
        case .privacy: "Your ideas.\nYour choice."
        }
    }
    var subtitle: String {
        switch self {
        case .writing: "Find the right words with Ari."
        case .planning: "Turn a busy week into a simple plan."
        case .outputs: "Keep drafts, summaries, and checklists."
        case .library: "Bring your own context to every chat."
        case .study: "Turn what you know into flashcards."
        case .privacy: "Choose on-device AI or Private Cloud Compute."
        }
    }
    var kicker: String {
        switch self {
        case .writing: "WRITE WITH CONFIDENCE"
        case .planning: "MAKE ROOM FOR WHAT MATTERS"
        case .outputs: "FROM CHAT TO SOMETHING USEFUL"
        case .library: "A LITTLE CONTEXT GOES A LONG WAY"
        case .study: "MAKE EVERY STUDY SESSION COUNT"
        case .privacy: "AI THAT FITS YOUR COMFORT ZONE"
        }
    }
    var dark: Bool { self == .writing || self == .privacy }
    var background: Color {
        switch self {
        case .writing: Color(hex: 0x122C32)
        case .planning: Color(hex: 0xE5EDEB)
        case .outputs: Color(hex: 0xF7D7C5)
        case .library: Color(hex: 0xF2EAD8)
        case .study: Color(hex: 0xE7E1F5)
        case .privacy: Color(hex: 0x13232E)
        }
    }
    var accent: Color { dark ? Color(hex: 0xADF2CE) : Color(hex: 0x15645A) }
    var ink: Color { dark ? .white : Color(hex: 0x142B30) }
}

enum CampaignAudience: String, CaseIterable {
    case `default`, writing, study, planning
    var scene: CampaignScene {
        switch self { case .default, .writing: .writing; case .study: .study; case .planning: .planning }
    }
    var title: String {
        switch self {
        case .default: "A little help.\nA lot more possible."
        case .writing: "Your next draft.\nYour best words."
        case .study: "Small cards.\nBig aha moments."
        case .planning: "Less scattered.\nMore sorted."
        }
    }
    var subtitle: String {
        switch self {
        case .default: "Write, study, and plan with Ari."
        case .writing: "Emails, ideas, and drafts that sound like you."
        case .study: "Notes, summaries, and flashcards. All in one place."
        case .planning: "Make a plan. Keep a checklist. Take the next step."
        }
    }
}

struct CampaignDevices { var primary: CGImage; var secondary: CGImage? }

@MainActor
struct CampaignAssets {
    var captures: URL
    var bezels: URL
    var photo: CGImage
    var ciContext = CIContext()

    init(captures: String, bezels: String, photo: String) throws {
        self.captures = URL(filePath: captures)
        self.bezels = URL(filePath: bezels)
        self.photo = try Self.read(URL(filePath: photo))
    }

    static func read(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }

    func devices(family: CampaignFamily, scene: CampaignScene) throws -> CampaignDevices {
        let sourceURL = family == .mac ? captures.appending(path: "mac/\(scene.rawValue).png") : captures.appending(path: "\(family.rawValue)-\(scene.rawValue)-opaque.png")
        let original = try Self.read(sourceURL)
        let crop = CGRect(x: scene == .writing || scene == .planning ? 820 : 288, y: scene == .writing || scene == .planning ? 780 : 144, width: scene == .writing || scene == .planning ? 1510 : original.width - 288, height: original.height - (scene == .writing || scene == .planning ? 780 : 144))
        guard let capture = family == .mac ? original.cropping(to: crop) : original else { throw CocoaError(.fileReadCorruptFile) }
        switch family {
        case .iphone:
            return CampaignDevices(primary: try angledPhone(capture), secondary: nil)
        case .duo:
            let outer = try framed(capture, frame: "Bezel-iPhone-Duo/PNG/iPhone Duo - Night Sky - Outer Closed Portrait.png", screen: CGRect(x: 88, y: 80, width: 1398, height: 2034), radius: 105)
            let innerSource = captures.appending(path: "duo-\(scene == .study ? "study" : scene == .outputs ? "outputs" : "writing")-inner-final.png")
            let inner = try framed(Self.read(innerSource), frame: "Bezel-iPhone-Duo/PNG/iPhone Duo - Night Sky - Inner Open Landscape.png", screen: CGRect(x: 120, y: 120, width: 2853, height: 2007), radius: 90)
            return CampaignDevices(primary: outer, secondary: inner)
        case .ipad:
            return CampaignDevices(primary: try framed(capture, frame: "Bezel-iPad-Pro-M5/PNG/iPad Pro (M5) 13\" - Space Black - Portrait.png", screen: CGRect(x: 118, y: 124, width: 2064, height: 2752), radius: 52), secondary: nil)
        case .mac:
            return CampaignDevices(primary: try framed(capture, frame: "Bezel-MacBook-Air-M5/PNG/MacBook Air M5 15-inch Midnight.png", screen: CGRect(x: 329, y: 218, width: 2880, height: 1864), radius: 32), secondary: nil)
        }
    }

    func framed(_ screenImage: CGImage, frame path: String, screen: CGRect, radius: CGFloat) throws -> CGImage {
        let frame = try Self.read(bezels.appending(path: path))
        guard let c = CGContext(data: nil, width: frame.width, height: frame.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        // The template coordinates use top-left origin; Core Graphics uses bottom-left.
        let rect = CGRect(x: screen.minX, y: CGFloat(frame.height) - screen.maxY, width: screen.width, height: screen.height)
        c.saveGState()
        c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.clip()
        c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(rect)
        let scale = min(rect.width / CGFloat(screenImage.width), rect.height / CGFloat(screenImage.height))
        let fitted = CGSize(width: CGFloat(screenImage.width) * scale, height: CGFloat(screenImage.height) * scale)
        c.draw(screenImage, in: CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2, width: fitted.width, height: fitted.height))
        c.restoreGState()
        c.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard let result = c.makeImage() else { throw CocoaError(.fileWriteUnknown) }; return result
    }

    func angledPhone(_ image: CGImage) throws -> CGImage {
        guard let screen = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let c = CGContext(data: nil, width: photo.width, height: photo.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        let size = CGSize(width: image.width, height: image.height)
        screen.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 130, cornerHeight: 130, transform: nil)); screen.clip()
        screen.draw(image, in: CGRect(origin: .zero, size: size))
        // The screen capture omits the simulator's hardware mask. Restore the
        // pill in the hardware's position, preserving all app content below it.
        screen.setFillColor(CGColor(gray: 0, alpha: 1))
        screen.addPath(CGPath(roundedRect: CGRect(x: size.width * 0.40, y: size.height - 125, width: size.width * 0.20, height: 70), cornerWidth: 35, cornerHeight: 35, transform: nil)); screen.fillPath()
        guard let source = screen.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        let perspective = CIFilter.perspectiveTransform()
        perspective.inputImage = CIImage(cgImage: source)
        perspective.topLeft = CGPoint(x: 251, y: 1536 - 133)
        perspective.topRight = CGPoint(x: 735, y: 1536 - 80)
        perspective.bottomLeft = CGPoint(x: 233, y: 1536 - 1417)
        perspective.bottomRight = CGPoint(x: 736, y: 1536 - 1447)
        guard let warped = perspective.outputImage,
              let composited = ciContext.createCGImage(warped, from: CGRect(x: 0, y: 0, width: photo.width, height: photo.height)) else { throw CocoaError(.fileWriteUnknown) }
        c.draw(photo, in: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
        c.draw(composited, in: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
        guard let result = c.makeImage() else { throw CocoaError(.fileWriteUnknown) }; return result
    }
}

private struct CampaignBackdrop: View {
    var scene: CampaignScene
    var body: some View {
        GeometryReader { g in
            ZStack {
                scene.background
                Circle().fill(scene.accent.opacity(scene.dark ? 0.13 : 0.11))
                    .frame(width: g.size.width * 1.35, height: g.size.width * 1.35)
                    .position(x: g.size.width * 0.92, y: g.size.height * 0.76)
                Circle().stroke(scene.accent.opacity(0.15), lineWidth: g.size.width * 0.002)
                    .frame(width: g.size.width * 1.6, height: g.size.width * 1.6)
                    .position(x: g.size.width * 0.9, y: g.size.height * 0.78)
            }
        }.clipped()
    }
}

private struct CampaignBrand: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        HStack(spacing: size * 0.3) {
            Image(systemName: "sparkle").font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(Color(hex: 0xFA9183))
            Text("Ari").font(.system(size: size, weight: .bold, design: .rounded)).tracking(-size * 0.04)
        }.foregroundStyle(color)
    }
}

private struct CampaignSlide: View {
    var family: CampaignFamily
    var scene: CampaignScene
    var devices: CampaignDevices
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let landscape = family == .mac
            let margin = w * 0.075
            ZStack(alignment: .topLeading) {
                CampaignBackdrop(scene: scene)
                if landscape {
                    VStack(alignment: .leading, spacing: h * 0.025) {
                        CampaignBrand(color: scene.ink, size: h * 0.042)
                        Text(scene.kicker).font(.system(size: h * 0.017, weight: .bold)).tracking(h * 0.002).foregroundStyle(scene.accent)
                        Text(scene.title).font(.system(size: h * 0.079, weight: .bold)).tracking(-h * 0.003).lineSpacing(-h * 0.008).fixedSize(horizontal: false, vertical: true)
                        Text(scene.subtitle).font(.system(size: h * 0.029)).lineSpacing(h * 0.008)
                    }.foregroundStyle(scene.ink).frame(width: w * 0.37, alignment: .leading).offset(x: margin, y: h * 0.20)
                    Image(decorative: devices.primary, scale: 1).resizable().scaledToFit()
                        .frame(width: w * 0.57).offset(x: w * 0.42, y: h * 0.18)
                } else {
                    VStack(alignment: .leading, spacing: h * 0.012) {
                        CampaignBrand(color: scene.ink, size: w * 0.047)
                        Text(scene.kicker).font(.system(size: w * 0.021, weight: .bold)).tracking(w * 0.003).foregroundStyle(scene.accent).padding(.top, h * 0.018)
                        Text(scene.title).font(.system(size: w * (family == .ipad || scene == .library ? 0.086 : 0.104), weight: .bold)).tracking(-w * 0.004).lineSpacing(-w * 0.005).fixedSize(horizontal: false, vertical: true)
                        Text(scene.subtitle).font(.system(size: w * 0.030)).foregroundStyle(scene.ink.opacity(0.78))
                    }.foregroundStyle(scene.ink).frame(width: w - margin * 2, alignment: .leading).offset(x: margin, y: h * 0.045)
                    if family == .iphone {
                        Image(decorative: devices.primary, scale: 1).resizable()
                            .frame(width: w * 1.09, height: h * 0.70)
                            .rotationEffect(.degrees(scene == .planning || scene == .study ? -9 : 5))
                            .offset(x: -w * 0.04, y: h * 0.27)
                    } else if family == .duo {
                        if let secondary = devices.secondary {
                            Image(decorative: secondary, scale: 1).resizable().scaledToFit()
                                .frame(width: w * 0.69).offset(x: w * 0.29, y: h * 0.43)
                        }
                        Image(decorative: devices.primary, scale: 1).resizable().scaledToFit()
                            .frame(width: w * 0.42).offset(x: margin * 0.55, y: h * 0.40)
                    } else {
                        Image(decorative: devices.primary, scale: 1).resizable().scaledToFit()
                            .frame(height: h * 0.59).offset(x: w * 0.197, y: h * 0.355)
                    }
                    Text(family == .duo ? "A little help. On both displays." : "Write. Study. Plan. Make it yours.")
                        .font(.system(size: w * 0.024, weight: .medium)).foregroundStyle(scene.ink.opacity(0.60))
                        .frame(width: w, alignment: .center).offset(y: h * 0.961)
                }
            }.clipped()
        }
    }
}

private struct CampaignCreative: View {
    var audience: CampaignAudience
    var devices: CampaignDevices
    var secondary: CampaignDevices
    var header: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let scene = audience.scene
            ZStack(alignment: .topLeading) {
                CampaignBackdrop(scene: scene)
                VStack(alignment: .leading, spacing: h * 0.035) {
                    CampaignBrand(color: scene.ink, size: h * 0.063)
                    Text(audience.title).font(.system(size: h * (header ? 0.116 : 0.092), weight: .bold)).tracking(-h * 0.004).lineSpacing(-h * 0.007).fixedSize(horizontal: false, vertical: true)
                    Text(audience.subtitle).font(.system(size: h * 0.036)).foregroundStyle(scene.ink.opacity(0.76)).lineSpacing(h * 0.01)
                    Text("YOUR EVERYDAY AI ASSISTANT").font(.system(size: h * 0.017, weight: .bold)).tracking(h * 0.003).foregroundStyle(scene.accent).padding(.top, h * 0.02)
                }.foregroundStyle(scene.ink).frame(width: w * (header ? 0.44 : 0.43), alignment: .leading)
                    .offset(x: w * 0.065, y: h * 0.18)
                if header {
                    Image(decorative: secondary.primary, scale: 1).resizable().scaledToFit()
                        .frame(height: h * 0.81).offset(x: w * 0.71, y: h * 0.11)
                }
                Image(decorative: devices.primary, scale: 1).resizable()
                    .frame(width: h * 0.83, height: h * 1.06)
                    .rotationEffect(.degrees(-8))
                    .offset(x: w * (header ? 0.46 : 0.48), y: -h * 0.008)
            }.clipped()
        }
    }
}

private struct CampaignDuoInner: View {
    var device: CGImage
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                CampaignBackdrop(scene: .writing)
                CampaignBrand(color: .white, size: 68).offset(x: 180, y: 120)
                Text("Room for big ideas.").font(.system(size: 166, weight: .bold)).tracking(-7).foregroundStyle(.white).offset(x: 180, y: 240)
                Text("The same Ari. A bigger canvas.").font(.system(size: 58)).foregroundStyle(Color.white.opacity(0.75)).offset(x: 180, y: 448)
                Image(decorative: device, scale: 1).resizable().scaledToFit().frame(width: 1840).offset(x: 506, y: 615)
            }.frame(width: g.size.width, height: g.size.height).clipped()
        }
    }
}

private extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

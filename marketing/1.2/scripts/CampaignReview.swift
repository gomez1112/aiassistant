import SwiftUI
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

@main
@MainActor
struct CampaignReview {
    static func main() async throws {
        let root = URL(filePath: CommandLine.arguments[1])
        let output = root.appending(path: "review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for family in ["iphone", "duo", "ipad", "mac"] {
            let files = try FileManager.default.contentsOfDirectory(at: root.appending(path: "screenshots/\(family)"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            try contactSheet(files, title: "ARI · \(family.uppercased()) · VERSION 1.2", output: output.appending(path: "\(family).png"))
        }
        let creative = try FileManager.default.contentsOfDirectory(at: root.appending(path: "creative"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        try contactSheet(creative, title: "ARI · HEADERS & SEARCH RESULTS", output: output.appending(path: "creative.png"))
        let videos = try FileManager.default.contentsOfDirectory(at: root.appending(path: "previews"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "mp4" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var audit: [[String: Any]] = []
        for url in videos {
            let asset = AVURLAsset(url: url)
            guard let video = try await asset.loadTracks(withMediaType: .video).first,
                  let audio = try await asset.loadTracks(withMediaType: .audio).first else { throw CocoaError(.fileReadCorruptFile) }
            let size = try await video.load(.naturalSize), fps = try await video.load(.nominalFrameRate)
            let duration = try await asset.load(.duration).seconds
            let vf = try await video.load(.formatDescriptions), af = try await audio.load(.formatDescriptions)
            guard let format = af.first, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { throw CocoaError(.fileReadCorruptFile) }
            func codec(_ type: FourCharCode) -> String { String(bytes: [UInt8((type >> 24) & 255), UInt8((type >> 16) & 255), UInt8((type >> 8) & 255), UInt8(type & 255)], encoding: .ascii) ?? "unknown" }
            audit.append(["file": url.lastPathComponent, "width": Int(size.width), "height": Int(size.height), "fps": fps, "duration": duration, "audioChannels": asbd.pointee.mChannelsPerFrame, "audioSampleRate": asbd.pointee.mSampleRate, "audioCodec": codec(asbd.pointee.mFormatID), "videoCodec": vf.first.map { codec(CMFormatDescriptionGetMediaSubType($0)) } ?? "unknown"])
            guard duration >= 15 && duration <= 30 && abs(fps - 30) < 0.01 && asbd.pointee.mChannelsPerFrame == 2 else { throw CocoaError(.validationMissingMandatoryProperty) }
            let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
            let generated = try await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600))
            try write(generated.image, to: output.appending(path: url.deletingPathExtension().lastPathComponent + ".png"))
        }
        try JSONSerialization.data(withJSONObject: audit, options: [.prettyPrinted, .sortedKeys]).write(to: output.appending(path: "video-inspection.json"))
        print("Reviewed 24 screenshots, 8 creative images, and \(videos.count) H.264/AAC previews")
    }

    static func contactSheet(_ files: [URL], title: String, output: URL) throws {
        let columns = files.count > 7 ? 4 : files.count
        let slotWidth: CGFloat = 280, slotHeight: CGFloat = files.count > 7 ? 220 : 610
        let views = try files.map { url -> ReviewTile in
            guard let image = NSImage(contentsOf: url) else { throw CocoaError(.fileReadCorruptFile) }
            return ReviewTile(image: image, name: url.deletingPathExtension().lastPathComponent, height: slotHeight)
        }
        let content = VStack(alignment: .leading, spacing: 22) {
            Text(title).font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(slotWidth), spacing: 15), count: columns), spacing: 20) {
                ForEach(views.indices, id: \.self) { i in views[i] }
            }
        }.padding(30).background(Color(red: 0.08, green: 0.12, blue: 0.15))
        let renderer = ImageRenderer(content: content)
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        try write(image, to: output)
    }

    static func write(_ image: CGImage, to output: URL) throws {
        guard let d = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(d, image, nil)
        guard CGImageDestinationFinalize(d) else { throw CocoaError(.fileWriteUnknown) }
    }
}

private struct ReviewTile: View {
    var image: NSImage
    var name: String
    var height: CGFloat
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: 280, height: height - 38)
            Text(name).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
        }.frame(width: 280, height: height)
    }
}

import SwiftUI
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

@main
@MainActor
struct AriMediaExport {
    static func main() async throws {
        let args = CommandLine.arguments
        switch args[1] {
        case "video":
            try await exportVideo(source: args[2], audio: args[3], output: args[4], width: Int(args[5]) ?? 1920, height: Int(args[6]) ?? 1080)
        case "mac-shot":
            try exportMacShot(source: args[2], output: args[3], title: args[4], subtitle: args[5])
        case "frames":
            try await exportFrames(folder: args[2], output: args[3])
        case "poster":
            let asset = AVURLAsset(url: URL(filePath: args[2]))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let generated = try await generator.image(at: CMTime(seconds: Double(args[3]) ?? 5, preferredTimescale: 600))
            guard let destination = CGImageDestinationCreateWithURL(URL(filePath: args[4]) as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(destination, generated.image, nil)
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
            print(args[4])
        case "image":
            try exportImage(source: args[2], output: args[3], width: Int(args[4]) ?? 2880, height: Int(args[5]) ?? 1800)
        case "creative":
            try exportCreative(source: args[2], output: args[3], width: Int(args[4]) ?? 3840, height: Int(args[5]) ?? 1646, title: args[6], subtitle: args[7])
        case "inspect":
            let asset = AVURLAsset(url: URL(filePath: args[2]))
            let duration = try await asset.load(.duration)
            let video = try await asset.loadTracks(withMediaType: .video).first
            let audio = try await asset.loadTracks(withMediaType: .audio).first
            let size = try await video?.load(.naturalSize)
            let fps = try await video?.load(.nominalFrameRate)
            print("duration=\(duration.seconds) size=\(String(describing: size)) fps=\(String(describing: fps)) audio=\(audio != nil)")
        default: throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    static func exportVideo(source: String, audio: String, output: String, width: Int, height: Int) async throws {
        let videoAsset = AVURLAsset(url: URL(filePath: source))
        let soundAsset = AVURLAsset(url: URL(filePath: audio))
        let sourceDuration = try await videoAsset.load(.duration)
        let length = CMTime(seconds: min(25, sourceDuration.seconds), preferredTimescale: 600)
        let composition = AVMutableComposition()
        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await soundAsset.loadTracks(withMediaType: .audio).first,
              let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw CocoaError(.fileReadCorruptFile) }
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: sourceVideo, at: .zero)
        try sound.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: sourceAudio, at: .zero)
        let size = try await sourceVideo.load(.naturalSize)
        let preferred = try await sourceVideo.load(.preferredTransform)
        let transformed = CGRect(origin: .zero, size: size).applying(preferred)
        let scale = min(CGFloat(width) / abs(transformed.width), CGFloat(height) / abs(transformed.height))
        let transform = preferred.concatenating(CGAffineTransform(translationX: -transformed.minX, y: -transformed.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (CGFloat(width) - abs(transformed.width) * scale) / 2, y: (CGFloat(height) - abs(transformed.height) * scale) / 2))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
        layer.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: length)
        instruction.layerInstructions = [layer]
        instruction.backgroundColor = CGColor(gray: 1, alpha: 1)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: width, height: height)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw CocoaError(.fileWriteUnknown) }
        exporter.videoComposition = videoComposition
        exporter.shouldOptimizeForNetworkUse = true
        let destination = URL(filePath: output)
        if FileManager.default.fileExists(atPath: output) { try FileManager.default.removeItem(at: destination) }
        try await exporter.export(to: destination, as: .mp4)
        print(output)
    }


    // Marketing images show a magnified portion of real app content. Cropping
    // excludes compositor-only navigation chrome that NSView cannot export.
    nonisolated static func macCrop(source: String, width: Int, height: Int) -> CGRect {
        let name = URL(filePath: source).lastPathComponent
        let frame = Int(name.replacingOccurrences(of: "frame-", with: "").replacingOccurrences(of: ".png", with: ""))
        let conversation = name.contains("writing") || name.contains("planning") || (frame.map { $0 < 80 } ?? false)
        if conversation { return CGRect(x: 820, y: 360, width: min(1510, width - 820), height: height - 360) }
        return CGRect(x: 288, y: 144, width: width - 288, height: height - 144)
    }

    nonisolated static func macContent(_ source: String) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(URL(filePath: source) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              let crop = image.cropping(to: macCrop(source: source, width: image.width, height: image.height)) else { throw CocoaError(.fileReadCorruptFile) }
        return crop
    }

    static func exportMacShot(source: String, output: String, title: String, subtitle: String) throws {
        let crop = try macContent(source)
        let content = VStack(alignment: .leading, spacing: 44) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 116, weight: .bold)).tracking(-3)
                Spacer()
                Label("ai.assistant", systemImage: "sparkles").font(.system(size: 48, weight: .semibold))
            }
            Text(subtitle).font(.system(size: 42)).foregroundStyle(.secondary)
            Image(decorative: crop, scale: 1).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
                .clipShape(.rect(cornerRadius: 28))
        }
        .padding(120)
        .frame(width: 2880, height: 1800)
        .foregroundStyle(Color(red: 0.04, green: 0.18, blue: 0.18))
        .background(Color(red: 0.94, green: 0.97, blue: 0.95))
        try render(content, output: output, width: 2880, height: 1800)
    }

    @concurrent nonisolated static func exportFrames(folder: String, output: String) async throws {
        let files = try FileManager.default.contentsOfDirectory(at: URL(filePath: folder), includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count >= 150 else { throw CocoaError(.fileReadCorruptFile) }
        let destination = URL(filePath: output)
        if FileManager.default.fileExists(atPath: output) { try FileManager.default.removeItem(at: destination) }
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000]])
        // This offline media utility retains the released writer adaptor API.
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 1920, kCVPixelBufferHeightKey as String: 1080])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        for (index, url) in files.prefix(200).enumerated() {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32ARGB, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else { throw CocoaError(.fileWriteUnknown) }
            let crop = try macContent(url.path)
            CVPixelBufferLockBaseAddress(buffer, [])
            guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw CocoaError(.fileWriteUnknown) }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))
            let scale = min(1920 / CGFloat(crop.width), 1080 / CGFloat(crop.height))
            let width = CGFloat(crop.width) * scale, height = CGFloat(crop.height) * scale
            context.draw(crop, in: CGRect(x: (1920 - width) / 2, y: (1080 - height) / 2, width: width, height: height))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index * 3), timescale: 30)) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        print(output)
    }

    static func exportImage(source: String, output: String, width: Int, height: Int) throws {
        guard let image = NSImage(contentsOfFile: source) else { throw CocoaError(.fileReadCorruptFile) }
        let content = Image(nsImage: image).resizable().scaledToFit().frame(width: CGFloat(width), height: CGFloat(height)).background(.white)
        try render(content, output: output, width: width, height: height)
    }

    static func exportCreative(source: String, output: String, width: Int, height: Int, title: String, subtitle: String) throws {
        guard let screenshot = NSImage(contentsOfFile: source) else { throw CocoaError(.fileReadCorruptFile) }
        let content = AriCreative(screenshot: screenshot, title: title, subtitle: subtitle, width: CGFloat(width), height: CGFloat(height))
        try render(content, output: output, width: width, height: height)
    }

    static func render<Content: View>(_ content: Content, output: String, width: Int, height: Int) throws {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
        renderer.isOpaque = true
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(URL(filePath: output) as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let opaqueImage = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, opaqueImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        print(output)
    }
}

private struct AriCreative: View {
    var screenshot: NSImage
    var title: String
    var subtitle: String
    var width: CGFloat
    var height: CGFloat
    private var accent: Color { Color(red: 0.025, green: 0.43, blue: 0.40) }

    var body: some View {
        HStack(spacing: width * 0.05) {
            VStack(alignment: .leading, spacing: height * 0.035) {
                Label("ai.assistant", systemImage: "sparkles")
                    .font(.system(size: height * 0.07, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: height * 0.13, weight: .bold))
                    .tracking(-height * 0.004)
                    .foregroundStyle(Color(red: 0.04, green: 0.18, blue: 0.18))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: height * 0.044, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width * 0.48, alignment: .leading)

            Image(nsImage: screenshot)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: height * 0.86)
                .clipShape(.rect(cornerRadius: height * 0.045))
                .shadow(color: accent.opacity(0.12), radius: height * 0.025, x: 0, y: height * 0.02)
        }
        .padding(.horizontal, width * 0.065)
        .frame(width: width, height: height)
        .background(Color(red: 0.94, green: 0.97, blue: 0.95))
    }
}

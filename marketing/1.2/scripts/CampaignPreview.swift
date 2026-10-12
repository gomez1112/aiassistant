import AppKit
import AVFoundation
import SwiftUI

// App Store previews use real in-app footage, direct cuts, and contextual copy.
// Physical-device compositions belong to the still-image campaign.
@main
@MainActor
@available(macOS 27.0, *)
struct CampaignPreview {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 5 else { throw CocoaError(.fileReadUnknown) }
        let root = URL(filePath: args[1]), output = URL(filePath: args[2])
        let sound = URL(filePath: args[3])
        let timelines = try JSONDecoder().decode([String: [String: Double]].self, from: Data(contentsOf: URL(filePath: args[4])))
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for family in ["iphone", "duo", "ipad", "mac"] {
            for audience in family == "mac" ? ["default"] : ["default", "writing", "study", "planning"] {
                guard let timing = timelines[family] else { throw CocoaError(.fileReadCorruptFile) }
                try await export(source: root.appending(path: family == "mac" ? "mac-raw.mp4" : "\(family)-raw.mov"), sound: sound, output: output.appending(path: "\(family)-\(audience)-preview.mp4"), family: family, audience: audience, timings: timing)
                print("Exported \(family) \(audience)", terminator: "\n")
            }
        }
    }

    static func export(source: URL, sound: URL, output: URL, family: String, audience: String, timings: [String: Double]) async throws {
        let asset = AVURLAsset(url: source), music = AVURLAsset(url: sound)
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await music.loadTracks(withMediaType: .audio).first else { throw CocoaError(.fileReadCorruptFile) }
        let size = try await sourceVideo.load(.naturalSize)
        let preferred = try await sourceVideo.load(.preferredTransform)
        let sourceDuration = try await asset.load(.duration).seconds
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw CocoaError(.fileWriteUnknown) }
        let scenes: [(String, String)]
        switch audience {
        case "writing": scenes = [("writing", "Find your words."), ("outputs", "Keep your best drafts."), ("library", "Add your own context.")]
        case "study": scenes = [("study", "Make learning stick."), ("library", "Bring your study notes."), ("outputs", "Keep it all together.")]
        case "planning": scenes = [("planning", "Make space for your week."), ("outputs", "Turn ideas into next steps."), ("library", "Keep what matters close.")]
        default: scenes = [("writing", "Find your words."), ("planning", "Clear your next step."), ("outputs", "Keep the good ideas."), ("library", "Bring your own context."), ("study", "Make learning stick.")]
        }
        let slice = audience == "default" ? 4.0 : 5.0
        var cursor = 0.0
        for (scene, _) in scenes {
            let clipLength = min(3.2, slice)
            guard let sceneStart = timings[scene] else { throw CocoaError(.fileReadCorruptFile) }
            let start = min(sceneStart, sourceDuration - clipLength)
            let targetStart = CMTime(seconds: cursor, preferredTimescale: 600)
            let sourceLength = CMTime(seconds: clipLength, preferredTimescale: 600)
            try video.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: sourceLength), of: sourceVideo, at: targetStart)
            video.scaleTimeRange(CMTimeRange(start: targetStart, duration: sourceLength), toDuration: CMTime(seconds: slice, preferredTimescale: 600))
            cursor += slice
        }
        let duration = CMTime(seconds: cursor, preferredTimescale: 600)
        try audio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudio, at: .zero)
        let width: CGFloat = family == "ipad" ? 1200 : family == "mac" ? 1920 : 886
        let height: CGFloat = family == "ipad" ? 1600 : family == "mac" ? 1080 : 1920
        let banner: CGFloat = family == "mac" ? 145 : 160
        let footer: CGFloat = 58
        let bounds = CGRect(origin: .zero, size: size).applying(preferred)
        let scale = min(width / abs(bounds.width), (height - banner - footer) / abs(bounds.height))
        let transformed = preferred.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (width - abs(bounds.width) * scale) / 2, y: banner + (height - banner - footer - abs(bounds.height) * scale) / 2))
        var layerConfiguration = AVVideoCompositionLayerInstruction.Configuration(assetTrack: video)
        layerConfiguration.setTransform(transformed, at: .zero)
        let instruction = AVVideoCompositionInstruction(configuration: .init(backgroundColor: CGColor(gray: 1, alpha: 1), layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layerConfiguration)], timeRange: CMTimeRange(start: .zero, duration: duration)))
        var videoConfiguration = AVVideoComposition.Configuration()
        videoConfiguration.renderSize = CGSize(width: width, height: height)
        videoConfiguration.frameDuration = CMTime(value: 1, timescale: 30)
        videoConfiguration.instructions = [instruction]

        let parent = CALayer(); parent.frame = CGRect(x: 0, y: 0, width: width, height: height)
        parent.backgroundColor = CGColor(red: 0.07, green: 0.17, blue: 0.20, alpha: 1)
        let picture = CALayer(); picture.frame = parent.bounds; parent.addSublayer(picture)
        for (index, (_, caption)) in scenes.enumerated() {
            let context = ImageRenderer(content: PreviewCaption(caption: caption, width: width, height: banner))
            context.proposedSize = ProposedViewSize(width: width, height: banner)
            guard let image = context.cgImage else { throw CocoaError(.fileWriteUnknown) }
            let title = CALayer(); title.contents = image; title.frame = CGRect(x: 0, y: height - banner, width: width, height: banner); title.opacity = 0
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 1, 1, 0]
            opacity.keyTimes = [0, 0.045, 0.955, 1]
            opacity.beginTime = AVCoreAnimationBeginTimeAtZero + Double(index) * slice
            opacity.duration = slice; opacity.isRemovedOnCompletion = false; opacity.fillMode = .both
            title.add(opacity, forKey: "caption"); parent.addSublayer(title)
        }
        let footerRenderer = ImageRenderer(content: Text("Free features available. Unlimited chat requires Ari+.")
            .font(.system(size: 23, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            .frame(width: width, height: footer).background(Color(red: 0.07, green: 0.17, blue: 0.20)))
        footerRenderer.proposedSize = ProposedViewSize(width: width, height: footer)
        guard let footerImage = footerRenderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let disclaimer = CALayer(); disclaimer.contents = footerImage
        disclaimer.frame = CGRect(x: 0, y: 0, width: width, height: footer); parent.addSublayer(disclaimer)
        videoConfiguration.animationTool = AVVideoCompositionCoreAnimationTool(configuration: .init(postProcessingAsVideoLayer: picture, containingLayer: parent))
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw CocoaError(.fileWriteUnknown) }
        export.videoComposition = AVVideoComposition(configuration: videoConfiguration)
        export.shouldOptimizeForNetworkUse = true
        if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
        try await export.export(to: output, as: .mp4)
    }
}

private struct PreviewCaption: View {
    var caption: String
    var width: CGFloat
    var height: CGFloat
    var body: some View {
        HStack(spacing: 25) {
            VStack(alignment: .leading, spacing: 10) {
                Text("A LITTLE HELP. A LOT MORE POSSIBLE.").font(.system(size: 19, weight: .bold)).tracking(2).foregroundStyle(Color(red: 0.68, green: 0.95, blue: 0.81))
                Text(caption).font(.system(size: width > 1500 ? 52 : 43, weight: .bold)).tracking(-1.5).foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Text("Ari").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(Color(red: 0.98, green: 0.57, blue: 0.51))
        }.padding(.horizontal, 35).frame(width: width, height: height).background(Color(red: 0.07, green: 0.17, blue: 0.20))
    }
}

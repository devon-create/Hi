import AVFoundation
import CoreVideo
import UIKit

final class VideoRecorder {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private(set) var outputURL: URL?
    private let queue = DispatchQueue(label: "com.lidarcapture.videoRecorder")

    var isRecording: Bool { writer?.status == .writing }

    func start(to url: URL, width: Int, height: Int) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 12_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        videoInput.transform = CGAffineTransform(rotationAngle: .pi / 2)

        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelAttrs
        )
        if writer.canAdd(videoInput) { writer.add(videoInput) }

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: 64_000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        if writer.canAdd(audioInput) { writer.add(audioInput) }

        guard writer.startWriting() else {
            throw NSError(domain: "VideoRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: writer.error?.localizedDescription ?? "Could not start writer"])
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = adaptor
        self.outputURL = url
        self.startTime = nil
    }

    func append(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let writer, writer.status == .writing,
              let adaptor = pixelBufferAdaptor,
              let videoInput, videoInput.isReadyForMoreMediaData else { return }

        if startTime == nil {
            startTime = presentationTime
        }
        guard let start = startTime else { return }
        let relative = CMTimeSubtract(presentationTime, start)
        adaptor.append(pixelBuffer, withPresentationTime: relative)
    }

    func append(sampleBuffer: CMSampleBuffer) {
        guard let audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }

    func finish() async -> URL? {
        guard let writer else { return nil }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        await writer.finishWriting()
        let url = outputURL
        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.pixelBufferAdaptor = nil
        self.startTime = nil
        return url
    }

    func cancel() {
        writer?.cancelWriting()
        writer = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        if let url = outputURL { try? FileManager.default.removeItem(at: url) }
        outputURL = nil
    }
}

import AVFoundation
import UIKit

@MainActor
protocol StretchCuePlaying: AnyObject {
    func playCountdownCue(remainingSeconds: Int)
    func playTransitionCue(isFinalStep: Bool)
    func stop()
}

extension StretchCuePlaying {
    func stop() {}
}

@MainActor
final class StretchCuePlayer: StretchCuePlaying {
    private let countdownToneData: Data
    private let transitionToneData: Data
    private let completionToneData: Data
    private let haptics = HapticClient()
    private var audioPlayer: AVAudioPlayer?

    init() {
        countdownToneData = Self.makeWaveData(
            segments: [(680, 0.12)],
            amplitude: 0.06
        )
        transitionToneData = Self.makeWaveData(
            segments: [(660, 0.12), (0, 0.03), (880, 0.18)],
            amplitude: 0.08
        )
        completionToneData = Self.makeWaveData(
            segments: [(620, 0.12), (0, 0.03), (880, 0.16), (0, 0.03), (1040, 0.22)],
            amplitude: 0.09
        )
    }

    func playCountdownCue(remainingSeconds _: Int) {
        play(data: countdownToneData)
    }

    func playTransitionCue(isFinalStep: Bool) {
        play(data: isFinalStep ? completionToneData : transitionToneData)
        haptics.softTap()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func play(data: Data) {
        configureAudioSession()
        audioPlayer?.stop()
        audioPlayer = try? AVAudioPlayer(data: data)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private static func makeWaveData(
        segments: [(frequency: Double, duration: Double)],
        amplitude: Float,
        sampleRate: Int = 44_100
    ) -> Data {
        let totalFrames = Int(segments.reduce(0) { partialResult, segment in
            partialResult + segment.duration
        } * Double(sampleRate))
        var samples: [Int16] = []
        samples.reserveCapacity(max(totalFrames, 1))

        for segment in segments {
            let segmentFrames = Int(segment.duration * Double(sampleRate))
            let safeFrames = max(segmentFrames, 1)

            for frame in 0..<segmentFrames {
                let progress = Double(frame) / Double(max(safeFrames - 1, 1))
                let fadeIn = min(progress / 0.18, 1)
                let fadeOut = min((1 - progress) / 0.22, 1)
                let envelope = Float(min(fadeIn, fadeOut))

                let sampleValue: Float
                if segment.frequency > 0 {
                    let time = Double(frame) / Double(sampleRate)
                    sampleValue = Float(sin(2 * Double.pi * segment.frequency * time)) * amplitude * envelope
                } else {
                    sampleValue = 0
                }

                let clampedValue = max(min(sampleValue, 1), -1)
                samples.append(Int16(clampedValue * Float(Int16.max)))
            }
        }

        return Self.makePCM16WaveData(samples: samples, sampleRate: sampleRate)
    }

    private static func makePCM16WaveData(samples: [Int16], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let channelCount = 1
        let dataSize = samples.count * bytesPerSample
        let riffChunkSize = 36 + dataSize
        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: UInt32(riffChunkSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt16(channelCount))
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(byteRate))
        data.append(littleEndian: UInt16(blockAlign))
        data.append(littleEndian: UInt16(bytesPerSample * 8))
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: UInt32(dataSize))

        for sample in samples {
            data.append(littleEndian: sample)
        }

        return data
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}

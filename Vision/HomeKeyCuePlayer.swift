import AVFoundation
import Foundation

/// Two short tones make the F and J home positions distinguishable by ear.
@MainActor
final class HomeKeyCuePlayer {
    enum HomeKey { case f, j }

    static let shared = HomeKeyCuePlayer()

    private let fPlayer: AVAudioPlayer?
    private let jPlayer: AVAudioPlayer?

    private init() {
        fPlayer = try? AVAudioPlayer(data: Self.tone(frequency: 660))
        jPlayer = try? AVAudioPlayer(data: Self.tone(frequency: 880))
        fPlayer?.prepareToPlay()
        jPlayer?.prepareToPlay()
    }

    func play(_ key: HomeKey) {
        let player = key == .f ? fPlayer : jPlayer
        player?.currentTime = 0
        player?.play()
    }

    private static func tone(frequency: Double) -> Data {
        let sampleRate = 22_050
        let sampleCount = Int(Double(sampleRate) * 0.10)
        let byteCount = sampleCount * 2
        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        appendLE32(UInt32(36 + byteCount), to: &wav)
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE32(16, to: &wav)
        appendLE16(1, to: &wav) // Linear PCM.
        appendLE16(1, to: &wav) // Mono.
        appendLE32(UInt32(sampleRate), to: &wav)
        appendLE32(UInt32(sampleRate * 2), to: &wav)
        appendLE16(2, to: &wav)
        appendLE16(16, to: &wav)
        wav.append(contentsOf: Array("data".utf8))
        appendLE32(UInt32(byteCount), to: &wav)
        for index in 0..<sampleCount {
            let fade = min(1.0, Double(index) / 150.0,
                           Double(sampleCount - index) / 300.0)
            let phase = 2 * Double.pi * frequency * Double(index) / Double(sampleRate)
            let sample = Int16(sin(phase) * 5_500 * fade)
            appendLE16(UInt16(bitPattern: sample), to: &wav)
        }
        return wav
    }

    private static func appendLE16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private static func appendLE32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}

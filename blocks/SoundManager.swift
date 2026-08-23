import AVFoundation

final class SoundManager {
    private var activePlayers: [AVAudioPlayer] = []
    private var musicPlayer: AVAudioPlayer?
    var sfxMuted = false

    // MARK: - Music

    func startMusic() {
        guard musicPlayer == nil || !(musicPlayer!.isPlaying) else { return }
        guard let data = Self.makeMusicLoop(),
              let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }
        player.numberOfLoops = -1
        player.volume = 0.45
        player.prepareToPlay()
        player.play()
        musicPlayer = player
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    private static func makeMusicLoop() -> Data? {
        let rate = 22050.0
        let loopDur = 4.0
        let n = Int(loopDur * rate)
        var buf = [Float](repeating: 0, count: n)

        // Am – F – C – G arpeggio (4 bars × 4 quarter-notes, 0.25 s each)
        let arps: [(t: Double, f: Double, d: Double, g: Float)] = [
            (0.00, 220.0, 0.22, 0.032), (0.25, 261.6, 0.22, 0.032),
            (0.50, 329.6, 0.22, 0.032), (0.75, 440.0, 0.22, 0.026),
            (1.00, 174.6, 0.22, 0.032), (1.25, 220.0, 0.22, 0.032),
            (1.50, 261.6, 0.22, 0.032), (1.75, 349.2, 0.22, 0.026),
            (2.00, 130.8, 0.22, 0.032), (2.25, 196.0, 0.22, 0.032),
            (2.50, 261.6, 0.22, 0.032), (2.75, 329.6, 0.22, 0.026),
            (3.00, 196.0, 0.22, 0.032), (3.25, 246.9, 0.22, 0.032),
            (3.50, 293.7, 0.22, 0.032), (3.75, 392.0, 0.22, 0.026),
        ]
        // Sustained bass note per bar
        let bass: [(t: Double, f: Double, d: Double, g: Float)] = [
            (0.0, 110.0, 0.92, 0.050), (1.0, 87.31, 0.92, 0.050),
            (2.0, 65.41, 0.92, 0.050), (3.0, 98.00, 0.92, 0.050),
        ]

        for note in arps + bass {
            let s0  = Int(note.t * rate)
            let ns  = Int(note.d * rate)
            let atk = Int(0.012 * rate)
            let rel = Int(0.07  * rate)
            for i in 0..<ns {
                let idx = s0 + i
                if idx >= n { break }
                let env: Double
                if i < atk          { env = Double(i) / Double(atk) }
                else if i > ns-rel  { env = Double(ns - i) / Double(rel) }
                else                { env = 1.0 }
                buf[idx] += Float(sin(2 * .pi * note.f * Double(i) / rate) * Double(note.g) * env)
            }
        }

        // Short crossfade at loop boundary to prevent clicks
        let fade = Int(0.06 * rate)
        for i in 0..<fade {
            let f = Float(i) / Float(fade)
            buf[i]       *= f
            buf[n-1-i]   *= f
        }

        let pcm = buf.map { s -> Int16 in
            Int16(clamping: Int((max(-1, min(1, Double(s))) * 32767).rounded()))
        }
        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 2)) }
        let db = n * 2
        wav.append(contentsOf: [0x52,0x49,0x46,0x46]); u32(UInt32(36+db))
        wav.append(contentsOf: [0x57,0x41,0x56,0x45,0x66,0x6D,0x74,0x20])
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate*2)); u16(2); u16(16)
        wav.append(contentsOf: [0x64,0x61,0x74,0x61]); u32(UInt32(db))
        pcm.withUnsafeBytes { wav.append(contentsOf: $0) }
        return wav
    }

    // MARK: - Core

    private func play(freq: Double, dur: Double, gain: Float = 0.08, wave: Int = 0, delay: Double = 0) {
        guard !sfxMuted else { return }
        let fire: () -> Void = { [weak self] in
            guard let self,
                  let data = Self.makeWAV(freq: freq, dur: dur, gain: gain, wave: wave),
                  let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }
            player.prepareToPlay()
            player.play()
            self.activePlayers.append(player)
            if self.activePlayers.count > 24 {
                self.activePlayers.removeAll { !$0.isPlaying }
            }
        }
        if delay <= 0 {
            fire()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fire)
        }
    }

    private static func makeWAV(freq: Double, dur: Double, gain: Float, wave: Int) -> Data? {
        let rate: Double = 22050
        let n = max(1, Int(dur * rate))
        var samples = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / rate
            let raw: Double
            switch wave {
            case 1: raw = sin(2 * .pi * freq * t) >= 0 ? 1 : -1      // square
            case 2: raw = 2 * ((freq * t).truncatingRemainder(dividingBy: 1)) - 1  // sawtooth
            default: raw = sin(2 * .pi * freq * t)
            }
            let atk = min(Double(i)   / (rate * 0.008), 1.0)
            let rel = min(Double(n-i) / (rate * 0.05),  1.0)
            samples[i] = Int16(clamping: Int((raw * Double(gain) * min(atk, rel) * 32767).rounded()))
        }

        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 2)) }
        let dataBytes = n * 2
        wav.append(contentsOf: [0x52,0x49,0x46,0x46])  // "RIFF"
        u32(UInt32(36 + dataBytes))
        wav.append(contentsOf: [0x57,0x41,0x56,0x45])  // "WAVE"
        wav.append(contentsOf: [0x66,0x6D,0x74,0x20])  // "fmt "
        u32(16); u16(1); u16(1)                         // PCM, mono
        u32(UInt32(rate)); u32(UInt32(rate * 2))        // sample rate, byte rate
        u16(2); u16(16)                                 // block align, bits
        wav.append(contentsOf: [0x64,0x61,0x74,0x61])  // "data"
        u32(UInt32(dataBytes))
        samples.withUnsafeBytes { wav.append(contentsOf: $0) }
        return wav
    }

    // MARK: - Effects

    func playPlace() {
        play(freq: 300, dur: 0.05, gain: 0.04, wave: 1)
    }

    func playGold() {
        play(freq: 700, dur: 0.09, gain: 0.09)
        play(freq: 1000, dur: 0.13, gain: 0.09, delay: 0.06)
    }

    func playClear(lines: Int, heat: Int) {
        let base = 420.0 + Double(heat) * 9
        for i in 0..<min(lines, 4) {
            play(freq: base + Double(i) * 95, dur: 0.17, gain: 0.09, delay: Double(i) * 0.05)
        }
    }

    func playJackpot() {
        let reel: [Double] = [880, 988, 1175, 1318, 1568, 1760, 1976, 2093]
        for (i, f) in reel.enumerated() {
            play(freq: f, dur: 0.045, gain: 0.055, wave: 1, delay: Double(i) * 0.055)
        }
        let fanfare: [Double] = [2637, 2349, 2093, 2637, 3136, 2794, 3136, 3520]
        for (i, f) in fanfare.enumerated() {
            play(freq: f, dur: 0.08, gain: 0.07, delay: 0.44 + Double(i) * 0.075)
        }
        for f: Double in [523, 659, 784, 1047, 1318] {
            play(freq: f, dur: 0.55, gain: 0.04, delay: 1.06)
        }
        play(freq: 4186, dur: 0.18, gain: 0.05, delay: 1.10)
    }

    func playBooster() {
        play(freq: 880,  dur: 0.08, gain: 0.07)
        play(freq: 1100, dur: 0.08, gain: 0.07, delay: 0.05)
    }

    func playInvalid() {
        play(freq: 140, dur: 0.08, gain: 0.05, wave: 1)
    }

    func playGameOver() {
        play(freq: 300, dur: 0.20, gain: 0.07, wave: 2)
        play(freq: 220, dur: 0.22, gain: 0.07, wave: 2, delay: 0.14)
        play(freq: 140, dur: 0.30, gain: 0.07, wave: 2, delay: 0.30)
    }

    func playRescue() {
        play(freq: 500, dur: 0.10, gain: 0.09)
        play(freq: 650, dur: 0.10, gain: 0.09, delay: 0.08)
        play(freq: 850, dur: 0.16, gain: 0.10, delay: 0.16)
    }
}

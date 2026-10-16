import Foundation

/// A 10-band peaking (RBJ cookbook) equalizer, transposed Direct-Form-II, that
/// is safe to run on the Core Audio render thread: all buffers are preallocated
/// and processing does no allocation. Coefficient updates happen on the main
/// thread by overwriting shared coefficient storage in place — a momentary
/// mid-update read is bounded and inaudible for peaking sections.
final class BiquadEQ: @unchecked Sendable {
    let bandCount = 10
    let channelCount: Int
    private let q = 1.41

    private let freqs = eqBandFrequencies
    private var sampleRate: Double

    // Per-band coefficients (shared across channels), normalized by a0.
    private let b0, b1, b2, a1, a2: UnsafeMutablePointer<Double>
    // Per-band, per-channel filter state.
    private let z1, z2: UnsafeMutablePointer<Double>

    init(sampleRate: Double, channels: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channels
        b0 = .allocate(capacity: bandCount); b1 = .allocate(capacity: bandCount)
        b2 = .allocate(capacity: bandCount); a1 = .allocate(capacity: bandCount)
        a2 = .allocate(capacity: bandCount)
        z1 = .allocate(capacity: bandCount * channels)
        z2 = .allocate(capacity: bandCount * channels)
        b0.initialize(repeating: 1, count: bandCount)
        for p in [b1, b2, a1, a2] { p.initialize(repeating: 0, count: bandCount) }
        z1.initialize(repeating: 0, count: bandCount * channels)
        z2.initialize(repeating: 0, count: bandCount * channels)
    }

    deinit {
        for p in [b0, b1, b2, a1, a2] { p.deallocate() }
        z1.deallocate(); z2.deallocate()
    }

    /// Recompute all band coefficients for the given gains (dB). Main thread.
    func updateGains(_ gains: [Double]) {
        for band in 0..<bandCount {
            let gainDB = band < gains.count ? gains[band] : 0
            setPeaking(band: band, freq: freqs[band], gainDB: gainDB)
        }
    }

    func setSampleRate(_ rate: Double, gains: [Double]) {
        guard rate > 0 else { return }
        sampleRate = rate
        reset()
        updateGains(gains)
    }

    func reset() {
        z1.update(repeating: 0, count: bandCount * channelCount)
        z2.update(repeating: 0, count: bandCount * channelCount)
    }

    private func setPeaking(band: Int, freq: Double, gainDB: Double) {
        let A = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * freq / sampleRate
        let cosw = cos(w0)
        let alpha = sin(w0) / (2.0 * q)

        let a0 = 1 + alpha / A
        b0[band] = (1 + alpha * A) / a0
        b1[band] = (-2 * cosw) / a0
        b2[band] = (1 - alpha * A) / a0
        a1[band] = (-2 * cosw) / a0
        a2[band] = (1 - alpha / A) / a0
    }

    /// Process `count` samples in place for one channel. Render thread — no
    /// allocation, no ARC traffic.
    func process(channel: Int, samples: UnsafeMutablePointer<Float>, count: Int) {
        guard channel < channelCount else { return }
        for i in 0..<count {
            var x = Double(samples[i])
            for band in 0..<bandCount {
                let s = band * channelCount + channel
                let y = b0[band] * x + z1[s]
                z1[s] = b1[band] * x - a1[band] * y + z2[s]
                z2[s] = b2[band] * x - a2[band] * y
                x = y
            }
            samples[i] = Float(x)
        }
    }
}

import Accelerate
import Foundation

/// Computes per-band energy for the 10 EQ frequencies from a running mono mix,
/// so the display's spectrum columns line up 1:1 with the EQ faders. Fed from
/// the real-time render thread; read (snapshot) from the main thread.
final class SpectrumAnalyzer: @unchecked Sendable {
    let bandCount = 10
    private let n = 1024
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup

    private let window: UnsafeMutablePointer<Float>
    private let ring: UnsafeMutablePointer<Float>
    private var ringFill = 0
    private let windowed: UnsafeMutablePointer<Float>
    private let realp: UnsafeMutablePointer<Float>
    private let imagp: UnsafeMutablePointer<Float>
    private let mags: UnsafeMutablePointer<Float>

    // Inclusive FFT-bin range covering each band (≈ ±½ octave).
    private let loBin: [Int]
    private let hiBin: [Int]

    private var levels: [Float]
    private var lock = os_unfair_lock()

    init(sampleRate: Double) {
        log2n = vDSP_Length(log2(Double(n)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = .allocate(capacity: n)
        vDSP_hann_window(window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        ring = .allocate(capacity: n); ring.initialize(repeating: 0, count: n)
        windowed = .allocate(capacity: n)
        realp = .allocate(capacity: n / 2)
        imagp = .allocate(capacity: n / 2)
        mags = .allocate(capacity: n / 2)

        let maxBin = n / 2 - 1
        let fftSize = Double(n)
        let rate = sampleRate
        func binIndex(_ f: Double) -> Int { min(maxBin, max(1, Int(f / rate * fftSize))) }
        loBin = eqBandFrequencies.map { binIndex($0 / 1.41) }
        hiBin = eqBandFrequencies.map { binIndex($0 * 1.41) }
        levels = [Float](repeating: 0, count: bandCount)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
        for p in [window, ring, windowed, realp, imagp, mags] { p.deallocate() }
    }

    /// Feed mono samples (render thread). Runs an FFT each time `n` accumulate.
    func process(_ samples: UnsafeMutablePointer<Float>, _ count: Int) {
        var i = 0
        while i < count {
            let take = min(n - ringFill, count - i)
            memcpy(ring + ringFill, samples + i, take * MemoryLayout<Float>.size)
            ringFill += take
            i += take
            if ringFill == n { analyze(); ringFill = 0 }
        }
    }

    func snapshot() -> [Float] {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return levels
    }

    private func analyze() {
        vDSP_vmul(ring, 1, window, 1, windowed, 1, vDSP_Length(n))
        var split = DSPSplitComplex(realp: realp, imagp: imagp)
        windowed.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { ptr in
            vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(n / 2))
        }
        vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_zvabs(&split, 1, mags, 1, vDSP_Length(n / 2))

        os_unfair_lock_lock(&lock)
        for b in 0..<bandCount {
            var sum: Float = 0
            let lo = loBin[b], hi = max(loBin[b], hiBin[b])
            for bin in lo...hi { sum += mags[bin] }
            let avg = sum / Float(hi - lo + 1)
            // Perceptual scaling + clamp; smoothed for a natural fall-off.
            var v = sqrtf(avg / Float(n)) * 4.5
            v = min(max(v, 0), 1)
            levels[b] = levels[b] * 0.55 + v * 0.45
        }
        os_unfair_lock_unlock(&lock)
    }
}

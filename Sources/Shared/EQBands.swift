import Foundation

/// The 10 ISO octave band centre frequencies. Shared by the Mac EQ, the
/// spectrum analyzer, and the iOS visualizer so their columns line up.
let eqBandFrequencies: [Double] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

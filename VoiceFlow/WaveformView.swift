import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    var barCount: Int = 30
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = levelAt(i)
                    let barWidth = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.25 + 0.75 * Double(level)))
                        .frame(
                            width: barWidth,
                            height: max(4, geo.size.height * CGFloat(level))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .animation(.linear(duration: 0.05), value: levels.count)
    }

    private func levelAt(_ index: Int) -> Float {
        let start = max(0, levels.count - barCount)
        let trailing = Array(levels[start...])
        let i = index - (barCount - trailing.count)
        guard i >= 0 && i < trailing.count else { return 0 }
        return trailing[i]
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(levels: (0..<30).map { _ in Float.random(in: 0.05...1) })
            .frame(height: 80)
        WaveformView(levels: (0..<10).map { _ in Float.random(in: 0.05...0.6) })
            .frame(height: 80)
    }
    .padding()
}

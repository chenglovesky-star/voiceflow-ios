import SwiftUI

/// 录音中的实时声波可视化样式。
/// - bars：经典 EQ 条形图（默认 v1 样式）
/// - ecg：心电图样式，Canvas 绘制 QRS 状尖峰，从右向左滚动
/// - heart：红色 ❤️ 跟随音量「砰砰」缩放
/// - house：橙色 🏠 跟随音量呼吸
enum WaveformStyle: String, CaseIterable, Sendable {
    case bars
    case ecg
    case heart
    case house

    var displayName: String {
        switch self {
        case .bars:  return String(localized: "Bars")
        case .ecg:   return String(localized: "ECG")
        case .heart: return String(localized: "Heart")
        case .house: return String(localized: "House")
        }
    }
}

struct WaveformView: View {
    let levels: [Float]
    var style: WaveformStyle = .ecg
    var color: Color = .accentColor
    var sampleCount: Int = 30

    var body: some View {
        switch style {
        case .bars:  barsView
        case .ecg:   ecgView
        case .heart: pulseSymbol(name: "heart.fill", tint: .red)
        case .house: pulseSymbol(name: "house.fill", tint: .orange)
        }
    }

    // MARK: - bars (legacy EQ style)

    private var barsView: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<sampleCount, id: \.self) { i in
                    let level = levelAt(i)
                    let barWidth = max(2, (geo.size.width - CGFloat(sampleCount - 1) * 2) / CGFloat(sampleCount))
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
        .animation(.linear(duration: 0.2), value: levels.last ?? 0)
    }

    // MARK: - ecg (心电图)

    /// 经典心电绿，比 accentColor 更"心电图气质"
    private static let ecgColor = Color(red: 0.22, green: 0.95, blue: 0.55)

    private var ecgView: some View {
        Canvas { ctx, size in
            let path = Self.ecgPath(in: size, samples: trailingLevels())
            ctx.stroke(
                path,
                with: .color(Self.ecgColor),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .animation(.linear(duration: 0.18), value: levels.last ?? 0)
    }

    /// 把 sampleCount 个 level 串成 ECG 折线：每个 sample 处画一个简化 QRS 复合波
    /// (Q 小负尖 → R 大正尖 → S 小负尖)，sample 之间是平直基线。
    private static func ecgPath(in size: CGSize, samples: [Float]) -> Path {
        var path = Path()
        let count = max(samples.count, 1)
        let stepX = size.width / CGFloat(count)
        let midY = size.height / 2
        let amplitude = size.height * 0.42

        path.move(to: CGPoint(x: 0, y: midY))

        for i in 0..<count {
            let level = CGFloat(samples[i])
            let xCenter = stepX * (CGFloat(i) + 0.5)
            let spike = level * amplitude

            // 进 spike 前的基线段
            path.addLine(to: CGPoint(x: xCenter - stepX * 0.30, y: midY))
            // Q：小负尖
            path.addLine(to: CGPoint(x: xCenter - stepX * 0.18, y: midY + spike * 0.25))
            // R：大正尖
            path.addLine(to: CGPoint(x: xCenter, y: midY - spike))
            // S：小负尖
            path.addLine(to: CGPoint(x: xCenter + stepX * 0.18, y: midY + spike * 0.25))
            // 回基线
            path.addLine(to: CGPoint(x: xCenter + stepX * 0.30, y: midY))
        }

        path.addLine(to: CGPoint(x: size.width, y: midY))
        return path
    }

    // MARK: - pulse symbol (心跳 / 房子等)

    /// 当前 level 驱动 SF Symbol 缩放；spring 动画让脉冲带回弹感
    private func pulseSymbol(name: String, tint: Color) -> some View {
        let level = CGFloat(levels.last ?? 0)
        return Image(systemName: name)
            .font(.system(size: 88, weight: .regular))
            .foregroundColor(tint)
            .scaleEffect(1.0 + 0.35 * level)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: level)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - helpers

    private func trailingLevels() -> [Float] {
        let start = max(0, levels.count - sampleCount)
        var trailing = Array(levels[start...])
        // 不足 sampleCount 时左侧补零，保证 ECG 折线 X 轴稳定
        if trailing.count < sampleCount {
            trailing = Array(repeating: 0, count: sampleCount - trailing.count) + trailing
        }
        return trailing
    }

    private func levelAt(_ index: Int) -> Float {
        let trailing = trailingLevels()
        return trailing.indices.contains(index) ? trailing[index] : 0
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(levels: (0..<30).map { _ in Float.random(in: 0.1...0.95) }, style: .ecg)
            .frame(height: 100)
            .background(Color.black.opacity(0.85))
        WaveformView(levels: (0..<30).map { _ in Float.random(in: 0.1...0.95) }, style: .bars)
            .frame(height: 100)
        WaveformView(levels: [0.7], style: .heart)
            .frame(height: 100)
        WaveformView(levels: [0.5], style: .house)
            .frame(height: 100)
    }
    .padding()
}

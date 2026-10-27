import AppKit
import Foundation
import SwiftUI

// MARK: - 特效预算（性能红线）
//
// 鸡血模式的设计目标：60fps 不掉帧。
// 做法：
// 1) 事件粒子（光点/星火/彩带/冲击环）用「时间函数」求位置，而不是每帧积分，
//    Canvas 每帧只做纯数学 + 少量 fill，不做布局、不用 blur。
// 2) 环境粒子（底部上浮的碎金）完全程序化生成：不占数组、不随 tick 增长，
//    只按 TimelineView 的当前时间算相位，数量封顶 42。
// 3) 事件粒子数组封顶 120 + 环境粒子 40，同屏粒子总量不超过约 160。
enum HypeFX {
    static let maxEventParticles = 120
    static let maxAmbientParticles = 40
    static let ambientBase = 26

    static let warmWhite = Color(red: 1.0, green: 0.95, blue: 0.80)
    static let glowPalette: [Color] = [Theme.gold, Theme.amber, HypeFX.warmWhite, Theme.pink, Theme.cyan]
    static let confettiPalette: [Color] = [Theme.gold, Theme.pink, Theme.cyan, Theme.green, Theme.amber]

    static func clampIntensity(_ value: Double) -> Double { min(1.6, max(0.5, value)) }
    static func rnd(_ range: ClosedRange<Double>) -> Double { Double.random(in: range) }
}

// MARK: - 粒子模型

enum HypeParticleKind {
    case orb       // 光点
    case spark     // 星火
    case confetti  // 彩带
    case ring      // 冲击环
}

struct HypeParticle {
    var kind: HypeParticleKind
    var born: TimeInterval
    var life: TimeInterval
    var origin: CGPoint
    var velocity: CGVector
    var gravity: CGFloat
    var drag: CGFloat
    var size: CGFloat
    var color: Color
    var spin: Double
    var spinSpeed: Double
}

// MARK: - 粒子场

struct HypeParticleField {
    private(set) var particles: [HypeParticle] = []

    mutating func clear() {
        particles.removeAll(keepingCapacity: true)
    }

    mutating func prune(now: TimeInterval) {
        particles.removeAll { now - $0.born > $0.life }
    }

    private mutating func push(_ particle: HypeParticle, now: TimeInterval) {
        if particles.count >= HypeFX.maxEventParticles {
            prune(now: now)
            if particles.count >= HypeFX.maxEventParticles {
                particles.removeFirst(particles.count - HypeFX.maxEventParticles + 1)
            }
        }
        particles.append(particle)
    }

    /// 每跨 1 单位：数字附近的小型光点 + 星火迸发
    mutating func pulseBurst(at origin: CGPoint, intensity: Double, now: TimeInterval) {
        let k = HypeFX.clampIntensity(intensity)
        let coins = max(3, Int((6.0 * k).rounded()))
        for _ in 0..<coins {
            let angle = HypeFX.rnd(-Double.pi * 0.96 ... -Double.pi * 0.04)
            let speed = HypeFX.rnd(64...170) * k
            push(HypeParticle(
                kind: .orb,
                born: now,
                life: HypeFX.rnd(0.55...1.05),
                origin: origin,
                velocity: CGVector(dx: CGFloat(cos(angle) * speed), dy: CGFloat(sin(angle) * speed)),
                gravity: 380,
                drag: 1.1,
                size: CGFloat(HypeFX.rnd(2.0...3.4)) * CGFloat(0.85 + 0.25 * k),
                color: HypeFX.glowPalette.randomElement() ?? Theme.gold,
                spin: HypeFX.rnd(0...Double.pi * 2),
                spinSpeed: HypeFX.rnd(-9...9)
            ), now: now)
        }
        let sparks = max(2, Int((4.0 * k).rounded()))
        for _ in 0..<sparks {
            push(HypeParticle(
                kind: .spark,
                born: now,
                life: HypeFX.rnd(0.45...0.9),
                origin: origin,
                velocity: CGVector(dx: CGFloat(HypeFX.rnd(-130...130) * k),
                                   dy: CGFloat(HypeFX.rnd(-200 ... -40) * k)),
                gravity: 220,
                drag: 0.9,
                size: CGFloat(HypeFX.rnd(1.6...2.8)),
                color: HypeFX.rnd(0...1) > 0.55 ? Theme.cyan : HypeFX.warmWhite,
                spin: HypeFX.rnd(0...Double.pi * 2),
                spinSpeed: HypeFX.rnd(-7...7)
            ), now: now)
        }
    }

    /// 每跨 10 档里程碑：光点大爆发 + 星火 + 顶部彩带 + 冲击环
    mutating func milestoneBurst(at origin: CGPoint, topOrigin: CGPoint, intensity: Double, now: TimeInterval) {
        let k = HypeFX.clampIntensity(intensity)

        let coins = max(8, Int((22.0 * k).rounded()))
        for _ in 0..<coins {
            let angle = HypeFX.rnd(-Double.pi * 1.05 ... Double.pi * 0.05)
            let speed = HypeFX.rnd(120...330) * k
            push(HypeParticle(
                kind: .orb,
                born: now,
                life: HypeFX.rnd(0.9...1.8),
                origin: origin,
                velocity: CGVector(dx: CGFloat(cos(angle) * speed), dy: CGFloat(sin(angle) * speed)),
                gravity: 430,
                drag: 0.95,
                size: CGFloat(HypeFX.rnd(2.6...5.2)) * CGFloat(0.85 + 0.25 * k),
                color: HypeFX.glowPalette.randomElement() ?? Theme.gold,
                spin: HypeFX.rnd(0...Double.pi * 2),
                spinSpeed: HypeFX.rnd(-12...12)
            ), now: now)
        }

        let sparks = max(5, Int((12.0 * k).rounded()))
        for _ in 0..<sparks {
            let angle = HypeFX.rnd(-Double.pi ... 0)
            let speed = HypeFX.rnd(160...400) * k
            push(HypeParticle(
                kind: .spark,
                born: now,
                life: HypeFX.rnd(0.55...1.15),
                origin: origin,
                velocity: CGVector(dx: CGFloat(cos(angle) * speed), dy: CGFloat(sin(angle) * speed)),
                gravity: 240,
                drag: 1.0,
                size: CGFloat(HypeFX.rnd(2.0...3.8)),
                color: HypeFX.confettiPalette.randomElement() ?? Theme.gold,
                spin: HypeFX.rnd(0...Double.pi * 2),
                spinSpeed: HypeFX.rnd(-10...10)
            ), now: now)
        }

        let ribbons = max(6, Int((16.0 * k).rounded()))
        for _ in 0..<ribbons {
            push(HypeParticle(
                kind: .confetti,
                born: now,
                life: HypeFX.rnd(1.5...2.3),
                origin: CGPoint(x: topOrigin.x + CGFloat(HypeFX.rnd(-150...150)), y: topOrigin.y),
                velocity: CGVector(dx: CGFloat(HypeFX.rnd(-70...70)), dy: CGFloat(HypeFX.rnd(30...130))),
                gravity: 250,
                drag: 0.7,
                size: CGFloat(HypeFX.rnd(3.2...6.4)),
                color: HypeFX.confettiPalette.randomElement() ?? Theme.pink,
                spin: HypeFX.rnd(0...Double.pi * 2),
                spinSpeed: HypeFX.rnd(-8...8)
            ), now: now)
        }

        for index in 0..<2 {
            push(HypeParticle(
                kind: .ring,
                born: now,
                life: 0.8,
                origin: origin,
                velocity: .zero,
                gravity: 0,
                drag: 0,
                size: CGFloat(5 + index * 7),
                color: index == 0 ? HypeFX.warmWhite : Theme.gold,
                spin: 0,
                spinSpeed: 0
            ), now: now)
        }
    }
}

// MARK: - 粒子画布

struct HypeParticleCanvas: View {
    /// 跨 1 单位触发器
    var coinPulse: Int
    /// 跨 10 档里程碑触发器
    var milestoneCount: Int
    /// 0.5 ~ 1.6
    var intensity: Double
    /// 仅在计时中为 true；否则 TimelineView 暂停、粒子清空
    var active: Bool
    /// 迸发原点（相对画布，用于对齐大号金额）
    var origin: UnitPoint

    @State private var field = HypeParticleField()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !active)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, canvasSize in
                    guard active else { return }
                    drawAmbient(in: &context, size: canvasSize, now: now)
                    drawParticles(in: &context, now: now)
                }
            }
            .onChange(of: coinPulse) { _, _ in
                spawnPulseBurst(size: size)
            }
            .onChange(of: milestoneCount) { _, _ in
                spawnMilestone(size: size)
            }
            .onChange(of: active) { _, isActive in
                if !isActive { field.clear() }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 生成

    private func spawnPulseBurst(size: CGSize) {
        guard active, size.width > 1, size.height > 1 else { return }
        let now = Date().timeIntervalSinceReferenceDate
        field.prune(now: now)
        field.pulseBurst(at: burstPoint(in: size), intensity: intensity, now: now)
    }

    private func spawnMilestone(size: CGSize) {
        guard active, size.width > 1, size.height > 1 else { return }
        let now = Date().timeIntervalSinceReferenceDate
        field.prune(now: now)
        field.milestoneBurst(at: burstPoint(in: size),
                             topOrigin: CGPoint(x: size.width * 0.5, y: -8),
                             intensity: intensity,
                             now: now)
    }

    private func burstPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * origin.x, y: size.height * origin.y)
    }

    // MARK: 绘制

    private func drawParticles(in ctx: inout GraphicsContext, now: TimeInterval) {
        for particle in field.particles {
            let age = now - particle.born
            guard age >= 0, age <= particle.life else { continue }
            let progress = age / particle.life
            let alpha = HypeParticleCanvas.fadeAlpha(progress)
            guard alpha > 0.01 else { continue }

            let decay: Double = particle.drag > 0.001
                ? (1 - exp(-particle.drag * age)) / particle.drag
                : age
            let x = particle.origin.x + particle.velocity.dx * CGFloat(decay)
            let y = particle.origin.y + particle.velocity.dy * CGFloat(decay)
                + 0.5 * particle.gravity * CGFloat(age * age)
            let point = CGPoint(x: x, y: y)

            switch particle.kind {
            case .orb:
                drawOrb(in: &ctx, point: point, particle: particle, progress: progress, alpha: alpha)
            case .spark:
                drawSpark(in: &ctx, point: point, particle: particle, age: age, progress: progress, alpha: alpha)
            case .confetti:
                drawConfetti(in: &ctx, point: point, particle: particle, age: age, progress: progress, alpha: alpha)
            case .ring:
                drawRing(in: &ctx, point: point, particle: particle, age: age, progress: progress, alpha: alpha)
            }
        }
    }

    private func drawAmbient(in ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let k = HypeFX.clampIntensity(intensity)
        let count = min(HypeFX.maxAmbientParticles, max(6, Int((Double(HypeFX.ambientBase) * k).rounded())))
        guard count > 0, size.width > 1 else { return }
        let width = Double(size.width)
        let height = Double(size.height)

        for index in 0..<count {
            let r1 = HypeParticleCanvas.hash(index, 1)
            let r2 = HypeParticleCanvas.hash(index, 2)
            let r3 = HypeParticleCanvas.hash(index, 3)
            let speed = (0.05 + r1 * 0.08) * (0.7 + 0.3 * k)
            let cycle = (now * speed + r2).truncatingRemainder(dividingBy: 1)
            let x = width * (0.04 + r3 * 0.92) + sin(now * (0.4 + r1) + r2 * 6.283) * (5 + r3 * 9)
            let y = height * (1.04 - cycle)
            // 首尾淡入淡出，中段最亮
            let fade = sin(Double.pi * cycle)
            let alpha = (0.08 + 0.28 * fade) * min(1.0, 0.6 + 0.4 * k)
            let radius = (0.9 + r2 * 1.5) * (0.8 + 0.25 * k)
            let color: Color = r1 > 0.80 ? Theme.cyan : (r1 > 0.62 ? Theme.amber : Theme.gold)
            let rect = CGRect(x: CGFloat(x - radius), y: CGFloat(y - radius),
                              width: CGFloat(radius * 2), height: CGFloat(radius * 2))
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
        }
    }

    private func drawOrb(in ctx: inout GraphicsContext, point: CGPoint, particle: HypeParticle,
                          progress: Double, alpha: Double) {
        let shrink = 0.72 + 0.28 * (1 - progress)
        let radius = particle.size * CGFloat(shrink)
        let glow = radius * 2.2
        ctx.fill(Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow,
                                        width: glow * 2, height: glow * 2)),
                 with: .color(particle.color.opacity(alpha * 0.15)))
        ctx.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                        width: radius * 2, height: radius * 2)),
                 with: .color(particle.color.opacity(alpha * 0.95)))
        let sheen = radius * 0.42
        ctx.fill(Path(ellipseIn: CGRect(x: point.x - radius * 0.45, y: point.y - radius * 0.55,
                                        width: sheen * 2, height: sheen * 2)),
                 with: .color(Color.white.opacity(alpha * 0.62)))
    }

    private func drawSpark(in ctx: inout GraphicsContext, point: CGPoint, particle: HypeParticle,
                           age: Double, progress: Double, alpha: Double) {
        let radius = particle.size * CGFloat(0.8 + 0.5 * (1 - progress))
        let path = starPath(center: point,
                            outer: radius * 1.9,
                            inner: radius * 0.5,
                            rotation: particle.spin + age * particle.spinSpeed)
        ctx.fill(path, with: .color(particle.color.opacity(alpha * 0.95)))
    }

    private func drawConfetti(in ctx: inout GraphicsContext, point: CGPoint, particle: HypeParticle,
                              age: Double, progress: Double, alpha: Double) {
        let shrink = 1 - 0.18 * progress
        let width = particle.size * CGFloat(shrink)
        let height = width * 0.55
        let transform = CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: CGFloat(particle.spin + age * particle.spinSpeed))
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: height * 0.3).applying(transform)
        ctx.fill(path, with: .color(particle.color.opacity(alpha * 0.9)))
    }

    private func drawRing(in ctx: inout GraphicsContext, point: CGPoint, particle: HypeParticle,
                          age: Double, progress: Double, alpha: Double) {
        let radius = particle.size + CGFloat(age) * 230
        let rect = CGRect(x: point.x - radius, y: point.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.stroke(Path(ellipseIn: rect),
                   with: .color(particle.color.opacity(alpha * 0.5)),
                   lineWidth: max(0.8, CGFloat(1 - progress) * 3.2))
    }

    private func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, rotation: Double) -> Path {
        var path = Path()
        let points = 4
        let step = Double.pi / Double(points)
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = rotation + Double(index) * step - Double.pi / 2
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                                y: center.y + radius * CGFloat(sin(angle)))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func fadeAlpha(_ progress: Double) -> Double {
        if progress < 0.10 { return progress / 0.10 }
        if progress > 0.62 { return max(0, (1 - progress) / 0.38) }
        return 1
    }

    /// 稳定伪随机：同一 index 每帧得到相同偏移，环境粒子不会闪跳
    private static func hash(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: seed &* 374_761_393 &+ salt &* 668_265_263)
        x = (x ^ (x >> 13)) &* 1_274_126_177
        x ^= x >> 16
        return Double(x & 0xFFFF) / 65_535.0
    }
}

// MARK: - 倒计时文本（< 1h 变红脉冲）

struct HypeCountdownText: View {
    var text: String
    var danger: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !danger)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = danger ? 0.5 + 0.5 * sin(time * 4.0) : 0
            Text(text)
                .font(Theme.mono(27, weight: .heavy).monospacedDigit())
                .foregroundStyle(danger ? AnyShapeStyle(HypeCountdownText.dangerGradient)
                                        : AnyShapeStyle(Theme.textPrimary))
                .shadow(color: danger ? Color.red.opacity(0.30 + 0.40 * pulse) : .clear,
                        radius: danger ? 9 : 0)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: text)
                .lineLimit(1)
        }
        .frame(height: 32, alignment: .leading)
    }

    private static var dangerGradient: LinearGradient {
        LinearGradient(colors: [Theme.pink, Color(red: 1.0, green: 0.22, blue: 0.26)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - 进度条（流光 + 危险脉冲）

struct HypeProgressBar: View {
    var progress: Double
    var danger: Bool
    var running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { timeline in
            bar(at: timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func bar(at time: TimeInterval) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = CGFloat(min(1, max(0, progress)))
            let fillWidth = max(6, width * clamped)
            let phase = running ? CGFloat((time / 2.2).truncatingRemainder(dividingBy: 1)) : 0.42
            let pulse = running ? 0.5 + 0.5 * (0.5 + 0.5 * sin(time * 4.2)) : 0.5
            let glow: Color = danger ? Color.red : Theme.gold
            // 性能：动画中的进度条不用 shadow / blendMode（软件合成下很贵），
            // 用「流光 + 呼吸高光 + 端点脉冲」表达光感。
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(danger ? AnyShapeStyle(HypeProgressBar.dangerGradient)
                                 : AnyShapeStyle(Theme.hypeBarGradient))
                    .frame(width: fillWidth)
                    .overlay(alignment: .leading) {
                        LinearGradient(colors: [.clear, Color.white.opacity(0.50), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 46)
                            .offset(x: (fillWidth + 46) * phase - 46)
                    }
                    .overlay {
                        Capsule().fill(glow.opacity(0.10 + 0.16 * pulse))
                    }
                    .clipShape(Capsule())
                Circle()
                    .fill(Color.white.opacity(running ? 0.55 + 0.45 * pulse : 0.4))
                    .frame(width: 4 + 2 * pulse, height: 4 + 2 * pulse)
                    .offset(x: fillWidth - 4)
            }
        }
    }

    private static var dangerGradient: LinearGradient {
        LinearGradient(colors: [Theme.pink, Color(red: 1.0, green: 0.22, blue: 0.26)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - 连击徽章

struct HypeComboBadge: View {
    var combo: Int
    var active: Bool

    var body: some View {
        if active && combo > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: tier == 2 ? 10.5 : 9.5, weight: .bold))
                Text("连击 ×\(combo)")
                    .font(.system(size: fontSize, weight: tier >= 1 ? .heavy : .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(tier == 2 ? AnyShapeStyle(Theme.hypeGradient)
                                       : AnyShapeStyle(tier == 1 ? Theme.gold : Theme.textSecondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.gold.opacity(tier == 0 ? 0.06 : 0.13)))
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(tier == 0 ? 0.12 : 0.38), lineWidth: 1))
            .shadow(color: Theme.gold.opacity(tier == 2 ? 0.55 : (tier == 1 ? 0.26 : 0)),
                    radius: tier == 2 ? 9 : 5)
            // 只在档位变化时做一次淡入动画（combo 本身 10Hz 变化，不做逐帧动画）
            .animation(.easeOut(duration: 0.22), value: tier)
        }
    }

    private var tier: Int {
        if combo >= 300 { return 2 }
        if combo >= 30 { return 1 }
        return 0
    }

    private var fontSize: CGFloat {
        switch tier {
        case 2: return 12.5
        case 1: return 11.5
        default: return 10.5
        }
    }
}

// MARK: - 励志语轮播（~15s 一条，淡入淡出）

struct HypeQuoteCarousel: View {
    var enabled: Bool

    @State private var index = 0

    private static let quotes: [String] = [
        "每一秒，进度都在向前",
        "你不是在硬撑，是在积累自己",
        "今天的专注，明天会加倍还你",
        "稳一点，数字在涨，班在下",
        "别人在摸鱼，你在往前",
        "再撑一会儿，下班就是自由",
        "现在的每一分钟，都算数",
        "你在前进，世界在让路",
        "疲惫是暂时的，成长是永久的",
        "保持节奏，成果会自己排队来",
        "别怀疑，你在变强",
        "今天的你，比昨天更强",
    ]

    var body: some View {
        if enabled {
            ZStack(alignment: .leading) {
                Text(HypeQuoteCarousel.quotes[index % HypeQuoteCarousel.quotes.count])
                    .id(index)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 7)),
                                            removal: .opacity.combined(with: .offset(y: -7))))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .task(id: enabled) {
                guard enabled else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    if Task.isCancelled { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        index &+= 1
                    }
                }
            }
        }
    }
}

// MARK: - 状态胶囊

struct HypeStatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.85), radius: 4)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - 里程碑横幅

struct MilestoneBanner: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.16))
                    .frame(width: 20, height: 20)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.hypeGradient)
            }
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("·")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("里程碑")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(Theme.gold.opacity(0.14)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.14, blue: 0.08),
                                              Color(red: 0.10, green: 0.10, blue: 0.14)],
                                     startPoint: .leading, endPoint: .trailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: Theme.gold.opacity(0.32), radius: 14, y: 4)
        .frame(maxWidth: .infinity)
        .lineLimit(1)
    }
}

/// 监听 milestoneCount 的变化，弹出 1.8s 自动消失的里程碑横幅（可选音效）。
struct HypeBannerHost: View {
    var milestoneCount: Int
    /// 隐晦展示前缀："" / "·" / 货币符号
    var prefix: String
    var soundEnabled: Bool
    var active: Bool
    var crossedMilestone: Double

    @State private var visible = false
    @State private var bannerID = 0
    @State private var phraseIndex = 0
    @State private var hideToken = 0

    private static let phrases: [String] = [
        "又 +10 了！",
        "正在超越昨天的自己",
        "距离下一杯咖啡又近了",
        "节奏在叠加，别停",
        "这一档，稳了",
        "继续，状态正好",
    ]

    var body: some View {
        ZStack(alignment: .top) {
            if visible {
                MilestoneBanner(title: title, subtitle: subtitle)
                    .id(bannerID)
                    .transition(.asymmetric(
                        insertion: .offset(y: 12).combined(with: .opacity),
                        removal: .scale(scale: 0.86, anchor: .center).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: visible)
        .onChange(of: milestoneCount) { _, newValue in
            guard active, newValue > 0 else { return }
            show()
        }
    }

    private var title: String {
        HypeBannerHost.phrases[phraseIndex % HypeBannerHost.phrases.count]
    }

    private var subtitle: String {
        "今日 \(MoneyFormat.compact(crossedMilestone, currency: prefix))"
    }

    private func show() {
        phraseIndex &+= 1
        hideToken &+= 1
        let token = hideToken
        bannerID &+= 1
        visible = true
        if soundEnabled {
            HypeSound.playMilestone()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard token == hideToken else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                visible = false
            }
        }
    }
}

// MARK: - 音效（默认关闭；找不到系统音时静默）

enum HypeSound {
    static func playMilestone() {
        for name in ["Glass", "Ping", "Pop"] {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.volume = 0.6
                sound.play()
                return
            }
        }
    }
}

import SwiftUI

/// 鸡血模式：把「每 0.1s 增长的数字」变成有爽感的现场。
///
/// 布局在父视图给定的 448×322 容器内（减去 RootView 的 header/padding 后约 416×276），
/// 所有尺寸都按固定高度估算，不留溢出风险。
struct HypeView: View {
    @ObservedObject var model: AppModel

    @State private var amountPop: CGFloat = 1
    @State private var popToken = 0

    // MARK: - 派生状态

    private var snapshot: SalarySnapshot { model.snapshot }
    /// 隐晦展示：按设置返回 "" / "·" / 货币符号
    private var prefix: String { model.config.displayPrefix }
    private var intensity: Double { min(1.6, max(0.5, model.config.hypeIntensity)) }

    /// 真正在计时：工作日 + 工作时段 + 不在午休
    private var isEarning: Bool {
        snapshot.isWorkday && snapshot.isWithinWorkWindow && !snapshot.isLunchBreak
    }

    /// 最后 1 小时：红色脉冲
    private var isDanger: Bool {
        isEarning && snapshot.remainingWorkSeconds < 3600
    }

    /// 今日已跨过的 10 档数（用于展示与横幅副标题）
    private var crossedMilestones: Int {
        max(0, Int(snapshot.earnedToday / 10))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            content

            // 粒子层：整个面板铺满，金币/星火/彩带在 UI 之上
            HypeParticleCanvas(coinPulse: model.coinPulse,
                               milestoneCount: model.milestoneCount,
                               intensity: intensity,
                               active: isEarning,
                               origin: UnitPoint(x: 0.26, y: 0.30))

            // 里程碑横幅：浮在金额与底部卡片之间
            HypeBannerHost(milestoneCount: model.milestoneCount,
                           prefix: prefix,
                           soundEnabled: model.config.soundEnabled,
                           active: isEarning,
                           crossedMilestone: Double(crossedMilestones) * 10)
                .padding(.top, 112)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: model.coinPulse) { _, _ in popAmount() }
        .onChange(of: model.milestoneCount) { _, _ in popAmount(strong: true) }
    }

    // MARK: - 主内容

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            amountSection
                .padding(.top, 12)
            Spacer(minLength: 8)
            bottomCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            HypeStatusPill(text: neutralStatusText, color: statusColor)
            Spacer(minLength: 6)
            HypeComboBadge(combo: model.combo, active: isEarning)
        }
        .frame(height: 24)
    }

    /// 状态文案中性化：共享层 statusText 可能含「赚钱/开薪」等字眼，
    /// 这里在视图内统一映射，保证公开场合不暴露（不改 Models）。
    private var neutralStatusText: String {
        if isEarning { return "计时中" }
        if snapshot.isLunchBreak { return "午休中 · 稍后继续" }
        if !snapshot.isWorkday { return "今天休息 · 不用上班" }
        if secondsUntilWorkStart != nil { return "还没开始 · 距开工还有" }
        if snapshot.remainingWorkSeconds <= 0 { return "今日已下班 · 明天继续" }
        return snapshot.statusText
            .replacingOccurrences(of: "赚钱", with: "计时")
            .replacingOccurrences(of: "开薪", with: "开工")
    }

    private var statusColor: Color {
        if !snapshot.isWorkday { return Theme.pink }
        if snapshot.isLunchBreak { return Theme.amber }
        if isEarning { return Theme.green }
        return Theme.cyan
    }

    // MARK: - 金额

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.amountText)
                .font(Theme.mono(52, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.hypeGradient)
                .contentTransition(.numericText())
                // 只在跨整数（coinPulse）/里程碑时做数字滚动，避免 10Hz 持续动画
                .animation(.easeOut(duration: 0.16), value: model.coinPulse)
                .scaleEffect(amountPop, anchor: .leading)
                .shadow(color: Theme.gold.opacity(isEarning ? 0.32 : 0.16), radius: 16, x: 0, y: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(height: 62, alignment: .leading)

            HStack(spacing: 8) {
                Text("每秒 \(prefix)\(model.perSecondText)")
                Capsule()
                    .fill(Theme.textSecondary.opacity(0.28))
                    .frame(width: 1, height: 9)
                Text(model.hourlyText)
                Spacer(minLength: 6)
                Text("下一档 \(MoneyFormat.compact(snapshot.milestoneValue, currency: prefix))")
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(height: 14)
            .padding(.top, 1)

            milestoneBar
                .padding(.top, 7)
        }
    }

    private var milestoneBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(Theme.hypeBarGradient)
                    .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, snapshot.milestoneProgress)))))
                    .shadow(color: Theme.amber.opacity(0.5), radius: 3)
            }
        }
        .frame(height: 4)
    }

    // MARK: - 底部卡片（倒计时 + 进度条 + 励志语）

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(remainingLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    HypeCountdownText(text: remainingValue, danger: isDanger)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("今日进度")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 5) {
                        Text("\(model.progressPercent)%")
                            .font(Theme.mono(15, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isEarning ? Theme.green : Theme.textSecondary)
                    }
                }
            }

            HypeProgressBar(progress: snapshot.todayProgress, danger: isDanger, running: isEarning)

            HStack(spacing: 8) {
                HypeQuoteCarousel(enabled: model.config.motivationalEnabled)
                Spacer(minLength: 6)
                milestoneChip
            }
            .frame(height: 16)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.035)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isDanger ? Theme.pink.opacity(0.35) : Theme.stroke, lineWidth: 1)
        )
    }

    private var milestoneChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "rosette")
                .font(.system(size: 8.5, weight: .semibold))
            Text("今日 \(crossedMilestones) 档")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.gold.opacity(0.9))
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(Theme.gold.opacity(0.10)))
        .lineLimit(1)
    }

    // MARK: - 文案

    private var remainingLabel: String {
        if snapshot.isLunchBreak { return "午休中 · 下午继续" }
        if isEarning {
            if isDanger { return "距下班 · 最后冲刺" }
            return "距下班"
        }
        if !snapshot.isWorkday {
            return secondsUntilNextWorkStart == nil ? "今天休息 · 明天再战" : "距下次开工"
        }
        if secondsUntilWorkStart != nil { return "距开工" }
        if snapshot.remainingWorkSeconds <= 0 { return "今日已下班 · 明天继续" }
        return "距下班"
    }

    private var remainingValue: String {
        if !snapshot.isWorkday {
            if let seconds = secondsUntilNextWorkStart { return MoneyFormat.shortClock(seconds) }
            return "—"
        }
        if let seconds = secondsUntilWorkStart {
            return MoneyFormat.clock(seconds)
        }
        return model.remainingText
    }

    /// 休息日：距离下一个工作日开工还有多少秒
    private var secondsUntilNextWorkStart: Double? {
        guard !snapshot.isWorkday, let next = snapshot.nextWorkdayStart else { return nil }
        return max(0, next.timeIntervalSince(snapshot.now))
    }

    /// 上班前：距离今天开工还有多少秒（工作日、未进入工作时段的早晨）
    private var secondsUntilWorkStart: Double? {
        guard snapshot.isWorkday, !snapshot.isWithinWorkWindow,
              !snapshot.isLunchBreak else { return nil }
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: model.config.startHour,
                                        minute: model.config.startMinute,
                                        second: 0,
                                        of: snapshot.now),
              start > snapshot.now else { return nil }
        return start.timeIntervalSince(snapshot.now)
    }

    // MARK: - Q 弹

    private func popAmount(strong: Bool = false) {
        guard isEarning || strong else { return }
        popToken &+= 1
        let token = popToken
        withAnimation(.spring(response: strong ? 0.20 : 0.14,
                              dampingFraction: strong ? 0.44 : 0.42)) {
            amountPop = strong ? 1.10 : 1.055
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(strong ? 150 : 90))
            guard token == popToken else { return }
            withAnimation(.spring(response: strong ? 0.55 : 0.42, dampingFraction: 0.6)) {
                amountPop = 1.0
            }
        }
    }
}

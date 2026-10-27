import SwiftUI

// MARK: - 简洁模式

/// 简洁模式：低干扰看板。
/// 一眼抓住两件事：今天累计了多少、距离下班还剩多久。
/// 无粒子、无闪烁；数字变化只做轻微过渡。
struct SimpleView: View {
    @ObservedObject var model: AppModel

    private enum Phase {
        case earning      // 计时中
        case lunch        // 午休
        case beforeWork   // 还没上班
        case afterWork    // 已下班
        case restDay      // 休息日
    }

    private var config: SalaryConfig { model.config }
    private var snapshot: SalarySnapshot { model.snapshot }

    /// 速率行前缀：圆点前缀与分隔符「·」视觉重复，此时省略
    private var ratePrefix: String {
        config.displayPrefix == "·" ? "" : config.displayPrefix
    }

    // MARK: - 状态推导

    private var phase: Phase {
        let s = snapshot
        if !s.isWorkday { return .restDay }
        if s.isLunchBreak { return .lunch }
        if s.isWithinWorkWindow { return .earning }
        let start = dateToday(hour: config.startHour, minute: config.startMinute)
        return s.now < start ? .beforeWork : .afterWork
    }

    private var phaseTitle: String {
        switch phase {
        case .earning: return "计时中"
        case .lunch: return "午休"
        case .beforeWork: return "还没上班"
        case .afterWork: return "已下班"
        case .restDay: return "休息日"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .earning: return Theme.green
        case .lunch: return Theme.amber
        case .beforeWork: return Theme.cyan
        case .afterWork: return Theme.gold
        case .restDay: return Color(red: 0.70, green: 0.66, blue: 1.0)
        }
    }

    // MARK: - 布局

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            Spacer(minLength: 6)
            amountRow
            rateRow
            Spacer(minLength: 8)
            progressRow
            Color.clear.frame(height: 9)
            footerRow
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 顶部：状态胶囊 + 「今日」小标
    private var statusRow: some View {
        HStack(spacing: 8) {
            statusCapsule
            Spacer(minLength: 0)
            Text("今日 +")
                .font(.system(size: 9.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary.opacity(0.55))
        }
        .frame(height: 20)
    }

    private var statusCapsule: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(phaseColor)
                .frame(width: 5, height: 5)
                .shadow(color: phaseColor.opacity(phase == .earning ? 0.8 : 0.0), radius: 2.5)
            Text(phaseTitle)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(phaseColor.opacity(0.95))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Capsule(style: .continuous).fill(phaseColor.opacity(0.10)))
        .overlay(Capsule(style: .continuous).strokeBorder(phaseColor.opacity(0.22), lineWidth: 1))
    }

    // 中部：大号金额（前缀 / 整数 / 小数 分层排版）
    // 前缀来自 config.displayPrefix：默认纯数字，不暴露金额属性。
    private var amountRow: some View {
        let parts = amountParts
        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            if !parts.prefix.isEmpty {
                Text(parts.prefix)
                    .font(Theme.mono(21, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
            Text(parts.whole)
                .font(Theme.mono(42, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [Color.white, Color.white.opacity(0.74)],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text(parts.decimals)
                .font(Theme.mono(21, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .contentTransition(.numericText())
        .animation(.easeOut(duration: 0.22), value: model.amountText)
        .shadow(color: Theme.green.opacity(0.14), radius: 9, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日 \(model.amountText)")
    }

    // 金额下方：每秒速率 / 每小时速率
    private var rateRow: some View {
        HStack(spacing: 5) {
            Text("每秒")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
            Text(MoneyFormat.amount(snapshot.perSecond, currency: ratePrefix, decimals: 4))
                .font(Theme.mono(10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary.opacity(0.9))
            Text("·")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary.opacity(0.35))
            Text(MoneyFormat.amount(snapshot.perHour, currency: ratePrefix, decimals: 1) + "/时")
                .font(Theme.mono(10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary.opacity(0.9))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // 细进度条 + 百分比
    private var progressRow: some View {
        HStack(spacing: 9) {
            ThinProgressBar(value: snapshot.todayProgress)
                .frame(height: 5)
            Text("\(model.progressPercent)%")
                .font(Theme.mono(10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary.opacity(0.85))
                .frame(width: 34, alignment: .trailing)
        }
    }

    // 底部：距下班 / 距离下一个上班时间
    private var footerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: footerSymbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(phaseColor.opacity(0.85))
            Text(footerLeading)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            Text(footerTrailing)
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(height: 16)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    // MARK: - 文案

    private var footerSymbol: String {
        switch phase {
        case .earning, .lunch: return "hourglass"
        case .beforeWork: return "clock"
        case .afterWork: return "checkmark.circle"
        case .restDay: return "moon.zzz"
        }
    }

    private var footerLeading: String {
        switch phase {
        case .earning, .lunch:
            return "距下班 \(model.remainingText)"
        case .beforeWork:
            let start = dateToday(hour: config.startHour, minute: config.startMinute)
            return "距开始 \(MoneyFormat.clock(start.timeIntervalSince(snapshot.now)))"
        case .afterWork:
            return "今天已完成"
        case .restDay:
            return "今天休息"
        }
    }

    private var footerTrailing: String {
        switch phase {
        case .earning, .lunch:
            return snapshot.weekdayLabel
        case .beforeWork:
            return String(format: "%02d:%02d 开始", config.startHour, config.startMinute)
        case .afterWork, .restDay:
            return nextStartText
        }
    }

    /// 「明天 09:00 继续」/「周一 09:00 继续」
    private var nextStartText: String {
        let cal = Calendar.current
        let now = snapshot.now
        let labels = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        for offset in 1...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            if config.workweek.contains(weekday) {
                let prefix = offset == 1 ? "明天" : labels[max(0, min(6, weekday - 1))]
                return String(format: "%@ %02d:%02d 继续", prefix, config.startHour, config.startMinute)
            }
        }
        return "好好休息"
    }

    // MARK: - 金额拆分

    /// 拆成「货币符号 / 整数 / 小数」三层，方便做层次排版。
    private var amountParts: (prefix: String, whole: String, decimals: String) {
        let value = max(0, snapshot.earnedToday)
        let cents = Int((value * 100).rounded())
        let whole = cents / 100
        let fraction = cents % 100

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let wholeText = formatter.string(from: NSNumber(value: whole)) ?? String(whole)

        return (config.displayPrefix, wholeText, String(format: ".%02d", fraction))
    }

    // MARK: - 工具

    private func dateToday(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: snapshot.now) ?? snapshot.now
    }
}

// MARK: - 细进度条

/// 4~6pt 高的圆角细进度条，绿色系渐变。
private struct ThinProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.07))
                Capsule(style: .continuous)
                    .fill(Theme.barGradient)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * clamp(value))))
                    .shadow(color: Theme.green.opacity(0.4), radius: 2.5)
            }
        }
        .animation(.easeOut(duration: 0.3), value: value)
        .accessibilityHidden(true)
    }

    private func clamp(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(1, max(0, v))
    }
}

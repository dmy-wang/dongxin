import SwiftUI
import AppKit

// MARK: - 设置窗口

/// 设置窗口（520 × 660）。
/// 深色分节布局；所有绑定直接写 `model.config.xxx`，
/// AppModel 的 didSet 会负责持久化、刷新与通知。
struct SettingsView: View {
    @ObservedObject var model: AppModel

    @State private var window: NSWindow? = nil
    @State private var launchAtLogin: Bool = AppModel.isLaunchAtLoginEnabled
    @State private var toast: String? = nil
    @State private var toastToken: Int = 0

    private var config: SalaryConfig { model.config }
    /// 展示前缀，跟随 symbolStyle：""（纯数字）/ "·" / 货币符号
    private var prefix: String { config.displayPrefix }

    // MARK: - 主体

    var body: some View {
        ZStack(alignment: .bottom) {
            backdrop
            VStack(spacing: 0) {
                header
                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        salarySection
                        timeSection
                        workweekSection
                        displaySection
                        privacySection
                        previewSection
                        actionSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                footerBar
            }
            toastView
        }
        .frame(width: 520, height: 660)
        .preferredColorScheme(.dark)
        .background(
            WindowProbe { resolved in
                guard let resolved, resolved !== window else { return }
                window = resolved
                resolved.appearance = NSAppearance(named: .darkAqua)
            }
        )
        .onAppear { launchAtLogin = AppModel.isLaunchAtLoginEnabled }
    }

    // MARK: - 背景 / 头尾

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.green.opacity(0.07), .clear],
                           center: .topLeading, startRadius: 2, endRadius: 420)
            RadialGradient(colors: [Theme.cyan.opacity(0.05), .clear],
                           center: .bottomTrailing, startRadius: 2, endRadius: 460)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.hypeGradient)
                    .frame(width: 30, height: 30)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("偏好设置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("修改即时保存并生效")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary.opacity(0.85))
            }
            Spacer(minLength: 8)
            HUDButton(symbol: "xmark", help: "关闭窗口", action: closeWindow)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.012))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.green.opacity(0.8))
            Text("所有修改即时保存，无需确认")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
            Spacer(minLength: 6)
            Text("动薪 v1.0")
                .font(Theme.mono(9.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    // MARK: - 薪资

    private var salarySection: some View {
        SettingsCard(title: "薪资", systemImage: "banknote") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("月薪")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    HStack(spacing: 3) {
                        if !prefix.isEmpty {
                            Text(prefix)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        TextField("", value: salaryBinding,
                                  format: .number.precision(.fractionLength(0)).grouping(.never))
                            .textFieldStyle(.plain)
                            .font(Theme.mono(13, weight: .semibold))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 96)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                VStack(spacing: 3) {
                    Slider(value: salarySliderBinding, in: 3000...200_000, step: 500)
                        .tint(Theme.green)
                    HStack {
                        Text("3,000").font(.system(size: 9)).foregroundStyle(Theme.textSecondary.opacity(0.5))
                        Spacer()
                        Text("200,000").font(.system(size: 9)).foregroundStyle(Theme.textSecondary.opacity(0.5))
                    }
                }

                HStack(spacing: 10) {
                    Text("计薪方式")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    Picker("", selection: $model.config.workdayMode) {
                        Text("手动 21.75").tag(WorkdayMode.manual)
                        Text("当月实际工作日").tag(WorkdayMode.actual)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 218)
                }

                if config.workdayMode == .manual {
                    HStack(spacing: 10) {
                        Text("每月计薪天数")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        Text(daysText(config.manualWorkdays))
                            .font(Theme.mono(12.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 58, alignment: .trailing)
                        Stepper("", value: $model.config.manualWorkdays, in: 1...31, step: 0.25)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.cyan.opacity(0.8))
                        Text("按当月实际工作日自动计算（随月份变化）")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - 时间

    private var timeSection: some View {
        SettingsCard(title: "时间", systemImage: "clock") {
            VStack(spacing: 9) {
                HStack(spacing: 14) {
                    timeField("上班", hour: $model.config.startHour, minute: $model.config.startMinute)
                    timeField("下班", hour: $model.config.endHour, minute: $model.config.endMinute)
                }
                HStack(spacing: 14) {
                    timeField("午休开始", hour: $model.config.lunchStartHour, minute: $model.config.lunchStartMinute)
                    lunchDurationField
                }
                if endBeforeStart {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.amber)
                        Text("下班时间需晚于上班时间")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber)
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        Text("每日有效工时 \(workHoursText)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func timeField(_ label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 46, alignment: .leading)
            HStack(spacing: 1) {
                Picker("", selection: hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 64)

                Text(":")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Picker("", selection: minute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 64)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lunchDurationField: some View {
        HStack(spacing: 5) {
            Text("午休时长")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 46, alignment: .leading)
            Text("\(config.lunchMinutes) 分钟")
                .font(Theme.mono(11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 52, alignment: .trailing)
            Stepper("", value: $model.config.lunchMinutes, in: 0...180, step: 5)
                .labelsHidden()
                .controlSize(.small)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var endBeforeStart: Bool {
        config.endHour * 60 + config.endMinute <= config.startHour * 60 + config.startMinute
    }

    private var workHoursText: String {
        String(format: "%.1f 小时/天", config.dailyWorkSeconds / 3600)
    }

    // MARK: - 工作日

    private var workweekSection: some View {
        SettingsCard(title: "工作日", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    weekdayChip(2, "周一")
                    weekdayChip(3, "周二")
                    weekdayChip(4, "周三")
                    weekdayChip(5, "周四")
                    weekdayChip(6, "周五")
                    weekdayChip(7, "周六")
                    weekdayChip(1, "周日")
                }
                HStack(spacing: 5) {
                    Text("已选 \(config.workweek.count) 天")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.green.opacity(0.85))
                    Text("· 未选中的日期不计薪")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func weekdayChip(_ day: Int, _ label: String) -> some View {
        let isOn = config.workweek.contains(day)
        return Button {
            var next = config.workweek
            if isOn { next.remove(day) } else { next.insert(day) }
            model.config.workweek = next
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? Color.black.opacity(0.82) : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 27)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? Theme.green.opacity(0.9) : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isOn ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: isOn)
    }

    // MARK: - 显示

    private var displaySection: some View {
        SettingsCard(title: "显示", systemImage: "paintbrush") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("显示模式")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    Picker("", selection: $model.config.displayMode) {
                        Text("简洁").tag(DisplayMode.simple)
                        Text("鸡血").tag(DisplayMode.hype)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 170)
                }

                HStack(spacing: 10) {
                    Text("鸡血强度")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Slider(value: $model.config.hypeIntensity, in: 0.5...1.6, step: 0.05)
                        .tint(Theme.amber)
                    Text(String(format: "%.2f×", config.hypeIntensity))
                        .font(Theme.mono(11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, alignment: .trailing)
                }
                .opacity(config.displayMode == .hype ? 1 : 0.5)

                HStack(spacing: 14) {
                    toggleRow("菜单栏显示金额", isOn: $model.config.showMenuBarAmount)
                    toggleRow("启动时显示面板", isOn: $model.config.showPanelOnLaunch)
                }
                HStack(spacing: 14) {
                    toggleRow("显示励志语", isOn: $model.config.motivationalEnabled)
                    toggleRow("音效", isOn: $model.config.soundEnabled)
                }
            }
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 20)
    }

    // MARK: - 隐私

    private var privacySection: some View {
        SettingsCard(title: "隐私", systemImage: "eye.slash") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("数字前缀")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    Picker("", selection: $model.config.symbolStyle) {
                        Text("纯数字").tag(SymbolStyle.none)
                        Text("圆点 ·").tag(SymbolStyle.dot)
                        Text("货币符号").tag(SymbolStyle.currency)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.cyan.opacity(0.8))
                    Text("公开场合建议选「纯数字」，数字不会暴露属性")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    Spacer(minLength: 0)
                }

                if config.symbolStyle == .currency {
                    HStack(spacing: 10) {
                        Text("货币符号")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        TextField("", text: currencyBinding)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(12.5, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 36)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        Text("例如 ¥ 或 $")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary.opacity(0.65))
                    }
                }
            }
        }
    }

    // MARK: - 实时预览

    private var previewSection: some View {
        SettingsCard(title: "实时预览", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 11) {
                HStack(spacing: 8) {
                    metricCell("每秒", MoneyFormat.amount(model.snapshot.perSecond, currency: prefix, decimals: 4))
                    metricCell("每小时", MoneyFormat.amount(model.snapshot.perHour, currency: prefix, decimals: 1))
                    metricCell("每日", MoneyFormat.amount(perDay, currency: prefix, decimals: 0))
                    metricCell("每月", MoneyFormat.amount(config.monthlySalary, currency: prefix, decimals: 0))
                }

                HStack(spacing: 10) {
                    Text(previewStatusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(previewStatusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(previewStatusColor.opacity(0.12)))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(previewStatusColor.opacity(0.22), lineWidth: 1)
                        )
                    Spacer(minLength: 6)
                    Text("距下班 \(model.remainingText)")
                        .font(Theme.mono(11.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("今日进度")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        Spacer(minLength: 4)
                        Text("\(model.progressPercent)%")
                            .font(Theme.mono(10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.green)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.07))
                            Capsule(style: .continuous)
                                .fill(Theme.barGradient)
                                .frame(width: max(0, geo.size.width * clampedProgress))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    private var perDay: Double {
        model.snapshot.perSecond * config.dailyWorkSeconds
    }

    private var clampedProgress: Double {
        let p = model.snapshot.todayProgress
        guard p.isFinite else { return 0 }
        return min(1, max(0, p))
    }

    private var previewStatusLabel: String {
        let s = model.snapshot
        if !s.isWorkday { return "休息日" }
        if s.isLunchBreak { return "午休中" }
        if s.isWithinWorkWindow { return "计时中" }
        return s.remainingWorkSeconds > 0 ? "还没上班" : "已下班"
    }

    private var previewStatusColor: Color {
        let s = model.snapshot
        if !s.isWorkday { return Color(red: 0.70, green: 0.66, blue: 1.0) }
        if s.isLunchBreak { return Theme.amber }
        if s.isWithinWorkWindow { return Theme.green }
        return s.remainingWorkSeconds > 0 ? Theme.cyan : Theme.gold
    }

    private func metricCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
            Text(value)
                .font(Theme.mono(12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 操作

    private var actionSection: some View {
        SettingsCard(title: "操作", systemImage: "gearshape.2") {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    SettingsButton(title: "重置今日进度", symbol: "arrow.counterclockwise", tint: Theme.cyan) {
                        model.resetTodayProgress()
                        showToast("已重置今日进度")
                    }
                    SettingsButton(title: "恢复默认设置", symbol: "arrow.uturn.backward", tint: Theme.amber) {
                        model.config = SalaryConfig()
                        showToast("已恢复默认设置")
                    }
                }

                HStack(spacing: 10) {
                    Text("开机自启")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                    Text("随 macOS 登录自动打开")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    Spacer(minLength: 6)
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                SettingsButton(title: "关闭设置窗口", symbol: "xmark.circle", tint: Color.white.opacity(0.72),
                               action: closeWindow)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                launchAtLogin = enabled
                AppModel.setLaunchAtLogin(enabled)
                showToast(enabled ? "已开启开机自启" : "已关闭开机自启")
            }
        )
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(toast)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.6)))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.green.opacity(0.3), lineWidth: 1))
            .padding(.bottom, 46)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .allowsHitTesting(false)
        }
    }

    private func showToast(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(.easeOut(duration: 0.18)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard token == toastToken else { return }
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }

    // MARK: - 动作 / 工具

    private func closeWindow() {
        if let window {
            window.performClose(nil)
        } else {
            NSApp.keyWindow?.performClose(nil)
        }
    }

    private func daysText(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded - rounded.rounded()) < 0.001 {
            return String(format: "%.0f 天", rounded)
        }
        return String(format: "%.2f 天", rounded)
    }

    // MARK: - 绑定

    private var salaryBinding: Binding<Double> {
        Binding(
            get: { model.config.monthlySalary },
            set: { value in
                guard value.isFinite else { return }
                model.config.monthlySalary = min(200_000, max(3_000, value))
            }
        )
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { model.config.currency },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                model.config.currency = String(trimmed.prefix(2))
            }
        )
    }

    private var salarySliderBinding: Binding<Double> {
        Binding(
            get: { min(200_000, max(3_000, model.config.monthlySalary)) },
            set: { model.config.monthlySalary = $0 }
        )
    }
}

// MARK: - 分节卡片

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.green.opacity(0.8))
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.075), lineWidth: 1)
        )
    }
}

// MARK: - 自绘按钮

private struct SettingsButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = .white
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(tint.opacity(hovering ? 1 : 0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(hovering ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(tint.opacity(hovering ? 0.38 : 0.20), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 窗口探测（拿到 NSWindow 以便设深色外观 / 关闭）

private struct WindowProbe: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}

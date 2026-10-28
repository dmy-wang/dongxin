import Foundation

// MARK: - 配置

enum WorkdayMode: String, Codable, CaseIterable {
    case manual      // 手动指定每月计薪天数（默认 21.75）
    case actual      // 按当月实际工作日计算
}

enum DisplayMode: String, Codable, CaseIterable {
    case simple
    case hype
}

/// 数字前缀风格：公开场合建议用 .none / .dot，避免暴露「这是钱」
enum SymbolStyle: String, Codable, CaseIterable, Identifiable {
    case none      // 纯数字，最隐晦
    case dot       // 前缀一个圆点 ·
    case currency  // 常规货币符号（¥ 等）
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "纯数字（无前缀）"
        case .dot: return "圆点前缀 ·"
        case .currency: return "货币符号"
        }
    }
}

struct SalaryConfig: Codable, Equatable {
    var monthlySalary: Double = 15000
    var workdayMode: WorkdayMode = .manual
    var manualWorkdays: Double = 21.75
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 18
    var endMinute: Int = 0
    var lunchStartHour: Int = 12
    var lunchStartMinute: Int = 0
    var lunchMinutes: Int = 60
    var currency: String = "¥"
    var symbolStyle: SymbolStyle = .none
    var displayMode: DisplayMode = .simple
    var showMenuBarAmount: Bool = true
    var motivationalEnabled: Bool = true
    var hypeIntensity: Double = 1.0   // 0.5 温和 / 1.0 标准 / 1.6 狂暴
    var soundEnabled: Bool = false
    var showPanelOnLaunch: Bool = true
    /// 界面缩放倍数（0.7–2.0），支持 ⌘+/⌘-/⌘0、触控板捏合、右下角拖拽
    var zoom: Double = 1.0
    /// Calendar weekday: 1=周日 ... 7=周六
    var workweek: Set<Int> = [2, 3, 4, 5, 6]

    /// 实际用于展示的前缀（"" = 纯数字）
    var displayPrefix: String {
        switch symbolStyle {
        case .none: return ""
        case .dot: return "·"
        case .currency: return currency
        }
    }

    var startDateComponents: DateComponents { DateComponents(hour: startHour, minute: startMinute) }
    var endDateComponents: DateComponents { DateComponents(hour: endHour, minute: endMinute) }
    var lunchStartComponents: DateComponents { DateComponents(hour: lunchStartHour, minute: lunchStartMinute) }
    var clampedZoom: Double { min(2.0, max(0.7, zoom)) }

    var dailyWorkSeconds: Double {
        let total = TimeInterval((endHour * 60 + endMinute) - (startHour * 60 + startMinute)) * 60
        return max(60, total - Double(lunchMinutes) * 60)
    }
}

// MARK: - 兼容解码（旧版本配置缺字段时用默认值，避免整份配置被重置）

extension SalaryConfig {
    enum CodingKeys: String, CodingKey {
        case monthlySalary, workdayMode, manualWorkdays
        case startHour, startMinute, endHour, endMinute
        case lunchStartHour, lunchStartMinute, lunchMinutes
        case currency, symbolStyle, displayMode
        case showMenuBarAmount, motivationalEnabled, hypeIntensity, soundEnabled
        case showPanelOnLaunch, zoom, workweek
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SalaryConfig()
        self.init()
        monthlySalary = try c.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? d.monthlySalary
        workdayMode = try c.decodeIfPresent(WorkdayMode.self, forKey: .workdayMode) ?? d.workdayMode
        manualWorkdays = try c.decodeIfPresent(Double.self, forKey: .manualWorkdays) ?? d.manualWorkdays
        startHour = try c.decodeIfPresent(Int.self, forKey: .startHour) ?? d.startHour
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute) ?? d.startMinute
        endHour = try c.decodeIfPresent(Int.self, forKey: .endHour) ?? d.endHour
        endMinute = try c.decodeIfPresent(Int.self, forKey: .endMinute) ?? d.endMinute
        lunchStartHour = try c.decodeIfPresent(Int.self, forKey: .lunchStartHour) ?? d.lunchStartHour
        lunchStartMinute = try c.decodeIfPresent(Int.self, forKey: .lunchStartMinute) ?? d.lunchStartMinute
        lunchMinutes = try c.decodeIfPresent(Int.self, forKey: .lunchMinutes) ?? d.lunchMinutes
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? d.currency
        symbolStyle = try c.decodeIfPresent(SymbolStyle.self, forKey: .symbolStyle) ?? d.symbolStyle
        displayMode = try c.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? d.displayMode
        showMenuBarAmount = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarAmount) ?? d.showMenuBarAmount
        motivationalEnabled = try c.decodeIfPresent(Bool.self, forKey: .motivationalEnabled) ?? d.motivationalEnabled
        hypeIntensity = try c.decodeIfPresent(Double.self, forKey: .hypeIntensity) ?? d.hypeIntensity
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        showPanelOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .showPanelOnLaunch) ?? d.showPanelOnLaunch
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? d.zoom
        workweek = try c.decodeIfPresent(Set<Int>.self, forKey: .workweek) ?? d.workweek
    }
}

// MARK: - 快照

struct SalarySnapshot: Equatable {
    var now: Date = Date()
    var perSecond: Double = 0
    var perMinute: Double = 0
    var perHour: Double = 0
    var earnedToday: Double = 0
    var earnedBeforeNow: Double = 0
    var workedSecondsToday: Double = 0
    var remainingWorkSeconds: Double = 0
    var todayProgress: Double = 0
    var isWorkday: Bool = true
    var isWithinWorkWindow: Bool = false
    var isLunchBreak: Bool = false
    var millisecondsToNextSecond: Int = 0
    var milestoneValue: Double = 0        // 下一个整 ¥10 里程碑
    var milestoneProgress: Double = 0     // 0..1
    var weekdayLabel: String = ""
    var statusText: String = ""
    var nextWorkdayStart: Date? = nil
}

// MARK: - 引擎（纯逻辑，可单测）

struct SalaryEngine {
    var config: SalaryConfig
    var calendar: Calendar

    init(config: SalaryConfig, calendar: Calendar = .current) {
        self.config = config
        var c = calendar
        c.firstWeekday = 1
        self.calendar = c
    }

    var workdaysPerMonth: Double {
        switch config.workdayMode {
        case .manual:
            return max(1, config.manualWorkdays)
        case .actual:
            let now = Date()
            let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<31
            var count = 0
            for day in range {
                if let d = calendar.date(from: DateComponents(year: calendar.component(.year, from: now),
                                                              month: calendar.component(.month, from: now),
                                                              day: day)),
                   config.workweek.contains(calendar.component(.weekday, from: d)) {
                    count += 1
                }
            }
            return Double(max(1, count))
        }
    }

    var perSecond: Double {
        max(0, config.monthlySalary) / (workdaysPerMonth * config.dailyWorkSeconds)
    }

    func dateOnToday(hour: Int, minute: Int, base: Date = Date()) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    func snapshot(at date: Date = Date()) -> SalarySnapshot {
        var s = SalarySnapshot()
        s.now = date
        s.perSecond = perSecond
        s.perMinute = perSecond * 60
        s.perHour = perSecond * 3600

        let weekday = calendar.component(.weekday, from: date)
        s.isWorkday = config.workweek.contains(weekday)
        s.weekdayLabel = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][max(0, min(6, weekday - 1))]

        let start = dateOnToday(hour: config.startHour, minute: config.startMinute, base: date)
        let end = dateOnToday(hour: config.endHour, minute: config.endMinute, base: date)
        let lunchStart = dateOnToday(hour: config.lunchStartHour, minute: config.lunchStartMinute, base: date)
        let lunchEnd = lunchStart.addingTimeInterval(Double(config.lunchMinutes) * 60)

        s.isWithinWorkWindow = date >= start && date < end
        s.isLunchBreak = s.isWithinWorkWindow && date >= lunchStart && date < lunchEnd

        var worked: Double = 0
        if s.isWorkday && date > start {
            let cursor = min(date, end)
            worked = cursor.timeIntervalSince(start)
            if cursor > lunchStart {
                worked -= min(cursor, lunchEnd).timeIntervalSince(lunchStart)
            }
            worked = max(0, min(worked, config.dailyWorkSeconds))
        }
        if !s.isWorkday { worked = 0 }
        s.workedSecondsToday = worked
        s.earnedToday = perSecond * worked

        var remaining: Double = 0
        if s.isWorkday && date < end {
            remaining = end.timeIntervalSince(max(date, start))
            if date < lunchStart { remaining -= Double(config.lunchMinutes) * 60 }
            else if date < lunchEnd { remaining -= lunchEnd.timeIntervalSince(date) }
        }
        s.remainingWorkSeconds = max(0, min(remaining, config.dailyWorkSeconds))
        s.todayProgress = config.dailyWorkSeconds > 0 ? min(1, worked / config.dailyWorkSeconds) : 0

        let step: Double = 10
        s.milestoneValue = floor(s.earnedToday / step) * step + step
        s.milestoneProgress = (s.earnedToday - (s.milestoneValue - step)) / step

        if !s.isWorkday {
            s.statusText = "今天休息 · 不用上班"
            // 找下一个工作日
            for offset in 1...7 {
                if let d = calendar.date(byAdding: .day, value: offset, to: date),
                   config.workweek.contains(calendar.component(.weekday, from: d)) {
                    s.nextWorkdayStart = dateOnToday(hour: config.startHour, minute: config.startMinute, base: d)
                    break
                }
            }
        } else if date < start {
            s.statusText = "还没上班 · 距开薪还有"
        } else if date >= end {
            s.statusText = "今日已下班 · 明天继续"
        } else if s.isLunchBreak {
            s.statusText = "午休中 · 摸鱼不算钱"
        } else {
            s.statusText = "正在赚钱"
        }
        return s
    }
}

// MARK: - 格式化

enum MoneyFormat {
    static func amount(_ value: Double, currency: String, decimals: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.groupingSeparator = ","
        let num = f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return currency + num
    }

    static func compact(_ value: Double, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return currency + (f.string(from: NSNumber(value: value.rounded())) ?? "0")
    }

    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static func shortClock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

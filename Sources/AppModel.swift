import Foundation
import SwiftUI

// MARK: - 持久化

enum Store {
    private static let key = "xintiao.config.v1"
    static func load() -> SalaryConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cfg = try? JSONDecoder().decode(SalaryConfig.self, from: data) else {
            return SalaryConfig()
        }
        return cfg
    }
    static func save(_ cfg: SalaryConfig) {
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 全局模型

@MainActor
final class AppModel: ObservableObject {
    @Published var config: SalaryConfig {
        didSet {
            if oldValue != config {
                engine = SalaryEngine(config: config)
                Store.save(config)
                refresh()
                onConfigChanged?()
            }
        }
    }
    @Published private(set) var snapshot: SalarySnapshot
    /// 每 0.1s 自增，视图用它驱动动画
    @Published private(set) var tick: Int = 0
    /// 每跨过 1 元自增一次（鸡血模式用来触发脉冲）
    @Published private(set) var coinPulse: Int = 0
    /// 每跨过 10 元自增一次（里程碑横幅）
    @Published private(set) var milestoneCount: Int = 0
    /// 累计连击（连续有收入的 tick 数，用于鸡血模式）
    @Published private(set) var combo: Int = 0

    var onConfigChanged: (() -> Void)?

    private var engine: SalaryEngine
    private var lastYuan: Int = 0
    private var lastMilestone: Int = 0

    init() {
        let cfg = Store.load()
        self.config = cfg
        self.engine = SalaryEngine(config: cfg)
        self.snapshot = engine.snapshot()
        self.lastYuan = Int(snapshot.earnedToday)
        self.lastMilestone = Int(snapshot.earnedToday / 10)
    }

    func refresh() {
        let s = engine.snapshot()
        let yuan = Int(s.earnedToday)
        if s.isWithinWorkWindow && !s.isLunchBreak {
            combo = min(combo + 1, 9999)
        } else {
            combo = 0
        }
        if yuan > lastYuan {
            coinPulse &+= 1
            lastYuan = yuan
        } else if yuan < lastYuan {
            lastYuan = yuan
        }
        let ms = Int(s.earnedToday / 10)
        if ms > lastMilestone {
            milestoneCount &+= ms - lastMilestone
            lastMilestone = ms
        } else if ms < lastMilestone {
            lastMilestone = ms
        }
        snapshot = s
        tick &+= 1
    }

    func resetTodayProgress() {
        lastYuan = 0
        lastMilestone = 0
        combo = 0
        refresh()
    }

    var perSecondText: String {
        String(format: "%.4f", snapshot.perSecond)
    }
    var amountText: String { MoneyFormat.amount(snapshot.earnedToday, currency: config.displayPrefix) }
    var hourlyText: String { MoneyFormat.amount(snapshot.perHour, currency: config.displayPrefix, decimals: 0) + "/时" }
    var remainingText: String { MoneyFormat.clock(snapshot.remainingWorkSeconds) }
    var progressPercent: Int { Int((snapshot.todayProgress * 100).rounded()) }

    // MARK: 开机自启（LaunchAgent）

    static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.xintiao.salarypulse.plist")
    }

    static var isLaunchAtLoginEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        let fm = FileManager.default
        let url = launchAgentURL
        if enabled {
            let exec = Bundle.main.executablePath ?? CommandLine.arguments[0]
            let plist: [String: Any] = [
                "Label": "com.xintiao.salarypulse",
                "ProgramArguments": [exec],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: url)
            }
        } else {
            try? fm.removeItem(at: url)
        }
    }
}

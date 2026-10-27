import Foundation

enum SelfTest {
    static func run() -> Int32 {
        var ok = 0, fail = 0
        func check(_ name: String, _ cond: Bool) {
            if cond { ok += 1 } else { fail += 1; print("❌ \(name)") }
        }
        var cfg = SalaryConfig()
        cfg.monthlySalary = 21750
        cfg.manualWorkdays = 21.75
        cfg.startHour = 9; cfg.endHour = 18; cfg.lunchMinutes = 60
        let eng = SalaryEngine(config: cfg)
        // 日工作 8h = 28800s；每秒 = 21750 / (21.75 * 28800) = 1/28.8 ≈ 0.034722
        check("perSecond", abs(eng.perSecond - 1.0 / 28.8) < 1e-9)
        check("perHour", abs(eng.perSecond * 3600 - 125.0) < 1e-6)
        check("dailySeconds", abs(cfg.dailyWorkSeconds - 28800) < 1e-6)

        let cal = Calendar.current
        func at(_ day: Int, _ h: Int, _ m: Int, _ s: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m, second: s))!
        }
        // 2026-10-27 是周二（工作日）
        let morning = eng.snapshot(at: at(27, 9, 0))
        check("morning.earned == 0", abs(morning.earnedToday) < 1e-9)
        check("morning.remaining ≈ 8h", abs(morning.remainingWorkSeconds - 28800) < 1)

        let noon = eng.snapshot(at: at(27, 12, 0))
        check("noon worked 3h", abs(noon.workedSecondsToday - 10800) < 1)
        check("noon lunch", noon.isLunchBreak)

        let lunchEnd = eng.snapshot(at: at(27, 13, 0))
        check("lunchEnd worked 3h", abs(lunchEnd.workedSecondsToday - 10800) < 1)
        check("lunchEnd not lunch", !lunchEnd.isLunchBreak)

        let afternoon = eng.snapshot(at: at(27, 15, 0))
        check("15:00 worked 5h", abs(afternoon.workedSecondsToday - 18000) < 1)
        check("15:00 remaining 3h", abs(afternoon.remainingWorkSeconds - 10800) < 1)

        let evening = eng.snapshot(at: at(27, 19, 0))
        check("evening full day", abs(evening.workedSecondsToday - 28800) < 1)
        check("evening remaining 0", evening.remainingWorkSeconds == 0)
        check("evening progress 1", abs(evening.todayProgress - 1) < 1e-9)

        // 周末（2026-10-31 周六）
        let weekend = eng.snapshot(at: at(31, 12, 0))
        check("weekend not workday", !weekend.isWorkday)
        check("weekend earned 0", weekend.earnedToday == 0)
        check("weekend next workday exists", weekend.nextWorkdayStart != nil)

        // 格式化
        check("clock", MoneyFormat.clock(3661) == "01:01:01")
        check("amount", MoneyFormat.amount(1234.5, currency: "¥") == "¥1,234.50")
        check("shortClock", MoneyFormat.shortClock(7200) == "2h 0m")
        // 隐私前缀：默认纯数字，不出现货币符号
        var pcfg = SalaryConfig()
        check("default prefix empty", pcfg.displayPrefix == "")
        pcfg.symbolStyle = .dot
        check("dot prefix", pcfg.displayPrefix == "·")
        pcfg.symbolStyle = .currency
        check("currency prefix", pcfg.displayPrefix == "¥")
        check("no symbol amount", !MoneyFormat.amount(12.3, currency: "").contains("¥"))

        // 实际工作日模式
        var cfg2 = cfg; cfg2.workdayMode = .actual
        let eng2 = SalaryEngine(config: cfg2)
        check("actual workdays range", eng2.workdaysPerMonth >= 18 && eng2.workdaysPerMonth <= 23)

        print("SELFTEST ok=\(ok) fail=\(fail)")
        return fail == 0 ? 0 : 1
    }
}

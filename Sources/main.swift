import AppKit
import SwiftUI

// MARK: - 应用入口

@main
struct XinTiaoMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run())
        }
        if let i = CommandLine.arguments.firstIndex(of: "--render"),
           CommandLine.arguments.count > i + 2 {
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
            let mode = CommandLine.arguments[i + 1]
            let out = CommandLine.arguments[i + 2]
            var salary: Double? = nil
            if CommandLine.arguments.count > i + 3 { salary = Double(CommandLine.arguments[i + 3]) }
            exit(mode == "settings" ? WindowRenderer.run(mode: mode, out: out, salary: salary)
                                    : Renderer.run(mode: mode, out: out))
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppDelegate.shared = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?
    var model: AppModel!
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var settingsWindow: NSWindow?
    var timer: Timer?
    private var lastTitle: String = ""
    private var lastMode: DisplayMode = .simple
    private let originKey = "xintiao.panelOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        model.onConfigChanged = { [weak self] in self?.applyConfig() }
        setupStatusItem()
        setupPanel()
        startTimer()
        if model.config.showPanelOnLaunch { showPanel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    // MARK: 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.title = ""
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusTitle(force: true)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func updateStatusTitle(force: Bool = false) {
        guard let button = statusItem.button else { return }
        guard model.config.showMenuBarAmount else {
            if force || !lastTitle.isEmpty {
                button.attributedTitle = NSAttributedString(string: "•", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: NSColor.secondaryLabelColor])
                lastTitle = ""
            }
            return
        }
        let text = MoneyFormat.amount(model.snapshot.earnedToday, currency: model.config.displayPrefix, decimals: 2)
        guard force || text != lastTitle else { return }
        lastTitle = text
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ])
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: panel.isVisible ? "隐藏面板" : "显示面板",
                     action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        for mode in [DisplayMode.simple, DisplayMode.hype] {
            let item = NSMenuItem(title: mode == .simple ? "简洁模式" : "鸡血模式",
                                  action: #selector(setSimpleMode), keyEquivalent: "")
            item.target = self
            item.tag = mode == .simple ? 0 : 1
            item.state = model.config.displayMode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "重置今日进度", action: #selector(resetToday), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let zi = NSMenuItem(title: "放大", action: #selector(zoomIn), keyEquivalent: "+")
        zi.target = self; zi.keyEquivalentModifierMask = [.command]
        menu.addItem(zi)
        let zo = NSMenuItem(title: "缩小", action: #selector(zoomOut), keyEquivalent: "-")
        zo.target = self; zo.keyEquivalentModifierMask = [.command]
        menu.addItem(zo)
        let zr = NSMenuItem(title: "实际大小", action: #selector(zoomReset), keyEquivalent: "0")
        zr.target = self; zr.keyEquivalentModifierMask = [.command]
        menu.addItem(zr)
        let launch = NSMenuItem(title: "开机自启", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = AppModel.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 动薪", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func setSimpleMode(_ sender: NSMenuItem) {
        model.config.displayMode = sender.tag == 0 ? .simple : .hype
    }
    @objc private func resetToday() { model.resetTodayProgress() }
    @objc private func zoomIn() { zoom(by: 0.1) }
    @objc private func zoomOut() { zoom(by: -0.1) }
    @objc private func zoomReset() { setZoom(1.0) }
    @objc private func toggleLaunchAtLogin() {
        AppModel.setLaunchAtLogin(!AppModel.isLaunchAtLoginEnabled)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: 浮窗

    private func setupPanel() {
        let size = panelSize(for: model.config.displayMode)
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.isReleasedWhenClosed = false

        let root = RootView(model: model,
                            onSettings: { [weak self] in self?.openSettings() },
                            onHide: { [weak self] in self?.hidePanel() },
                            onToggleMode: { [weak self] in self?.toggleMode() },
                            onZoom: { [weak self] delta in self?.zoom(by: delta) },
                            onZoomTo: { [weak self] value in self?.setZoom(value) })
        panel.contentView = NSHostingView(rootView: root)
        lastMode = model.config.displayMode

        if let saved = UserDefaults.standard.string(forKey: originKey) {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                panel.setFrameOrigin(NSPoint(x: parts[0], y: parts[1]))
                return
            }
        }
        positionDefault()
    }

    private func panelSize(for mode: DisplayMode) -> NSSize {
        let z = model?.config.clampedZoom ?? 1.0
        let base = mode == .simple ? NSSize(width: 348, height: 208) : NSSize(width: 448, height: 322)
        return NSSize(width: (base.width * z).rounded(), height: (base.height * z).rounded())
    }

    private func positionDefault() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panelSize(for: model.config.displayMode)
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 36,
                                     y: visible.maxY - size.height - 12))
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = panel.frame.origin as CGPoint? else { return }
        UserDefaults.standard.set("\(Double(origin.x)),\(Double(origin.y))", forKey: originKey)
    }

    @objc func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }
    func showPanel() {
        panel.orderFrontRegardless()
    }
    func hidePanel() {
        panel.orderOut(nil)
    }
    @objc func toggleMode() {
        model.config.displayMode = model.config.displayMode == .simple ? .hype : .simple
    }

    func zoom(by delta: CGFloat) {
        let base = model.config.clampedZoom
        setZoom(base + Double(delta))
    }

    func setZoom(_ value: Double) {
        model.config.zoom = min(2.0, max(0.7, value))
    }

    private func applyConfig() {
        let target = panelSize(for: model.config.displayMode)
        if panel.frame.size != target || lastMode != model.config.displayMode {
            var frame = panel.frame
            let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
            frame.size = target
            panel.setFrame(frame, display: true, animate: false)
            panel.setFrameOrigin(NSPoint(x: topLeft.x, y: topLeft.y - target.height))
            lastMode = model.config.displayMode
        }
        updateStatusTitle(force: true)
    }

    // MARK: 计时

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.refresh()
                self.updateStatusTitle()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    // MARK: 设置窗口

    @objc func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 660),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = "动薪 · 设置"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: SettingsView(model: model))
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }
}

// MARK: - 根视图

struct RootView: View {
    @ObservedObject var model: AppModel
    var onSettings: () -> Void
    var onHide: () -> Void
    var onToggleMode: () -> Void
    var onZoom: (CGFloat) -> Void
    var onZoomTo: (Double) -> Void

    @State private var hovering = false
    @State private var pinchBase: Double? = nil
    @State private var dragBase: Double? = nil

    private var isHype: Bool { model.config.displayMode == .hype }
    private var baseSize: CGSize { isHype ? CGSize(width: 448, height: 322) : CGSize(width: 348, height: 208) }
    private var zoom: Double { model.config.clampedZoom }

    var body: some View {
        content
            .frame(width: baseSize.width, height: baseSize.height)
            .scaleEffect(zoom, anchor: .topLeading)
            .frame(width: baseSize.width * zoom, height: baseSize.height * zoom, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) { resizeHandle }
            .gesture(pinchGesture)
            .onHover { hovering = $0 }
            .animation(.easeInOut(duration: 0.16), value: hovering)
            .animation(.easeOut(duration: 0.12), value: zoom)
    }

    private var content: some View {
        ZStack(alignment: .topLeading) {
            PanelBackground(hype: isHype)
            VStack(spacing: 0) {
                header
                Group {
                    if isHype {
                        HypeView(model: model)
                    } else {
                        SimpleView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: baseSize.width, height: baseSize.height)
    }

    /// 触控板双指捏合缩放
    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if pinchBase == nil { pinchBase = zoom }
                onZoomTo((pinchBase ?? 1) * value.magnification)
            }
            .onEnded { _ in pinchBase = nil }
    }

    /// 右下角拖拽缩放（拖出 1px ≈ 0.16%）；双击恢复 100%
    private var resizeHandle: some View {
        Circle()
            .fill(Color.white.opacity(hovering ? 0.22 : 0.001))
            .frame(width: 11, height: 11)
            .padding(5)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.crosshair.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragBase == nil { dragBase = zoom }
                        let d = Double(value.translation.width + value.translation.height) / 620.0
                        onZoomTo((dragBase ?? 1) + d)
                    }
                    .onEnded { _ in dragBase = nil }
            )
            .onTapGesture(count: 2) { onZoomTo(1.0) }
            .help("拖拽缩放，双击恢复 100%")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(isHype ? "鸡血模式" : "简洁模式")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            HUDButton(symbol: isHype ? "bolt.fill" : "bolt.slash.fill",
                      help: "切换模式", action: onToggleMode)
            HUDButton(symbol: "slider.horizontal.3", help: "设置", action: onSettings)
            HUDButton(symbol: "xmark", help: "隐藏面板", action: onHide)
        }
        .opacity(hovering ? 1 : 0)
        .frame(height: 22)
    }
}

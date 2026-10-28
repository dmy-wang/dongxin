import Foundation
import SwiftUI
import AppKit

/// 离屏渲染：--render simple|hype <out.png>
/// 用于开发期在无屏幕权限的环境下检查布局。
@MainActor
enum Renderer {
    static func run(mode: String, out: String) -> Int32 {
        Store.isEphemeral = true
        let model = AppModel()
        if let idx = CommandLine.arguments.firstIndex(of: "--render") {
            if CommandLine.arguments.count > idx + 3, let salary = Double(CommandLine.arguments[idx + 3]) {
                model.config.monthlySalary = salary
            }
            if CommandLine.arguments.count > idx + 4, let z = Double(CommandLine.arguments[idx + 4]) {
                model.config.zoom = min(2.0, max(0.7, z))
            }
        }
        let zoom = model.config.clampedZoom
        model.refresh()
        let isHype = (mode == "hype")
        let isSettings = (mode == "settings")
        let w: CGFloat = isSettings ? 520 : (isHype ? 448 : 348)
        let h: CGFloat = isSettings ? 660 : (isHype ? 322 : 208)

        let content: AnyView
        if isSettings {
            content = AnyView(SettingsView(model: model).frame(width: w, height: h))
        } else {
            content = AnyView(
                ZStack(alignment: .topLeading) {
                    PanelBackground(hype: isHype)
                    VStack(spacing: 0) {
                        if isHype { HypeView(model: model) } else { SimpleView(model: model) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
                .frame(width: w, height: h)
            )
        }

        let rendered = content
            .scaleEffect(zoom, anchor: .topLeading)
            .frame(width: w * zoom, height: h * zoom, alignment: .topLeading)
        let renderer = ImageRenderer(content: rendered)
        renderer.scale = 2
        guard let cg = renderer.cgImage else {
            FileHandle.standardError.write("render failed\n".data(using: .utf8)!)
            return 2
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return 3 }
        do {
            try data.write(to: URL(fileURLWithPath: out))
            print("rendered \(mode) \(Int(w))x\(Int(h)) -> \(out)")
            return 0
        } catch {
            FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
            return 4
        }
    }
}


/// 用真实 AppKit 视图层级渲染（能正确渲染 ScrollView 等懒加载容器）
@MainActor
enum WindowRenderer {
    static func run(mode: String, out: String, salary: Double?) -> Int32 {
        Store.isEphemeral = true
        let model = AppModel()
        if let salary { model.config.monthlySalary = salary }
        model.refresh()
        let isHype = (mode == "hype")
        let isSettings = (mode == "settings")
        let zoom = model.config.clampedZoom
        let base = isSettings ? NSSize(width: 520, height: 660)
                              : (isHype ? NSSize(width: 448, height: 322) : NSSize(width: 348, height: 208))
        let size = NSSize(width: (base.width * zoom).rounded(), height: (base.height * zoom).rounded())

        let root: AnyView
        if isSettings {
            root = AnyView(SettingsView(model: model))
        } else if isHype {
            root = AnyView(ZStack(alignment: .topLeading) {
                PanelBackground(hype: true)
                HypeView(model: model).padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
            })
        } else {
            root = AnyView(ZStack(alignment: .topLeading) {
                PanelBackground(hype: false)
                SimpleView(model: model).padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
            })
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            FileHandle.standardError.write("bitmap rep failed\n".data(using: .utf8)!)
            return 2
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return 3 }
        do {
            try data.write(to: URL(fileURLWithPath: out))
            print("window-rendered \(mode) -> \(out)")
            return 0
        } catch { return 4 }
    }
}

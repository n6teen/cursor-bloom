import AppKit
import SwiftUI

@main
struct CursorBloomApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
                .onAppear {
                    PreviewWindow.present(store: store)
                    RenderShot.capture(store: store)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

enum PreviewWindow {
    private static var window: NSWindow?

    static func present(store: UsageStore) {
        guard CommandLine.arguments.contains("--preview"), window == nil else { return }
        let host = NSHostingController(rootView: PopoverView(store: store))
        let window = NSWindow(contentViewController: host)
        window.title = "Bloom"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        host.view.layoutSubtreeIfNeeded()
        let fitted = host.view.fittingSize
        window.setContentSize(NSSize(width: max(fitted.width, 384), height: max(fitted.height, 420)))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

enum RenderShot {
    @MainActor
    static func capture(store: UsageStore) {
        guard CommandLine.arguments.contains("--render") else { return }
        Task { @MainActor in
            for _ in 0..<25 {
                if store.snapshot != nil, store.isRefreshing == false { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            let view = PopoverView(store: store)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.isOpaque = false
            let url = URL(fileURLWithPath: "/Users/n6teen/cursor-bloom/preview.png")
            if let image = renderer.nsImage,
               let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
            NSApp.terminate(nil)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        CowboyDog(menuBar: true)
        .accessibilityLabel("Cursor usage \(store.menuText)")
    }
}

import AppKit
import SwiftUI

enum XP {
    static let desktop = Color(red: 0, green: 0, blue: 128 / 255)
    static let face = Color(red: 192 / 255, green: 192 / 255, blue: 192 / 255)
    static let title = Color(red: 180 / 255, green: 182 / 255, blue: 187 / 255)
    static let titleBottom = Color(red: 160 / 255, green: 162 / 255, blue: 168 / 255)
    static let highlight = Color.white
    static let shadow = Color(red: 128 / 255, green: 128 / 255, blue: 128 / 255)
    static let dark = Color.black
    static let field = Color.white
    static let bar = Color(red: 0, green: 0, blue: 128 / 255)

    static func font(_ size: CGFloat) -> Font {
        .custom("Tahoma", size: size)
    }
}

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var openMenu: XPMenu?

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            menuBar
            VStack(alignment: .leading, spacing: 8) {
                if let snapshot = store.snapshot {
                    artRow(snapshot)
                    alertBanner(snapshot.alert)
                    meterBlock(snapshot)
                    tokenBlock(snapshot)
                } else {
                    emptyState
                }
                buttonRow
                loginRow
            }
            .padding(8)
            statusBar
        }
        .background(XP.face)
        .overlay(ClassicEdge(sunk: false))
        .padding(8)
        .background(XP.desktop)
        .frame(width: 384)
        .background(WindowChrome())
        .onAppear {
            Task { await store.refresh() }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 4) {
            CowboyDog(menuBar: true)
                .frame(width: 14, height: 14)
                .clipped()
                .overlay(ClassicEdge(sunk: true))
            Text("Bloom")
                .font(XP.font(12))
                .foregroundStyle(.black)
            Spacer(minLength: 4)
            captionButton("–") {}
            captionButton("□") {}
            captionButton("×") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            LinearGradient(colors: [XP.title, XP.titleBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(XP.shadow).frame(height: 1)
        }
    }

    private func captionButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(XP.font(11))
                .foregroundStyle(.black)
                .frame(width: 16, height: 14)
        }
        .buttonStyle(XPButtonStyle(horizontal: 0, vertical: 0))
    }

    private var menuBar: some View {
        HStack(spacing: 0) {
            menuTitle(.file, "File")
            menuTitle(.view, "View")
            menuTitle(.help, "Help")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .background(XP.face)
        .overlay(alignment: .topLeading) {
            if let openMenu {
                menuPopup(openMenu)
                    .offset(x: openMenu.origin, y: 20)
                    .zIndex(4)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(XP.shadow).frame(height: 1)
        }
        .zIndex(openMenu == nil ? 0 : 4)
    }

    private func menuTitle(_ menu: XPMenu, _ title: String) -> some View {
        Button {
            openMenu = openMenu == menu ? nil : menu
        } label: {
            Text(title)
                .font(XP.font(12))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(openMenu == menu ? XP.face : Color.clear)
                .overlay {
                    if openMenu == menu {
                        ClassicEdge(sunk: true)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func menuPopup(_ menu: XPMenu) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(menu.items) { item in
                Button {
                    openMenu = nil
                    item.action(self)
                } label: {
                    Text(item.title)
                        .font(XP.font(11))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(XPMenuItemStyle())
            }
        }
        .padding(2)
        .frame(width: 132)
        .background(XP.face)
        .overlay(ClassicEdge(sunk: false))
        .background(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .offset(x: 3, y: 3)
        }
    }

    private func alertBanner(_ alert: UsageAlert) -> some View {
        HStack(alignment: .center, spacing: 8) {
            AlertGlyph(alert: alert)
                .frame(width: 18, height: 18)
            Text(alert.title)
                .font(XP.font(12))
                .foregroundStyle(.black)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alertFill(alert))
        .overlay(ClassicEdge(sunk: true))
    }

    private func alertFill(_ alert: UsageAlert) -> Color {
        switch alert.tone {
        case .info:
            return XP.field
        case .caution:
            return Color(red: 1, green: 0.98, blue: 0.9)
        case .warning:
            return Color(red: 1, green: 1, blue: 0.82)
        case .critical:
            return Color(red: 1, green: 0.86, blue: 0.86)
        }
    }

    private func artRow(_ snapshot: UsageSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            CowboyDog()
                .frame(width: 108, height: 108)
                .overlay(ClassicEdge(sunk: true))
            VStack(spacing: 4) {
                labeledField("Used", UsageSnapshot.formatPercent(snapshot.totalPercent))
                labeledField("Left", UsageSnapshot.formatPercent(snapshot.remainingPercent))
                labeledField("Plan", planText(snapshot))
                labeledField("Account", snapshot.accountLabel ?? "Cursor")
            }
        }
    }

    private func planText(_ snapshot: UsageSnapshot) -> String {
        if let price = snapshot.price, price.isEmpty == false {
            return "\(snapshot.planName) · \(price)"
        }
        return snapshot.planName
    }

    private func labeledField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(XP.font(11))
                .foregroundStyle(.black)
            Text(value)
                .font(XP.font(11))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(XP.field)
                .overlay(ClassicEdge(sunk: true))
        }
    }

    private func meterBlock(_ snapshot: UsageSnapshot) -> some View {
        VStack(spacing: 4) {
            chunkBar("Cursor model", snapshot.autoPercent)
            chunkBar("other model", snapshot.apiPercent)
            chunkBar("Elapsed", snapshot.cycleFraction * 100)
        }
    }

    private func chunkBar(_ title: String, _ percent: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(XP.font(11))
                .foregroundStyle(.black)
                .frame(width: 96, alignment: .leading)
                .lineLimit(1)
            ClassicChunks(percent: percent)
            Text(UsageSnapshot.formatPercent(percent))
                .font(XP.font(11))
                .foregroundStyle(.black)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func tokenBlock(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 6) {
            tokenCell("Input", UsageSnapshot.formatTokens(snapshot.inputTokens))
            tokenCell("Output", UsageSnapshot.formatTokens(snapshot.outputTokens))
            tokenCell("Cache", UsageSnapshot.formatTokens(snapshot.cacheTokens))
        }
    }

    private func tokenCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(XP.font(11))
                .foregroundStyle(.black)
            Text(value)
                .font(XP.font(11))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(XP.field)
                .overlay(ClassicEdge(sunk: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 8) {
            CowboyDog()
                .frame(width: 72, height: 72)
                .overlay(ClassicEdge(sunk: true))
            Text(emptyMessage)
                .font(XP.font(12))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)
                .background(XP.field)
                .overlay(ClassicEdge(sunk: true))
        }
        .frame(minHeight: 72)
    }

    private var emptyMessage: String {
        if case .failed(let text) = store.phase {
            return text
        }
        return "Checking this cycle…"
    }

    private var buttonRow: some View {
        HStack(spacing: 6) {
            Button(store.isRefreshing ? "Loading" : "Refresh") {
                Task { await store.refresh() }
            }
            .buttonStyle(XPButtonStyle())
            .disabled(store.isRefreshing)
            Button("Dashboard") { openDashboard() }
                .buttonStyle(XPButtonStyle())
            Spacer(minLength: 0)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(XPButtonStyle())
        }
    }

    private var loginRow: some View {
        Button {
            store.setLaunchAtLogin(!store.launchesAtLogin)
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Rectangle().fill(XP.field)
                    if store.launchesAtLogin {
                        Text("✓")
                            .font(XP.font(10))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 13, height: 13)
                .overlay(ClassicEdge(sunk: true))
                Text("Open at login")
                    .font(XP.font(11))
                    .foregroundStyle(.black)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusBar: some View {
        HStack(spacing: 4) {
            statusCell(updatedLine, align: .leading)
            statusCell(store.snapshot?.resetLine ?? "Bloom", align: .trailing)
                .frame(maxWidth: 196)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(XP.face)
        .overlay(alignment: .top) {
            Rectangle().fill(XP.highlight).frame(height: 1)
        }
    }

    private func statusCell(_ text: String, align: Alignment) -> some View {
        Text(text)
            .font(XP.font(11))
            .foregroundStyle(.black)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: align)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(XP.face)
            .overlay(ClassicEdge(sunk: true))
    }

    private var updatedLine: String {
        guard let date = store.snapshot?.fetchedAt else { return "Waiting for Cursor" }
        if abs(Date().timeIntervalSince(date)) < 45 {
            return "Updated just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    func openDashboard() {
        NSWorkspace.shared.open(URL(string: "https://cursor.com/dashboard?tab=usage")!)
    }

    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Bloom"
        alert.informativeText = "A Cursor usage tracker.\nReads the account signed in on this Mac."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct XPButtonStyle: ButtonStyle {
    var horizontal: CGFloat = 10
    var vertical: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XP.font(11))
            .foregroundStyle(.black)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
            .background(XP.face)
            .overlay(ClassicEdge(sunk: configuration.isPressed))
    }
}

struct ClassicEdge: View {
    var sunk: Bool

    var body: some View {
        Canvas { context, size in
            let light = GraphicsContext.Shading.color(sunk ? XP.shadow : XP.highlight)
            let dark = GraphicsContext.Shading.color(sunk ? XP.highlight : XP.dark)
            let innerLight = GraphicsContext.Shading.color(sunk ? XP.dark : XP.face)
            let innerDark = GraphicsContext.Shading.color(sunk ? XP.face : XP.shadow)
            let width = size.width
            let height = size.height

            context.fill(Path(CGRect(x: 0, y: 0, width: width, height: 1)), with: light)
            context.fill(Path(CGRect(x: 0, y: 0, width: 1, height: height)), with: light)
            context.fill(Path(CGRect(x: 1, y: 1, width: max(0, width - 2), height: 1)), with: innerLight)
            context.fill(Path(CGRect(x: 1, y: 1, width: 1, height: max(0, height - 2))), with: innerLight)

            context.fill(Path(CGRect(x: 0, y: height - 1, width: width, height: 1)), with: dark)
            context.fill(Path(CGRect(x: width - 1, y: 0, width: 1, height: height)), with: dark)
            context.fill(Path(CGRect(x: 1, y: height - 2, width: max(0, width - 2), height: 1)), with: innerDark)
            context.fill(Path(CGRect(x: width - 2, y: 1, width: 1, height: max(0, height - 2))), with: innerDark)
        }
        .allowsHitTesting(false)
    }
}

struct ClassicChunks: View {
    var percent: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<14, id: \.self) { index in
                Rectangle()
                    .fill(fill(index))
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }
        }
        .padding(2)
        .background(XP.field)
        .overlay(ClassicEdge(sunk: true))
    }

    private func fill(_ index: Int) -> Color {
        let filled = Int((min(max(percent, 0), 100) / 100 * 14).rounded(.up))
        if percent <= 0 { return .clear }
        return index < filled ? XP.bar : .clear
    }
}

enum CowboyArtwork {
    static let panel = fitted(side: 108)
    static let menu = roundedMenuIcon(side: 20)

    private static func roundedMenuIcon(side: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(forResource: "cowboy-dog", withExtension: "jpg"),
              let source = NSImage(contentsOf: url),
              source.size.width > 0 else { return nil }
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: side, height: side)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSBezierPath(roundedRect: rect, xRadius: side * 0.32, yRadius: side * 0.32).addClip()
        let fit = max(rect.width / source.size.width, rect.height / source.size.height)
        let width = source.size.width * fit
        let height = source.size.height * fit
        source.draw(in: NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func fitted(side: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(forResource: "cowboy-dog", withExtension: "jpg"),
              let source = NSImage(contentsOf: url),
              source.size.width > 0, source.size.height > 0 else { return nil }
        let canvas = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let scale = max(rect.width / source.size.width, rect.height / source.size.height)
            let width = source.size.width * scale
            let height = source.size.height * scale
            let destination = NSRect(
                x: rect.midX - width / 2,
                y: rect.midY - height / 2,
                width: width,
                height: height
            )
            source.draw(in: destination)
            return true
        }
        canvas.isTemplate = false
        return canvas
    }
}

struct CowboyDog: View {
    var menuBar = false

    var body: some View {
        if menuBar, let image = CowboyArtwork.menu {
            Image(nsImage: image)
                .renderingMode(.original)
        } else if let image = CowboyArtwork.panel {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.black)
        }
    }
}

enum XPMenu: Equatable {
    case file, view, help

    var origin: CGFloat {
        switch self {
        case .file: return 4
        case .view: return 46
        case .help: return 90
        }
    }

    var items: [XPMenuItem] {
        switch self {
        case .file:
            return [
                XPMenuItem(title: "Refresh") { $0.refreshFromMenu() },
                XPMenuItem(title: "Exit") { _ in NSApp.terminate(nil) }
            ]
        case .view:
            return [
                XPMenuItem(title: "Dashboard") { $0.openDashboard() }
            ]
        case .help:
            return [
                XPMenuItem(title: "About Bloom") { $0.showAbout() }
            ]
        }
    }
}

struct XPMenuItem: Identifiable {
    let title: String
    let action: (PopoverView) -> Void
    var id: String { title }
}

private extension PopoverView {
    func refreshFromMenu() {
        Task { await store.refresh() }
    }
}

struct XPMenuItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? XP.desktop : Color.clear)
            .foregroundStyle(configuration.isPressed ? Color.white : Color.black)
    }
}

struct AlertGlyph: View {
    var alert: UsageAlert

    var body: some View {
        ZStack {
            switch alert.tone {
            case .info:
                Circle().fill(Color(red: 0.05, green: 0.28, blue: 0.72))
                Text("i")
                    .font(XP.font(12))
                    .foregroundStyle(.white)
                    .offset(y: -0.5)
            case .caution, .warning:
                Triangle()
                    .fill(Color(red: 1, green: 0.82, blue: 0.1))
                    .overlay(Triangle().stroke(Color.black, lineWidth: 1))
                Text("!")
                    .font(XP.font(11))
                    .foregroundStyle(.black)
                    .offset(y: 1)
            case .critical:
                Circle().fill(Color(red: 0.75, green: 0.08, blue: 0.08))
                Text("×")
                    .font(XP.font(12))
                    .foregroundStyle(.white)
                    .offset(y: -1)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { style(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { style(nsView.window) }
    }

    private func style(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
    }
}

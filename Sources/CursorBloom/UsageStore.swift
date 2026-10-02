import Foundation
import ServiceManagement

@MainActor
final class UsageStore: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var isRefreshing = false
    @Published var launchesAtLogin: Bool

    private var timer: Timer?
    private let cacheURL: URL

    init() {
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bloom", isDirectory: true)
        cacheURL = support.appendingPathComponent("snapshot.json")
        snapshot = Self.readCache(at: cacheURL)
        phase = snapshot == nil ? .loading : .ready
        start()
    }

    var menuText: String {
        if let percent = snapshot?.totalPercent {
            return UsageSnapshot.formatPercent(percent)
        }
        if case .loading = phase {
            return "…"
        }
        return "Bloom"
    }

    var menuProgress: Double {
        min(max((snapshot?.totalPercent ?? 0) / 100, 0), 1)
    }

    func refresh() async {
        guard isRefreshing == false else { return }
        isRefreshing = true
        if snapshot == nil {
            phase = .loading
        }
        defer { isRefreshing = false }

        do {
            let credentials = try await Task.detached(priority: .userInitiated) {
                try CredentialStore.load()
            }.value
            let next = try await UsageClient.fetch(credentials: credentials)
            snapshot = next
            phase = .ready
            writeCache(next)
        } catch let error as UsageError {
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed(UsageError.network.localizedDescription)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func start() {
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { await refresh() }
    }

    private func writeCache(_ snapshot: UsageSnapshot) {
        let directory = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func readCache(at url: URL) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }
}

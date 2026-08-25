import AppKit
import Combine

extension Notification.Name {
    static let storeDidUpdate = Notification.Name("storeDidUpdate")
    static let routeDidChange = Notification.Name("routeDidChange")
    static let runPrimaryAction = Notification.Name("runPrimaryAction")
    static let focusSearchAction = Notification.Name("focusSearchAction")
}

enum Route: String, CaseIterable {
    case overview, containers, images, volumes, networks, machines, k8s, settings

    var title: String {
        switch self {
        case .overview: return L("nav.overview")
        case .containers: return L("nav.containers")
        case .images: return L("nav.images")
        case .volumes: return L("nav.volumes")
        case .networks: return L("nav.networks")
        case .machines: return L("nav.machines")
        case .k8s: return L("nav.k8s")
        case .settings: return L("nav.settings")
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .containers: return "cube"
        case .images: return "square.3.layers.3d"
        case .volumes: return "externaldrive"
        case .networks: return "globe"
        case .machines: return "display"
        case .k8s: return "steeringwheel"
        case .settings: return "gearshape"
        }
    }
}

/// Central observable state. Pages observe `.storeDidUpdate`.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var route: Route = .overview
    @Published private(set) var containers: [ManagedContainer] = []
    @Published private(set) var images: [ImageResourceJSON] = []
    @Published private(set) var volumes: [VolumeResourceJSON] = []
    @Published private(set) var networks: [NetworkResourceJSON] = []
    @Published private(set) var machines: [MachineResourceJSON] = []
    @Published private(set) var clusters: [K8sCluster] = []
    @Published private(set) var servicesRunning = false
    @Published private(set) var versions: [VersionEntryJSON] = []
    @Published private(set) var df: DfReportJSON?
    @Published private(set) var properties: [(key: String, value: String)] = []
    @Published private(set) var dnsDomains: [String] = []
    @Published private(set) var registries: [String] = []
    @Published private(set) var systemStartedAt: Date?
    @Published private(set) var languageVersion = 0
    var lastError: String?

    private var pollTimer: Timer?
    private var loading = false

    func setRoute(_ r: Route) {
        guard r != route else { return }
        route = r
        NotificationCenter.default.post(name: .routeDidChange, object: r)
        refresh()
    }

    /// Switch the in-app language, then nudge observers so `L()` strings (rendered
    /// from `@ObservedObject store`) re-evaluate and the AppKit sidebar re-localizes.
    func setLanguage(_ code: String) {
        AppLanguage.set(code)
        languageVersion += 1
        NotificationCenter.default.post(name: .storeDidUpdate, object: nil)
        NotificationCenter.default.post(name: .keymapChanged, object: nil)
    }

    func start() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        guard !loading else { return }
        loading = true
        Task { @MainActor in
            async let ct = Commands.listContainers(all: true)
            async let im = Commands.listImages()
            async let vo = Commands.listVolumes()
            async let ne = Commands.listNetworks()
            async let ma = Commands.listMachines()
            async let cl = Commands.k8sClusters()
            async let st = Commands.systemStatus()
            let (c, i, v, n, m, k, s) = await (ct, im, vo, ne, ma, cl, st)
            NSLog("CGUI refresh done: status=%@ images=%d err=%@", s?.status ?? "nil", i.count, lastError ?? "-")
            self.containers = c
            self.images = i
            self.volumes = v
            self.networks = n
            self.machines = await self.enrichMachines(m)
            self.clusters = k
            let wasRunning = self.servicesRunning
            self.servicesRunning = (s?.status == "running")
            if self.servicesRunning, self.systemStartedAt == nil { self.systemStartedAt = Date() }
            if !self.servicesRunning { self.systemStartedAt = nil }
            if wasRunning != self.servicesRunning { self.refreshSystemInfo() }
            self.loading = false
            NotificationCenter.default.post(name: .storeDidUpdate, object: nil)
        }
    }

    /// Merge `container machine inspect` detail (image, home mount, platform) into the list
    /// rows while preserving the `default` flag that only `machine list` reports.
    @MainActor
    private func enrichMachines(_ list: [MachineResourceJSON]) async -> [MachineResourceJSON] {
        guard !list.isEmpty else { return list }
        return await withTaskGroup(of: (String, MachineResourceJSON?).self) { group in
            for m in list {
                group.addTask {
                    let detail = await Commands.inspectMachine(m.name)
                    return (m.name, detail)
                }
            }
            var details: [String: MachineResourceJSON] = [:]
            for await (name, detail) in group where detail != nil {
                details[name] = detail
            }
            return list.map { m in
                guard let d = details[m.name] else { return m }
                return MachineResourceJSON(
                    diskSize: d.diskSize ?? m.diskSize,
                    cpus: d.cpus ?? m.cpus,
                    id: m.id,
                    default: m.default,
                    createdDate: d.createdDate ?? m.createdDate,
                    memory: d.memory ?? m.memory,
                    status: d.status ?? m.status,
                    homeMount: d.homeMount ?? m.homeMount,
                    image: d.image ?? m.image,
                    platform: d.platform ?? m.platform
                )
            }
        }
    }

    func refreshSystemInfo() {
        Task { @MainActor in
            async let vs = Commands.version()
            async let d = Commands.df()
            async let p = Commands.properties()
            async let dns = Commands.dnsDomains()
            async let regs = Commands.registries()
            self.versions = await vs
            self.df = await d
            self.properties = await p
            self.dnsDomains = await dns
            self.registries = await regs
            NotificationCenter.default.post(name: .storeDidUpdate, object: nil)
        }
    }

    var runningCount: Int { containers.filter(\.isRunning).count }
    var cliVersion: String {
        versions.first { $0.appName == "container" }.map { v in
            let commit = (v.commit ?? "").prefix(7)
            return commit.isEmpty ? "\(v.version ?? "")" : "\(v.version ?? "") (\(v.buildType ?? "")/\(commit))"
        } ?? "—"
    }
    var apiVersion: String {
        versions.first { $0.appName == "container-apiserver" }?.version ?? "—"
    }

    /// Containers that look like k8s cluster nodes (used to guard k8s actions).
    func containerExists(_ id: String) -> Bool {
        containers.contains { $0.id == id }
    }
}

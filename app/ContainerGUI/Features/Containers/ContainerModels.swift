import Foundation

extension ManagedContainer: Identifiable {}

// MARK: - Containers (`container list --all --format json`)

struct ManagedContainer: Codable {
    struct Configuration: Codable {
        struct InitProcess: Codable {
            struct UserInfo: Codable {
                struct ID: Codable { let gid: Int?; let uid: Int? }
                let id: ID?
            }
            let executable: String?
            let arguments: [String]?
            let environment: [String]?
            let workingDirectory: String?
            let terminal: Bool?
            let user: UserInfo?
        }
        struct Mount: Codable { let source: String?; let target: String?; let type: String?; let readOnly: Bool? }
        struct NetConfig: Codable { let network: String?; let hostname: String? }
        struct PublishedPort: Codable {
            let hostPort: String?
            let containerPort: String?
            let `protocol`: String?
            let hostIp: String?
        }
        let id: String
        let image: OCIImage
        let platform: Platform?
        let resources: Resources?
        let creationDate: Date?
        let initProcess: InitProcess?
        let mounts: [Mount]?
        let networks: [NetConfig]?
        let publishedPorts: [PublishedPort]?
        let labels: [String: String]?
        let readOnly: Bool?
        let useInit: Bool?
        let rosetta: Bool?
        let virtualization: Bool?
        let ssh: Bool?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            image = (try? c.decode(OCIImage.self, forKey: .image)) ?? OCIImage(reference: "—")
            platform = try? c.decode(Platform.self, forKey: .platform)
            resources = try? c.decode(Resources.self, forKey: .resources)
            creationDate = try? c.decode(Date.self, forKey: .creationDate)
            initProcess = try? c.decode(InitProcess.self, forKey: .initProcess)
            mounts = try? c.decode([Mount].self, forKey: .mounts)
            networks = try? c.decode([NetConfig].self, forKey: .networks)
            publishedPorts = try? c.decode([PublishedPort].self, forKey: .publishedPorts)
            labels = try? c.decode([String: String].self, forKey: .labels)
            readOnly = try? c.decode(Bool.self, forKey: .readOnly)
            useInit = try? c.decode(Bool.self, forKey: .useInit)
            rosetta = try? c.decode(Bool.self, forKey: .rosetta)
            virtualization = try? c.decode(Bool.self, forKey: .virtualization)
            ssh = try? c.decode(Bool.self, forKey: .ssh)
        }
        enum CodingKeys: String, CodingKey {
            case id, image, platform, resources, creationDate, initProcess, mounts, networks
            case publishedPorts, labels, readOnly, useInit, rosetta, virtualization, ssh
        }
    }
    struct OCIImage: Codable { let reference: String }
    struct Platform: Codable { let os: String; let architecture: String }
    struct Resources: Codable {
        let cpus: Int?
        let memoryInBytes: UInt64?
    }
    struct Status: Codable {
        enum State: String, Codable { case running, stopped, created, unknown }
        let state: State?
        let networks: [Network]?
        let startedDate: Date?
        let finishedDate: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            state = (try? c.decode(State.self, forKey: .state)) ?? nil
            networks = try? c.decode([Network].self, forKey: .networks)
            startedDate = try? c.decode(Date.self, forKey: .startedDate)
            finishedDate = try? c.decode(Date.self, forKey: .finishedDate)
        }
        enum CodingKeys: String, CodingKey { case state, networks, startedDate, finishedDate }
    }
    struct Network: Codable {
        let network: String?
        let ipv4Address: String?
    }

    let configuration: Configuration
    let status: Status

    var id: String { configuration.id }
    var imageRef: String { configuration.image.reference }
    var isRunning: Bool { status.state == .running }
    var createdDate: Date? { configuration.creationDate }
    var networkName: String { configuration.networks?.first?.network ?? "default" }
    var commandText: String {
        guard let p = configuration.initProcess else { return "—" }
        return ([p.executable].compactMap { $0 } + (p.arguments ?? [])).joined(separator: " ")
    }
    var workdirText: String { configuration.initProcess?.workingDirectory ?? "—" }
    var userText: String {
        guard let u = configuration.initProcess?.user?.id else { return "—" }
        return u.uid?.description ?? "—"
    }
    var portPairs: [(host: String, ct: String, proto: String)] {
        (configuration.publishedPorts ?? []).compactMap { p in
            guard let ct = p.containerPort else { return nil }
            return (host: p.hostPort ?? "—", ct: ct, proto: p.protocol ?? "tcp")
        }
    }
    var mountPairs: [(src: String, dst: String)] {
        (configuration.mounts ?? []).compactMap { m in
            guard let src = m.source, let dst = m.target else { return nil }
            return (src: src, dst: dst)
        }
    }
    var envPairs: [(key: String, value: String)] {
        (configuration.initProcess?.environment ?? []).compactMap { line in
            guard let eq = line.firstIndex(of: "=") else { return nil }
            return (String(line[line.startIndex..<eq]), String(line[line.index(after: eq)...]))
        }
    }
    var optionFlags: [String] {
        var flags: [String] = []
        if configuration.useInit == true { flags.append(L("run.opt.init")) }
        if configuration.rosetta == true { flags.append("Rosetta") }
        if configuration.readOnly == true { flags.append(L("run.opt.ro")) }
        if configuration.virtualization == true { flags.append(L("mach.new.virt")) }
        if configuration.ssh == true { flags.append("SSH") }
        if configuration.initProcess?.terminal == true { flags.append(L("run.opt.tty")) }
        return flags
    }
    var ip: String {
        let raw = status.networks?.first?.ipv4Address ?? ""
        return raw.split(separator: "/").first.map(String.init) ?? "—"
    }
}

// MARK: - Stats (`container stats --no-stream --format json`)

struct ContainerStatsSnapshot: Codable {
    let id: String
    let memoryUsageBytes: UInt64?
    let memoryLimitBytes: UInt64?
    let cpuUsageUsec: UInt64?
    let networkRxBytes: UInt64?
    let networkTxBytes: UInt64?
    let blockReadBytes: UInt64?
    let blockWriteBytes: UInt64?
    let numProcesses: UInt64?

    var cpuPercent: Double {
        // cpuUsageUsec over a sampling window; CLI computes its own ratio — approximate with usec/10_000 capped
        guard let u = cpuUsageUsec else { return 0 }
        return min(Double(u) / 10_000.0, 100 * 16)
    }
}

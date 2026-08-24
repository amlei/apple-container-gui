import Foundation

extension ManagedContainer: Identifiable {}
extension NetworkResourceJSON: Identifiable {}
extension K8sCluster: Identifiable {
    var id: String { name }
}

// MARK: - Containers (`container list --all --format json`)

struct ManagedContainer: Codable {
    struct Configuration: Codable {
        let id: String
        let image: OCIImage
        let platform: Platform?
        let resources: Resources?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            image = (try? c.decode(OCIImage.self, forKey: .image)) ?? OCIImage(reference: "—")
            platform = try? c.decode(Platform.self, forKey: .platform)
            resources = try? c.decode(Resources.self, forKey: .resources)
        }
        enum CodingKeys: String, CodingKey { case id, image, platform, resources }
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
    var ip: String {
        let raw = status.networks?.first?.ipv4Address ?? ""
        return raw.split(separator: "/").first.map(String.init) ?? "—"
    }
}

// MARK: - Images (`container image list --format json`)

struct ImageResourceJSON: Codable {
    struct ConfigInfo: Codable {
        let creationDate: Date?
        let descriptor: Descriptor?
        let name: String?
        struct Descriptor: Codable { let digest: String; let mediaType: String?; let size: UInt64? }
    }
    struct Variant: Codable {
        struct VariantConfig: Codable {
            let architecture: String?
            let `default`: Bool?
            struct InnerConfig: Codable {
                let Cmd: [String]?
                let Env: [String]?
                let WorkingDir: String?
            }
            let config: InnerConfig?
        }
        let architecture: String?
        let config: VariantConfig?
        // history may carry sizes in some outputs; tolerate absence
    }
    let configuration: ConfigInfo
    let id: String
    let variants: [Variant]?

    var ref: String { configuration.name ?? id.prefix(12).description }
    var arch: String { variants?.first?.architecture ?? variants?.first?.config?.architecture ?? "arm64" }
    var cmdText: String { variants?.first?.config?.config?.Cmd?.joined(separator: " ") ?? "" }
}

// MARK: - Volumes (`container volume list --format json`)

struct VolumeResourceJSON: Codable {
    struct Configuration: Codable {
        let name: String
        let driver: String?
        let format: String?
        let source: String?
        let creationDate: Date?
        let labels: [String: String]?
        let options: [String: String]?
        let sizeInBytes: UInt64?
    }
    let configuration: Configuration
    let id: String

    var name: String { configuration.name }
    var journalMode: String? { configuration.options?["journal"] }
}

// MARK: - Networks (`container network list --format json`)

struct NetworkResourceJSON: Codable {
    struct Configuration: Codable {
        let creationDate: Date?
        let labels: [String: String]?
        let mode: String?
        let name: String
        let options: [String: String]?
        let plugin: String?
    }
    struct Status: Codable {
        let ipv4Gateway: String?
        let ipv4Subnet: String?
        let ipv6Subnet: String?
    }
    let configuration: Configuration
    let id: String
    let status: Status?

    var name: String { configuration.name }
    var isSystem: Bool { configuration.labels?["com.apple.container.resource.role"] != nil || name == "default" }
}

// MARK: - Machines (`container machine list --format json`)

struct MachineResourceJSON: Codable {
    let diskSize: UInt64?
    let cpus: Int?
    let id: String
    let `default`: Bool?
    let createdDate: Date?
    let memory: UInt64?
    let status: String?

    var name: String { id }
    var isRunning: Bool { status == "running" }
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

// MARK: - System

struct SystemStatusJSON: Codable {
    let status: String?
    let appRoot: String?
    let installRoot: String?
    let logRoot: String?
}

struct VersionEntryJSON: Codable {
    let appName: String?
    let buildType: String?
    let commit: String?
    let version: String?
}

struct DfSection: Codable {
    let active: Int?
    let reclaimable: UInt64?
    let sizeInBytes: UInt64?
    let total: Int?
}

struct DfReportJSON: Codable {
    let containers: DfSection?
    let images: DfSection?
    let volumes: DfSection?
}

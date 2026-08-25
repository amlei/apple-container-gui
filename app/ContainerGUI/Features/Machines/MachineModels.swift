import Foundation

// MARK: - Machines (`container machine list --format json`)

struct MachineResourceJSON: Codable {
    let diskSize: UInt64?
    let cpus: Int?
    let id: String
    let `default`: Bool?
    let createdDate: Date?
    let memory: UInt64?
    let status: String?
    let homeMount: String?
    let image: MachineImage?
    let platform: MachinePlatform?

    struct MachineImage: Codable { let reference: String? }
    struct MachinePlatform: Codable { let architecture: String?; let os: String? }

    var name: String { id }
    var isRunning: Bool { status == "running" }
    var imageReference: String { image?.reference ?? "—" }
    var homeMountText: String {
        switch homeMount?.lowercased() {
        case "rw": return L("mach.home.rw")
        case "ro": return L("mach.home.ro")
        case "none": return L("mach.home.none")
        default: return homeMount ?? "—"
        }
    }
    var homeMountValue: String { homeMount ?? "rw" }
    var archText: String {
        guard let a = platform?.architecture ?? platform?.os, !a.isEmpty else { return "—" }
        return platform?.os.map { "\($0)/\(a)" } ?? a
    }
}

import Foundation

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
    let cache: DfSection?
}

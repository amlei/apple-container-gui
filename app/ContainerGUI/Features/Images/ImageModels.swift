import Foundation

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
            struct LayerHistory: Codable {
                let createdBy: String?
                let comment: String?
                let emptyLayer: Bool?
                enum CodingKeys: String, CodingKey {
                    case createdBy = "created_by"
                    case comment
                    case emptyLayer = "empty_layer"
                }
            }
            let history: [LayerHistory]?
        }
        let architecture: String?
        let config: VariantConfig?
        let size: UInt64?
    }
    let configuration: ConfigInfo
    let id: String
    let variants: [Variant]?

    var ref: String { configuration.name ?? id.prefix(12).description }
    var arch: String { variants?.first?.architecture ?? variants?.first?.config?.architecture ?? "arm64" }
    var cmdText: String { variants?.first?.config?.config?.Cmd?.joined(separator: " ") ?? "" }
    /// Layer size is carried on the variant; the descriptor size is the manifest digest only.
    var sizeBytes: UInt64? { variants?.first?.size ?? configuration.descriptor?.size }
    /// The build steps that produced this image (from the CSV history), for the drawer.
    var layers: [(cmd: String, size: UInt64?)] {
        variants?.first?.config?.history?.compactMap { h in
            guard let by = h.createdBy, !by.isEmpty else { return nil }
            return (cmd: by, size: nil)
        } ?? []
    }
}

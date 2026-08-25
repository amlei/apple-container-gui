import SwiftUI

// MARK: - Global interaction model (sheets, drawers, toasts, confirmations)

@MainActor
final class SQAppModel: ObservableObject {
    @Published var sheet: SQSheetKind?
    @Published var drawer: SQDrawer?
    @Published var toast: SQToast?
    @Published var confirmation: SQConfirm?
    @Published var searchFocusTick = 0

    func show(_ sheet: SQSheetKind) { self.sheet = sheet }
    func openDrawer(_ drawer: SQDrawer) {
        withAnimation(.easeOut(duration: 0.28)) { self.drawer = drawer }
    }
    func closeDrawer() {
        withAnimation(.easeOut(duration: 0.24)) { self.drawer = nil }
    }
    func showToast(_ message: String, isError: Bool = false) {
        let item = SQToast(message: message, isError: isError)
        toast = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            if self?.toast?.id == item.id { withAnimation { self?.toast = nil } }
        }
    }
    func requestSearchFocus() { searchFocusTick += 1 }
    func confirm(_ title: String, message: String, confirm: String, danger: Bool = false, _ onConfirm: @escaping @MainActor () -> Void) {
        confirmation = SQConfirm(title: title, message: message, confirm: confirm, danger: danger) { onConfirm() }
    }
}

struct SQToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

struct SQConfirm: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirm: String
    let danger: Bool
    let onConfirm: @MainActor () -> Void
}

enum SQSheetKind: Identifiable {
    case run(image: String?)
    case pull
    case build
    case newVolume
    case newNetwork
    case newMachine
    case machineConfig(name: String)
    case k8sNew
    case registryLogin
    case tag(image: String)
    case loadImage(cluster: String)
    case systemLogs

    var id: String {
        switch self {
        case .run: return "run"
        case .pull: return "pull"
        case .build: return "build"
        case .newVolume: return "newVolume"
        case .newNetwork: return "newNetwork"
        case .newMachine: return "newMachine"
        case .machineConfig: return "machineConfig"
        case .k8sNew: return "k8sNew"
        case .registryLogin: return "registryLogin"
        case .tag: return "tag"
        case .loadImage: return "loadImage"
        case .systemLogs: return "systemLogs"
        }
    }
}

enum SQDrawer: Identifiable {
    case container(id: String)
    case image(ref: String)
    case volume(name: String)
    case machineShell(name: String)
    case machineLogs(name: String)

    var id: String {
        switch self {
        case .container(let id): return "c-\(id)"
        case .image(let ref): return "i-\(ref)"
        case .volume(let name): return "v-\(name)"
        case .machineShell(let name): return "ms-\(name)"
        case .machineLogs(let name): return "ml-\(name)"
        }
    }
}

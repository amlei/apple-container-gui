import AppKit
import SwiftUI

struct OverviewPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        PageScaffold(title: L("nav.overview")) {
            EmptyView()
        } body: {
            VStack(alignment: .leading, spacing: SQ.gap) {
                tileGrid
                HStack(alignment: .top, spacing: 14) {
                    diskCard
                    serviceCard
                }
            }
        }
    }

    private var runningCount: Int { store.containers.filter(\.isRunning).count }

    private var tileGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            tile(title: L("ov.tiles.containers"), icon: "cube.fill", value: "\(runningCount)", sub: "/ \(store.containers.count)", route: .containers)
            tile(title: L("ov.tiles.images"), icon: "square.3.layers.3d", value: "\(store.images.count)", route: .images)
            tile(title: L("ov.tiles.volumes"), icon: "externaldrive", value: "\(store.volumes.count)", route: .volumes)
            tile(title: L("ov.tiles.networks"), icon: "globe", value: "\(store.networks.filter { !$0.isSystem }.count)", route: .networks)
        }
    }

    private func tile(title: String, icon: String, value: String, sub: String = "", route: Route) -> some View {
        Button {
            store.setRoute(route)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SQ.accent)
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SQ.text2)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(SQ.text)
                    if !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SQ.text3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: SQ.corner, style: .continuous)
                    .fill(SQ.cardBg)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
            .overlay(RoundedRectangle(cornerRadius: SQ.corner, style: .continuous).stroke(SQ.cardBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var diskCard: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(L("ov.disk"))
                        .font(.system(size: 15, weight: .bold))
                    Text(L("ov.disk.sub"))
                        .font(.system(size: 12))
                        .foregroundStyle(SQ.text2)
                    Spacer()
                    Menu {
                        Button(L("act.pruneContainers")) { prune("containers", confirm: false) }
                        Divider()
                        Button(L("act.pruneDangling")) { prune("dangling", confirm: false) }
                        Button(L("act.pruneUnusedImages")) { prune("unusedImages", confirm: true) }
                        Divider()
                        Button(L("act.pruneVolumes")) { prune("volumes", confirm: true) }
                        Button(L("act.pruneNetworks")) { prune("networks", confirm: true) }
                    } label: {
                        SQButton(title: L("act.maintain"), icon: "arrow.3.trianglepath", small: true) {}
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.top, 15)
                VStack(spacing: 0) {
                    diskRow(label: L("ov.disk.images"), section: store.df?.images)
                    Divider()
                    diskRow(label: L("ov.disk.containers"), section: store.df?.containers)
                    Divider()
                    diskRow(label: L("ov.disk.volumes"), section: store.df?.volumes)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
    }

    private func diskRow(label: String, section: DfSection?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let active = section.map { s -> UInt64 in
                let rec = s.reclaimable ?? 0
                let tot = s.sizeInBytes ?? 0
                return tot >= rec ? tot - rec : 0
            } ?? 0
            let rec = section?.reclaimable ?? 0
            let tot = section?.sizeInBytes ?? 0
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 92, alignment: .leading)
                GeometryReader { geo in
                    let w = geo.size.width
                    let usedFrac = tot > 0 ? min(1, CGFloat(active) / CGFloat(tot)) : 0
                    let recFrac = tot > 0 ? min(1, CGFloat(rec) / CGFloat(tot)) : 0
                    HStack(spacing: 0) {
                        Rectangle().fill(SQ.accent).frame(width: w * usedFrac)
                        Rectangle().fill(SQ.orange.opacity(0.75)).frame(width: w * recFrac)
                    }
                    .background(Rectangle().fill(SQ.fill1))
                }
                .frame(height: 7)
                .clipShape(Capsule())
                Text(metaText(active: active, rec: rec, tot: tot))
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text2)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
    }

    private func metaText(active: UInt64, rec: UInt64, tot: UInt64) -> String {
        "\(Fmt.bytes(active)) \(L("ov.disk.reclaimable")) \(Fmt.bytes(rec)) · \(Fmt.bytes(tot))"
    }

    private var serviceCard: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(L("ov.service"))
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    SQPill(text: store.servicesRunning ? L("st.running") : L("st.exited"), ok: store.servicesRunning)
                }
                let kernel = store.properties.first { $0.key == "kernel.binaryPath" }?.value
                    .components(separatedBy: "/").last ?? "—"
                SQKV(monoValue: true, rows: [
                    (L("ov.service.version.cli"), "container \(store.cliVersion)"),
                    (L("ov.service.version.api"), store.apiVersion),
                    (L("ov.service.kernel"), kernel),
                    (L("ov.service.registry"), store.registries.first ?? L("ct.d.none")),
                    (L("ov.service.dns"), store.dnsDomains.first.map { ".\($0)" } ?? "—"),
                    (L("ov.service.uptime"), uptimeText),
                ])
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
    }

    private var uptimeText: String {
        guard let start = store.systemStartedAt else { return "—" }
        return Fmt.duration(seconds: Date().timeIntervalSince(start))
    }

    private func prune(_ kind: String, confirm: Bool) {
        let needConfirm = ["unusedImages", "volumes", "networks"].contains(kind)
        let title: String = switch kind {
        case "unusedImages": L("prune.imga.title")
        case "volumes": L("prune.vol.title")
        default: L("prune.net.title")
        }
        let run: () -> Void = {
            Task {
                do {
                    switch kind {
                    case "containers": try await Commands.pruneContainers()
                    case "dangling": try await Commands.pruneImages(all: false)
                    case "unusedImages": try await Commands.pruneImages(all: true)
                    case "volumes": try await Commands.pruneVolumes()
                    case "networks": try await Commands.pruneNetworks()
                    default: break
                    }
                    model.showToast(L("prune.done"))
                    Store.shared.refresh()
                } catch {
                    model.showToast(error.localizedDescription, isError: true)
                }
            }
        }
        if needConfirm && confirm {
            model.confirm(title, message: "", confirm: L("confirm.prune"), danger: true, run)
        } else {
            run()
        }
    }
}

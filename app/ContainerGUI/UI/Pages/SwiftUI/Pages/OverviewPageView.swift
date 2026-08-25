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
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11.5, weight: .medium))
                            Text(L("act.maintain"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(SQ.text)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SQ.hairlineStrong, lineWidth: 0.5))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .padding(.top, 15)
                VStack(spacing: 0) {
                    diskRow(label: L("ov.disk.images"), section: store.df?.images)
                    Divider()
                    diskRow(label: L("ov.disk.containers"), section: store.df?.containers)
                    Divider()
                    diskRow(label: L("ov.disk.volumes"), section: store.df?.volumes)
                    if store.df?.cache != nil {
                        Divider()
                        diskRow(label: L("ov.disk.cache"), section: store.df?.cache)
                    }
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
                        DiskStripes().frame(width: w * recFrac)
                    }
                    .background(Rectangle().fill(SQ.fill1))
                }
                .frame(height: 7)
                .clipShape(Capsule())
                (Text(Fmt.bytes(active)).font(SQ.monoSmall).bold()
                    + Text(" \(L("ov.disk.reclaimable")) \(Fmt.bytes(rec)) · \(Fmt.bytes(tot))")
                        .font(SQ.monoSmall))
                    .foregroundStyle(SQ.text2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
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

/// Diagonal orange/gold stripes used for the reclaimable portion of a disk bar
/// (matches the design/ prototype).
struct DiskStripes: View {
    private static let tileSize: CGFloat = 20
    private static let tile: NSImage = {
        let img = NSImage(size: NSSize(width: tileSize, height: tileSize))
        img.lockFocus()
        let gold = NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.35, alpha: 1)
        let orange = NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.0, alpha: 1)
        gold.setFill()
        NSRect(x: 0, y: 0, width: tileSize, height: tileSize).fill()
        let stripeW: CGFloat = 5
        let period = stripeW * 2
        orange.setFill()
        var x: CGFloat = -tileSize - period
        while x < tileSize {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: x, y: tileSize))
            p.line(to: NSPoint(x: x + tileSize, y: 0))
            p.line(to: NSPoint(x: x + tileSize + stripeW, y: 0))
            p.line(to: NSPoint(x: x + stripeW, y: tileSize))
            p.close()
            p.fill()
            x += period
        }
        img.unlockFocus()
        return img
    }()

    var body: some View {
        Image(nsImage: Self.tile)
            .resizable(resizingMode: .tile)
    }
}

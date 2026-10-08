import AppKit
import SwiftUI

struct NetworksPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var noteDismissed = false

    var body: some View {
        PageScaffold(
            title: L("nav.networks"),
            toolbar: [ToolbarAction(id: "tb-new-network", symbol: "plus", label: L("net.new.title"), primary: true) {
                model.show(.newNetwork)
            }]
        ) {
            VStack(spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if !noteDismissed {
                    banner(title: "macOS 26", message: L("net.mac26.note")) { noteDismissed = true }
                }
                if store.networks.isEmpty {
                    SQCard {
                        SQEmpty(icon: "globe", title: L("net.empty"), hint: L("net.empty.hint"), buttonTitle: L("net.new.title")) { model.show(.newNetwork) }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                        ForEach(store.networks) { net in
                            NetworkCardView(network: net, onDelete: {
                                model.confirm(L("del.net.title", ["n": net.name]), message: L("del.net.msg"), confirm: L("confirm.yes"), danger: true) {
                                    Task { try? await Commands.deleteNetworks([net.name]); Store.shared.refresh() }
                                }
                            })
                        }
                    }
                }
            }
        }
    }

    private func banner(title: String, message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SQ.accent)
                .padding(.top, 1)
            Text("**\(title)** · \(message)")
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(SQ.text2)
            }
            .buttonStyle(SQPlainButtonStyle())
        }
        .padding(11)
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.accent.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SQ.accent.opacity(0.25), lineWidth: 0.5))
    }
}

private struct NetworkCardView: View {
    let network: NetworkResourceJSON
    let onDelete: () -> Void

    var body: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SQ.accent)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SQ.accentTint))
                    Text(network.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(network.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if network.isSystem { SQBadge(text: L("net.default.tag"), accent: true) }
                    if network.configuration.options?["internal"] != nil || network.name.hasPrefix("internal") {
                        SQBadge(text: L("net.internal"), icon: "shield")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) { Rectangle().fill(SQ.hairline).frame(height: 0.5) }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    GridRow {
                        kvLabel(L("net.subnet4"))
                        Text(network.status?.ipv4Subnet ?? "—")
                            .font(SQ.mono)
                            .foregroundStyle(network.status?.ipv4Subnet != nil ? SQ.text : SQ.text3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GridRow {
                        kvLabel(L("net.subnet6"))
                        Text(network.status?.ipv6Subnet ?? "—")
                            .font(SQ.mono)
                            .foregroundStyle(network.status?.ipv6Subnet != nil ? SQ.text : SQ.text3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GridRow {
                        kvLabel(L("net.attached"))
                        if attached.isEmpty {
                            Text("—").foregroundStyle(SQ.text3)
                        } else {
                            FlowLayout(spacing: 5) {
                                ForEach(attached, id: \.self) { name in
                                    SQChip(text: name)
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 12))
                .padding(16)

                Spacer(minLength: 0)

                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if network.isSystem {
                HStack(spacing: 6) {
                    Image(systemName: "shield")
                        .font(.system(size: 11, weight: .medium))
                    Text(L("del.net.system"))
                        .font(.system(size: 11.5))
                }
                .foregroundStyle(SQ.text3)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                SQButton(title: L("act.delete"), icon: "trash", danger: true, small: true, action: onDelete)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46, alignment: .center)
        .overlay(alignment: .top) { Rectangle().fill(SQ.hairline).frame(height: 0.5) }
    }

    private func kvLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(SQ.text2)
            .lineLimit(1)
    }

    private var attached: [String] {
        Store.shared.containers.compactMap { c -> String? in
            guard c.status.networks?.contains(where: { $0.network == network.name }) == true else { return nil }
            return c.id
        }
    }
}

// MARK: - Flow layout (wrapping chips)

/// Minimal wrapping layout so attached-container chips wrap instead of
/// overflowing the card.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

import AppKit
import SwiftUI

struct K8sPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var noteDismissed = false

    var body: some View {
        PageScaffold(title: L("nav.k8s")) {
            SQButton(title: L("k8.new.title"), icon: "plus", primary: true) { model.show(.k8sNew) }
        } body: {
            VStack(alignment: .leading, spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if !noteDismissed {
                    noteBanner(title: "k8s", message: L("k8.exp.note")) { noteDismissed = true }
                }
                Text(L("k8.sub"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(SQ.text2)
                    .padding(.horizontal, 2)
                if store.clusters.isEmpty {
                    SQCard {
                        SQEmpty(icon: "steeringwheel", title: L("k8.empty"), hint: L("k8.empty.hint"), buttonTitle: L("k8.new.title")) { model.show(.k8sNew) }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                        ForEach(store.clusters.indices, id: \.self) { i in
                            K8sCardView(cluster: store.clusters[i])
                        }
                    }
                }
            }
        }
    }

    private func noteBanner(title: String, message: String, onDismiss: @escaping () -> Void) -> some View {
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
            .buttonStyle(.plain)
        }
        .padding(11)
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.accent.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SQ.accent.opacity(0.25), lineWidth: 0.5))
    }
}

private struct K8sCardView: View {
    let cluster: K8sCluster
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SQ.accent)
                    Text(cluster.name)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SQPill(text: cluster.isRunning ? L("st.running") : L("mach.stopped"), ok: cluster.isRunning)
                }
                VStack(alignment: .leading, spacing: 5) {
                    kvLine(L("k8.nodeImage"), cluster.nodeImage)
                    kvLine(L("mach.resources"), "—")
                    kvLine(L("k8.images"), "—")
                    kvLine(L("mach.created"), "—")
                }
                .font(.system(size: 12))
                Divider()
                HStack(spacing: 8) {
                    if cluster.isRunning {
                        SQButton(title: L("k8.loadimg.short"), icon: "arrow.up", small: true) { model.show(.loadImage(cluster: cluster.name)) }
                    } else {
                        SQButton(title: L("act.start"), icon: "play.fill", small: true) {
                            Task { try? await Commands.k8sStart(cluster.name); Store.shared.refresh() }
                        }
                    }
                    Spacer()
                    Menu {
                        if !cluster.isRunning {
                            Button {
                                Task { try? await Commands.k8sStart(cluster.name); Store.shared.refresh() }
                            } label: { Label(L("act.start"), systemImage: "play.fill") }
                        }
                        if cluster.isRunning {
                            Button { model.show(.loadImage(cluster: cluster.name)) } label: {
                                Label(L("k8.loadimg.short"), systemImage: "arrow.up")
                            }
                            Button {
                                model.confirm(L("k8.writecfg"), message: L("k8.writecfg.msg"), confirm: L("act.confirm")) {
                                    Task { try? await Commands.k8sWriteConfig(cluster.name); model.showToast(L("k8.writecfg.doneMsg", ["n": cluster.name])) }
                                }
                            } label: { Label(L("k8.writecfg"), systemImage: "key") }
                        }
                        Divider()
                        Button(role: .destructive) {
                            model.confirm(L("del.k8s.title", ["n": cluster.name]), message: L("del.k8s.msg"), confirm: L("confirm.yes"), danger: true) {
                                Task { try? await Commands.k8sDelete(cluster.name); Store.shared.refresh() }
                            }
                        } label: { Label(L("act.delete"), systemImage: "trash").foregroundStyle(SQ.red) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SQ.text2)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.fill1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            .padding(16)
        }
    }

    private func kvLine(_ key: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(key).foregroundStyle(SQ.text2)
            Text(value).font(SQ.mono).foregroundStyle(SQ.text)
        }
    }
}

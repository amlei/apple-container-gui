import AppKit
import SwiftUI

// MARK: - Palette & spacing tokens (mirrors design/assets styles.css)

enum SQ {
    // Accent / status colors (prototype light & dark values).
    static let accent = adaptive(light: nsHex(0x0077ff), dark: nsHex(0x0a84ff))
    static let accentTint = adaptive(light: nsRGBA(0, 122, 255, 0.12), dark: nsRGBA(10, 132, 255, 0.22))
    static let green = adaptive(light: nsHex(0x34c759), dark: nsHex(0x30d158))
    static let red = adaptive(light: nsHex(0xff3b30), dark: nsHex(0xff453a))
    static let orange = adaptive(light: nsHex(0xff9500), dark: nsHex(0xff9f0a))
    static let purple = Color(hex: 0xaf52de)
    static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)

    // Semantic text / surfaces (prototype light & dark values).
    static let text = adaptive(light: nsHex(0x1d1d1f), dark: nsHex(0xf5f5f7))
    static let text2 = adaptive(light: nsHex(0x6e6e73), dark: nsHex(0x98989d))
    static let text3 = adaptive(light: nsHex(0xaeaeb2), dark: nsHex(0x636366))
    static let hairline = adaptive(light: nsRGBA(0, 0, 0, 0.09), dark: nsRGBA(255, 255, 255, 0.09))
    static let hairlineStrong = adaptive(light: nsRGBA(0, 0, 0, 0.14), dark: nsRGBA(255, 255, 255, 0.16))
    static let fill1 = adaptive(light: nsRGBA(120, 120, 128, 0.08), dark: nsRGBA(120, 120, 128, 0.16))
    static let fill2 = adaptive(light: nsRGBA(120, 120, 128, 0.14), dark: nsRGBA(120, 120, 128, 0.26))
    static let fill3 = adaptive(light: nsRGBA(120, 120, 128, 0.22), dark: nsRGBA(120, 120, 128, 0.36))
    static let cardBg = adaptive(light: nsHex(0xffffff), dark: nsHex(0x2c2c30))
    static let cardBorder = adaptive(light: nsRGBA(0, 0, 0, 0.07), dark: nsRGBA(255, 255, 255, 0.075))
    // The app window is a clean solid panel: pure white in light, window-dark in dark.
    static let contentBg = adaptive(light: nsHex(0xffffff), dark: nsHex(0x232326))

    static let corner: CGFloat = 11
    static let pad: CGFloat = 18
    static let gap: CGFloat = 14
    static let mono = Font.system(size: 11.5, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
}

// MARK: - Adaptive color helpers (light/dark, matching design/assets styles.css)

private func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
}

private func nsHex(_ hex: UInt32) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

private func nsRGBA(_ r: Int, _ g: Int, _ b: Int, _ a: Double) -> NSColor {
    NSColor(
        calibratedRed: CGFloat(r) / 255,
        green: CGFloat(g) / 255,
        blue: CGFloat(b) / 255,
        alpha: CGFloat(a)
    )
}

private extension Color {
    /// Create a SwiftUI color from a 0xRRGGBB integer.
    init(hex: UInt32) {
        self.init(nsColor: nsHex(hex))
    }
}

// MARK: - Card wrapper

struct SQCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: SQ.corner, style: .continuous)
                    .fill(SQ.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SQ.corner, style: .continuous)
                    .stroke(SQ.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

// MARK: - Button

struct SQButton: View {
    let title: String
    var icon: String? = nil
    var primary = false
    var danger = false
    var small = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: small ? 11.5 : 13.5, weight: .medium))
                }
                Text(title)
                    .font(.system(size: small ? 12 : 13, weight: .medium))
            }
            .foregroundStyle(primary ? .white : (danger ? SQ.red : SQ.text))
            .padding(.horizontal, small ? 10 : 13)
            .frame(height: small ? 26 : 30)
            .background(
                RoundedRectangle(cornerRadius: small ? 6 : 7, style: .continuous)
                    .fill(primary ? SQ.accent : (danger ? SQ.red.opacity(0.10) : SQ.cardBg))
            )
            .overlay(
                RoundedRectangle(cornerRadius: small ? 6 : 7, style: .continuous)
                    .stroke(primary ? Color.clear : (danger ? SQ.red.opacity(0.22) : SQ.hairlineStrong), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search field

struct SQSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SQ.text3)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(onCommit)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(SQ.fill1))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
        .frame(minWidth: 200)
    }
}

// MARK: - Segmented control (sliding thumb, mirrors prototype)

struct SQSegmented: View {
    let options: [String]
    @Binding var selection: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.26)) { selection = i }
                } label: {
                    Text(options[i])
                        .font(.system(size: 12.5, weight: selection == i ? .semibold : .medium))
                        .foregroundStyle(selection == i ? SQ.text : SQ.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(alignment: .center) {
                            if selection == i {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(SQ.cardBg)
                                    .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
                                    .matchedGeometryEffect(id: "thumb", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SQ.fill1))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
    }
}

// MARK: - Status dot

struct SQStatusDot: View {
    let ok: Bool
    var pulsing = false
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(ok ? SQ.green : SQ.text2)
            .frame(width: 8, height: 8)
            .opacity(pulsing && dim ? 0.4 : 1)
            .overlay(
                Circle().stroke(ok ? SQ.green.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

// MARK: - Pill / badge / chip

struct SQPill: View {
    let text: String
    let ok: Bool
    var body: some View {
        HStack(spacing: 5) {
            SQStatusDot(ok: ok, pulsing: ok)
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 3)
        .foregroundStyle(ok ? Color(red: 0.36, green: 0.78, blue: 0.31) : SQ.text2)
        .background(
            Capsule().fill(ok ? SQ.green.opacity(0.15) : SQ.fill2)
        )
    }
}

struct SQBadge: View {
    let text: String
    var icon: String? = nil
    var accent = false
    var green = false
    var orange = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .foregroundStyle(accent ? SQ.accent : (green ? Color(red: 0.36, green: 0.78, blue: 0.31) : (orange ? SQ.orange : SQ.text2)))
        .background(
            Capsule().fill(accent ? SQ.accent.opacity(0.12) : (green ? SQ.green.opacity(0.15) : (orange ? SQ.orange.opacity(0.15) : SQ.fill2)))
        )
    }
}

struct SQChip: View {
    let text: String
    var accent = false
    var body: some View {
        Text(text)
            .font(SQ.monoSmall)
            .padding(.horizontal, 7)
            .padding(.vertical, 1.5)
            .foregroundStyle(accent ? SQ.accent : SQ.text2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(accent ? SQ.accent.opacity(0.12) : SQ.fill1))
    }
}

// MARK: - Empty state

struct SQEmpty: View {
    let icon: String
    let title: String
    let hint: String
    var buttonTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(SQ.text3)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SQ.fill1))
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(hint)
                .font(.system(size: 12.5))
                .foregroundStyle(SQ.text2)
                .frame(maxWidth: 320)
                .multilineTextAlignment(.center)
            if let buttonTitle {
                SQButton(title: buttonTitle, icon: "plus", primary: true, action: action)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .padding(.horizontal, 20)
    }
}

// MARK: - KV list (2-col grid)

struct SQKV: View {
    let monoValue: Bool
    let rows: [(String, String)]

    init(monoValue: Bool = false, rows: [(String, String)]) {
        self.monoValue = monoValue
        self.rows = rows
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
            ForEach(rows, id: \.0) { k, v in
                GridRow {
                    Text(k)
                        .font(.system(size: 12.5))
                        .foregroundStyle(SQ.text2)
                        .gridColumnAlignment(.leading)
                    Text(v)
                        .font(monoValue ? SQ.mono : .system(size: 12.5))
                        .foregroundStyle(SQ.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Disclosure (details/summary)

struct SQDisclosure<Content: View>: View {
    let title: String
    @State private var open: Bool
    @ViewBuilder var content: () -> Content

    init(_ title: String, open: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        _open = State(initialValue: open)
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.22)) { open.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(SQ.text2)
            }
            .buttonStyle(.plain)
            .padding(.top, 11)
            if open {
                content()
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }
}

// MARK: - Row hover actions

struct SQRowsActions<Content: View>: View {
    @State private var hovering = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 3) { content() }
            .opacity(hovering ? 1 : 0)
            .onHover { hovering = $0 }
    }
}

//
//  GlassEngineView.swift
//  Rclone GUI — Views/Settings
//
//  Écran « Transparence » (Glass Engine) : prouve la revendication « 0 appel
//  maison ». Affiche le verdict live, l'allowlist déclarative complète de tout
//  ce que l'app est conçue pour contacter, les remotes rclone de l'utilisateur
//  (lus depuis config/dump — honnêteté sur la couche Go), un journal live des
//  egress observés, et les garanties (aucun SDK de tracking, pas de push
//  distant, pas de dorsal, build reproductible).
//
//  Cf. `GlassEngine.swift` pour la logique pure et le bus passif `GlassEngineMonitor`.
//

import SwiftUI

struct GlassEngineView: View {
    @ObservedObject private var monitor = GlassEngineMonitor.shared
    @Environment(\.openURL) private var openURL

    @State private var remotes: [RemoteRow] = []
    @State private var remotesLoaded = false

    private let transparencyURL = URL(string: "https://rclone.rougetet.com/transparency.html")!
    private let sourceURL = URL(string: "https://github.com/VitalysRDT/rclone-gui-ios")!

    private struct RemoteRow: Identifiable {
        let name: String
        let type: String
        var id: String { name }
    }

    private var allowlist: [EgressDestination] { GlassEngine.declaredAllowlist() }

    var body: some View {
        List {
            verdictSection
            allowlistSection
            remotesSection
            liveLogSection
            guaranteesSection
        }
        .navigationTitle("Transparency")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadRemotes() }
    }

    // MARK: - Verdict

    private var verdictSection: some View {
        let clean = monitor.verdict.isClean
        return Section {
            HStack(spacing: 14) {
                Image(systemName: clean ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(clean ? Color.green : Color.red)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Appels maison : \(monitor.verdict.homeCallCount)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(clean
                         ? "No calls to custom servers. The app only communicates with your remotes, Apple, and itself."
                         : "An unexpected call was observed — see log below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Glass Engine passively monitors app network calls and categorizes them. Anything that is not your remote, Apple, or the local device counts as a “phone home” call.")
        }
    }

    // MARK: - Allowlist déclarative

    private var allowlistSection: some View {
        Section("What the app is designed to contact") {
            ForEach([EgressCategory.loopback, .apple, .provider], id: \.self) { cat in
                let items = allowlist.filter { $0.category == cat }
                if !items.isEmpty {
                    DisclosureGroup {
                        ForEach(items) { dest in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dest.host).font(.callout.monospaced())
                                Text(dest.purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } label: {
                        Label {
                            Text(cat.displayTitle)
                            Text("\(items.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: cat.icon).foregroundStyle(cat.tint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Remotes de l'utilisateur (couche Go)

    private var remotesSection: some View {
        Section {
            if !remotesLoaded {
                HStack { ProgressView(); Text("Reading rclone configuration…").foregroundStyle(.secondary) }
            } else if remotes.isEmpty {
                Text("No remotes configured yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(remotes) { r in
                    HStack {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .foregroundStyle(.teal)
                        Text(r.name)
                        Spacer()
                        Text(r.type)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Your rclone remotes")
        } footer: {
            Text("librclone ONLY contacts the remotes you configured above. Its traffic exits outside iOS and cannot be intercepted in-app — we declare it here rather than simulate it.")
        }
    }

    // MARK: - Journal live

    private var liveLogSection: some View {
        Section {
            if monitor.events.isEmpty {
                Text("No network calls observed so far.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(monitor.events.suffix(60).reversed()) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(e.category.tint).frame(width: 9, height: 9).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(e.host).font(.callout.monospaced())
                                Spacer()
                                Text(e.date, style: .time)
                                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                            }
                            Text(e.purpose).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Live log")
                Spacer()
                if !monitor.events.isEmpty {
                    ShareLink(item: monitor.exportText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        monitor.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("What the app emits via URLSession (OAuth token exchanges, local bridge). Native rclone traffic is not included — see “Your remotes”.")
        }
    }

    // MARK: - Garanties

    private var guaranteesSection: some View {
        Section("Guarantees") {
            guaranteeRow("No analytics, crash-reporting, or advertising SDKs")
            guaranteeRow("No remote push notifications (no APNs, no device token)")
            guaranteeRow("No backend server: trial, subscription, and config stay on device / iCloud / Apple")
            guaranteeRow("Reproducible build: the native rclone binary can be verified by third parties")

            Button {
                openURL(transparencyURL)
            } label: {
                Label("How to check for yourself", systemImage: "checkmark.seal")
            }
            Button {
                openURL(sourceURL)
            } label: {
                Label("Source code (GitHub)", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    private func guaranteeRow(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).font(.callout)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }

    // MARK: - Chargement

    private func loadRemotes() async {
        do {
            let dump = try await RcloneCore.shared.configDump()
            remotes = dump
                .map { RemoteRow(name: $0.key, type: $0.value["type"] ?? "?") }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            remotes = []
        }
        remotesLoaded = true
    }
}

// MARK: - Affichage des catégories

private extension EgressCategory {
    var displayTitle: LocalizedStringKey {
        switch self {
        case .loopback:   return "On device (loopback)"
        case .provider:   return "Cloud providers (your accounts)"
        case .apple:      return "Apple"
        case .userRemote: return "Your remotes"
        case .home:       return "Phone-home calls"
        }
    }

    var tint: Color {
        switch self {
        case .loopback:   return .green
        case .provider:   return .blue
        case .apple:      return .gray
        case .userRemote: return .teal
        case .home:       return .red
        }
    }

    var icon: String {
        switch self {
        case .loopback:   return "iphone"
        case .provider:   return "cloud"
        case .apple:      return "apple.logo"
        case .userRemote: return "externaldrive.connected.to.line.below"
        case .home:       return "exclamationmark.triangle.fill"
        }
    }
}

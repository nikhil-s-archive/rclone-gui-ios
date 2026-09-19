//
//  RoadmapView.swift
//  Rclone GUI — Views/Settings
//
//  Compact "what's coming" screen with target dates. The full, continuously-
//  evolving roadmap lives on the website (rclone.rougetet.com/#roadmap) so it
//  can change without an App Store update; here we surface the headline items
//  per horizon with their target date and link out. Dates are locale-neutral
//  (numeric month/year, Qn) so they need no translation. Stays on-brand:
//  privacy-first, open source, no backend.
//

import SwiftUI

struct RoadmapView: View {
    @Environment(\.openURL) private var openURL
    private let fullURL = URL(string: "https://rclone.rougetet.com/#roadmap")!

    private struct Item: Identifiable {
        let id = UUID()
        let name: LocalizedStringKey
        let date: String   // locale-neutral, e.g. "07/2026", "Q1 2027"
        var done: Bool = false
    }

    var body: some View {
        List {
            Section {
                Text("What's coming to Rclone GUI. Everything stays privacy-first, open source and serverless.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            horizon(label: "Short term", window: "07–09 / 2026", tint: .green, items: [
                Item(name: "Pro Transfers", date: "07/2026"),
                Item(name: "Flows", date: "07/2026"),
                Item(name: "Ghost Vault", date: "08/2026"),
                Item(name: "P2P Handoff", date: "08/2026"),
                Item(name: "Glass Engine", date: "09/2026"),
            ])
            horizon(label: "Mid term", window: "10–12 / 2026", tint: .blue, items: [
                Item(name: "Remote Lens", date: "10/2026", done: true),
                Item(name: "Sealed Share", date: "10/2026"),
                Item(name: "On-device semantic search", date: "11/2026"),
                Item(name: "Sync rules", date: "11/2026"),
                Item(name: "Travel Mode", date: "12/2026"),
            ])
            horizon(label: "Long term", window: "2027", tint: .purple, items: [
                Item(name: "ChronoDrive", date: "Q1 2027"),
                Item(name: "Ghost Sync", date: "Q1 2027"),
                Item(name: "Quantum Vault", date: "Q2 2027"),
                Item(name: "Digital legacy", date: "Q2 2027"),
                Item(name: "CipherSpace", date: "Q3 2027"),
            ])

            Section {
                Button {
                    openURL(fullURL)
                } label: {
                    Label("See the full roadmap", systemImage: "safari")
                }
            } footer: {
                Text("Target dates, subject to change.")
            }
        }
        .navigationTitle("Roadmap")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func horizon(label: LocalizedStringKey, window: String, tint: Color, items: [Item]) -> some View {
        Section {
            ForEach(items) { it in
                HStack(spacing: 10) {
                    if it.done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Text(it.name)
                        .font(.callout)
                        .foregroundStyle(it.done ? .secondary : .primary)
                    Spacer(minLength: 8)
                    Text(it.done ? String(localized: "Delivered") : it.date)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(it.done ? .green : .secondary)
                }
            }
        } header: {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Text(window)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.18), in: Capsule())
                    .foregroundStyle(tint)
                    .textCase(nil)
            }
        }
    }
}

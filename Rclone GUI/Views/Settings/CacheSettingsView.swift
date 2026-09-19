//
//  CacheSettingsView.swift
//  Rclone GUI — Views/Settings
//

import SwiftUI

struct CacheSettingsView: View {
    @AppStorage("cache.maxSizeGB") private var maxSizeGB: Double = 5.0
    @State private var currentBytes: Int64 = 0
    @State private var purging = false
    @State private var error: String?
    @State private var success: String?

    var body: some View {
        Form {
            Section {
                CacheHeaderCard(currentBytes: currentBytes, maxSizeGB: maxSizeGB)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Files downloaded temporarily for playback. You can purge them at any time.")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max size")
                        Spacer()
                        Text("\(Int(maxSizeGB)) Go")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $maxSizeGB, in: 1...50, step: 1) {
                        Text("Max cache")
                    }
                }
            } footer: {
                Text("When the cache exceeds this size, the least recently played files are deleted automatically first (LRU).")
            }

            Section {
                Button(role: .destructive) {
                    Task { await purge() }
                } label: {
                    if purging {
                        HStack { ProgressView(); Text("Erasing…") }
                    } else {
                        Label("Clear cache now", systemImage: "trash")
                    }
                }
                .disabled(purging || currentBytes == 0)
            } footer: {
                if let error {
                    Text(error).foregroundStyle(.red)
                } else if let success {
                    Text(success).foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Cache")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .task {
            // Synchronise la limite LRU du service avec le réglage de l'UI
            // (sources de vérité distinctes) puis affiche la taille courante.
            await MediaCacheService.shared.setMaxSizeBytes(bytes(forGB: maxSizeGB))
            await refreshSize()
        }
        .onChange(of: maxSizeGB) { _, newValue in
            // L'utilisateur ajuste la limite : on l'applique au service et on
            // évince immédiatement si le cache dépasse déjà la nouvelle taille.
            Task {
                await MediaCacheService.shared.setMaxSizeBytes(bytes(forGB: newValue))
                try? await MediaCacheService.shared.evictIfNeeded()
                await refreshSize()
            }
        }
    }

    private func bytes(forGB gb: Double) -> Int64 {
        Int64(gb) * 1_073_741_824
    }

    private func refreshSize() async {
        currentBytes = (try? await MediaCacheService.shared.currentSize()) ?? 0
    }

    private func purge() async {
        purging = true
        defer { purging = false }
        do {
            try await MediaCacheService.shared.purge()
            success = "Cache effacé."
            error = nil
        } catch {
            self.error = error.localizedDescription
            success = nil
        }
        await refreshSize()
    }

    private func humanSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct CacheHeaderCard: View {
    let currentBytes: Int64
    let maxSizeGB: Double

    var body: some View {
        AppHeroCard(
            title: "Media cache",
            subtitle: "Smoother playback, local purge and LRU limit.",
            systemImage: "tray.full",
            tint: .orange
        ) {
            HStack(spacing: 10) {
                AppMetricPill(value: humanSize(currentBytes), label: "used", systemImage: "internaldrive", tint: .orange)
                AppMetricPill(value: "\(Int(maxSizeGB)) Go", label: "Limit", systemImage: "gauge.with.dots.needle.67percent", tint: .blue)
            }
        }
    }

    private func humanSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

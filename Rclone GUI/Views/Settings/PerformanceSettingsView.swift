//
//  PerformanceSettingsView.swift
//  Rclone GUI — Views/Settings
//
//  User-tunable bandwidth ceiling and global pause for the transfer queue.
//  The persisted value is in MB/s (Double, 0 = unlimited). The view applies
//  it through TransferQueue.applyBandwidthLimit on every change so the
//  setting takes effect immediately without app restart.
//

import Combine
import SwiftUI

struct PerformanceSettingsView: View {
    /// Bandwidth ceiling stored in MB/s. 0 means "no limit" (rclone rate "off").
    /// Granularity 0.5 MB/s — fine enough for cellular tuning, coarse enough
    /// to keep the slider readable.
    @AppStorage("transfer.bandwidthLimitMBps") private var bandwidthLimitMBps: Double = 0
    /// File d'attente (Transferts Pro) : nb max de transferts simultanés.
    @AppStorage("transfer.maxConcurrentTransfers") private var maxConcurrent: Int = 3
    /// Suspend les transferts en cellulaire (et Wi-Fi bridé).
    @AppStorage("transfer.pauseOnCellular") private var pauseOnCellular: Bool = false
    /// Limite de bande passante distincte appliquée en cellulaire (0 = illimité).
    @AppStorage("transfer.cellularLimitMBps") private var cellularLimitMBps: Double = 0
    /// Mode Auto : la concurrence de la file est décidée automatiquement selon
    /// le réseau et l'énergie (AutoTransferPolicy). OFF → le Stepper manuel
    /// et sa clé reprennent la main à l'identique.
    @AppStorage(AutoTransferPolicy.autoModeEnabledKey) private var autoMode: Bool = true

    @State private var isPaused = false
    @State private var transientMessage: String?
    @State private var isApplying = false
    /// Résumé affiché en mode Auto (« 4 · connexion rapide »). Rafraîchi sur
    /// les mêmes évènements que la décision (réseau, thermique, mode éco).
    @State private var autoSummary = ""

    static let maxMBps: Double = 100  // 100 MB/s ≈ Gigabit ceiling — beyond user's
                                      // realistic LTE/Wi-Fi needs without making
                                      // the slider unreadable.

    var body: some View {
        Form {
            Section {
                bandwidthCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Limit")
                            .font(.subheadline)
                        Spacer()
                        Text(rateLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $bandwidthLimitMBps,
                        in: 0...Self.maxMBps,
                        step: 0.5
                    ) {
                        Text("Bandwidth limit")
                    } minimumValueLabel: {
                        Text("0").font(.caption2).foregroundStyle(.tertiary)
                    } maximumValueLabel: {
                        Text("\(Int(Self.maxMBps))").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .onChange(of: bandwidthLimitMBps) { _, newValue in
                        Task { await applyBandwidthLimit(mbps: newValue) }
                    }
                    .accessibilityValue(rateLabel)
                    .accessibilityHint("Drag to adjust the global bandwidth limit in MB/s. Zero means no limit.")
                }
                .padding(.vertical, 4)
            } header: {
                Text("Global limit")
            } footer: {
                Text("0 MB/s = unlimited. The limit applies to all rclone operations (upload + download). Ideal to save battery or avoid saturating a cellular connection.")
            }

            Section("Global pause") {
                Toggle(isOn: Binding(
                    get: { isPaused },
                    set: { newValue in
                        Task { await togglePause(to: newValue) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPaused ? "All transfers paused" : "Active transfers")
                            .font(.body.weight(.medium))
                        Text(isPaused
                             ? "Running jobs keep their slots and will resume when you do."
                             : "Pausing immediately stops throughput without cancelling jobs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isApplying)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { autoMode },
                    set: { newValue in
                        autoMode = newValue
                        // Réévalue immédiatement : la décision Auto (ou le
                        // réglage manuel restauré) s'applique sans redémarrage.
                        TransferQueue.shared.refreshAutoPolicy()
                        TransferQueue.shared.scheduleNext()
                        refreshAutoSummary()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic management")
                            .font(.body.weight(.medium))
                        Text("Adjusts the number of simultaneous transfers based on network, heat and battery.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if autoMode {
                    HStack {
                        Text("Simultaneous transfers")
                        Spacer()
                        // verbatim : nombre + libellé déjà localisé, pas de clé à
                        // extraire. @State (et non lecture directe du singleton) :
                        // TransferQueue n'est pas Observable — sans ça la ligne
                        // resterait figée quand la décision change écran ouvert.
                        Text(verbatim: autoSummary)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Stepper(value: Binding(
                        get: { maxConcurrent },
                        set: { newValue in
                            maxConcurrent = newValue
                            TransferQueue.shared.setMaxConcurrent(newValue)
                        }
                    ), in: 1...8) {
                        HStack {
                            Text("Simultaneous transfers")
                            Spacer()
                            Text("\(maxConcurrent)")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Queue")
            } footer: {
                // Deux Text littéraux distincts (pas un ternaire de String) pour
                // rester sur LocalizedStringKey → clés extraites dans le catalogue.
                if autoMode {
                    Text("Wi-Fi: 4 · Cellular: 2 · Low Power or heat: 1-2 · Critical overheating: 1. Small files go first, and an offline failure resumes on its own when the network returns. Your manual settings are kept and restored if you turn off automatic mode.")
                } else {
                    Text("Maximum number of concurrent downloads/uploads. Remaining transfers wait in the queue and start automatically as slots open.")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { pauseOnCellular },
                    set: { newValue in
                        pauseOnCellular = newValue
                        Task { await TransferQueue.shared.applyNetworkPolicy() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause on cellular")
                            .font(.body.weight(.medium))
                        Text("Suspends transfers on cellular data (and Low Data Mode Wi-Fi). They automatically resume on Wi-Fi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !pauseOnCellular {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Cellular limit")
                                .font(.subheadline)
                            Spacer()
                            Text(cellularRateLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { cellularLimitMBps },
                            set: { newValue in
                                cellularLimitMBps = newValue
                                Task { await TransferQueue.shared.applyNetworkPolicy() }
                            }
                        ), in: 0...Self.maxMBps, step: 0.5)
                        .accessibilityValue(cellularRateLabel)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Cellular network")
            } footer: {
                Text("Separate limit applied when the device is on cellular. 0 MB/s = unlimited.")
            }
        }
        .navigationTitle("Performance")
        .alert("Info", isPresented: Binding(
            get: { transientMessage != nil },
            set: { if !$0 { transientMessage = nil } }
        )) {
            Button("OK", role: .cancel) { transientMessage = nil }
        } message: {
            Text(transientMessage ?? "")
        }
        .task {
            // Reflect the live queue state on appearance. The launch task in
            // Rclone_GUIApp already replayed the persisted pause/bwlimit state
            // through restoreFromPersistedState; we just mirror the resulting
            // isPausedGlobally into the local Toggle binding.
            isPaused = TransferQueue.shared.isPausedGlobally
            refreshAutoSummary()
        }
        // Suit les mêmes évènements que refreshAutoPolicy pour que la ligne
        // « Transferts simultanés » reste juste écran ouvert (bascule Wi-Fi →
        // cellulaire, chauffe…). receive(on:) : les notifications thermique/
        // énergie peuvent arriver hors main thread.
        .onReceive(NotificationCenter.default.publisher(for: .networkPathDidChange).receive(on: RunLoop.main)) { _ in
            refreshAutoSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification).receive(on: RunLoop.main)) { _ in
            refreshAutoSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            refreshAutoSummary()
        }
    }

    /// Réévalue la décision Auto (idempotente) puis recopie le résumé dans le
    /// @State — TransferQueue n'est pas Observable, c'est ce @State qui rend
    /// la ligne réactive.
    private func refreshAutoSummary() {
        TransferQueue.shared.refreshAutoPolicy()
        autoSummary = "\(TransferQueue.shared.maxConcurrent) · \(TransferQueue.shared.currentAutoDecision.reason.localizedLabel)"
    }

    // MARK: - Actions

    private func applyBandwidthLimit(mbps: Double) async {
        isApplying = true
        defer { isApplying = false }
        let bytesPerSecond = Int64(mbps * 1024 * 1024)
        do {
            try await TransferQueue.shared.applyBandwidthLimit(bytesPerSecond: bytesPerSecond)
        } catch {
            transientMessage = "Échec de l'application de la limite : \(error.localizedDescription)"
        }
    }

    private func togglePause(to newValue: Bool) async {
        isApplying = true
        defer { isApplying = false }
        do {
            if newValue {
                try await TransferQueue.shared.pauseAllTransfers()
            } else {
                let bytesPerSecond = Int64(bandwidthLimitMBps * 1024 * 1024)
                try await TransferQueue.shared.resumeAllTransfers(bytesPerSecond: bytesPerSecond)
            }
            isPaused = newValue
        } catch {
            transientMessage = "Échec : \(error.localizedDescription)"
            // Don't flip the toggle — leave it in the previous position so
            // the user knows the action didn't go through.
            isPaused = TransferQueue.shared.isPausedGlobally
        }
    }

    // MARK: - Derived

    private var rateLabel: String {
        if bandwidthLimitMBps <= 0 { return String(localized: "Unlimited") }
        if bandwidthLimitMBps < 1 {
            return "\(Int(bandwidthLimitMBps * 1024)) KB/s"
        }
        return String(format: "%.1f MB/s", bandwidthLimitMBps)
    }

    private var cellularRateLabel: String {
        if cellularLimitMBps <= 0 { return String(localized: "Unlimited") }
        if cellularLimitMBps < 1 {
            return "\(Int(cellularLimitMBps * 1024)) KB/s"
        }
        return String(format: "%.1f MB/s", cellularLimitMBps)
    }

    @ViewBuilder
    private var bandwidthCard: some View {
        HStack(spacing: 14) {
            AppIconTile(systemImage: "speedometer", tint: .indigo, size: 54, iconSize: .title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(isPaused ? "Paused" : rateLabel)
                    .font(.headline)
                Text("Global limit applied to all rclone operations (upload + download).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary)
        }
    }
}

//
//  PhotoSyncStatsView.swift
//  Rclone GUI — Views/Settings
//
//  Vue dédiée aux statistiques détaillées de la sync photo : graphique débit
//  en temps réel, distribution des statuts, compteurs d'intégrité.
//

import Charts
import SwiftData
import SwiftUI

struct PhotoSyncStatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var summary: PhotoSyncRunSummary?
    @State private var throughputPoints: [ThroughputPoint] = []
    @State private var hashCounts = HashCounts()

    var body: some View {
        Form {
            Section {
                if let summary {
                    LabeledContent("Total to transfer", value: formatBytes(summary.totalBytes))
                    LabeledContent("Already transferred", value: formatBytes(summary.transferredBytes))
                    LabeledContent("Instant throughput", value: formatThroughput(summary.averageBytesPerSecond))
                    if let eta = summary.estimatedTimeRemaining, eta > 0 {
                        LabeledContent("Estimated time", value: formatETA(eta))
                    }
                } else {
                    Text("No data yet.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Overall status")
            }

            Section {
                if throughputPoints.count >= 2 {
                    Chart(throughputPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Throughput", point.bytesPerSecond / 1024)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(RG.photoSync.accent)
                        // Aire = accent doux pour cohérence avec le reste de l'app
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Throughput", point.bytesPerSecond / 1024)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.pink.opacity(0.15))
                    }
                    .chartYAxisLabel("KB/s")
                    .frame(height: 180)
                } else {
                    Text("The chart will appear as soon as throughput is measured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Throughput (30 s window)")
            }

            if let summary {
                Section {
                    Chart {
                        BarMark(
                            x: .value("Status", "Waiting"),
                            y: .value("Count", summary.pendingCount)
                        )
                        .foregroundStyle(.orange)
                        BarMark(
                            x: .value("Status", "In progress"),
                            y: .value("Count", summary.activeCount)
                        )
                        .foregroundStyle(.blue)
                        BarMark(
                            x: .value("Status", "Completed"),
                            y: .value("Count", summary.completedCount)
                        )
                        .foregroundStyle(.green)
                        BarMark(
                            x: .value("Status", "Failures"),
                            y: .value("Count", summary.failedCount)
                        )
                        .foregroundStyle(.red)
                        BarMark(
                            x: .value("Status", "Ignorés"),
                            y: .value("Count", summary.skippedCount)
                        )
                        .foregroundStyle(.gray)
                    }
                    .frame(height: 180)
                } header: {
                    Text("Distribution by status")
                }
            }

            Section {
                LabeledContent("Verified", value: "\(hashCounts.verified)")
                LabeledContent("Remote hash missing", value: "\(hashCounts.unsupported)")
                LabeledContent("Mismatches", value: "\(hashCounts.mismatch)")
                LabeledContent("Not found on remote", value: "\(hashCounts.missing)")
            } header: {
                Text("Integrity (MD5)")
            } footer: {
                Text("Verification runs automatically after each successful upload. A mismatch indicates corruption during transfer — the asset stays marked complete, but should be re-uploaded manually.")
            }
        }
        .navigationTitle("Statistics")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .task {
            await reload()
            // Live refresh tant que la vue est affichée.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await reload()
            }
        }
    }

    private func reload() async {
        summary = await PhotoSyncService.shared.currentSummary()
        throughputPoints = PhotoSyncService.shared.throughputHistory()
            .map { ThroughputPoint(date: $0.date, bytesPerSecond: $0.bytesPerSecond) }
        hashCounts = HashCounts(modelContext: modelContext)
    }

    private func formatBytes(_ bytes: Int64) -> String { PhotoSyncFormat.bytes(bytes) }
    private func formatThroughput(_ bps: Double) -> String { PhotoSyncFormat.throughput(bps) }
    private func formatETA(_ seconds: TimeInterval) -> String { PhotoSyncFormat.eta(seconds) }
}

private struct ThroughputPoint: Identifiable {
    let date: Date
    let bytesPerSecond: Double
    var id: Date { date }
}

private struct HashCounts {
    var verified = 0
    var mismatch = 0
    var missing = 0
    var unsupported = 0

    init() {}

    init(modelContext: ModelContext) {
        verified = Self.count(in: modelContext, status: "verified")
        mismatch = Self.count(in: modelContext, status: "mismatch")
        missing = Self.count(in: modelContext, status: "missing")
        unsupported = Self.count(in: modelContext, status: "unsupported")
    }

    private static func count(in modelContext: ModelContext, status: String) -> Int {
        let descriptor = FetchDescriptor<PhotoSyncAsset>(
            predicate: #Predicate { $0.verificationStatus == status }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}

#Preview {
    NavigationStack {
        PhotoSyncStatsView()
    }
}

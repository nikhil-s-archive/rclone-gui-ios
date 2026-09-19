//
//  PhotoSyncFiltersView.swift
//  Rclone GUI — Views/Settings
//
//  Lets the user restrict which Photos library assets get backed up. Maps
//  directly to `PhotoSyncService.filters` (PhotoSyncFilters JSON in UserDefaults).
//

import SwiftUI

struct PhotoSyncFiltersView: View {
    @State private var filters: PhotoSyncFilters = .allEnabled
    @State private var useDateRange = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var useMaxDuration = false
    @State private var maxDurationMinutes: Double = 10

    var body: some View {
        Form {
            Section {
                Toggle("Photos", isOn: $filters.includePhotos)
                Toggle("Videos", isOn: $filters.includeVideos)
            } header: {
                Text("Main types")
            } footer: {
                Text("Unchecking excludes the category entirely. At least one must stay checked for the sync to have something to do.")
            }

            Section {
                Toggle("Live Photos", isOn: $filters.includeLivePhotos)
                    .disabled(!filters.includePhotos)
                Toggle("Screenshots", isOn: $filters.includeScreenshots)
                    .disabled(!filters.includePhotos)
                Toggle("Panoramas", isOn: $filters.includePanoramas)
                    .disabled(!filters.includePhotos)
                Toggle("Slow-mo / time-lapse", isOn: $filters.includeSlowMo)
                    .disabled(!filters.includeVideos)
            } header: {
                Text("Subtypes")
            } footer: {
                Text("A Live Photo is still a photo: unchecking the option doesn’t remove the main photo, it just ignores the linked video component.")
            }

            Section {
                Toggle("Filter by dates", isOn: $useDateRange)
                if useDateRange {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            } header: {
                Text("Date range")
            } footer: {
                Text("Only photos taken between these two dates will be indexed by the next sync.")
            }

            Section {
                Toggle("Limit video duration", isOn: $useMaxDuration)
                if useMaxDuration {
                    HStack {
                        Slider(value: $maxDurationMinutes, in: 1...120, step: 1)
                        Text("\(Int(maxDurationMinutes)) min")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            } header: {
                Text("Size (video duration)")
            } footer: {
                Text("Videos longer than this threshold are skipped. Photos are not affected (they’re always small).")
            }

            Section {
                Button {
                    resetToDefaults()
                } label: {
                    Label("Re-enable all (reset)", systemImage: "arrow.uturn.backward")
                }
                .disabled(filters.isDefault && !useDateRange && !useMaxDuration)
            } footer: {
                let n = filters.activeCount
                if n == 0 {
                    Text("No active filter — the entire library is eligible.")
                } else {
                    Text("\(n) filtre(s) actif(s). Les changements s'appliquent à la prochaine synchro.")
                }
            }
        }
        .navigationTitle("Filters")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .task {
            load()
        }
        .onChange(of: filters) { _, _ in save() }
        .onChange(of: useDateRange) { _, _ in syncDateRangeToFilters(); save() }
        .onChange(of: startDate) { _, _ in syncDateRangeToFilters(); save() }
        .onChange(of: endDate) { _, _ in syncDateRangeToFilters(); save() }
        .onChange(of: useMaxDuration) { _, _ in syncMaxDurationToFilters(); save() }
        .onChange(of: maxDurationMinutes) { _, _ in syncMaxDurationToFilters(); save() }
    }

    private func load() {
        let current = PhotoSyncService.shared.filters
        filters = current
        if let start = current.dateRangeStart {
            startDate = start
            useDateRange = true
        }
        if let end = current.dateRangeEnd {
            endDate = end
            useDateRange = true
        }
        if let seconds = current.maxVideoDurationSeconds, seconds > 0 {
            maxDurationMinutes = max(1, seconds / 60)
            useMaxDuration = true
        }
    }

    private func save() {
        PhotoSyncService.shared.filters = filters
    }

    private func syncDateRangeToFilters() {
        if useDateRange {
            filters.dateRangeStart = startDate
            filters.dateRangeEnd = endDate
        } else {
            filters.dateRangeStart = nil
            filters.dateRangeEnd = nil
        }
    }

    private func syncMaxDurationToFilters() {
        if useMaxDuration {
            filters.maxVideoDurationSeconds = maxDurationMinutes * 60
        } else {
            filters.maxVideoDurationSeconds = nil
        }
    }

    private func resetToDefaults() {
        filters = .allEnabled
        useDateRange = false
        useMaxDuration = false
        save()
    }
}

#Preview {
    NavigationStack {
        PhotoSyncFiltersView()
    }
}

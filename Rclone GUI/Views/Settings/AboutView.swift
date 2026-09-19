//
//  AboutView.swift
//  Rclone GUI — Views/Settings
//

import SwiftUI

struct AboutView: View {
    @State private var rcloneVersion: String = "—"

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("Versions") {
                LabeledContent("Rclone GUI", value: appVersion)
                LabeledContent("rclone (librclone)", value: rcloneVersion)
            }

            Section("Links") {
                Link(destination: URL(string: "https://rclone.rougetet.com")!) {
                    Label("rclone.rougetet.com", systemImage: "globe")
                }
                Link(destination: URL(string: "https://rclone.rougetet.com/transparency.html")!) {
                    Label("Transparency & Privacy", systemImage: "lock.shield")
                }
                Link(destination: URL(string: "https://github.com/VitalysRDT/rclone-gui-ios")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://rclone.org")!) {
                    Label("rclone.org", systemImage: "globe")
                }
                Link(destination: URL(string: "https://forum.rclone.org")!) {
                    Label("rclone community forum", systemImage: "person.3")
                }
                Link(destination: URL(string: "https://github.com/rclone/rclone")!) {
                    Label("rclone source code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://code.videolan.org/videolan/VLCKit")!) {
                    Label("VLCKit (libVLC) source code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Section("Credits") {
                Text("Built with rclone and SwiftUI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Multi-format playback powered by VLCKit / libVLC (VideoLAN), licensed under LGPL v2.1. VLCKit's source code is available via the link above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .task {
            do {
                rcloneVersion = try await RcloneCore.shared.version()
            } catch {
                rcloneVersion = "ERR : \(error.localizedDescription)"
            }
        }
    }
}

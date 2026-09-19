//
//  PublicLinkSheet.swift
//  Rclone GUI — Views/Folders
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PublicLinkSheet: View {
    @Environment(\.dismiss) private var dismiss

    let remote: String
    let entry: RemoteEntryDTO

    @State private var customBaseURL = ""
    @State private var pathPrefixToRemove = ""
    @State private var nativeURL: URL?
    @State private var supportsNativeLink: Bool?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var confirmationMessage: String?

    private var customURL: URL? {
        guard let baseURL = PublicLinkFormatter.normalizedBaseURL(from: customBaseURL) else {
            return nil
        }
        return PublicLinkFormatter.customURL(
            baseURL: baseURL,
            remotePath: entry.pathInRemote,
            removingPathPrefix: pathPrefixToRemove
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let customURL {
                    linkSection(title: "Custom CDN link", url: customURL)
                }

                Section {
                    urlTextField
                    TextField("Path prefix to remove (optional)", text: $pathPrefixToRemove)
                        .autocorrectionDisabled(true)

                    HStack {
                        Button("Save") { saveCustomDomain() }
                            .buttonStyle(.borderedProminent)
                        if !customBaseURL.isEmpty {
                            Button("Erase", role: .destructive) {
                                customBaseURL = ""
                                pathPrefixToRemove = ""
                                _ = RemotePublicLinkSettingsStore.setCustomBaseURL("", for: remote)
                                _ = RemotePublicLinkSettingsStore.setPathPrefixToRemove("", for: remote)
                                confirmationMessage = String(localized: "CDN domain deleted.")
                            }
                        }
                    }
                } header: {
                    Text("Domaine CDN de \(remote)")
                } footer: {
                    Text("The domain must point to the public root of this remote or bucket. The app automatically appends the file path; it does not alter storage permissions. If the path starts with a bucket prefix, enter it in the optional field to remove it from the CDN URL.")
                }

                Section {
                    if let nativeURL {
                        linkActions(url: nativeURL)
                    } else if supportsNativeLink == nil {
                        HStack {
                            ProgressView()
                            Text("Checking compatibility…")
                        }
                    } else if supportsNativeLink == true {
                        Button {
                            Task { await generateNativeLink() }
                        } label: {
                            Label {
                                Text(isGenerating
                                     ? String(localized: "Generating…")
                                     : String(localized: "Generate via rclone"))
                            } icon: {
                                Image(systemName: "link.badge.plus")
                            }
                        }
                        .disabled(isGenerating)
                    } else {
                        Label(
                            "This backend does not report public link creation support. Configure a CDN domain above.",
                            systemImage: "info.circle"
                        )
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Rclone public link")
                } footer: {
                    Text("Depending on the provider, generating this link may make the file accessible to anyone with the URL.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let confirmationMessage {
                    Section {
                        Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Public link")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Completed") { dismiss() }
                }
            }
        }
        .task {
            customBaseURL = RemotePublicLinkSettingsStore.customBaseURL(for: remote)
            pathPrefixToRemove = RemotePublicLinkSettingsStore.pathPrefixToRemove(for: remote)
            supportsNativeLink = await RemoteService.shared.supportsPublicLink(remote: remote)
        }
    }

    @ViewBuilder
    private var urlTextField: some View {
        let field = TextField("https://img.example.com", text: $customBaseURL)
            .textContentType(.URL)
            .autocorrectionDisabled(true)
        #if os(iOS)
        field
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        #else
        field
        #endif
    }

    private func linkSection(title: LocalizedStringKey, url: URL) -> some View {
        Section(title) {
            linkActions(url: url)
        }
    }

    private func linkActions(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(url.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    copy(url.absoluteString, confirmation: String(localized: "Link copied."))
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }

                Button {
                    copy(
                        PublicLinkFormatter.markdown(
                            url: url,
                            name: entry.name,
                            isDirectory: entry.isDirectory
                        ),
                        confirmation: String(localized: "Markdown copied.")
                    )
                } label: {
                    Label("Copy as Markdown", systemImage: "text.badge.checkmark")
                }

                Button {
                    copy(
                        PublicLinkFormatter.html(
                            url: url,
                            name: entry.name,
                            isDirectory: entry.isDirectory
                        ),
                        confirmation: String(localized: "HTML copied.")
                    )
                } label: {
                    Label("Copy as HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .buttonStyle(.bordered)

            ShareLink(item: url) {
                Label("Share link", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func saveCustomDomain() {
        errorMessage = nil
        confirmationMessage = nil
        guard let stored = RemotePublicLinkSettingsStore.setCustomBaseURL(customBaseURL, for: remote) else {
            errorMessage = String(localized: "Enter a valid HTTP(S) domain, without credentials.")
            return
        }
        customBaseURL = stored
        pathPrefixToRemove = RemotePublicLinkSettingsStore.setPathPrefixToRemove(
            pathPrefixToRemove,
            for: remote
        )
        confirmationMessage = stored.isEmpty
            ? String(localized: "CDN domain deleted.")
            : String(localized: "CDN domain saved.")
    }

    @MainActor
    private func generateNativeLink() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        confirmationMessage = nil
        defer { isGenerating = false }
        do {
            nativeURL = try await RemoteService.shared.createPublicLink(
                remote: remote,
                path: entry.pathInRemote
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copy(_ value: String, confirmation: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
        errorMessage = nil
        confirmationMessage = confirmation
    }
}

struct RemotePublicLinkSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let remote: String

    @State private var customBaseURL = ""
    @State private var pathPrefixToRemove = ""
    @State private var errorMessage: String?
    @State private var supportsNativeLink: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://img.example.com", text: $customBaseURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled(true)
                    TextField("Path prefix to remove (optional)", text: $pathPrefixToRemove)
                        .autocorrectionDisabled(true)
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                } header: {
                    Text("Custom CDN domain")
                } footer: {
                    Text("Ce domaine est enregistré uniquement sur cet appareil pour le remote « \(remote) ». Il doit déjà servir publiquement la racine du bucket. Pour Qiniu Kodo ou un autre backend qui renvoie le bucket dans le chemin, saisis ici le préfixe à retirer, par exemple `aab`.")
                }

                Section("Native rclone link") {
                    if supportsNativeLink == nil {
                        ProgressView()
                    } else {
                        Label {
                            Text(supportsNativeLink == true
                                 ? String(localized: "This backend supports public links.")
                                 : String(localized: "This backend does not report support for public links."))
                        } icon: {
                            Image(systemName: supportsNativeLink == true ? "checkmark.circle.fill" : "info.circle")
                        }
                        .foregroundStyle(
                            supportsNativeLink == true
                                ? AnyShapeStyle(.green)
                                : AnyShapeStyle(.secondary)
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Liens publics · \(remote)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Completed") { dismiss() }
                }
            }
        }
        .task {
            customBaseURL = RemotePublicLinkSettingsStore.customBaseURL(for: remote)
            pathPrefixToRemove = RemotePublicLinkSettingsStore.pathPrefixToRemove(for: remote)
            supportsNativeLink = await RemoteService.shared.supportsPublicLink(remote: remote)
        }
    }

    private func save() {
        guard let stored = RemotePublicLinkSettingsStore.setCustomBaseURL(customBaseURL, for: remote) else {
            errorMessage = String(localized: "Enter a valid HTTP(S) domain, without credentials.")
            return
        }
        customBaseURL = stored
        pathPrefixToRemove = RemotePublicLinkSettingsStore.setPathPrefixToRemove(
            pathPrefixToRemove,
            for: remote
        )
        errorMessage = nil
        dismiss()
    }
}

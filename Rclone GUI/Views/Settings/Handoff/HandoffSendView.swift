//
//  HandoffSendView.swift
//  Rclone GUI — Views/Settings/Handoff
//
//  Wizard « Handoff P2P — envoyer » :
//   1. Aperçu de la config locale + bouton « Préparer le Handoff »
//      (FaceID via HandoffSendService.prepare).
//   2. Une fois scellé : QR code (si le payload tient), gros panel
//      « Code de récupération » avec les 6 mots Diceware, boutons
//      « Partager via AirDrop » / « Copier le payload » / « Enregistrer ».
//      Au premier envoi, un dialog demande de confirmer que les 6 mots
//      ont été notés (gate de sécurité, boutons jamais grisés).
//   3. Si le payload dépasse la capacité single-QR (très grosse
//      config), on masque le QR et on expose uniquement les
//      alternatives.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HandoffSendView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .intro
    @State private var preparing = false
    @State private var prepared: HandoffPrepared?
    @State private var error: String?
    @State private var passphraseRevealed = false
    @State private var passphraseAcknowledged = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var toast: AppToast?
    @State private var pendingTransport: Transport?
    @State private var showPassphraseConfirm = false

    enum Step: Equatable {
        case intro
        case sealed
    }

    enum Transport {
        case airdrop
        case clipboard
        case file
    }

    var body: some View {
        Form {
            switch step {
            case .intro:
                introSection
            case .sealed:
                sealedSection
            }

            if let error {
                Section {
                    AppInlineMessage(
                        title: "Unable to prepare Handoff",
                        message: LocalizedStringKey(error),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                }
            }
        }
        .navigationTitle("Send")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(preparing)
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showShare) {
            HandoffShareSheet(items: shareItems)
        }
        #endif
        .confirmationDialog(
            "Did you write down the 6 words?",
            isPresented: $showPassphraseConfirm,
            titleVisibility: .visible
        ) {
            Button("I have the 6 words — continue") {
                passphraseAcknowledged = true
                let transport = pendingTransport
                pendingTransport = nil
                if let transport {
                    // Laisse le dialog se refermer avant de présenter la
                    // share sheet, sinon iOS annule la présentation.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        perform(transport)
                    }
                }
            }
            Button("Not yet, view words", role: .cancel) {
                pendingTransport = nil
            }
        } message: {
            Text("The passphrase is never included in the sent payload. Without the 6 words, the other device will not be able to decrypt anything.")
        }
        .appToast($toast)
    }

    // MARK: Sections

    private var introSection: some View {
        Group {
            Section {
                AppHeroCard(
                    title: "Prepare a Handoff",
                    subtitle: "Your current config will be encrypted and a 6-word passphrase will be provided to enter on the other device.",
                    systemImage: "lock.rotation",
                    tint: .purple
                ) {
                    HStack(spacing: 10) {
                        AppMetricPill(
                            value: "6",
                            label: "words",
                            systemImage: "key.fill",
                            tint: .purple
                        )
                        AppMetricPill(
                            value: "E2E",
                            label: "encrypted",
                            systemImage: "lock.fill",
                            tint: .green
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                if preparing {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Face ID then seal…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task { await prepare() }
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Prepare Handoff")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } footer: {
                Text("This operation requires Face ID / Touch ID before encrypting and revealing the passphrase.")
            }
        }
    }

    private var sealedSection: some View {
        Group {
            switch prepared?.qrDecision {
            case .tooLargeForQR:
                tooLargeSection
            default:
                qrSection
            }
            passphraseSection
            transportSection
        }
    }

    private var qrSection: some View {
        Section {
            VStack(spacing: 14) {
                if let prepared {
                    HandoffQRDisplay(payload: prepared.payload)
                        .frame(maxWidth: .infinity)
                }
                Text("Scan this QR code with the other device, then enter the 6 words below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        } header: {
            Text("QR code")
        }
    }

    private var tooLargeSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("Your config is too large to fit in a single QR code.")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Use AirDrop, clipboard, or a .rclonebackup file instead — encryption remains the same.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } header: {
            Text("QR code")
        }
    }

    private var passphraseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "key.horizontal.fill")
                        .foregroundStyle(.purple)
                    Text("Recovery code")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        passphraseRevealed.toggle()
                    } label: {
                        Image(systemName: passphraseRevealed ? "eye.slash.fill" : "eye.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(passphraseRevealed ? "Hide the words" : "Show the words")
                }

                if passphraseRevealed, let prepared {
                    // Grille 3×2 : un HStack de 6 colonnes donnait ~55 pt par
                    // mot, ce qui coupait les mots Diceware longs (« nemeton »,
                    // « flocon »…) avec césure. 3 colonnes = ~110 pt par mot,
                    // et minimumScaleFactor gère les rares mots plus longs.
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(Array(prepared.passphraseWords.enumerated()), id: \.offset) { idx, word in
                            VStack(spacing: 3) {
                                Text("\(idx + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                Text(word)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    Toggle(isOn: $passphraseAcknowledged) {
                        Text("I have memorized or noted the 6 words")
                            .font(.footnote)
                    }
                } else {
                    Text("Tap to show the 6 words. They are never included in the QR or file — transmit them to the other person via a separate channel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Passphrase (out-of-band)")
        } footer: {
            Text("Once the passphrase is revealed here, the other device can only use it once. For a new transfer, start another Handoff.")
        }
    }

    private var transportSection: some View {
        Section {
            Button {
                requestTransport(.airdrop)
            } label: {
                Label("Share via AirDrop", systemImage: "square.and.arrow.up")
            }

            Button {
                requestTransport(.clipboard)
            } label: {
                Label("Copy the payload", systemImage: "doc.on.clipboard")
            }

            Button {
                requestTransport(.file)
            } label: {
                Label("Save to Files", systemImage: "folder.fill")
            }
        } header: {
            Text("Alternative transports")
        } footer: {
            if passphraseAcknowledged {
                Text("Sending via AirDrop or file also shares the encrypted payload. The passphrase must always be transmitted separately.")
            } else {
                Text("The payload sent is encrypted: the other device will need the 6 words above. You will be asked to confirm them on the first send.")
            }
        }
    }

    // MARK: Actions

    private func prepare() async {
        preparing = true
        error = nil
        defer { preparing = false }
        do {
            let prepared = try await HandoffSendService.shared.prepare()
            self.prepared = prepared
            self.passphraseRevealed = false
            self.passphraseAcknowledged = false
            self.step = .sealed
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Gate de sécurité des transports : le payload seul est inutile sans
    /// la passphrase, donc on force l'utilisateur à confirmer qu'il a bien
    /// noté les 6 mots avant le premier envoi. Les boutons restent
    /// cliquables — le gate est un dialog guidé, pas un bouton grisé.
    private func requestTransport(_ transport: Transport) {
        guard passphraseAcknowledged else {
            pendingTransport = transport
            passphraseRevealed = true
            showPassphraseConfirm = true
            return
        }
        perform(transport)
    }

    private func perform(_ transport: Transport) {
        switch transport {
        case .airdrop: shareViaAirDrop()
        case .clipboard: copyToClipboard()
        case .file: saveToFiles()
        }
    }

    private func shareViaAirDrop() {
        guard let prepared else { return }
        do {
            let url = try HandoffSendService.shared.materializeAirDropFile(payload: prepared.payload)
            #if os(iOS)
            presentActivitySheet(items: [url])
            #else
            shareItems = [url]
            showShare = true
            #endif
        } catch {
            self.error = "Impossible de préparer le fichier : \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        guard let prepared else { return }
        #if os(iOS)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: prepared.payload]],
            options: [
                .expirationDate: Date().addingTimeInterval(60 * 60)
            ]
        )
        #endif
        toast = AppToast(title: "Payload copié (expire dans 1 h)", severity: .success)
    }

    private func saveToFiles() {
        guard let prepared else { return }
        do {
            let url = try HandoffSendService.shared.materializeAirDropFile(payload: prepared.payload)
            #if os(iOS)
            presentActivitySheet(items: [url])
            #else
            shareItems = [url]
            showShare = true
            #endif
        } catch {
            self.error = "Écriture impossible : \(error.localizedDescription)"
        }
    }

    #if os(iOS)
    /// Présente la share sheet directement depuis le contrôleur le plus
    /// haut de la fenêtre clé. Encapsuler `UIActivityViewController` dans un
    /// `.sheet` SwiftUI produit une feuille vide sur iOS récent (le VC ne
    /// se met pas en page) — d'où « AirDrop n'affiche rien ». La présenter
    /// en UIKit règle le problème.
    @MainActor
    private func presentActivitySheet(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            self.error = "Impossible d'ouvrir le partage : aucune fenêtre active."
            return
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad : la share sheet est un popover et exige une ancre.
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
    #endif
}

// MARK: - QR Display

private struct HandoffQRDisplay: View {
    let payload: String

    var body: some View {
#if canImport(UIKit)
        if let image = QRCodeImageRenderer.render(
            payload: payload,
            targetDimension: 280,
            correction: .medium
        ) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .padding(20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Handoff QR code")
        } else {
            placeholder
        }
#else
        if let image = QRCodeImageRenderer.render(
            payload: payload,
            targetDimension: 280,
            correction: .medium
        ) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .padding(20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            placeholder
        }
#endif
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Unable to generate QR code")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 280, height: 280)
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
private struct HandoffShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif

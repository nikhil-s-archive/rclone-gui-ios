//
//  HandoffLandingView.swift
//  Rclone GUI — Views/Settings/Handoff
//
//  Point d'entrée du flux Handoff P2P (RG-16 / RG-4) :
//  propose d'envoyer ou de recevoir une config chiffrée entre appareils
//  sans serveur. Le transport (QR code, AirDrop, presse-papiers,
//  fichier .rclonebackup) est sélectionné à la seconde étape, le
//  chiffrement (ChaCha20-Poly1305, passphrase Diceware 6 mots hors
//  canal) reste identique.
//

import SwiftUI

struct HandoffLandingView: View {
    var body: some View {
        Form {
            heroSection
            actionsSection
            explainerSection
        }
        .navigationTitle("P2P Handoff")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
    }

    private var heroSection: some View {
        Section {
            AppHeroCard(
                title: "P2P Handoff",
                subtitle: "Transfers an encrypted config between devices via QR or AirDrop. Serverless.",
                systemImage: "iphone.and.arrow.forward",
                tint: .purple
            ) {
                HStack(spacing: 10) {
                    AppMetricPill(
                        value: "E2E",
                        label: "encrypted",
                        systemImage: "lock.fill",
                        tint: .green
                    )
                    AppMetricPill(
                        value: "0",
                        label: "server",
                        systemImage: "xmark.icloud.fill",
                        tint: .indigo
                    )
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var actionsSection: some View {
        Section {
            NavigationLink {
                HandoffSendView()
            } label: {
                HandoffNavigationRow(
                    icon: "arrow.up.doc.fill",
                    title: "Send my config",
                    subtitle: "To another iPhone, Mac, or iPad",
                    tint: .purple,
                    showsChevron: false
                )
            }

            NavigationLink {
                HandoffReceiveView()
            } label: {
                HandoffNavigationRow(
                    icon: "arrow.down.doc.fill",
                    title: "Receive a config",
                    subtitle: "From a QR code, AirDrop, or a file",
                    tint: .blue,
                    showsChevron: false
                )
            }
        } header: {
            Text("Choose a direction")
        }
    }

    private var explainerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                row(
                    systemImage: "lock.shield.fill",
                    tint: .green,
                    title: "End-to-end encryption",
                    body: "Your rclone.conf is encrypted (ChaCha20-Poly1305) with a key derived from a 6-word passphrase before leaving the device. No one can read it without the passphrase."
                )
                row(
                    systemImage: "person.fill.questionmark",
                    tint: .purple,
                    title: "No server",
                    body: "No backend, no account, no cloud. The blob travels directly from device to device via QR (visual), AirDrop (local Bluetooth/Wi-Fi), or file."
                )
                row(
                    systemImage: "key.horizontal.fill",
                    tint: .orange,
                    title: "Out-of-band passphrase",
                    body: "The 6 words of the passphrase are never embedded in the QR or file. Read them on the sender's screen and enter them manually on the receiving device."
                )
                row(
                    systemImage: "eye.slash.fill",
                    tint: .indigo,
                    title: "Single-use passphrase",
                    body: "Each Handoff generates a fresh passphrase. If you perform another Handoff later, it will be 6 new words — previous passphrases cannot be reused."
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("How it works")
        }
    }

    private func row(systemImage: String, tint: Color, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct HandoffNavigationRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var tint: Color = .accentColor
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

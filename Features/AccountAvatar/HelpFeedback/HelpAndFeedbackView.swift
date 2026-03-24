//
//  HelpAndFeedbackView.swift
//  GluVibProbe
//
//  Settings / Account — Help & Feedback Screen
//  Purpose:
//  - Collects a simple feedback/help message and opens Apple Mail with prefilled content.
//  - Uses Apple system mail composer when available and mailto fallback otherwise.
//
//  Data Flow (SSoT):
//  - Local view state only -> Mail composer / mailto URL
//
//  Key Connections:
//  - MFMailComposeViewController
//  - AppDiagnostics
//  - MailtoBuilder
//

import SwiftUI
import MessageUI

struct HelpAndFeedbackView: View {

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let supportEmail: String = "support@gluvib.com"

    // ============================================================
    // MARK: - Local State
    // ============================================================

    private enum Category: String, CaseIterable, Identifiable {
        case feedback
        case help
        case other

        var id: String { rawValue }

        var title: String { // 🟨 UPDATED
            switch self {
            case .feedback: return L10n.Avatar.HelpFeedback.feedback
            case .help: return L10n.Avatar.HelpFeedback.help
            case .other: return L10n.Avatar.HelpFeedback.other
            }
        }

        var subjectPrefix: String { // 🟨 UPDATED
            "GluVib \(title)"
        }
    }

    @State private var category: Category = .feedback
    @State private var message: String = ""

    @State private var showMailComposer: Bool = false
    @State private var showMailUnavailableAlert: Bool = false

    @Environment(\.openURL) private var openURL

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var subject: String {
        category.subjectPrefix
    }

    private var bodyText: String {
        let appInfo = AppDiagnostics.summaryLine
        return """
        Category: \(category.title)

        Message:
        \(message)

        ----
        \(appInfo)
        """
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        Form {
            Section {
                Picker(
                    String(
                        localized: "Feedback Type",
                        defaultValue: "Feedback Type",
                        comment: "Picker title for feedback category in help and feedback view"
                    ),
                    selection: $category
                ) {
                    ForEach(Category.allCases) { item in
                        Text(item.title)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)

            } header: {
                Text(
                    String(
                        localized: "Feedback Type",
                        defaultValue: "Feedback Type",
                        comment: "Section header for feedback category in help and feedback view"
                    )
                ) // 🟨 UPDATED
                .foregroundStyle(titleColor)
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    .overlay(alignment: .topLeading) {
                        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(
                                String(
                                    localized: "Write your message…",
                                    defaultValue: "Write your message…",
                                    comment: "Placeholder text in help and feedback message editor"
                                )
                            ) // 🟨 UPDATED
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                        }
                    }

            } header: {
                Text(
                    String(
                        localized: "Message",
                        defaultValue: "Message",
                        comment: "Section header for message input in help and feedback view"
                    )
                ) // 🟨 UPDATED
                .foregroundStyle(titleColor)
            }

            Section {
                Button {
                    sendTapped()
                } label: {
                    HStack {
                        Spacer()
                        Text(
                            String(
                                localized: "Send",
                                defaultValue: "Send",
                                comment: "Send button title in help and feedback view"
                            )
                        ) // 🟨 UPDATED
                        .font(.headline)
                        Spacer()
                    }
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            } footer: {
                Text(
                    String(
                        localized: "This will open Apple Mail. GluVib does not send messages automatically.",
                        defaultValue: "This will open Apple Mail. GluVib does not send messages automatically.",
                        comment: "Footer note in help and feedback view"
                    )
                ) // 🟨 UPDATED
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(titleColor)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "Help & Feedback",
                        defaultValue: "Help & Feedback",
                        comment: "Navigation title for help and feedback view"
                    )
                ) // 🟨 UPDATED
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerSheet(
                recipients: [supportEmail],
                subject: subject,
                body: bodyText
            )
        }
        .alert(
            String(
                localized: "Mail is not available",
                defaultValue: "Mail is not available",
                comment: "Alert title when mail is unavailable in help and feedback view"
            ),
            isPresented: $showMailUnavailableAlert
        ) {
            Button(
                String(
                    localized: "OK",
                    defaultValue: "OK",
                    comment: "Dismiss button title for mail unavailable alert"
                ),
                role: .cancel
            ) { }
        } message: {
            Text(
                String(
                    localized: "Please set up Apple Mail on this device to send messages.",
                    defaultValue: "Please set up Apple Mail on this device to send messages.",
                    comment: "Alert message when mail is unavailable in help and feedback view"
                )
            ) // 🟨 UPDATED
        }
    }

    // ============================================================
    // MARK: - Actions
    // ============================================================

    private func sendTapped() {
        if MailComposerSheet.canSendMail {
            showMailComposer = true
            return
        }

        if let url = MailtoBuilder.makeURL(
            to: supportEmail,
            subject: subject,
            body: bodyText
        ) {
            openURL(url)
        } else {
            showMailUnavailableAlert = true
        }
    }
}

// ============================================================
// MARK: - Local Helpers
// ============================================================

private enum AppDiagnostics {

    static var summaryLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let model = UIDevice.current.model
        return "App: GluVib \(version) (\(build)) • Device: \(model) • iOS: \(system)"
    }
}

private enum MailtoBuilder {

    static func makeURL(to: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

private struct MailComposerSheet: UIViewControllerRepresentable {

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    let recipients: [String]
    let subject: String
    let body: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#if DEBUG
#Preview("HelpAndFeedbackView") {
    NavigationStack {
        HelpAndFeedbackView()
    }
}
#endif

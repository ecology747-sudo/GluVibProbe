//
//  HelpAndFeedbackView.swift
//  GluVibProbe
//
//  Help & Feedback (static form → Apple Mail composer)
//  - Apple-conform: uses MFMailComposeViewController (system UI)
//  - Prefills recipient, subject and body
//  - No HealthStore access, no medical advice
//

import SwiftUI
import MessageUI

struct HelpAndFeedbackView: View {

    // MARK: - Constants

    private let supportEmail: String = "support@gluvib.com"

    // MARK: - Form State

    private enum Category: String, CaseIterable, Identifiable {
        case feedback = "Feedback"
        case help = "Help"
        case other = "Other"

        var id: String { rawValue }

        var subjectPrefix: String {
            "GluVib \(rawValue)"
        }
    }

    @State private var category: Category = .feedback
    @State private var message: String = ""

    @State private var showMailComposer: Bool = false
    @State private var showMailUnavailableAlert: Bool = false

    // UPDATED: Fallback to mailto: if in-app composer is unavailable
    @Environment(\.openURL) private var openURL // UPDATED

    // MARK: - Derived

    private var subject: String {
        "\(category.subjectPrefix)"
    }

    private var bodyText: String {
        // Keep this minimal and non-sensitive. No Health data.
        let appInfo = AppDiagnostics.summaryLine
        return """
        Category: \(category.rawValue)

        Message:
        \(message)

        ----
        \(appInfo)
        """
    }

    var body: some View {
        Form {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

            } header: {
                Text("Feedback Type")
                    .foregroundStyle(Color("GluPrimaryBlue"))
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    .overlay(alignment: .topLeading) {
                        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Write your message…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }

            } header: {
                Text("Message")
                    .foregroundStyle(Color("GluPrimaryBlue"))
            }

            Section {
                Button {
                    sendTapped()
                } label: {
                    HStack {
                        Spacer()
                        Text("Send")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            } footer: {
                Text("This will open Apple Mail. GluVib does not send messages automatically.")
            }
        }
        .navigationTitle("Help & Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("GluPrimaryBlue"))
        .toolbar { // UPDATED
            ToolbarItem(placement: .principal) { // UPDATED
                Text("Help & Feedback") // UPDATED
                    .font(.headline.weight(.semibold)) // UPDATED
                    .foregroundStyle(Color("GluPrimaryBlue")) // UPDATED
            }
        }        .sheet(isPresented: $showMailComposer) {
            MailComposerSheet(
                recipients: [supportEmail],
                subject: subject,
                body: bodyText
            )
        }
        .alert("Mail is not available", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please set up Apple Mail on this device to send messages.")
        }
    }

    private func sendTapped() {
        if MailComposerSheet.canSendMail {
            showMailComposer = true
            return
        }

        // UPDATED: mailto fallback (opens Mail app)
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

// MARK: - App Diagnostics (non-sensitive)

private enum AppDiagnostics {
    static var summaryLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let model = UIDevice.current.model
        return "App: GluVib \(version) (\(build)) • Device: \(model) • iOS: \(system)"
    }
}

// MARK: - mailto URL Builder (fallback)

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

// MARK: - Mail Composer Sheet (UIKit wrapper)

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

#if DEBUG
#Preview("HelpAndFeedbackView") {
    NavigationStack {
        HelpAndFeedbackView()
    }
}
#endif

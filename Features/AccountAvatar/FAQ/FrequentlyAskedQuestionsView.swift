//
//  FrequentlyAskedQuestionsView.swift
//  GluVibProbe
//
//  FAQ (static)
//  - Static, informational only (no HealthStore, no Settings writes)
//  - Apple-default List + Sections + DisclosureGroups
//  - Uses GluPrimaryBlue for navigation title + section headers
//

import SwiftUI

struct FrequentlyAskedQuestionsView: View {

    // MARK: - Static Content (placeholder – we will adapt wording later)

    private let sections: [FAQSection] = [

        // ============================================================
        // 1) START HERE — BEFORE YOU GO FURTHER
        // ============================================================

        FAQSection(
            title: "Start Here — Before You Go Further",
            items: [
                FAQItem(
                    question: "What is GluVib?",
                    answer: "GluVib is an analysis and visualization app for personal health data."
                ),
                FAQItem(
                    question: "Who is GluVib for?",
                    answer: "GluVib is intended for people who want to review and understand patterns and trends in their own data."
                ),
                FAQItem(
                    question: "Is GluVib a coaching app?",
                    answer: "No. GluVib is not a coaching, motivational, or behavior-change app."
                ),
                FAQItem(
                    question: "Does GluVib provide medical recommendations?",
                    answer: "No. GluVib does not provide medical advice, diagnosis, or therapy recommendations."
                ),
                FAQItem(
                    question: "Does GluVib replace professional care?",
                    answer: "No. GluVib does not replace professional medical care."
                ),
                FAQItem(
                    question: "What are the main limitations of GluVib?",
                    answer: "GluVib’s output depends on the data available in Apple Health. If data is missing or incomplete, some metrics, charts, or summaries may be limited."
                )
            ]
        ),

        // ============================================================
        // 2) DATA BASICS — HOW GLUVIB WORKS
        // ============================================================

        FAQSection(
            title: "Data Basics — How GluVib Works",
            items: [
                FAQItem(
                    question: "Where does GluVib get its data from?",
                    answer: "GluVib works exclusively with Apple Health. Apple Health is the single source of truth for all data shown in the app."
                ),
                FAQItem(
                    question: "Can GluVib work without Apple Health?",
                    answer: "No. GluVib requires Apple Health to read and display your health data."
                ),
                FAQItem(
                    question: "Why does GluVib improve over time?",
                    answer: "The more consistent and complete your Apple Health data is, the more meaningful GluVib’s analysis becomes."
                ),
                FAQItem(
                    question: "Are CGM values shown in real time?",
                    answer: "No. GluVib does not receive real-time sensor readings. CGM values are shown based on what is available through Apple Health."
                ),
                FAQItem(
                    question: "Why can CGM data appear delayed?",
                    answer:
                        "GluVib does not receive CGM readings in real time. CGM data is first collected by your sensor and its source app, then synced into Apple Health. "
                        + "This Apple Health synchronization is a system process and can introduce a delay before new readings appear in Apple Health—and therefore in GluVib. "
                        + "This is expected and does not indicate an issue in GluVib. "
                        + "The delay depends on the sensor and setup; for example, some systems may provide data with a delay of around a few hours (e.g., ~3 hours)."
                )
            ]
        ),

        // ============================================================
        // 3) HARDWARE & SYSTEM REQUIREMENTS
        // ============================================================

        FAQSection(
            title: "Hardware & System Requirements",
            items: [
                FAQItem(
                    question: "What devices do I need to use GluVib?",
                    answer: "You need an iPhone with Apple Health and a supported iOS version."
                ),
                FAQItem(
                    question: "Do I need an Apple Watch?",
                    answer: "No. GluVib can be used without an Apple Watch. However, an Apple Watch often improves data completeness for activity, heart rate, and sleep metrics."
                ),
                FAQItem(
                    question: "Do I need CGM hardware?",
                    answer: "No. CGM hardware is optional. However, metabolic analytics that rely on CGM require CGM data to be available in Apple Health."
                )
            ]
        ),

        // ============================================================
        // 4) FREE VS PREMIUM — WHAT’S THE DIFFERENCE?
        // ============================================================

        FAQSection(
            title: "Free vs Premium — What’s the Difference?",
            items: [
                FAQItem(
                    question: "What is Free vs Premium in GluVib?",
                    answer: "Free includes Nutrition, Body, and Activity features. Premium unlocks additional metabolic analytics when CGM mode is enabled."
                ),
                FAQItem(
                    question: "What is included in the Free version?",
                    answer: "The Free version includes Nutrition, Body, and Activity domains with charts and KPIs, based on your Apple Health data."
                ),
                FAQItem(
                    question: "What does Premium unlock?",
                    answer: "Premium unlocks metabolic analytics (for example, CGM-based glucose metrics and related visualizations). We will refine the exact scope text later."
                ),
                FAQItem(
                    question: "Why do metabolic features require CGM mode?",
                    answer: "Metabolic analytics rely on continuous glucose data. These features are only available when CGM data is available through Apple Health."
                ),
                FAQItem(
                    question: "Why are insulin metrics sometimes hidden?",
                    answer: "Insulin-related metrics are shown only when CGM mode is enabled and insulin is activated."
                )
            ]
        ),

        // ============================================================
        // 5) USING THE APP — EVERYDAY QUESTIONS
        // ============================================================

        FAQSection(
            title: "Using the App — Everyday Questions",
            items: [
                FAQItem(
                    question: "How do I refresh my data?",
                    answer: "Use pull-to-refresh on supported screens. Today’s values may update differently from past days."
                ),
                FAQItem(
                    question: "Why does “Today” behave differently from past days?",
                    answer: "Today updates as new data becomes available. Past days are read-only and typically reflect finalized data."
                ),
                FAQItem(
                    question: "Where can I set goals and targets?",
                    answer: "Goals and targets can be configured in Settings. These values provide context for charts and KPIs."
                ),
                FAQItem(
                    question: "Where can I change units?",
                    answer: "Units can be changed in Settings. Changing units affects how values are displayed, not the underlying Apple Health data."
                ),
                FAQItem(
                    question: "How can I add lab results (e.g., HbA1c)?",
                    answer: "Lab results can be entered in Settings. We will refine the exact workflow text later."
                )
            ]
        ),

        // ============================================================
        // 6) METRICS & ABBREVIATIONS (GLOSSARY)
        // ============================================================

        FAQSection(
            title: "Metrics & Abbreviations (Glossary)",
            items: [
                FAQItem(
                    question: "What does TIR mean?",
                    answer: "TIR stands for Time in Range."
                ),
                FAQItem(
                    question: "What does GMI mean?",
                    answer: "GMI stands for Glucose Management Indicator."
                ),
                FAQItem(
                    question: "What does CV mean?",
                    answer: "CV stands for Coefficient of Variation."
                ),
                FAQItem(
                    question: "What does SD mean?",
                    answer: "SD stands for Standard Deviation."
                ),
                FAQItem(
                    question: "What do Bolus and Basal mean?",
                    answer: "Bolus and Basal describe different types of insulin dosing. We will refine definitions later."
                ),
                FAQItem(
                    question: "What is the difference between Active Energy and Nutrition Energy?",
                    answer: "Active Energy refers to energy burned through activity. Nutrition Energy refers to energy consumed via food. We will refine wording later."
                )
            ]
        ),
        
        

        // ============================================================
        // 7) Reports — Printable Diabetological Report
        // ============================================================

        FAQSection(
            title: "Reports — Printable Diabetological Report",
            items: [
                FAQItem(
                    question: "What is the printable report in GluVib?",
                    answer: "GluVib provides a printable, diabetological-style report designed to summarize relevant metabolic data for structured review."
                ),
                FAQItem(
                    question: "Is the report a medical or clinical recommendation?",
                    answer: "No. The report is an analytical summary of available data and does not provide medical advice, diagnosis, or therapy recommendations."
                ),
                FAQItem(
                    question: "What is included in the Free version of the report?",
                    answer: "The Free version includes general summaries based on Nutrition, Body, and Activity data available in Apple Health."
                ),
                FAQItem(
                    question: "What additional content is included in the Premium report?",
                    answer: "The Premium report includes additional metabolic content based on CGM data, such as glucose-related metrics and visualizations, when available."
                )
            ]
        ),
        
        // ============================================================
        // 8) Troubleshooting
        // ============================================================

        FAQSection(
            title: "Troubleshooting",
            items: [
                FAQItem(
                    question: "Why is a metric empty?",
                    answer: "Common reasons include missing Apple Health permissions, missing data in Apple Health, or insufficient data coverage for the selected time period."
                ),
                FAQItem(
                    question: "Why does GluVib show different values compared to another app?",
                    answer: "Different apps may use different aggregation methods, time windows, or data sources. GluVib reflects the data as available in Apple Health."
                ),
                FAQItem(
                    question: "Why are some features or sections not visible?",
                    answer: "Feature visibility depends on your configuration, such as CGM availability, insulin status, and whether you are using the Free or Premium version."
                )
            ]
        )
    ]
    
    // MARK: - View

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        FAQRow(item: item)
                    }
                } header: {
                    Text(section.title)
                        .foregroundStyle(Color("GluPrimaryBlue"))
                }
            }
        }
        .navigationTitle("Frequently Asked Questions")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("GluPrimaryBlue")) // affects nav elements, links, disclosure chevrons
    }
}

// MARK: - Row

private struct FAQRow: View {

    let item: FAQItem
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(item.answer)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 2)
        } label: {
            Text(item.question)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Models

private struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [FAQItem]
}

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FrequentlyAskedQuestionsView()
    }
}

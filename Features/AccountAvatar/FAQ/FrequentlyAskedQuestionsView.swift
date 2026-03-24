//
//  FrequentlyAskedQuestionsView.swift
//  GluVibProbe
//
//  FAQ (static)
//  - Level 1: Chapter overview (chapters only)
//  - Level 2: Chapter detail (all Q&As already expanded)
//  - Static, informational only
//  - ALL text uses adaptive SystemForeground in sheet/settings context
//

import SwiftUI

struct FrequentlyAskedQuestionsView: View {

    // 🟨 UPDATED: sheet/settings foreground now uses adaptive system foreground
    private let titleColor: Color = Color.Glu.systemForeground

    // MARK: - Static Content

    private var sections: [FAQSection] { // 🟨 UPDATED
        [
            FAQSection(
                title: L10n.FAQ.General.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.General.WhatIsGluVib.question,
                        answer: L10n.FAQ.General.WhatIsGluVib.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.General.WhoIsGluVibFor.question,
                        answer: L10n.FAQ.General.WhoIsGluVibFor.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.General.IsCoachingApp.question,
                        answer: L10n.FAQ.General.IsCoachingApp.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.General.MedicalRecommendations.question,
                        answer: L10n.FAQ.General.MedicalRecommendations.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.General.ReplaceProfessionalCare.question,
                        answer: L10n.FAQ.General.ReplaceProfessionalCare.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.General.MainLimitations.question,
                        answer: L10n.FAQ.General.MainLimitations.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.DataBasics.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.DataBasics.DataSource.question,
                        answer: L10n.FAQ.DataBasics.DataSource.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.WithoutAppleHealth.question,
                        answer: L10n.FAQ.DataBasics.WithoutAppleHealth.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.ImprovesOverTime.question,
                        answer: L10n.FAQ.DataBasics.ImprovesOverTime.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.RealTimeUpdates.question,
                        answer: L10n.FAQ.DataBasics.RealTimeUpdates.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.CGMRealTime.question,
                        answer: L10n.FAQ.DataBasics.CGMRealTime.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.CGMDelay.question,
                        answer: L10n.FAQ.DataBasics.CGMDelay.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.CGMCoverage.question,
                        answer: L10n.FAQ.DataBasics.CGMCoverage.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.DataBasics.SmallInsulinDosesDisappear.question,
                        answer: L10n.FAQ.DataBasics.SmallInsulinDosesDisappear.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.HardwareSystemRequirements.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.HardwareSystemRequirements.IPhoneRequirements.question,
                        answer: L10n.FAQ.HardwareSystemRequirements.IPhoneRequirements.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.HardwareSystemRequirements.IPadRequirements.question,
                        answer: L10n.FAQ.HardwareSystemRequirements.IPadRequirements.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.HardwareSystemRequirements.AppleWatchNeeded.question,
                        answer: L10n.FAQ.HardwareSystemRequirements.AppleWatchNeeded.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.HardwareSystemRequirements.CGMHardwareNeeded.question,
                        answer: L10n.FAQ.HardwareSystemRequirements.CGMHardwareNeeded.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.FreeVsPremium.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.FreeVsPremium.WhatIsFreeVsPremium.question,
                        answer: L10n.FAQ.FreeVsPremium.WhatIsFreeVsPremium.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.FreeVsPremium.Trial30Days.question,
                        answer: L10n.FAQ.FreeVsPremium.Trial30Days.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.FreeVsPremium.AfterTrialEnds.question,
                        answer: L10n.FAQ.FreeVsPremium.AfterTrialEnds.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.FreeVsPremium.WhatPremiumUnlocks.question,
                        answer: L10n.FAQ.FreeVsPremium.WhatPremiumUnlocks.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.FreeVsPremium.WhyMetabolicNeedsCGM.question,
                        answer: L10n.FAQ.FreeVsPremium.WhyMetabolicNeedsCGM.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.UsingTheApp.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.UsingTheApp.RefreshData.question,
                        answer: L10n.FAQ.UsingTheApp.RefreshData.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.UsingTheApp.TodayVsPastDays.question,
                        answer: L10n.FAQ.UsingTheApp.TodayVsPastDays.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.UsingTheApp.GoalsTargetsRanges.question,
                        answer: L10n.FAQ.UsingTheApp.GoalsTargetsRanges.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.UsingTheApp.ChangeUnits.question,
                        answer: L10n.FAQ.UsingTheApp.ChangeUnits.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.UsingTheApp.AddLabResults.question,
                        answer: L10n.FAQ.UsingTheApp.AddLabResults.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.Glossary.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.Glossary.TIR.question,
                        answer: L10n.FAQ.Glossary.TIR.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.GMI.question,
                        answer: L10n.FAQ.Glossary.GMI.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.CV.question,
                        answer: L10n.FAQ.Glossary.CV.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.SD.question,
                        answer: L10n.FAQ.Glossary.SD.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.BolusAndBasal.question,
                        answer: L10n.FAQ.Glossary.BolusAndBasal.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.CarbohydrateBolusRatio.question,
                        answer: L10n.FAQ.Glossary.CarbohydrateBolusRatio.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.BolusBasalRatio.question,
                        answer: L10n.FAQ.Glossary.BolusBasalRatio.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.IG.question,
                        answer: L10n.FAQ.Glossary.IG.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.MovementSplit.question,
                        answer: L10n.FAQ.Glossary.MovementSplit.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.BMI.question,
                        answer: L10n.FAQ.Glossary.BMI.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Glossary.ActiveVsNutritionEnergy.question,
                        answer: L10n.FAQ.Glossary.ActiveVsNutritionEnergy.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.Reports.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.Reports.WhatIsReport.question,
                        answer: L10n.FAQ.Reports.WhatIsReport.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Reports.HowUsedAndShared.question,
                        answer: L10n.FAQ.Reports.HowUsedAndShared.answer
                    )
                ]
            ),

            FAQSection(
                title: L10n.FAQ.Troubleshooting.title,
                items: [
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.ExclamationMarkMetric.question,
                        answer: L10n.FAQ.Troubleshooting.ExclamationMarkMetric.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.HideExclamationMarks.question,
                        answer: L10n.FAQ.Troubleshooting.HideExclamationMarks.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.MetricEmpty.question,
                        answer: L10n.FAQ.Troubleshooting.MetricEmpty.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.DifferentValues.question,
                        answer: L10n.FAQ.Troubleshooting.DifferentValues.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.FeaturesNotVisible.question,
                        answer: L10n.FAQ.Troubleshooting.FeaturesNotVisible.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.NoDataForToday.question,
                        answer: L10n.FAQ.Troubleshooting.NoDataForToday.answer
                    ),
                    FAQItem(
                        question: L10n.FAQ.Troubleshooting.NoDataAtAll.question,
                        answer: L10n.FAQ.Troubleshooting.NoDataAtAll.answer
                    )
                ]
            )
        ]
    }

    // MARK: - View (Chapter Overview)

    var body: some View {
        List {
            Section {
                ForEach(sections) { section in
                    NavigationLink {
                        FAQSectionDetailView(section: section)
                    } label: {
                        Text(section.title)
                            .foregroundStyle(titleColor) // 🟨 UPDATED
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.FAQ.navigationTitle) // 🟨 UPDATED
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }
}

// MARK: - Chapter Detail (All answers shown)

private struct FAQSectionDetailView: View {

    let section: FAQSection
    @Environment(\.dismiss) private var dismiss

    // 🟨 UPDATED: sheet/settings foreground now uses adaptive system foreground
    private let titleColor: Color = Color.Glu.systemForeground

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: 6) {

                        Text(item.question)
                            .font(.headline)
                            .foregroundStyle(titleColor)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.answer)
                            .font(.subheadline)
                            .foregroundStyle(titleColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                        .opacity(0.35)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(titleColor)
            }

            ToolbarItem(placement: .principal) {
                Text(section.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
            }
        }
        .tint(titleColor)
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

//
//  L10n+Metabolic.swift
//  GluVib
//

import Foundation

extension L10n {
    
    enum MetabolicOverview {

        static var glucoseTitle: String {
            String(
                localized: "metabolic_overview.glucose.title",
                defaultValue: "Glucose",
                comment: "Title label for glucose average overview card"
            )
        }

        static var coverageLabel: String {
            String(
                localized: "metabolic_overview.coverage.label",
                defaultValue: "Coverage",
                comment: "Label for CGM coverage percentage in metabolic overview"
            )
        }
        
        static var last24hInfoTitle: String {
            String(
                localized: "metabolic_overview.glucose.info.last24h.title",
                defaultValue: "Last 24 Hours (24h)",
                comment: "Title of the info bubble for the glucose overview last 24 hours metric"
            )
        }

        static var last24hInfoMessage: String {
            String(
                localized: "metabolic_overview.glucose.info.last24h.message",
                defaultValue: "This metric uses the most recent CGM readings available in Apple Health. Due to system synchronization, newer readings may appear with a short delay. Details are available in the FAQs.",
                comment: "Message of the info bubble for the glucose overview last 24 hours metric"
            )
        }

        static var infoPrimaryOK: String {
            String(
                localized: "metabolic_overview.info.primary_ok",
                defaultValue: "OK",
                comment: "Primary button title for metabolic overview info bubbles"
            )
        }

        static var infoSecondaryOpenFAQs: String {
            String(
                localized: "metabolic_overview.info.secondary_open_faqs",
                defaultValue: "Open FAQs",
                comment: "Secondary button title for metabolic overview info bubbles"
            )
        }
        
    }

    enum Bolus {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.bolus.title",
                defaultValue: "Bolus",
                comment: "Metric title for bolus insulin"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.bolus.kpi.today",
                defaultValue: "Bolus Today",
                comment: "KPI title for today's bolus insulin"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 UPDATED
            String(
                localized: "metric.bolus.hint.no_data_or_permission",
                defaultValue: "No bolus insulin data available. Please check Apple Health permissions and whether bolus insulin has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible bolus insulin data is available because permission is missing and/or no readable bolus history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.bolus.hint.no_today",
                defaultValue: "No bolus insulin recorded today yet.",
                comment: "Hint shown when no bolus insulin is recorded today yet"
            )
        }
    }
    
    enum Basal {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.basal.title",
                defaultValue: "Basal",
                comment: "Metric title for basal insulin"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.basal.kpi.today",
                defaultValue: "Basal Today",
                comment: "KPI title for today's basal insulin"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 UPDATED
            String(
                localized: "metric.basal.hint.no_data_or_permission",
                defaultValue: "No basal insulin data available. Please check Apple Health permissions and whether basal insulin has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible basal insulin data is available because permission is missing and/or no readable basal history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.basal.hint.no_today",
                defaultValue: "No basal insulin recorded today yet.",
                comment: "Hint shown when no basal insulin is recorded today yet"
            )
        }
    }

    enum BolusBasalRatio {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.bolus_basal_ratio.title",
                defaultValue: "Bolus/Basal",
                comment: "Metric title for bolus to basal ratio"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.bolus_basal_ratio.kpi.today",
                defaultValue: "Bolus/Basal Today",
                comment: "KPI title for today's bolus to basal ratio"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.bolus_basal_ratio.hint.no_data_or_permission",
                defaultValue: "No bolus/basal ratio data available. Please check Apple Health permissions and whether bolus and basal insulin have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible bolus/basal ratio data is available because permission is missing and/or no readable ratio history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.bolus_basal_ratio.hint.no_today",
                defaultValue: "No bolus/basal ratio available today yet.",
                comment: "Hint shown when no bolus to basal ratio is available today yet"
            )
        }
    }
    enum CarbsBolusRatio {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.carbs_bolus_ratio.title",
                defaultValue: "Carbs/Bolus",
                comment: "Metric title for carbs to bolus ratio"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.carbs_bolus_ratio.kpi.today",
                defaultValue: "Carbs/Bolus Today",
                comment: "KPI title for today's carbs to bolus ratio"
            )
        }

        static var gramsPerUnit: String {
            String(
                localized: "metric.carbs_bolus_ratio.unit.grams_per_unit",
                defaultValue: "g/U",
                comment: "Unit label for grams per insulin unit"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.carbs_bolus_ratio.hint.no_data_or_permission",
                defaultValue: "No carbs/bolus ratio data available. Please check Apple Health permissions and whether carbohydrates and bolus insulin have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible carbs to bolus ratio data is available because permission is missing and/or no readable ratio history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.carbs_bolus_ratio.hint.no_today",
                defaultValue: "No carbs/bolus ratio available today yet.",
                comment: "Hint shown when no carbs to bolus ratio is available today yet"
            )
        }
    }

    enum TimeInRange {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.tir.title",
                defaultValue: "TIR",
                comment: "Metric title for time in range"
            )
        }

        static var targetKPI: String {
            String(
                localized: "metric.tir.kpi.target",
                defaultValue: "Target",
                comment: "KPI title for TIR target"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.tir.kpi.today",
                defaultValue: "Today",
                comment: "KPI title for today's TIR"
            )
        }

        static var deltaKPI: String {
            String(
                localized: "metric.tir.kpi.delta",
                defaultValue: "Delta",
                comment: "KPI title for TIR delta"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.tir.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.tir.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }
    }
    enum IG {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.ig.title",
                defaultValue: "IG",
                comment: "Metric title for interstitial glucose"
            )
        }

        static var meanKPI: String {
            String(
                localized: "metric.ig.kpi.mean",
                defaultValue: "Mean",
                comment: "KPI title for mean interstitial glucose"
            )
        }

        static var last24hKPI: String {
            String(
                localized: "metric.ig.kpi.last_24h",
                defaultValue: "Last 24h",
                comment: "KPI title for last 24 hours interstitial glucose"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.ig.kpi.today",
                defaultValue: "Today",
                comment: "KPI title for today's interstitial glucose"
            )
        }

        static var average90dKPI: String {
            String(
                localized: "metric.ig.kpi.average_90d",
                defaultValue: "Ø 90d",
                comment: "KPI title for 90 day average interstitial glucose"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.ig.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.ig.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }
    }

    enum GMI {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.gmi.title",
                defaultValue: "GMI",
                comment: "Metric title for glucose management indicator"
            )
        }

        static var last24hKPI: String {
            String(
                localized: "metric.gmi.kpi.last_24h",
                defaultValue: "Last 24h",
                comment: "KPI title for last 24 hours GMI"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.gmi.kpi.today",
                defaultValue: "Today",
                comment: "KPI title for today's GMI"
            )
        }

        static var average90dKPI: String {
            String(
                localized: "metric.gmi.kpi.average_90d",
                defaultValue: "Ø 90d",
                comment: "KPI title for 90 day average GMI"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.gmi.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.gmi.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }

        // MARK: - HbA1c Lab Card

        static var labResultsTitle: String {
            String(
                localized: "metric.gmi.lab_results.title",
                defaultValue: "HbA1c Lab Results",
                comment: "Title of the HbA1c lab results card in GMI view"
            )
        }

        static var labResultsEmpty: String {
            String(
                localized: "metric.gmi.lab_results.empty",
                defaultValue: "No HbA1c lab values recorded yet.",
                comment: "Empty state text when no HbA1c lab results are available"
            )
        }

        static var labResultsDate: String {
            String(
                localized: "metric.gmi.lab_results.date",
                defaultValue: "Date",
                comment: "Column title for date in HbA1c lab results card"
            )
        }

        static var labResultsHbA1c: String {
            String(
                localized: "metric.gmi.lab_results.hba1c",
                defaultValue: "HbA1c",
                comment: "Column title for HbA1c value in HbA1c lab results card"
            )
        }

        static var labResultsManageHint: String {
            String(
                localized: "metric.gmi.lab_results.manage_hint",
                defaultValue: "Manage all lab values in Settings.",
                comment: "Hint below HbA1c lab results card when more values exist"
            )
        }
    }

    enum SD {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.sd.title",
                defaultValue: "SD",
                comment: "Metric title for standard deviation"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.sd.kpi.today",
                defaultValue: "Today",
                comment: "KPI title for today's glucose SD"
            )
        }

        static var last24hKPI: String {
            String(
                localized: "metric.sd.kpi.last_24h",
                defaultValue: "Last 24h",
                comment: "KPI title for last 24 hours glucose SD"
            )
        }

        static var average90dKPI: String {
            String(
                localized: "metric.sd.kpi.average_90d",
                defaultValue: "Ø 90d",
                comment: "KPI title for 90 day average glucose SD"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.sd.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.sd.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }
    }

    enum CV {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.cv.title",
                defaultValue: "CV",
                comment: "Metric title for coefficient of variation"
            )
        }

        static var currentKPI: String {
            String(
                localized: "metric.cv.kpi.current",
                defaultValue: "Today",
                comment: "KPI title for today's glucose coefficient of variation"
            )
        }

        static var last24hKPI: String {
            String(
                localized: "metric.cv.kpi.last_24h",
                defaultValue: "Last 24h",
                comment: "KPI title for last 24 hours glucose coefficient of variation"
            )
        }

        static var last90dKPI: String {
            String(
                localized: "metric.cv.kpi.last_90d",
                defaultValue: "Ø 90d",
                comment: "KPI title for 90 day glucose coefficient of variation"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.cv.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.cv.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }
    }

    enum Range {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.range.title",
                defaultValue: "Range",
                comment: "Metric title for glucose range"
            )
        }
        
        static var coverageLabel: String {
            String(
                localized: "metric.range.coverage.label",
                defaultValue: "Coverage",
                comment: "Label for coverage row in range metric tiles"
            )
        }

        static var period7dTitle: String {
            String(
                localized: "metric.range.period.7d_title",
                defaultValue: "7 Days",
                comment: "Title for 7 day range tile"
            )
        }

        static var period14dTitle: String {
            String(
                localized: "metric.range.period.14d_title",
                defaultValue: "14 Days",
                comment: "Title for 14 day range tile"
            )
        }

        static var period30dTitle: String {
            String(
                localized: "metric.range.period.30d_title",
                defaultValue: "30 Days",
                comment: "Title for 30 day range tile"
            )
        }

        static var period90dTitle: String {
            String(
                localized: "metric.range.period.90d_title",
                defaultValue: "90 Days",
                comment: "Title for 90 day range tile"
            )
        }

        static var thresholdVeryLow: String {
            String(
                localized: "metric.range.threshold.very_low",
                defaultValue: "Very Low",
                comment: "Label for very low glucose range threshold"
            )
        }

        static var thresholdLow: String {
            String(
                localized: "metric.range.threshold.low",
                defaultValue: "Low",
                comment: "Label for low glucose range threshold"
            )
        }

        static var thresholdInRange: String {
            String(
                localized: "metric.range.threshold.in_range",
                defaultValue: "In Range",
                comment: "Label for in range glucose threshold"
            )
        }

        static var thresholdHigh: String {
            String(
                localized: "metric.range.threshold.high",
                defaultValue: "High",
                comment: "Label for high glucose range threshold"
            )
        }

        static var thresholdVeryHigh: String {
            String(
                localized: "metric.range.threshold.very_high",
                defaultValue: "Very High",
                comment: "Label for very high glucose range threshold"
            )
        }

        static var thresholdsHint: String {
            String(
                localized: "metric.range.thresholds.hint",
                defaultValue: "Thresholds can be adjusted in Metabolic Settings.",
                comment: "Hint below the range threshold legend card"
            )
        }

        static var openSettingsAccessibility: String {
            String(
                localized: "metric.range.thresholds.open_settings_accessibility",
                defaultValue: "Open Metabolic Settings",
                comment: "Accessibility label for opening metabolic settings from range threshold legend"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String { // 🟨 NEW
            String(
                localized: "metric.range.hint.no_data_or_permission",
                defaultValue: "No CGM data available. Please check Apple Health permissions and whether blood glucose data has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible CGM data is available because permission is missing and/or no readable glucose history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.range.hint.no_today",
                defaultValue: "No CGM data available today yet.",
                comment: "Hint shown when no CGM data is available today yet"
            )
        }
    }
    
    enum MainChart { // 🟨 NEW

        static var emptyTitle: String {
            String(
                localized: "main_chart.empty.title",
                defaultValue: "No cached profile",
                comment: "Empty state title when no cached main chart profile is available"
            )
        }

        static var emptyMessage: String {
            String(
                localized: "main_chart.empty.message",
                defaultValue: "Cache will populate after ensureMainChartCachedV1() has run.",
                comment: "Empty state message when no cached main chart profile is available"
            )
        }

        static var sensorChip: String {
            String(
                localized: "main_chart.chip.sensor",
                defaultValue: "Sensor",
                comment: "Overlay chip title for glucose sensor data in main chart"
            )
        }

        static var today: String {
            String(
                localized: "main_chart.day.today",
                defaultValue: "Today",
                comment: "Label for today in main chart header and day picker"
            )
        }

        static var yesterday: String {
            String(
                localized: "main_chart.day.yesterday",
                defaultValue: "Yesterday",
                comment: "Label for yesterday in main chart header and day picker"
            )
        }

        static var dayPickerTitle: String {
            String(
                localized: "main_chart.day_picker.title",
                defaultValue: "Select Day",
                comment: "Navigation title for main chart day picker sheet"
            )
        }

        static var last10Days: String {
            String(
                localized: "main_chart.day_picker.last_10_days",
                defaultValue: "Last 10 days",
                comment: "Headline for main chart day picker sheet"
            )
        }

        static var done: String {
            String(
                localized: "main_chart.common.done",
                defaultValue: "Done",
                comment: "Done button title in main chart day picker sheet"
            )
        }

        static var selected: String {
            String(
                localized: "main_chart.common.selected",
                defaultValue: "Selected",
                comment: "Accessibility value for selected day in main chart day picker"
            )
        }
        
        static var carbsChip: String { // 🟨 NEW
            String(
                localized: "main_chart.chip.carbs",
                defaultValue: "Carbs",
                comment: "Short overlay chip title for carbs in main chart"
            )
        }
    }
    
    enum MetabolicOverviewTIR {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.tir.card.title",
                defaultValue: "TIR",
                comment: "Short title of the TIR overview card"
            )
        }

        static var period24h: String {
            String(
                localized: "overview.metabolic.tir.card.period_24h",
                defaultValue: "(24h)",
                comment: "24-hour suffix shown next to the TIR title in the overview card"
            )
        }

        static var openAccessibility: String {
            String(
                localized: "overview.metabolic.tir.card.accessibility.open",
                defaultValue: "Open Time in Range",
                comment: "Accessibility label for opening the Time in Range detail screen from the overview card"
            )
        }

        static var infoTitle: String {
            String(
                localized: "overview.metabolic.tir.info.title",
                defaultValue: "Time in Range (24h)",
                comment: "Title of the info bubble for the TIR overview card"
            )
        }

        static var infoMessage: String {
            String(
                localized: "overview.metabolic.tir.info.message",
                defaultValue: "This metric uses the most recent sensor readings available in Apple Health. Due to system synchronization, newer readings may appear with a short delay. Details are available in the FAQs.",
                comment: "Message of the info bubble for the TIR overview card"
            )
        }

        static var chartDay: String {
            String(
                localized: "overview.metabolic.tir.chart.day",
                defaultValue: "Day",
                comment: "X-axis value label for days in the TIR mini trend chart"
            )
        }

        static var chartValue: String {
            String(
                localized: "overview.metabolic.tir.chart.value",
                defaultValue: "TIR",
                comment: "Y-axis value label for TIR values in the TIR mini trend chart"
            )
        }
    }
    
    enum MetabolicOverviewBolus {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.bolus.card.title",
                defaultValue: "Bolus (U)",
                comment: "Title of the bolus overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.bolus.card.today",
                defaultValue: "Today",
                comment: "Today label in the bolus overview card"
            )
        }
    }
    
    enum MetabolicOverviewBasal {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.basal.card.title",
                defaultValue: "Basal (U)",
                comment: "Title of the basal overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.basal.card.today",
                defaultValue: "Today",
                comment: "Today label in the basal overview card"
            )
        }
    }
    
    enum MetabolicOverviewCarbs {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.carbs.card.title",
                defaultValue: "Carbs (g)",
                comment: "Title of the carbs overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.carbs.card.today",
                defaultValue: "Today",
                comment: "Today label in the carbs overview card"
            )
        }
    }
    
    enum MetabolicOverviewActivityEnergy {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.activity_energy.card.title",
                defaultValue: "Active Energy (kcal)",
                comment: "Title of the activity energy overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.activity_energy.card.today",
                defaultValue: "Today",
                comment: "Today label in the activity energy overview card"
            )
        }
    }
    
    enum MetabolicOverviewBolusBasalRatio {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.bolus_basal_ratio.card.title",
                defaultValue: "Bolus/Basal Ratio",
                comment: "Title of the bolus basal ratio overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.bolus_basal_ratio.card.today",
                defaultValue: "Today",
                comment: "Today label in the bolus basal ratio overview card"
            )
        }
    }
    
    enum MetabolicOverviewCarbsBolusRatio {

        static var cardTitle: String {
            String(
                localized: "overview.metabolic.carbs_bolus_ratio.card.title",
                defaultValue: "Carbs/Bolus (g/U)",
                comment: "Title of the carbs bolus ratio overview card in the metabolic overview"
            )
        }

        static var todayLabel: String {
            String(
                localized: "overview.metabolic.carbs_bolus_ratio.card.today",
                defaultValue: "Today",
                comment: "Today label in the carbs bolus ratio overview card"
            )
        }
    }
    
    enum MetabolicReportFlow {

        static var openAccessibility: String {
            String(
                localized: "metabolic_report_flow.open.accessibility",
                defaultValue: "Open glucose report",
                comment: "Accessibility label for opening the glucose report flow from the overview header"
            )
        }

        static var periodDialogTitle: String {
            String(
                localized: "metabolic_report_flow.period_dialog.title",
                defaultValue: "Glucose Report",
                comment: "Title of the report period selection dialog in the overview header"
            )
        }

        static var period7Days: String {
            String(
                localized: "metabolic_report_flow.period_dialog.7_days",
                defaultValue: "7 days",
                comment: "Button title for selecting a 7-day glucose report period"
            )
        }

        static var period14Days: String {
            String(
                localized: "metabolic_report_flow.period_dialog.14_days",
                defaultValue: "14 days",
                comment: "Button title for selecting a 14-day glucose report period"
            )
        }

        static var period30Days: String {
            String(
                localized: "metabolic_report_flow.period_dialog.30_days",
                defaultValue: "30 days",
                comment: "Button title for selecting a 30-day glucose report period"
            )
        }

        static var period90Days: String {
            String(
                localized: "metabolic_report_flow.period_dialog.90_days",
                defaultValue: "90 days",
                comment: "Button title for selecting a 90-day glucose report period"
            )
        }

        static var cancel: String {
            String(
                localized: "metabolic_report_flow.common.cancel",
                defaultValue: "Cancel",
                comment: "Cancel button title used in the glucose report dialog flow"
            )
        }

        static var include: String {
            String(
                localized: "metabolic_report_flow.daily_charts.include",
                defaultValue: "Include",
                comment: "Button title for including daily charts in the glucose report"
            )
        }

        static var skip: String {
            String(
                localized: "metabolic_report_flow.daily_charts.skip",
                defaultValue: "Skip",
                comment: "Button title for skipping daily charts in the glucose report"
            )
        }

        static var includeDailyChartsMessage: String {
            String(
                localized: "metabolic_report_flow.daily_charts.message",
                defaultValue: "Include daily charts for the last 9 days.",
                comment: "Message shown before opening the glucose report preview asking whether to include daily charts"
            )
        }
    }
    
    
    
}

//
//  MainChartViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — MainChart Component (Read-only, Cache-based)
//

import SwiftUI
import Charts

struct MainChartViewV1: View {

    // ============================================================
    // MARK: - Layout Inputs
    // ============================================================

    enum ChipLayout {
        case twoRows
        case singleRow
    }

    enum InteractionMode {
        case embedded
        case landscape
    }

    // ============================================================
    // MARK: - Dependencies (SSoT)
    // ============================================================

    @ObservedObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    private let chipLayout: ChipLayout
    private let interactionMode: InteractionMode

    init(
        healthStore: HealthStore,
        chipLayout: ChipLayout = .twoRows,
        interactionMode: InteractionMode = .embedded
    ) {
        self.healthStore = healthStore
        self.chipLayout = chipLayout
        self.interactionMode = interactionMode
    }

    // ============================================================
    // MARK: - UI State
    // ============================================================

    private var dayOffset: Int { healthStore.mainChartSelectedDayOffsetV1 }

    @State private var showDayPickerSheet: Bool = false

    @State private var visibleXSeconds: TimeInterval = 24 * 60 * 60
    @State private var lastMagnificationValue: CGFloat = 1.0

    @State private var yUpperBound: Double = 300
    @State private var lastVerticalDragY: CGFloat = 0

    // ============================================================
    // MARK: - Derived (Cache Read)
    // ============================================================

    private var profile: MainChartDayProfileV1? {
        healthStore.cachedMainChartProfileV1(dayOffset: dayOffset)
    }

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let fixedYDomain: ClosedRange<Double> = 0 ... 300
    private let nutritionOverlayMaxY: Double = 250

    // ============================================================
    // MARK: - Gating (Premium rules)
    // ============================================================

    private var isTherapyEnabled: Bool {
        settings.hasCGM && settings.isInsulinTreated
    }

    // ============================================================
    // MARK: - Glucose Unit (Display-Only Helpers)
    // ============================================================

    private func yAxisLabelText(forTickPositionMgdl tickMgdl: Double) -> String {
        switch settings.glucoseUnit {
        case .mgdL:
            return "\(Int(tickMgdl.rounded()))"
        case .mmolL:
            let mmol = settings.glucoseUnit.convertedValue(fromMgdl: tickMgdl).rounded()
            return "\(Int(mmol))"
        }
    }

    private var glucoseUnitText: String {
        settings.glucoseUnit.label
    }

    private var unitBadge: some View {
        Text(glucoseUnitText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.gray.opacity(0.18), lineWidth: 1))
            .allowsHitTesting(false)
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {

        Group {
            switch interactionMode {
            case .embedded:
                embeddedCardLayout
            case .landscape:
                landscapeFullscreenLayout
            }
        }
        .task { await initialEnsureCache() }
        .modifier(RefreshableIfNeeded(isEnabled: interactionMode == .embedded) {
            await handlePullToRefresh()
        })
        .onAppear {
            applyTherapyGatingIfNeeded()
        }
        .onChange(of: settings.hasCGM) { _ in
            applyTherapyGatingIfNeeded()
        }
        .onChange(of: settings.isInsulinTreated) { _ in
            applyTherapyGatingIfNeeded()
        }
        .onChange(of: healthStore.mainChartSelectedDayOffsetV1) { _ in
            resetZoomStateForNewDay()
            Task { await healthStore.ensureMainChartCachedV1(dayOffset: dayOffset) }
        }
        .sheet(isPresented: $showDayPickerSheet) {
            DayPickerLast10DaysSheet(
                selectedOffset: dayOffset,
                onSelectOffset: { newOffset in
                    healthStore.mainChartSelectedDayOffsetV1 = newOffset
                    showDayPickerSheet = false
                }
            )
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // ============================================================
    // MARK: - Portrait (Embedded)
    // ============================================================

    private var embeddedCardLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            embeddedSingleCard
        }
    }

    private var embeddedSingleCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            headerRow

            chartTapArea

            overlayChipBar
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
    }

    // ============================================================
    // MARK: - Embedded Chart Tap Area
    // ============================================================

    private var chartTapArea: some View {
        Group {
            if let p = profile {
                mainChart(profile: p)
                    .frame(height: 260)
            } else {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                    .padding(.horizontal, 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard interactionMode == .embedded else { return }
            appState.currentStatsScreen = .ig
        }
    }

    // ============================================================
    // MARK: - Landscape
    // ============================================================

    private var landscapeFullscreenLayout: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let edge: CGFloat = 12

            VStack(alignment: .leading, spacing: 10) {

                headerRow
                    .padding(.top, max(edge, insets.top + 6))
                    .padding(.horizontal, edge)

                Group {
                    if let p = profile {
                        mainChart(profile: p)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, edge)

                overlayChipBar
                    .padding(.bottom, max(edge, insets.bottom + 6))
                    .padding(.horizontal, edge)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
        }
    }

    // ============================================================
    // MARK: - Header Row
    // ============================================================

    private var headerRow: some View {
        ZStack {

            HStack(spacing: 14) {
                dayNavButton(isLeft: true)

                Button {
                    showDayPickerSheet = true
                } label: {
                    Text(dayTitleText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                }
                .buttonStyle(.plain)

                dayNavButton(isLeft: false)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                unitBadge
                    .padding(.trailing, 2)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // ============================================================
    // MARK: - Empty State
    // ============================================================

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(L10n.MainChart.emptyTitle)
                .font(.headline)
            Text(L10n.MainChart.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // ============================================================
    // MARK: - Overlay Chip Bar
    // ============================================================

    private var overlayChipBar: some View {
        VStack(alignment: .leading, spacing: 12) {

            switch chipLayout {

            case .twoRows:

                GeometryReader { geo in
                    let spacing: CGFloat = 12
                    let columns: CGFloat = 3
                    let chipWidth = (geo.size.width - spacing * (columns - 1)) / columns

                    VStack(alignment: .leading, spacing: 12) {

                        HStack(spacing: spacing) {
                            overlayChipMetricStyle(L10n.Common.activity, isOn: $settings.mainChartShowActivity, accent: Color.Glu.activityDomain)
                                .frame(width: chipWidth)
                            overlayChipMetricStyle(L10n.MainChart.carbsChip, isOn: $settings.mainChartShowCarbs, accent: Color.Glu.nutritionDomain)
                                .frame(width: chipWidth)
                            overlayChipMetricStyle(L10n.Protein.title, isOn: $settings.mainChartShowProtein, accent: Color.Glu.bodyDomain)
                                .frame(width: chipWidth)
                        }

                        HStack(spacing: spacing) {

                            if isTherapyEnabled {
                                overlayChipMetricStyle(L10n.Bolus.title, isOn: $settings.mainChartShowBolus, accent: bolusChipAccent)
                                    .frame(width: chipWidth)

                                overlayChipMetricStyle(L10n.Basal.title, isOn: $settings.mainChartShowBasal, accent: Color("GluBasalMagenta").opacity(0.5))
                                    .frame(width: chipWidth)

                                overlayChipMetricStyle(L10n.MainChart.sensorChip, isOn: $settings.mainChartShowCGM, accent: Color.Glu.acidCGMRed)
                                    .frame(width: chipWidth)

                            } else {
                                Color.clear.frame(width: chipWidth, height: 1)
                                overlayChipMetricStyle(L10n.MainChart.sensorChip, isOn: $settings.mainChartShowCGM, accent: Color.Glu.acidCGMRed)
                                    .frame(width: chipWidth)
                                Color.clear.frame(width: chipWidth, height: 1)
                            }
                        }
                    }
                    .frame(width: geo.size.width, alignment: .leading)
                }
                .frame(height: (interactionMode == .landscape) ? 104 : 82)

            case .singleRow:

                if interactionMode == .landscape {

                    GeometryReader { geo in
                        let spacing: CGFloat = 12
                        let count: CGFloat = isTherapyEnabled ? 6 : 4
                        let chipWidth = (geo.size.width - spacing * (count - 1)) / count

                        HStack(spacing: spacing) {
                            overlayChipMetricStyle(L10n.Common.activity, isOn: $settings.mainChartShowActivity, accent: Color.Glu.activityDomain)
                                .frame(width: chipWidth)
                            overlayChipMetricStyle(L10n.MainChart.carbsChip, isOn: $settings.mainChartShowCarbs, accent: Color.Glu.nutritionDomain)
                                .frame(width: chipWidth)
                            overlayChipMetricStyle(L10n.Protein.title, isOn: $settings.mainChartShowProtein, accent: Color.Glu.bodyDomain)
                                .frame(width: chipWidth)

                            if isTherapyEnabled {
                                overlayChipMetricStyle(L10n.Bolus.title, isOn: $settings.mainChartShowBolus, accent: bolusChipAccent)
                                    .frame(width: chipWidth)
                                overlayChipMetricStyle(L10n.Basal.title, isOn: $settings.mainChartShowBasal, accent: Color("GluBasalMagenta").opacity(0.5))
                                    .frame(width: chipWidth)
                            }

                            overlayChipMetricStyle(L10n.MainChart.sensorChip, isOn: $settings.mainChartShowCGM, accent: Color.Glu.acidCGMRed)
                                .frame(width: chipWidth)
                        }
                        .frame(width: geo.size.width, alignment: .leading)
                    }
                    .frame(height: 44)

                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            overlayChipMetricStyle(L10n.Common.activity, isOn: $settings.mainChartShowActivity, accent: Color.Glu.activityDomain)
                            overlayChipMetricStyle(L10n.MainChart.carbsChip, isOn: $settings.mainChartShowCarbs, accent: Color.Glu.nutritionDomain)
                            overlayChipMetricStyle(L10n.Protein.title, isOn: $settings.mainChartShowProtein, accent: Color.Glu.bodyDomain)
                            if isTherapyEnabled {
                                overlayChipMetricStyle(L10n.Bolus.title, isOn: $settings.mainChartShowBolus, accent: bolusChipAccent)
                                overlayChipMetricStyle(L10n.Basal.title, isOn: $settings.mainChartShowBasal, accent: Color("GluBasalMagenta").opacity(0.5))
                            }
                            overlayChipMetricStyle(L10n.MainChart.sensorChip, isOn: $settings.mainChartShowCGM, accent: Color.Glu.acidCGMRed)
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 5)
        .padding(.bottom, 0)
    }

    private var bolusChipAccent: Color { Color("acidBolusDarkGreen") }

    private func overlayChipMetricStyle(_ title: String, isOn: Binding<Bool>, accent: Color) -> some View {
        let isActive = isOn.wrappedValue

        let font: Font = (interactionMode == .landscape)
        ? .callout.weight(.semibold)
        : .caption.weight(.semibold)

        let vPad: CGFloat = (interactionMode == .landscape) ? 10 : 5
        let hPad: CGFloat = (interactionMode == .landscape) ? 18 : 12

        return Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .padding(.vertical, vPad)
                .padding(.horizontal, hPad)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MetricChipLookalikeStyle(accent: accent, isActive: isActive))
    }

    private struct MetricChipLookalikeStyle: ButtonStyle {

        let accent: Color
        let isActive: Bool

        func makeBody(configuration: Configuration) -> some View {

            let visualActive = isActive || configuration.isPressed

            let strokeColor: Color = visualActive
            ? Color.white.opacity(0.90)
            : accent.opacity(0.90)

            let lineWidth: CGFloat = visualActive ? 1.6 : 1.2

            let backgroundFill: some ShapeStyle = visualActive
            ? LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            let shadowOpacity: Double = visualActive ? 0.25 : 0.15
            let shadowRadius: CGFloat = visualActive ? 4 : 2.5
            let shadowYOffset: CGFloat = visualActive ? 2 : 1.5

            return configuration.label
                .background(Capsule().fill(backgroundFill))
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(visualActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95))
                .scaleEffect(visualActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: visualActive)
        }
    }

    // ============================================================
    // MARK: - MainChart (CGM + Overlays)
    // ============================================================

    @ViewBuilder
    private func mainChart(profile: MainChartDayProfileV1) -> some View {

        let window = xDomainWindow(for: profile)

        let baseY: Double = 0
        let activityBarHeight: Double = 8

        let insulinMaxUnits = maxVisibleInsulinUnits(profile: profile, window: window)

        let targetMin = max(fixedYDomain.lowerBound, min(Double(settings.glucoseMin), fixedYDomain.upperBound))
        let targetMax = max(fixedYDomain.lowerBound, min(Double(settings.glucoseMax), fixedYDomain.upperBound))
        let bandLower = min(targetMin, targetMax)
        let bandUpper = max(targetMin, targetMax)

        // 🟨 UPDATED
        let autoUpper = autoYUpperBound(for: profile, window: window)
        let effectiveUpper = interactionMode == .landscape
        ? max(autoUpper, max(120, min(600, yUpperBound)))
        : autoUpper
        let yDomain: ClosedRange<Double> = 0 ... effectiveUpper

        let baseChart = Chart {

            targetRangeBand(window: window, bandLower: bandLower, bandUpper: bandUpper)

            if settings.mainChartShowCGM {
                cgmLineMarks(profile: profile, window: window)
            }

            if settings.mainChartShowActivity {
                activityBars(profile: profile, window: window, baseY: baseY, height: activityBarHeight)
            }

            if settings.mainChartShowCarbs {
                nutritionStems(profile: profile, window: window, kind: .carbs, baseY: baseY)
            }

            if settings.mainChartShowProtein {
                nutritionStems(profile: profile, window: window, kind: .protein, baseY: baseY)
            }

            if isTherapyEnabled && settings.mainChartShowBolus {
                bolusStems(profile: profile, window: window, baseY: baseY, insulinMaxUnits: insulinMaxUnits)
            }

            if isTherapyEnabled && settings.mainChartShowBasal {
                basalStems(profile: profile, window: window, baseY: baseY, insulinMaxUnits: insulinMaxUnits)
            }
        }
        .chartXScale(domain: window.start ... window.end)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: xAxisHourStride24h())) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(xAxisHourText(date))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                    }
                }
            }
        }
        .chartYAxis {
            // 🟨 UPDATED
            AxisMarks(position: .leading, values: yAxisValues(upperMgdl: effectiveUpper)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.22))
                AxisTick()
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(yAxisLabelText(forTickPositionMgdl: v))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                    }
                }
            }
        }

        if #available(iOS 17.0, *) {

            let availableSeconds = max(1, window.end.timeIntervalSince(window.start))
            let visibleLengthSeconds = min(visibleXSeconds, availableSeconds)
            let isZoomedIn = visibleLengthSeconds < (availableSeconds - 1)

            let chartWithDomain = baseChart
                .chartXVisibleDomain(length: visibleLengthSeconds)

            let chartWithOptionalScroll = Group {
                if isZoomedIn {
                    chartWithDomain.chartScrollableAxes(.horizontal)
                } else {
                    chartWithDomain
                }
            }

            if interactionMode == .embedded {
                chartWithOptionalScroll
            } else {

                let xZoomGesture = MagnifyGesture(minimumScaleDelta: 0.01)
                    .onChanged { value in
                        let current = value.magnification
                        let delta = current / max(0.0001, lastMagnificationValue)
                        lastMagnificationValue = current

                        let proposed = visibleXSeconds / Double(delta)

                        let minSeconds: TimeInterval = 1 * 60 * 60
                        let maxSeconds: TimeInterval = availableSeconds
                        visibleXSeconds = min(maxSeconds, max(minSeconds, proposed))
                    }
                    .onEnded { _ in
                        lastMagnificationValue = 1.0
                    }

                chartWithOptionalScroll
                    .highPriorityGesture(xZoomGesture)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { g in
                                let dx = g.translation.width
                                let dy = g.translation.height
                                guard abs(dy) > abs(dx) else { return }

                                let deltaY = dy - lastVerticalDragY
                                lastVerticalDragY = dy

                                let sensitivity: Double = 0.9
                                let proposed = yUpperBound + Double(deltaY) * sensitivity
                                yUpperBound = min(600, max(120, proposed))
                            }
                            .onEnded { _ in
                                lastVerticalDragY = 0
                            }
                    )
            }

        } else {
            baseChart
        }
    }

    // 🟨 UPDATED
    private func yAxisValues(upperMgdl: Double) -> [Double] {
        let upperMgdl = max(120, min(600, upperMgdl))

        switch settings.glucoseUnit {

        case .mgdL:
            let step: Double = 50
            let snappedUpper = ceil(upperMgdl / step) * step
            return Array(stride(from: 0, through: snappedUpper, by: step))

        case .mmolL:
            let stepMmol: Double = 2
            let upperMmol = settings.glucoseUnit.convertedValue(fromMgdl: upperMgdl)
            let snappedUpperMmol = ceil(upperMmol / stepMmol) * stepMmol
            let mmolTicks = Array(stride(from: 0, through: snappedUpperMmol, by: stepMmol))
            return mmolTicks.map { settings.glucoseUnit.mgdlValue(fromMmol: $0) }
        }
    }

    // ============================================================
    // MARK: - Refresh Logic
    // ============================================================

    @MainActor
    private func initialEnsureCache() async {
        await healthStore.ensureMainChartCachedV1(dayOffset: dayOffset)
    }

    @MainActor
    private func handlePullToRefresh() async {
        if settings.hasCGM && settings.isInsulinTreated {
            await healthStore.refreshMetabolicRaw3DaysTherapyOnlyV1(refreshSource: "mainchart-pull")
        }
        await healthStore.ensureMainChartCachedV1(dayOffset: dayOffset, forceRefetch: true)
    }

    // ============================================================
    // MARK: - Gating Apply Helper
    // ============================================================

    @MainActor
    private func applyTherapyGatingIfNeeded() {

        if isTherapyEnabled {
            return
        }

        settings.mainChartShowBolus = false
        settings.mainChartShowBasal = false
    }

    // ============================================================
    // MARK: - Helpers (Chart Data)
    // ============================================================

    private struct TimeWindow {
        let start: Date
        let end: Date
    }

    private func xDomainWindow(for profile: MainChartDayProfileV1) -> TimeWindow {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: profile.day)

        let fullEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let end: Date = profile.isToday ? min(Date(), fullEnd) : fullEnd
        let start: Date = dayStart

        return TimeWindow(start: start, end: end)
    }

    private func xAxisHourStride24h() -> Int { 3 }

    // ============================================================
    // MARK: - Chart Content Builders
    // ============================================================

    @ChartContentBuilder
    private func targetRangeBand(window: TimeWindow, bandLower: Double, bandUpper: Double) -> some ChartContent {
        RectangleMark(
            xStart: .value("Band Start", window.start),
            xEnd:   .value("Band End", window.end),
            yStart: .value("Target Min", bandLower),
            yEnd:   .value("Target Max", bandUpper)
        )
        .foregroundStyle(Color.green.opacity(0.15))
        .opacity(1.0)
    }

    @ChartContentBuilder
    private func cgmLineMarks(profile: MainChartDayProfileV1, window: TimeWindow) -> some ChartContent {
        let stroke = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        let cgm = Color.Glu.acidCGMRed

        ForEach(filteredCGMPoints(profile: profile, window: window)) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.glucoseMgdl)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(stroke)
            .foregroundStyle(cgm)
            .shadow(color: cgm.opacity(0.20), radius: 1.6, x: 0, y: 1)
        }
    }

    @ChartContentBuilder
    private func activityBars(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        height: Double
    ) -> some ChartContent {
        let fill = Color.Glu.activityDomain.opacity(0.55)

        ForEach(filteredActivityEvents(profile: profile, window: window)) { act in
            RectangleMark(
                xStart: .value("Activity Start", act.start),
                xEnd:   .value("Activity End", act.end),
                yStart: .value("Activity Base", baseY),
                yEnd:   .value("Activity Top", baseY + height)
            )
            .foregroundStyle(fill)
            .shadow(color: Color.black.opacity(0.18), radius: 2.0, x: 0, y: 1.4)
        }
    }

    @ChartContentBuilder
    private func nutritionStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        kind: NutritionEventKind,
        baseY: Double
    ) -> some ChartContent {

        let isCarbs = (kind == .carbs)

        let carbsColor: Color = Color.Glu.nutritionDomain.opacity(0.85)
        let proteinColor: Color = Color.Glu.bodyDomain.opacity(0.95)

        let lineWidth: CGFloat = isCarbs ? 6.0 : 3.0

        let markColor: Color = isCarbs ? carbsColor : proteinColor
        let textColor: Color = isCarbs ? carbsColor : Color.Glu.bodyDomain

        ForEach(filteredNutrition(profile: profile, window: window, kind: kind)) { e in
            let topY = nutritionBarTopYMgdl(grams: e.grams)

            RuleMark(
                x: .value(isCarbs ? "Carbs Time" : "Protein Time", e.timestamp),
                yStart: .value("Nutrition Base", baseY),
                yEnd:   .value("Nutrition Top", topY)
            )
            .lineStyle(
                StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .butt,
                    lineJoin: .miter
                )
            )
            .foregroundStyle(markColor)
            .shadow(color: Color.black.opacity(0.14), radius: 1.4, x: 0, y: 1.1)
            .annotation(position: .top, alignment: .center) {
                if e.grams >= 5 {
                    Text("\(Int(e.grams.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(textColor)
                }
            }
        }
    }

    @ChartContentBuilder
    private func bolusStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        insulinMaxUnits: Double
    ) -> some ChartContent {

        let bolusGreen = Color("acidBolusDarkGreen")

        ForEach(filteredBolusEvents(profile: profile, window: window)) { event in
            let topY = insulinBarTopYMgdl(units: event.units, maxUnits: insulinMaxUnits)

            RuleMark(
                x: .value("Bolus Time", event.timestamp),
                yStart: .value("Bolus Base", baseY),
                yEnd:   .value("Bolus Top", topY)
            )
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(bolusGreen.opacity(0.92))
            .shadow(color: Color.black.opacity(0.16), radius: 1.8, x: 0, y: 1.2)
            .annotation(position: .top, alignment: .center) {
                if event.units > 0 {
                    Text("\(Int(event.units.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(bolusGreen.opacity(0.95))
                }
            }
        }
    }

    @ChartContentBuilder
    private func basalStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        insulinMaxUnits: Double
    ) -> some ChartContent {

        let basalColor: Color = Color("GluBasalMagenta").opacity(0.7)

        ForEach(filteredBasalEvents(profile: profile, window: window)) { event in
            let topY = insulinBarTopYMgdl(units: event.units, maxUnits: insulinMaxUnits)

            RuleMark(
                x: .value("Basal Time", event.timestamp),
                yStart: .value("Basal Base", baseY),
                yEnd:   .value("Basal Top", topY)
            )
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(basalColor)
            .shadow(color: Color.black.opacity(0.18), radius: 2.0, x: 0, y: 1.4)
            .annotation(position: .top, alignment: .center) {
                if event.units > 0 {
                    Text("\(Int(event.units.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(basalColor)
                }
            }
        }
    }

    // ============================================================
    // MARK: - Helpers (Chart Data)
    // ============================================================

    private func filteredCGMPoints(profile: MainChartDayProfileV1, window: TimeWindow) -> [CGMSamplePoint] {
        profile.cgm
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredBolusEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [InsulinBolusEvent] {
        profile.bolus
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredBasalEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [InsulinBasalEvent] {
        profile.basal
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredActivityEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [ActivityOverlayEvent] {
        profile.activity
            .filter { $0.end > window.start && $0.start < window.end }
            .sorted { $0.start < $1.start }
    }

    private func filteredNutrition(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        kind: NutritionEventKind
    ) -> [NutritionEvent] {
        let list: [NutritionEvent] = (kind == .carbs) ? profile.carbs : profile.protein
        return list
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // 🟨 UPDATED
    private func autoYUpperBound(for profile: MainChartDayProfileV1, window: TimeWindow) -> Double {
        let visibleCGMMax = filteredCGMPoints(profile: profile, window: window)
            .map(\.glucoseMgdl)
            .max() ?? 0

        let headroom: Double = 20
        let rawUpper = max(
            300,
            Double(settings.glucoseMax),
            visibleCGMMax + headroom
        )

        let snapped = ceil(rawUpper / 50) * 50
        return min(600, max(300, snapped))
    }

    // ============================================================
    // MARK: - Mapping: Nutrition (grams -> mg/dL height)
    // ============================================================

    private func nutritionBarTopYMgdl(grams: Double) -> Double {
        let g = max(0, grams)

        let anchorGrams: Double = 34
        let anchorMgdl: Double = 100

        let y = (g / max(1, anchorGrams)) * anchorMgdl
        return min(nutritionOverlayMaxY, max(0, y))
    }

    // ============================================================
    // MARK: - Mapping: Insulin (units -> mg/dL height)
    // ============================================================

    private func maxVisibleInsulinUnits(profile: MainChartDayProfileV1, window: TimeWindow) -> Double {
        let bolus = profile.bolus
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .map { max(0, $0.units) }

        let basal = profile.basal
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .map { max(0, $0.units) }

        return max(0.0, (bolus + basal).max() ?? 0.0)
    }

    private func insulinBarTopYMgdl(units: Double, maxUnits: Double) -> Double {
        let u = max(0, units)

        let targetPeakMgdl: Double = 150
        guard maxUnits > 0 else { return 0 }

        let y = (u / maxUnits) * targetPeakMgdl
        return min(nutritionOverlayMaxY, max(0, y))
    }

    // ============================================================
    // MARK: - Helpers (UI)
    // ============================================================

    private func xAxisHourText(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        return String(format: "%02d", hour)
    }

    private var dayTitleText: String {
        if dayOffset == 0 { return L10n.MainChart.today }
        if dayOffset == -1 { return L10n.MainChart.yesterday }

        guard let p = profile else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: p.day)
    }

    private func dayNavButton(isLeft: Bool) -> some View {
        Button {
            if isLeft {
                healthStore.mainChartSelectedDayOffsetV1 = max(dayOffset - 1, -9)
            } else {
                healthStore.mainChartSelectedDayOffsetV1 = min(dayOffset + 1, 0)
            }

            resetZoomStateForNewDay()

            Task { await healthStore.ensureMainChartCachedV1(dayOffset: dayOffset) }

        } label: {
            Image(systemName: isLeft ? "chevron.left" : "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    Color.Glu.primaryBlue.opacity(isEnabledNav(isLeft: isLeft) ? 0.95 : 0.25)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabledNav(isLeft: isLeft))
    }

    private func isEnabledNav(isLeft: Bool) -> Bool {
        if isLeft { return dayOffset > -9 }
        return dayOffset < 0
    }

    private func resetZoomStateForNewDay() {
        visibleXSeconds = 24 * 60 * 60
        lastMagnificationValue = 1.0
        lastVerticalDragY = 0

        // 🟨 UPDATED
        if let profile {
            let window = xDomainWindow(for: profile)
            yUpperBound = autoYUpperBound(for: profile, window: window)
        } else {
            yUpperBound = 300
        }
    }
}

// ============================================================
// MARK: - Last 10 Days Sheet (Calendar-like)
// ============================================================

private struct DayPickerLast10DaysSheet: View {

    let selectedOffset: Int
    let onSelectOffset: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    private struct DayItem: Identifiable {
        let id: Int
        let date: Date
        let isToday: Bool
        let isYesterday: Bool
    }

    private var days: [DayItem] {
        let todayStart = calendar.startOfDay(for: Date())
        return (0...9).map { delta in
            let offset = -delta
            let date = calendar.date(byAdding: .day, value: offset, to: todayStart) ?? todayStart
            return DayItem(
                id: offset,
                date: date,
                isToday: offset == 0,
                isYesterday: offset == -1
            )
        }
    }

    private var titleText: String { L10n.MainChart.dayPickerTitle }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(days) { item in
                        dayCell(item)
                    }
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(titleText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(
                            colorScheme == .light
                            ? Color.Glu.primaryBlue
                            : Color.Glu.systemForeground
                        )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.MainChart.done) { dismiss() }
                }
            }
            .tint(Color.Glu.systemForeground)
            .background(Color(.systemBackground))
        }
        .tint(Color.Glu.systemForeground)
        .presentationBackground(Color(.systemBackground))
    }

    private func dayCell(_ item: DayItem) -> some View {

        let isSelected = (item.id == selectedOffset)
        let bg = isSelected ? Color.Glu.primaryBlue.opacity(0.10) : Color.gray.opacity(0.08)
        let stroke = isSelected ? Color.Glu.systemForeground.opacity(0.55) : Color.clear

        return Button {
            onSelectOffset(item.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {

                Text(weekdayShort(item.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Glu.systemForeground.opacity(0.85))

                Text(item.id == 0 ? L10n.MainChart.today : (item.id == -1 ? L10n.MainChart.yesterday : dateMedium(item.date)))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.Glu.systemForeground.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(bg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(stroke, lineWidth: 1.6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.id == 0 ? L10n.MainChart.today : (item.id == -1 ? L10n.MainChart.yesterday : dateMedium(item.date)))
        .accessibilityValue(isSelected ? L10n.MainChart.selected : "")
    }

    private func weekdayShort(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE")
        return df.string(from: date)
    }

    private func dateMedium(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }
}

// ============================================================
// MARK: - Refreshable Helper (Landscape: disabled)
// ============================================================

private struct RefreshableIfNeeded: ViewModifier {
    let isEnabled: Bool
    let action: () async -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    MainChartViewV1(healthStore: .preview())
        .environmentObject(SettingsModel.shared)
}

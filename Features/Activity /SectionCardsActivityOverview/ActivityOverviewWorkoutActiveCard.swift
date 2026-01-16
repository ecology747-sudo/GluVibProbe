//
//  ActivityOverviewWorkoutActiveCard.swift
//  GluVibProbe
//
//  Activity Overview — Section Card (Workout Time + Active Energy)
//  - Extracted from ActivityOverviewViewV1 (no design changes)
//  - Two tiles remain identical (layout, fonts, spacing)
//  - All icons/fills use Activity Domain color
//

import SwiftUI

struct ActivityOverviewWorkoutActiveCard: View {

    let todayWorkoutMinutes: Int
    let avgWorkoutMinutes7d: Int
    let onTapWorkout: () -> Void

    let todayKcal: Int
    let avgKcal7d: Int
    let onTapActiveEnergy: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            ActivityOverviewWorkoutTile(
                todayWorkoutMinutes: todayWorkoutMinutes,
                avgWorkoutMinutes7d: avgWorkoutMinutes7d,
                onTap: onTapWorkout
            )

            ActivityOverviewActiveEnergyTile(
                todayKcal: todayKcal,
                avgKcal7d: avgKcal7d,
                onTap: onTapActiveEnergy
            )
        }
    }
}

// MARK: - Workout Tile (identical layout, Activity color)

private struct ActivityOverviewWorkoutTile: View {

    let todayWorkoutMinutes: Int
    let avgWorkoutMinutes7d: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Label {
                    Text("Workout min")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Glu.activityDomain) // ✅ Activity
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("\(todayWorkoutMinutes)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                let avg = max(Double(avgWorkoutMinutes7d), 1.0)
                let ratio = min(max(Double(todayWorkoutMinutes) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {

                    ZStack {
                        Circle()
                            .stroke(Color.Glu.primaryBlue.opacity(0.15), lineWidth: 7)

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.activityDomain, // ✅ Activity
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("Ø")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)

                            Text("7d")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 50, height: 50)

                    Text("\(avgWorkoutMinutes7d) min")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Active Energy Tile (identical layout, Activity color)

private struct ActivityOverviewActiveEnergyTile: View {

    let todayKcal: Int
    let avgKcal7d: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Label {
                    Text("Active energy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Glu.activityDomain) // ✅ Activity
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("\(todayKcal)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                let avg = max(Double(avgKcal7d), 1.0)
                let ratio = min(max(Double(todayKcal) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {

                    ZStack {
                        Circle()
                            .stroke(Color.Glu.primaryBlue.opacity(0.15), lineWidth: 7)

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.activityDomain, // ✅ Activity
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("Ø")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)

                            Text("7d")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 50, height: 50)

                    Text("\(avgKcal7d) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Preview (minimal, no extra layout/background)

#Preview("Activity Overview Workout + Active Card") {
    ActivityOverviewWorkoutActiveCard(
        todayWorkoutMinutes: 38,
        avgWorkoutMinutes7d: 42,
        onTapWorkout: {},

        todayKcal: 620,
        avgKcal7d: 540,
        onTapActiveEnergy: {}
    )
}

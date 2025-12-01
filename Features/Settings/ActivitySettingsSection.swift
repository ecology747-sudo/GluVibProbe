//
//  ActivitySettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: ACTIVITY – Targets wie Daily Step Goal
///
/// - Nutzt die zentrale Domain-Farbe: Color.Glu.activityAccent
/// - Zeigt nur den Activity-Bereich (Daily Step Target)
/// - Optik wie eine Domain-Kachel (ähnlich BodySettingsSection)
struct ActivitySettingsSection: View {

    // MARK: - Bindings aus SettingsView
    
    @Binding var dailyStepTarget: Int

    // MARK: - Body
    
    var body: some View {
        Section {
            ZStack {
                // Hintergrundkarte
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.activityAccent.opacity(0.06))
                
                // Rahmen in Activity-Farbe
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.activityAccent.opacity(0.7), lineWidth: 1)
                
                VStack(alignment: .leading, spacing: 16) {
                    
                
                    
                    // CONTENT: Daily Step Target
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Step Target")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)
                        
                        HStack {
                            Spacer()
                            
                            Picker("", selection: $dailyStepTarget) {
                                ForEach(Array(stride(from: 1_000, through: 30_000, by: 500)), id: \.self) { steps in
                                    Text("\(steps) steps")
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(steps)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }
                }
                .padding(16)
            }
            // Zelle im Form-Hintergrund freistellen,
            // damit nur unsere Karte sichtbar ist
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

// MARK: - Preview

#Preview("ActivitySettingsSection") {
    NavigationStack {
        Form {
            ActivitySettingsSection(dailyStepTarget: .constant(10_000))
        }
    }
}

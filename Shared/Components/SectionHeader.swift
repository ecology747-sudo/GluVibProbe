//
//  SectionHeader.swift
//  GluVibProbe
//
//  Created by MacBookAir on 17.11.25.
//

import SwiftUI

struct SectionHeader: View {
    let title: String      // z.B. "Heute", "Schrittverlauf (30 Tage)"
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.top, 10)
    }
}

#Preview {
    SectionHeader("Beispiel-Überschrift")
}

//
//  ContentView.swift
//  90
//
//  Created by Shahin on 17.07.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        CameraView()
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

#Preview {
    ContentView()
}

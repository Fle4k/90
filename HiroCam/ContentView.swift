//
//  ContentView.swift
//  HiroCam
//
//  Created by Shahin on 17.07.25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        CameraView()
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
            .onAppear {
                // Ensure camera session starts early so auto-record can trigger
                // CameraView already calls startCameraSession in onAppear, this is just a safeguard
            }
    }
}

#Preview {
    ContentView()
}

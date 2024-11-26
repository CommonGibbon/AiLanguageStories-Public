//
//  LaunchScreenView.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/16/24.
//

import Foundation
import SwiftUI

struct LaunchScreenView: View {
   @State private var isActive = false
   @State private var showLanguageSelectionView: Bool = false
   @State private var opacity = 1.0
   @ObservedObject var viewModel: StoryViewModel

   var body: some View {
       ZStack {
           Color("BackgroundColor")
               .ignoresSafeArea(.all)
           VStack {
               if self.isActive {
                   if showLanguageSelectionView {
                       LanguageSelectionView(viewModel: viewModel, isPresented: $showLanguageSelectionView)
                   } else {
                       MainView(viewModel: viewModel)
                   }
               } else {
                   if viewModel.settingsConfig.selectedLanguage.name == "Japanese" {
                       Image("LoadScreenLogoJapanese")
                           .resizable()
                           .scaledToFit()
                           .frame(width: 600, height: 800)
                           .opacity(opacity)
                           .transition(.opacity)  // Add transition effect
                   } else {
                       Image("LoadScreenLogo")
                           .resizable()
                           .scaledToFit()
                           .frame(width: 600, height: 800)
                           .opacity(opacity)
                           .transition(.opacity)  // Add transition effect
                   }
               }
           }
           .onAppear {
               viewModel.loadCharacterClickCounts()
               viewModel.loadSettingsConfig()
               if !viewModel.settingsConfig.didInitialize {
                   showLanguageSelectionView = true
               } else {
                   Task { // if we've already configured language settings, we can load assistant and thread now
                       await viewModel.initializeAssistantAndThread()
                   }
               }

               DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                   withAnimation(.easeOut(duration: 1.5)) {
                       self.opacity = 0.0
                   }
                   DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                       self.isActive = true
                   }
               }
           }
       }
   }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var red, green, blue, alpha: Double

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            red = Double((rgb & 0xFF0000) >> 16) / 255.0
            green = Double((rgb & 0x00FF00) >> 8) / 255.0
            blue = Double(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        } else if length == 8 {
            red = Double((rgb & 0xFF000000) >> 24) / 255.0
            green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

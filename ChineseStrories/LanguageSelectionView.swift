//
//  LanguageSelectionView.swift
//  ChineseStories
//
//  Created by Will Shannon on 10/1/24.
//

import Foundation
import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var viewModel: StoryViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea(.all)
            VStack {
                Text("Select Language")
                    .font(.title)
                    .padding()
                
                VStack(alignment: .leading, spacing: 15) {
                    // Language Picker
                    VStack(alignment: .leading) {
                        Text("Language")
                            .font(.headline)
                        Picker("Language", selection: $viewModel.settingsConfig.selectedLanguage) {
                            ForEach(SettingsConfiguration.availableLanguages) { language in
                                Text(language.name).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Language Level Section
                    LanguageLevelPickerView(selectedLanguageLevel: $viewModel.settingsConfig.languageLevel)
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    viewModel.settingsConfig.didInitialize = true
                    viewModel.saveSettingsConfig() // Save the settings
                    isPresented = false
                    viewModel.settingsChanged = true
                    viewModel.initializingConnection = false
                    // now that we've set the language settings, we can load assistant and thread
                    /*Task {
                        await viewModel.initializeAssistantAndThread()
                    }*/
                }) {
                    Text("Save")
                        .padding()
                        .background(Color("ButtonColor"))
                        .foregroundColor(Color("ButtonTextColor"))
                        .cornerRadius(10)
                        .padding(.bottom, 10)
                }
            }
            .padding()
        }
    }
}


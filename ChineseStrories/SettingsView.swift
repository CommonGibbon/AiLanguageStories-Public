//
//  SettingsView.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/15/24.
//

import Foundation
import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var viewModel: StoryViewModel
    @Binding var settingsConfig: SettingsConfiguration  // Updated
    @Binding var isPresented: Bool
    
    @State private var showGenres: Bool = false
    
    private let genres = ["Sci-Fi", "Fantasy", "Mystery", "Adventure", "Horror", "Comedy"]
    private let tones = ["", "Dark", "Lighthearted", "Suspensful"]
    private let conflicts = ["", "Character vs. Character", "Character vs. Nature", "Character vs. Self", "Character vs. Society", "Character vs. Technology", "Character vs. Alien/Monster/Creature", "Character vs. Engima"]
    private let timePeriods = ["", "Distant Past", "Near Past", "Present", "Near Future", "Distant Future"]
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title2)
                .padding(.bottom, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Language Picker
                    VStack(alignment: .leading) {
                        Text("Language")
                            .font(.headline)
                        Picker("Language", selection: $settingsConfig.selectedLanguage) {
                            ForEach(SettingsConfiguration.availableLanguages) { language in
                                Text(language.name).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    LanguageLevelPickerView(selectedLanguageLevel: $settingsConfig.languageLevel)
                    /*VStack(alignment: .leading, spacing: 20) {
                        Text("Language Level")
                            .font(.headline)
                        
                        HStack {
                            // Left arrow (conditionally hidden if at the first item)
                            Image(systemName: "chevron.left")
                                .opacity(settingsConfig.languageLevel == SettingsConfiguration.languageLevels.first?.key ? 0.3 : 1.0)
                                .onTapGesture {
                                    moveSelectionLeft()
                                }
                            
                            // Horizontal Picker using TabView
                            TabView(selection: $settingsConfig.languageLevel) {
                                ForEach(SettingsConfiguration.languageLevels, id: \.key) { level in
                                    Text(level.key)
                                        .font(.headline)
                                        .tag(level.key)
                                        .frame(maxWidth: .infinity, maxHeight: 50)  // Adjust height as needed
                                        .background(Color.gray.opacity(0.2))  // Optional: Add background for better visibility
                                        .cornerRadius(10)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))  // Horizontal scrolling without page dots
                            .frame(height: 60)  // Adjust height to fit your design
                            
                            // Right arrow (conditionally hidden if at the last item)
                            Image(systemName: "chevron.right")
                                .opacity(settingsConfig.languageLevel == SettingsConfiguration.languageLevels.last?.key ? 0.3 : 1.0)
                                .onTapGesture {
                                    moveSelectionRight()
                                }
                        }
                        
                        // Show the description of the selected language level
                        if let selectedDescription = SettingsConfiguration.languageLevels.first(where: { $0.key == settingsConfig.languageLevel })?.description {
                            Text(selectedDescription)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                    }
                    .padding()*/

                    // Genre Section
                    HStack {
                        Text("Genre")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showGenres.toggle()
                        }) {
                            Image(systemName: showGenres ? "chevron.up" : "chevron.down")
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.bottom, 5)
                    
                    if showGenres {
                        VStack {
                            ForEach(genres, id: \.self) { genre in
                                MultipleSelectionRow(title: genre, isSelected: settingsConfig.selectedGenres.contains(genre)) {
                                    if let index = settingsConfig.selectedGenres.firstIndex(of: genre) {
                                        settingsConfig.selectedGenres.remove(at: index)
                                    } else {
                                        settingsConfig.selectedGenres.append(genre)
                                        if settingsConfig.selectedGenres.count > 2 {
                                            settingsConfig.selectedGenres.removeFirst()
                                        }
                                    }
                                }
                                .padding(5)
                                .background(settingsConfig.selectedGenres.contains(genre) ? Color("ButtonColor").opacity(0.2) : Color.clear)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(settingsConfig.selectedGenres.contains(genre) ? Color("ButtonColor") : Color.gray, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    
                    // Tone Section
                    VStack(alignment: .leading) {
                        Text("Tone")
                            .font(.headline)
                        Picker("Tone", selection: $settingsConfig.selectedTone) {
                            ForEach(tones, id: \.self) { tone in
                                Text(tone).tag(tone)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Conflict Type Section
                    VStack(alignment: .leading) {
                        Text("Conflict Type")
                            .font(.headline)
                        Picker("Conflict Type", selection: $settingsConfig.selectedConflict) {
                            ForEach(conflicts, id: \.self) { conflict in
                                Text(conflict).tag(conflict)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Time Period Section
                    VStack(alignment: .leading) {
                        Text("Time Period")
                            .font(.headline)
                        Picker("Time Period", selection: $settingsConfig.selectedTimePeriod) {
                            ForEach(timePeriods, id: \.self) { timePeriod in
                                Text(timePeriod).tag(timePeriod)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Custom Requests Section
                    VStack(alignment: .leading) {
                        Text("Custom Requests")
                            .font(.headline)
                        TextField("Enter custom requests", text: $settingsConfig.customRequest)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Save Button
            Spacer()
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("ButtonColor"))
                .foregroundColor(Color("ButtonTextColor"))
                .cornerRadius(10)
                .padding(.bottom, 10)
                
                Button("Save") {
                    viewModel.settingsConfig = settingsConfig
                    viewModel.saveSettingsConfig()  // Save the settings when user saves
                    viewModel.settingsChanged = true
                    isPresented = false
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("ButtonColor"))
                .foregroundColor(Color("ButtonTextColor"))
                .cornerRadius(10)
                .padding(.bottom, 10)
            }
        }
        .padding()
        .onAppear {
            self.settingsConfig = viewModel.settingsConfig
        }
    }
    
    // Helper functions to move the selection
    func moveSelectionLeft() {
        if let currentIndex = SettingsConfiguration.languageLevels.firstIndex(where: { $0.key == settingsConfig.languageLevel }),
           currentIndex > 0 {
            settingsConfig.languageLevel = SettingsConfiguration.languageLevels[currentIndex - 1].key
        }
    }

    func moveSelectionRight() {
        if let currentIndex = SettingsConfiguration.languageLevels.firstIndex(where: { $0.key == settingsConfig.languageLevel }),
           currentIndex < SettingsConfiguration.languageLevels.count - 1 {
            settingsConfig.languageLevel = SettingsConfiguration.languageLevels[currentIndex + 1].key
        }
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: self.action) {
            HStack {
                Text(self.title)
                    .foregroundColor(.black)
                Spacer()
                if self.isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("ButtonTextColor"))
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
    }
}



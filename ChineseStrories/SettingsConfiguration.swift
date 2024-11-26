//
//  SettingsConfiguration.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/18/24.
//
                                                                                                                   
import Foundation
import SwiftUI
                                                                                                                   
// Define the Language struct
struct Language: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let romanizationSystem: String
    var scriptName: String
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Implement Equatable
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.id == rhs.id
    }
}

// Define the SettingsConfiguration struct
struct SettingsConfiguration: Codable {
    // Define available languages
    static let availableLanguages: [Language] = [
        Language(id: "zh", name: "Chinese", romanizationSystem: "Pinyin", scriptName: "Simplified Chinese"),
        Language(id: "ja", name: "Japanese", romanizationSystem: "Romaji", scriptName: "Japanese Hiragana")
    ]

    // using CEFR learning levels:
    static let languageLevels: [(key: String, description: String)] = [
        ("Pre-A1", "Can recognize a few basic words or phrases but cannot yet use the language independently."),
        ("Beginner - A1", "Can understand and use basic expressions and phrases for immediate needs."),
        ("Beginner - A2", "Can communicate in simple tasks and understand frequently used expressions."),
        ("Intermediate - B1", "Can handle most situations while traveling and produce simple connected text."),
        ("Intermediate - B2", "Can understand main ideas of complex texts and interact with fluency."),
        ("Advanced - C1", "Can express ideas fluently and use language flexibly in social and professional contexts."),
        ("Advanced - C2", "Can understand almost everything and express themselves spontaneously with precision.")
    ]
    
    // Settings properties
    var selectedLanguage: Language = availableLanguages[0]
    var languageLevel: String = "Pre-A1"
    var selectedGenres: [String] = []
    var selectedTone: String = ""
    var selectedConflict: String = ""
    var selectedTimePeriod: String = ""
    var customRequest: String = ""
    var didInitialize: Bool = false
}

struct LanguageLevelPickerView: View {
    @Binding var selectedLanguageLevel: String  // Binding to the selected language level

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Language Level")
                .font(.headline)
            
            HStack {
                // Left arrow (conditionally hidden if at the first item)
                Image(systemName: "chevron.left")
                    .opacity(selectedLanguageLevel == SettingsConfiguration.languageLevels.first?.key ? 0.3 : 1.0)
                    .onTapGesture {
                        moveSelectionLeft()
                    }
                
                // Horizontal Picker using TabView
                TabView(selection: $selectedLanguageLevel) {
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
                    .opacity(selectedLanguageLevel == SettingsConfiguration.languageLevels.last?.key ? 0.3 : 1.0)
                    .onTapGesture {
                        moveSelectionRight()
                    }
            }
            
            // Show the description of the selected language level
            if let selectedDescription = SettingsConfiguration.languageLevels.first(where: { $0.key == selectedLanguageLevel })?.description {
                Text(selectedDescription)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
            }
        }
        .padding()
    }
    
    // Helper functions to move the selection
    func moveSelectionLeft() {
        if let currentIndex = SettingsConfiguration.languageLevels.firstIndex(where: { $0.key == selectedLanguageLevel }),
           currentIndex > 0 {
            selectedLanguageLevel = SettingsConfiguration.languageLevels[currentIndex - 1].key
        }
    }

    func moveSelectionRight() {
        if let currentIndex = SettingsConfiguration.languageLevels.firstIndex(where: { $0.key == selectedLanguageLevel }),
           currentIndex < SettingsConfiguration.languageLevels.count - 1 {
            selectedLanguageLevel = SettingsConfiguration.languageLevels[currentIndex + 1].key
        }
    }
}

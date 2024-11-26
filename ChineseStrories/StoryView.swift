//
//  StoryView.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/9/24.
//

import SwiftUI

struct StoryView: View {
    @ObservedObject var viewModel: StoryViewModel
    @State private var showTranslations = false
    @State private var selectedMode: TextMode = .selectedLanguage
    @State private var fontName: String = "Arial"
    @State private var fontSize: CGFloat = 20.0
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea(.all)
            VStack {
                Picker("Select Mode", selection: $selectedMode) {
                    ForEach(TextMode.allCases, id: \.self) { mode in
                        Text(mode.description(for: viewModel)).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                ScrollView {
                    FlowLayout(items: viewModel.phraseBlocks, fontName: fontName, fontSize: fontSize) { block in
                        Text(displayText(for: block))
                            .padding(.trailing, 5)
                            .font(.custom(fontName, size: fontSize))
                            .onTapGesture {
                                viewModel.selectedPhrase = block
                                showTranslations = true
                                viewModel.updateCharacterClickCounts(for: block)
                            }
                            .fixedSize(horizontal: false, vertical: true) // Allow multiline text
                    }
                    .padding()
                }
                if viewModel.isLoading {
                    ProgressView("Generating...")
                } else {
                    Button(action: {
                        Task {
                            await viewModel.continueStory()
                        }
                    }) {
                        Text("Continue Story")
                            .font(.title3)
                            .padding()
                            .background(Color("ButtonColor"))
                            .foregroundColor(Color("ButtonTextColor"))
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            // Use popover to display PhraseDetailView
            .popover(isPresented: $showTranslations) {
                if let phrase = viewModel.selectedPhrase {
                    PhraseDetailView(phrase: phrase, fontName: fontName, viewModel: viewModel)
                }
            }
        }
    }
    
    func displayText(for phraseBlock: PhraseBlock) -> String {
        switch selectedMode {
        case .selectedLanguage:
            return phraseBlock.selectedLanguage
        case .romanization:
            return phraseBlock.romanization
        }
    }
}
                  
enum TextMode: String, CaseIterable {
    case selectedLanguage// = viewModel.settingsConfig.selectedLanguage.name
    case romanization// = viewModel.settingsConfig.selectedLanguage.romanizationSystem
    
    func description(for viewModel: StoryViewModel) -> String {
        switch self {
        case .selectedLanguage:
            return viewModel.settingsConfig.selectedLanguage.name
        case .romanization:
            return viewModel.settingsConfig.selectedLanguage.romanizationSystem
        }
    }
}



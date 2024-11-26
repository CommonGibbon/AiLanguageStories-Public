//
//  PhraseDetailView.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/18/24.
//

import Foundation
import SwiftUI

struct PhraseDetailView: View {
    let phrase: PhraseBlock
    let fontName: String
                                                                                                                   
    @ObservedObject var viewModel: StoryViewModel

    @State private var isGeneratingAudio = false  // Indicate if audio is generating
    @State private var isCopied = false
    @State private var displayMode: DisplayMode = .phrase
    @State private var showingDetails: Bool = false
    
    enum DisplayMode {
        case phrase
        case sentence
    }
                                                                                                                   
    var body: some View {
        VStack(spacing: 20) {
            Picker("Display Mode", selection: $displayMode) {
                Text("Phrase").tag(DisplayMode.phrase)
                Text("Sentence").tag(DisplayMode.sentence)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: displayMode) { _,_ in
                // when user toggles between views, we need to clear the current detailedtranslation
                viewModel.detailedTranslation = nil
                showingDetails = false
            }
                         
            let displayContent = displayMode == .sentence ? viewModel.getSentenceBlock(for: phrase) : phrase
            ScrollView {
                ZStack {
                    HighlightedText(prefix: "\(viewModel.settingsConfig.selectedLanguage.name): ", text: displayContent.selectedLanguage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            UIPasteboard.general.string = displayContent.selectedLanguage
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    isCopied = false
                                }
                            }
                        }
                    if isCopied {
                        Color.gray.opacity(0.5)
                            .overlay(
                                Text("Copied!")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            )
                            .cornerRadius(8)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity
                                )
                            )
                            .zIndex(1)
                    }
                }
                .padding(.bottom, 4)
                            
                HighlightedText(prefix: "\(viewModel.settingsConfig.selectedLanguage.romanizationSystem): ", text: displayContent.romanization)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                
                HighlightedText(prefix: "English: ", text: displayContent.english)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if displayMode == .sentence {
                    (Text(LocalizedStringKey("English (Contextual): "))
                        .bold() +
                    Text(displayContent.englishContextual))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .frame(maxHeight: showingDetails ? 200 : .infinity)
            .background(Color(white: 0.95))
            .padding(.horizontal)

            
            
            Button(action: {
                let audioFileName = displayMode == .phrase ? "phrase-\(phrase.id).mp3" : "sentence-\(phrase.parentSentence).mp3"
                let audioFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(audioFileName)
                if FileManager.default.fileExists(atPath: audioFileURL.path) {
                    viewModel.storyAssistantService.playAudio(from: audioFileURL)
                } else {
                    Task {
                        isGeneratingAudio = true
                        do {
                            try await viewModel.storyAssistantService.createAudio(text: displayContent.selectedLanguage, fileURL: audioFileURL)
                            viewModel.storyAssistantService.playAudio(from: audioFileURL)
                        } catch {
                            print("Error generating or playing audio: \(error.localizedDescription)")
                        }
                        isGeneratingAudio = false
                    }
                }
            }) {
                if isGeneratingAudio {
                    ProgressView("Generating Audio...")
                } else {
                    Text("Play \(viewModel.settingsConfig.selectedLanguage.name) Audio")
                        .padding()
                        .background(Color("ButtonColor"))
                        .foregroundColor(Color("ButtonTextColor"))
                        .cornerRadius(10)
                }
            }
            .padding(.top, 5)

            if viewModel.isLoading {
                ProgressView("Loading detailed translation...")
                    .padding(.top, 5)
            } else if let detailedTranslation = viewModel.detailedTranslation {
                ScrollView {
                    Text(detailedTranslation)
                        .padding(.top, 5)
                        .font(.custom(fontName, size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .background(Color(white: 0.95))
                .padding(.horizontal)
                .padding(.bottom, 5)
                .onAppear {
                    showingDetails = true
                }
            } else {
                Button(action: {
                    Task {
                        switch displayMode {
                        case .phrase:
                            await viewModel.fetchDetailedTranslation(phrase: phrase.selectedLanguage, contextSentence: viewModel.getSentenceBlock(for: phrase).selectedLanguage, displayMode: .phrase)
                        case .sentence:
                            await viewModel.fetchDetailedTranslation(phrase: displayContent.selectedLanguage, contextSentence: displayContent.selectedLanguage, displayMode: .sentence)
                        }
                    }
                }) {
                    Text("Get Detailed Translation")
                        .padding()
                        .background(Color("ButtonColor"))
                        .foregroundColor(Color("ButtonTextColor"))
                        .cornerRadius(10)
                }
                .padding(.top, 5)
            }
        }
        .font(.custom(fontName, size: 22))
        .onDisappear {
            // Reset the detailed translation when the view disappears
            viewModel.detailedTranslation = nil
        }
    }
}

private func HighlightedText(prefix: String, text: String) -> Text {
    let components = text.split(separator: "~", omittingEmptySubsequences: false).map { String($0) }
    return components.reduce(Text(prefix).bold()) { (result, component) in
        let trimmedComponent = component.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmedComponent.hasPrefix("[") && trimmedComponent.hasSuffix("]") ?
            Text(trimmedComponent.dropFirst().dropLast()).bold() :
            Text(trimmedComponent)
        return result + text + Text(" ")
    }
}

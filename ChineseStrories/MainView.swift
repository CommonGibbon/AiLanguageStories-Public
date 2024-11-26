//
//  ContentView.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/9/24.
//

import SwiftUI
                                                                                                                   
struct MainView: View {
    @ObservedObject var viewModel: StoryViewModel
    @State private var showSettings = false
    @State private var settingsConfig = SettingsConfiguration()  // Local settingsConfig
    @State private var navigateToStoryView = false
    @State private var showCharacterClickList = false
    @State private var showDebugInfo = false
    
    let maxButtonHeight: CGFloat = 45
    let maxButtonWidth:CGFloat = 220
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea(.all)
                VStack {
                    if viewModel.initializingConnection {
                        ProgressView("Connecting to network...")
                            .padding()
                    } else if viewModel.isLoading {
                        ProgressView("Generating Story...")
                    } else {
                        VStack(spacing: 20) {   // Update to VStack with spacing
                            Button(action: {
                                Task {
                                    await viewModel.generateStory()
                                }
                            }) {
                                Label("Generate Story", systemImage: "book")
                                    .frame(maxWidth: maxButtonWidth, maxHeight: maxButtonHeight)
                                    .font(.title2)
                                    .padding()
                                    .background(Color("ButtonColor"))
                                    .foregroundColor(Color("ButtonTextColor"))
                                    .cornerRadius(10)
                            }
                            if viewModel.storyGenerated {
                                Button(action: {
                                    Task {
                                        await self.navigateToStoryView = viewModel.resumeStory()
                                    }
                                }) {
                                    Label("Resume Story", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: maxButtonWidth, maxHeight: maxButtonHeight)
                                        .font(.title2)
                                        .padding()
                                        .background(Color("ButtonColor"))
                                        .foregroundColor(Color("ButtonTextColor"))
                                        .cornerRadius(10)
                                }
                            }
                            
                            Button(action: {
                                showSettings.toggle()
                            }) {
                                Label("Settings", systemImage: "gear")
                                    .frame(maxWidth: maxButtonWidth, maxHeight: maxButtonHeight)
                                    .font(.title2)
                                    .padding()
                                    .background(Color("ButtonColor"))
                                    .foregroundColor(Color("ButtonTextColor"))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showDebugInfo.toggle()
                            }) {
                                Label("Debug", systemImage: "wrench.fill")
                                    .frame(maxWidth: maxButtonWidth, maxHeight: maxButtonHeight)
                                    .padding()
                                    .font(.title2)
                                    .background(Color("ButtonColor"))
                                    .foregroundColor(Color("ButtonTextColor"))
                                    .cornerRadius(10)
                                    
                            }
                            .sheet(isPresented: $showDebugInfo) {
                                DebugInfoView(viewModel: viewModel) // Pass data to DebugInfoView
                            }
                        }
                        .padding()
                    }
                }
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    SettingsView(viewModel: viewModel, settingsConfig: $settingsConfig, isPresented: $showSettings)
                        .padding()
                        .background(Color("BackgroundColor"))
                }
                // Use a NavigationLink to transition to StoryView based on state
                .navigationDestination(isPresented: $navigateToStoryView) {
                    StoryView(viewModel: viewModel)
                }
            }
            // Observe changes to `storyGenerated` and set `navigateToStoryView`
            .onChange(of: viewModel.storyGenerated) { oldValue, newValue in
                if newValue {
                    self.navigateToStoryView = true
                }
            }
        }
    }
}
                                                                                                                   
#Preview {
    MainView(viewModel: StoryViewModel())
}

//
//  DebugInfoView.swift
//  ChineseStories
//
//  Created by Will Shannon on 10/12/24.
//
import SwiftUI

struct DebugInfoView: View {
    @ObservedObject var viewModel: StoryViewModel
    @State private var showCharacterClickRates: Bool = false

    var sortedCharacters: [(key: String, value: Int)] {
        viewModel.characterClickCounts
            .sorted { $0.value.clicks > $1.value.clicks }
            .map { (key: $0.key, value: $0.value.clicks) }
    }

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea(.all)
            VStack {
                Text(viewModel.bugReport)
                    .padding()
                
                Text(viewModel.storyArc)
                    .padding()
                
                Button(action: {
                    showCharacterClickRates.toggle()
                }) {
                    Text(showCharacterClickRates ? "Hide Character Clicks" : "Show Character Clicks")
                        .padding()
                        .background(Color("ButtonColor"))
                        .foregroundColor(Color("ButtonTextColor"))
                        .cornerRadius(8)
                }
                
                if showCharacterClickRates {
                    List {
                        ForEach(sortedCharacters, id: \.key) { entry in
                            HStack {
                                Text("\(entry.key)")
                                    .font(.title)
                                Spacer()
                                Text("\(entry.value) clicks")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                    }
                    
                    Button(action: {
                        viewModel.resetCharacterClickCounts()
                    }) {
                        Text("Reset Click Counts")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Debug Information")
        }
    }
}

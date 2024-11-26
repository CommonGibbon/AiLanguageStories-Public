//
//  CharacterClickListView.swift
//  ChineseStories
//
//  Created by Will Shannon on 10/2/24.
//

import Foundation
import SwiftUI
                                                                                                                   
struct CharacterClickListView: View {
    let characterClickCounts: [String: Int]
                                                                                                                   
    var sortedCharacters: [(key: String, value: Int)] {
        characterClickCounts.sorted { $0.value > $1.value }
    }
                                                                                                                   
    var body: some View {
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
        .navigationTitle("Character Clicks")
    }
}

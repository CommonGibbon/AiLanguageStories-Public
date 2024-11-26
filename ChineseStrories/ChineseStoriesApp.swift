//
//  ChineseStoriesApp.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/9/24.
//

import SwiftUI

@main
struct ChineseStoryApp: App {
    @StateObject private var viewModel = StoryViewModel()

    var body: some Scene {
        WindowGroup {
            LaunchScreenView(viewModel: viewModel)
        }
    }
}  

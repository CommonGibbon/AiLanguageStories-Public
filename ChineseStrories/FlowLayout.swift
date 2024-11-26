//
//  FlowLayout.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/11/24.
//

import Foundation
import SwiftUI
import UIKit

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    let fontName: String
    let fontSize: CGFloat
    let content: (Data.Element) -> Content
                                                                                                                   
    @State private var totalHeight = CGFloat.zero
                                                                                                                   
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
                                                                                                                   
    private func generateContent(in geometry: GeometryProxy) -> some View {
        /*
         This function tells use where, in terms of x and y coordinates, to place a text view on the screen. It calculate sthe correct position by
         determining how much space we have on the current line, how many lines our twxt will take up.
         There are two main limitations to this function:
         1. If a text view is too long to fit on the current line, we cannot deploy it to the current line and have its excess characters wrap once it hits the right wall. This is because a text view has a fixed width. For example suppose we have a text line that is 20 points long and our current line has 5 extra points of spcae. If we wanted the text view to wrap, we'd need to set its width to 5, but this would cause it to take up four lines, each one five points long.
         2. If a view takes up more than one line, we cannot place text on the same line as the last line of text. This is because we don't actually know how far the text extends on that final line. Again, we only know the width of the text view, and that's determined by the first line.
         
         The cost to this is occassional odd spacing in our storyview, which I do think slightly breaks the immersion. I'm thinking that a potential
         alternative to this could be using a single text view for all our text content, then overlaying invisble buttons based off phrase positions.
         This could be done by calculating the size of the text and placing separate buttons with the same links when we wrap new lines.
         */
        var xPosition = CGFloat.zero
        var yPosition = CGFloat.zero
        var newLines = 0
        let lineHeight = calculateTextHeight(text: "t", fontSize: fontSize, fontName: fontName, maxWidth: 200.0) // the height of a SINGLE line of text
        
        return ZStack(alignment: .topLeading) {
            ForEach(self.items) { item in
                self.content(item)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(xPosition - d.width) > geometry.size.width) { // if the current item is too big to fit on this line...
                            xPosition = 0 // ...set the xPosition to 0 so that the item will be aligned on the left as a new line
                            // we're creating a new line, so this will affect the yposition of the current line:
                            yPosition -= lineHeight
                            newLines = Int(floor(d.height / lineHeight)) - 1 // -1 because we just accounted for one of them
                        } else {
                            newLines = 0
                        }
                                                                                                                   
                        let result = xPosition // capture the current x position for the current line before augmenting for the next one.
                        if item.id == self.items.last?.id { // if this is the last item...
                            xPosition = 0 // ...reset xPosition for the next time we use FlowLayout
                        } else {
                            xPosition -= d.width // offset the x position for the next item
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = yPosition // capture the current y position for the current line before augmenting for the next one.
                        if item.id == self.items.last?.id {  // if this is the last item...
                            yPosition = 0 // ...reset yPosition for the next time we use FlowLayout
                        }
                        while (newLines > 0) {
                            // If we've created a new line of text, we always need to print the next line on a new line after that one.
                            // for details as to why, see the description of this function
                            yPosition -= lineHeight
                            newLines -= 1
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
                                                                                                                   
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geo.frame(in: .local).size.height
            }
            return .clear
        }
    }
    // Function to calculate the height of the text
    func calculateTextHeight(text: String, fontSize: CGFloat, fontName: String, maxWidth: CGFloat) -> CGFloat {
        guard let uiFont = UIFont(name: fontName, size: fontSize) else {
            return 0 // Return 0 if the font is not found
        }

        // Define text attributes with the loaded font
        let textAttributes = [NSAttributedString.Key.font: uiFont]

        // Calculate the bounding rectangle for the text
        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: textAttributes,
            context: nil
        )

        return boundingRect.height
    }
}

//
//  DataModel.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/9/24.
//

import Foundation
                                                                                                                   
struct StoryResponse: Codable {
    let selectedLanguage: String
    let romanization: String
    let english: String
}
     
class PhraseBlock: Identifiable, Equatable, Encodable, Decodable {
    var id: String { "\(index)" }  // Computed property for unique ID
    let index: Int
    let selectedLanguage: String
    var romanization: String
    var english: String
    var parentSentence: Int
    var englishContextual: String
    
    // Initializer for the full set of properties
    init(index: Int, selectedLanguage: String, romanization: String, english: String, englishContextual: String, parentSentence: Int = 0) {
        self.index = index
        self.selectedLanguage = selectedLanguage
        self.romanization = romanization
        self.english = english
        self.englishContextual = englishContextual
        self.parentSentence = parentSentence
    }
    
    // Convenience initializer without romanization and english
    convenience init(index: Int, selectedLanguage: String, parentSentence: Int) {
        self.init(index: index, selectedLanguage: selectedLanguage, romanization: "", english: "", englishContextual: "", parentSentence: parentSentence)
    }
    
    // Implement Equatable for class comparison
    static func == (lhs: PhraseBlock, rhs: PhraseBlock) -> Bool {
        return lhs.id == rhs.id &&
               lhs.index == rhs.index &&
               lhs.selectedLanguage == rhs.selectedLanguage &&
               lhs.romanization == rhs.romanization &&
               lhs.english == rhs.english &&
               lhs.parentSentence == rhs.parentSentence
    }
}

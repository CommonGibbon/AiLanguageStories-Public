//
//  ViewModel.swift
//  ChineseStories
//
//  Created by Will Shannon on 9/9/24.
//

import Foundation
import Combine
//import OpenAI

class StoryViewModel: ObservableObject {
    @Published var phraseBlocks: [PhraseBlock] = []
    @Published var isLoading = false
    @Published var storyGenerated = false
    @Published var selectedPhrase: PhraseBlock? = nil
    @Published var detailedTranslation: String? = nil
    @Published var initializingConnection = true
    @Published var bugReport: String = ""
    @Published var storyArc: String = ""
    @Published var settingsConfig = SettingsConfiguration()
    @Published var settingsChanged = false

    private var cancellables = Set<AnyCancellable>()
    private var retryCount: Int = 0
    private var writerID: String = ""
    private var architectID: String = ""
    private var translatedSentences: [Int: String] = [:]
    
    // MARK: Story Generation
    // temporary solution to api key storage until I add user accounts and server-side queries
    let storyAssistantService = StoryAssistantService(bearerTokenOpenAI: Bundle.main.object(forInfoDictionaryKey: "OPENAIAPIKEY") as! String, keybearerTokenElevenLabs: Bundle.main.object(forInfoDictionaryKey: "ELEVENLABSAPIKEY") as! String)

    func initializeAssistantAndThread(overwriteThread: Bool = false) async {
        let architectPrompt: String = """
            You are an expert in writing, publishing, and editing, with a special talent for crafting unique and engaging short story arcs. Your task is to write a concise (maximum three sentences) concept for a short story that can inspire another writer. Then, briefly outline what happens in each of five parts (max two setences per part), with the final part concluding the story.
            Each time, before you begin writing, you always think of a list of random nouns, verbs, and adjectives as inspiration for your story. This helps you keep your storys fresh and unique. There is no need to write these random words down.
        """
        
        let writerPrompt: String = """
            You are an expert story writer and an expert in writing in the \(settingsConfig.selectedLanguage.name) language.
            You will generate short stories in \(settingsConfig.selectedLanguage.name) exclusively using \(settingsConfig.selectedLanguage.scriptName) and using limited vocabulary that will be defined later. The stories must be written in the third-person limited narrative style and they must follow the plan provided to you by your story planning partner. 

            1. Phrase Format:
                - Purpose: segment the story into meaningful phrases.
                - Definition: A meaningful phrase is a group of words/characters that naturally belong together in both \(settingsConfig.selectedLanguage.name) and English. When segmenting the text into meaningful phrases, ensure that you keep grammatically dependent elements together. Do not separate particles, markers, or modifiers from the words they directly modify or are closely associated with. Each phrase should be a complete grammatical unit that can stand on its own while retaining its intended meaning within the context of the sentence. Try to keep phrases  to less than 6 characters/words in length. In the past, you've made one of the following mistakes: of making each phase into an entire sentence or making the entire story into one run-on sentence by never using any punctuation. Think of a phrase as a sentence fragments, and think about how you can construct sentences by piecing together multiple phrases.

            2. You are an expert grammarian and you must take care to add punctuation when necessary at the end of phrases. For example commas should be added after introductory phrases, between items in a list, and to separate independent clauses joined by conjunctions. Use periods to end complete sentences, question marks for direct questions, and exclamation marks for emphasis. Do not add punctuation unless you are at least 80% sure it is correct to do so, in the past you've added a comma to the end of every phrase, but I want you to think carefully about whether a comma is grammatically correct before adding them.
            """
        
        let writerResponseFormat: [String: Any] = [
            "type": "json_schema",
            "json_schema": [
                "name": "phraseFormat",
                "schema": [
                    "type": "object",
                    "properties": [
                        "phrases": [
                            "type": "array",
                            "items": [
                                "type": "string"
                            ]
                        ]
                    ],
                    "required": ["phrases"],
                    "additionalProperties": false
                ],
                "strict": true
            ]
        ]
        
        do {
            self.architectID = try await storyAssistantService.createAssistant(instructions: architectPrompt)
            
            self.writerID = try await storyAssistantService.createAssistant(instructions: writerPrompt, responseFormat: writerResponseFormat)
            
            if !overwriteThread && storyAssistantService.loadThreadID(){
                DispatchQueue.main.async {
                    self.storyGenerated = true // if a thread was successfully loaded, we already have a generated story
                }
            }
            DispatchQueue.main.async {
                self.initializingConnection = false  // Set to false once initialization is completed
            }
        } catch {
            DispatchQueue.main.async {
                self.bugReport = "Error initializing assistant or thread: \(error.localizedDescription)"
                self.initializingConnection = false  // Set to false even if there's an error
            }
        }
    }
    
    // Function to call ChatGPT API
    func generateStory() async {
        if settingsChanged { // if settings have changed, we need to re-initialize the assistant to make sure it uses the latest prompt.
            DispatchQueue.main.async {
                self.settingsChanged = false
            }
            await initializeAssistantAndThread(overwriteThread: true)
        }
        DispatchQueue.main.async {
            self.bugReport = ""
            self.isLoading = true
            self.storyGenerated = false // reset in case there was a previous story; we're replacing it.
            self.updateClickedCharacters(decrement: false) // process any pending click count updates before generaing the story
        }
     
        storyAssistantService.clearGeneratedAudios()  // Clear cached audio files
     
        let genreString = settingsConfig.selectedGenres.joined(separator: ", ")
        var architectPrompt = "The reader is learning a new language and can read at CEFR level of \(settingsConfig.languageLevel), so keep your planned story accordingly complex. Write a story arc for a short story"
        
        // Add genre if it's not empty
        architectPrompt += genreString.isEmpty ? "" : " in the genres of \(genreString)"
        // Add tone if it's not empty
        if !settingsConfig.selectedTone.isEmpty {
            architectPrompt += " with a \(settingsConfig.selectedTone) tone"
        }
        // Add conflict type if it's not empty
        if !settingsConfig.selectedConflict.isEmpty {
            architectPrompt += " involving \(settingsConfig.selectedConflict) conflict"
        }
        // Add time period if it's not empty
        if !settingsConfig.selectedTimePeriod.isEmpty {
            architectPrompt += " based in the \(settingsConfig.selectedTimePeriod) time period"
        }
        // Add custom request if it's not empty
        if !settingsConfig.customRequest.isEmpty {
            architectPrompt += ". Custom requests: \(settingsConfig.customRequest)"
        }
        
        let writerPrompt = "Write the first chapter of the short story using vocabulary appropriate for someone learnning at CEFR level of \(settingsConfig.languageLevel)"
                                                                                               
        do {
            try await storyAssistantService.createThread() // create a thread ID. This will override an existing ID
            storyArc = try await storyAssistantService.postMessage(userPrompt: architectPrompt, assistantID: self.architectID, getResponse: true)
            let resultJsonString = try await storyAssistantService.postMessage(userPrompt: writerPrompt, assistantID: self.writerID, getResponse: true)

            processJsonString(resultJsonString) // Get the chinese phrases
            await translatePhraseBlocks() // Generate the english and pinyin translations
            savePhraseBlocksToLocalStorage() // save the generated phraseblocks
            
        } catch {
            DispatchQueue.main.async {
                self.bugReport = "Unexpected error: \(error.localizedDescription)"
                self.isLoading = false
                self.storyGenerated = false
            }
        }
    }
    
    func continueStory() async {
       DispatchQueue.main.async {
           self.isLoading = true
           self.updateClickedCharacters(decrement: true) // before we generate the next story, decrement non-click counts from the current text
       }
        
       storyAssistantService.clearGeneratedAudios()  // Clear cached audio files
                                                                                                               
       let userPrompt = """
        Continue writing the next segment, ensuring consistency with the planner's story arc and previous chapters. Maintain tone, style, and plot, while addressing character development, pacing, and unresolved elements. If any planned details were missed, decide whether to include or drop them.        
        """
        
        //userPrompt += addProblemCharacters()
                                                                                                               
       do {
           let resultJsonString = try await storyAssistantService.postMessage(userPrompt: userPrompt, assistantID: self.writerID, getResponse: true)
                                                                                                        
           processJsonString(resultJsonString) // Get the chinese phrases
           await translatePhraseBlocks() // Generate the english and pinyin translations
           savePhraseBlocksToLocalStorage() // save the generated phraseblocks
           
       } catch {
           DispatchQueue.main.async {
               self.bugReport = "Unexpected error: \(error.localizedDescription)"
               self.isLoading = false
               self.storyGenerated = false
           }
       }
   }
    
    // MARK: Save & Load PhraseBlocks
    // Key for saving phrase blocks
    private let phraseBlocksKey = "phraseBlocksKey"
    
    // Method to save phrase blocks
    private func savePhraseBlocksToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(phraseBlocks) {
            UserDefaults.standard.set(encoded, forKey: phraseBlocksKey)
        }
    }
    
    // Method to load phrase blocks
    private func loadPhraseBlocksFromLocalStorage() -> [PhraseBlock]? {
        if let savedData = UserDefaults.standard.data(forKey: phraseBlocksKey),
           let decodedBlocks = try? JSONDecoder().decode([PhraseBlock].self, from: savedData) {
            return decodedBlocks
        }
        return nil
    }
    
    func resumeStory() async -> Bool {
        if !phraseBlocks.isEmpty {
            return true
        } else if let loadedPhraseBlocks = loadPhraseBlocksFromLocalStorage() {
            DispatchQueue.main.async {
                self.phraseBlocks = loadedPhraseBlocks
            }
            return true
        } else {
            DispatchQueue.main.async {
                self.isLoading = true
            }
            
            do {
                let resultJsonString = try await storyAssistantService.resumeStory()
                processJsonString(resultJsonString) // Replace this with saving, if necessary
                savePhraseBlocksToLocalStorage()
            } catch {
                DispatchQueue.main.async {
                    self.bugReport = "Unexpected error: \(error.localizedDescription)"
                    self.isLoading = false
                    self.storyGenerated = false
                }
            }
        }
        return false
    }
        
    // MARK: Translation Management
    private func translatePhraseBlocks() async {
        // Determine the number of sentences by checking the parentSentence of the last phraseBlock
        guard let lastPhraseBlock = self.phraseBlocks.last else {
            // If there are no phrase blocks, return early
            DispatchQueue.main.async {
                self.isLoading = false
                self.storyGenerated = true
            }
            return
        }
        
        let totalSentences = lastPhraseBlock.parentSentence
        
        // Use TaskGroup to parallelize the translation of each sentence
        await withTaskGroup(of: Void.self) { group in
            for sentenceIndex in 0...totalSentences {
                group.addTask {
                    // Get all phrase blocks that belong to this sentence
                    let phraseBlocksForSentence = self.phraseBlocks.filter { $0.parentSentence == sentenceIndex }
                    
                    // Call translateText asynchronously for the entire sentence
                    do {
                        let (romanizedPhrases, englishPhrases, englishSentence) = try await self.storyAssistantService.translateSentencePhrases(phrases: phraseBlocksForSentence, language: self.settingsConfig.selectedLanguage)
                        
                        // Ensure the number of translated phrases matches the number of phrase blocks
                        if englishPhrases.count == phraseBlocksForSentence.count && romanizedPhrases.count == phraseBlocksForSentence.count {
                            for (index, phraseBlock) in phraseBlocksForSentence.enumerated() {
                                // Update the english property on the main thread
                                DispatchQueue.main.async {
                                    phraseBlock.romanization = romanizedPhrases[index]
                                    phraseBlock.english = englishPhrases[index]
                                }
                            }
                            self.translatedSentences[sentenceIndex] = englishSentence
                        } else {
                            DispatchQueue.main.async {
                                self.bugReport = "Block mismatch count"
                                self.isLoading = false
                            }
                        }
                    } catch {
                        // Handle translation failure for the entire sentence
                        DispatchQueue.main.async {
                            self.bugReport = "Translation failed for sentence \(sentenceIndex)"
                            self.isLoading = false
                        }
                    }
                }
            }
        }
        
        // Once all translations are done, update the UI to reflect that the story has been generated
        DispatchQueue.main.async {
            self.isLoading = false
            self.storyGenerated = true
        }
    }
    
    
    private func cacheKey(for phrase: String, contextSentence: String, displayMode: PhraseDetailView.DisplayMode) -> String {
        let prefix = displayMode == .phrase ? "detail-phrase" : "detail-sentence"
        return "\(prefix)-\(phrase.hashValue)-\(contextSentence.hashValue).txt"
    }
                                                     
    func fetchDetailedTranslation(phrase: String, contextSentence: String, displayMode: PhraseDetailView.DisplayMode) async {
        let cacheKey = cacheKey(for: phrase, contextSentence: contextSentence, displayMode: displayMode)
                                                     
        if let cachedTranslation = storyAssistantService.loadTranslationFromCache(fileName: cacheKey) {
            DispatchQueue.main.async {
                self.detailedTranslation = cachedTranslation
            }
            return
        }
                
        DispatchQueue.main.async {
            self.isLoading = true
            self.detailedTranslation = nil  // Reset previous translation
        }
                 
        do {
            let translation = try await storyAssistantService.getDetailedTranslation(phrase: phrase, contextSentence: contextSentence, language: settingsConfig.selectedLanguage, languageLevel: settingsConfig.languageLevel)
            DispatchQueue.main.async {
                self.detailedTranslation = translation
            }
            try storyAssistantService.saveTranslationToCache(content: translation, fileName: cacheKey)
        } catch {
            DispatchQueue.main.async {
                self.bugReport = "Error fetching detailed translation: \(error.localizedDescription)"
                self.detailedTranslation = "Error fetching detailed translation."
            }
        }
             
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    // MARK: Story Parse Code
    // since we're using structured responses, which is much cleaner than the previous bracketed method, our parsing code is simpler

    func processJsonString(_ resultJsonString: String) {
        if let resultJson = parseJSON(resultJsonString) {
            // unpack the json objects into phrases, tracking parent sentences along the way.
            let newBlocks = resultJson.enumerated().reduce(into: (blocks: [PhraseBlock](), currentSentenceIndex: 0, isNewSentence: true)) { result, enumeratedBlock in
                let (index, block) = enumeratedBlock
                
                // Function to lowercase first character unless it's a new sentence or a special case
                func processText(_ text: String, isNewSentence: Bool) -> String {
                    guard !text.isEmpty else { return text }
                    if isNewSentence {
                        return text
                    } else {
                        // Find the first letter character
                        if let firstLetterRange = text.rangeOfCharacter(from: .letters) {
                            let beforeFirstLetter = text[..<firstLetterRange.lowerBound]
                            let firstLetter = text[firstLetterRange].lowercased()
                            let afterFirstLetter = text[firstLetterRange.upperBound...]
                            return beforeFirstLetter + firstLetter + afterFirstLetter
                        } else {
                            // If no letter is found, return the original text
                            return text
                        }
                    }
                }
                
                // Process the output text to remove incorrect capitalization
                let processedSelectedLanguage = processText(block, isNewSentence: result.isNewSentence)
                
                result.blocks.append(PhraseBlock(
                    index: index,
                    selectedLanguage: processedSelectedLanguage,
                    parentSentence: Int(result.currentSentenceIndex)
                ))
                
                
                // Check if the selected language text ends with a punctuation denoting end of a sentence
                let endsWithSentencePunctuation = block.last.map({ [".", "!", "?", "。", "？", "！"].contains($0) }) ?? false
                
                if endsWithSentencePunctuation {
                    result.currentSentenceIndex += 1
                    result.isNewSentence = true
                } else {
                    result.isNewSentence = false
                }
            }.blocks
            
            DispatchQueue.main.async {
                self.phraseBlocks = newBlocks
            }
            
            storyAssistantService.saveThreadID() // keep track of the thread so we can continue the story later.
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.bugReport = "Unexpected error parsing JSON: \(resultJsonString)"
            }
        }
    }
    
    func parseJSON(_ jsonString: String) -> [String]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            // Decode the JSON into a dictionary with an array of strings under the "phrases" key
            let decodedData = try decoder.decode([String: [String]].self, from: jsonData)
            
            // Access the "phrases" array from the dictionary
            if let phraseBlocks = decodedData["phrases"] {
                return phraseBlocks
            } else {
                print("Key 'phraseBlocks' not found in JSON")
                return nil
            }
        } catch {
            print("Decoding error: \(error)")
            return nil
        }
    }
    // MARK: Parent Sentence Management
    
    func getSentenceBlock(for phrase: PhraseBlock) -> PhraseBlock {
        let sentencePhrases = phraseBlocks.filter { $0.parentSentence == phrase.parentSentence }
        let boldIndex = sentencePhrases.firstIndex { $0.index == phrase.index }
                                                                                                                                                    
        let selectedLanguage = sentencePhrases.enumerated().map {
            let text = $0.element.selectedLanguage
            return $0.offset == boldIndex ? "[\(text)]" : text
        }.joined(separator: "~")
                                        
        let romanization = sentencePhrases.enumerated().map {
            let text = $0.element.romanization
            return $0.offset == boldIndex ? "[\(text)]" : text
        }.joined(separator: "~")
                                                                                                                                                    
        let english =  sentencePhrases.enumerated().map {
            let text = $0.element.english
            return $0.offset == boldIndex ? "[\(text)]" : text
        }.joined(separator: "~")
        
        let englishContextual = self.translatedSentences[phrase.parentSentence] ?? "Failed to generate contextual translation"
        
        return PhraseBlock(index: phrase.parentSentence, selectedLanguage: selectedLanguage, romanization: romanization, english: english, englishContextual: englishContextual)
    }
    
    // MARK: Save settings
    let settingsKey = "settingsConfigKey"
         
    func saveSettingsConfig() {
        if let encoded = try? JSONEncoder().encode(settingsConfig) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
                                                                                                                   
    func loadSettingsConfig() {
        if let savedConfigData = UserDefaults.standard.data(forKey: settingsKey),
           let decodedConfig = try? JSONDecoder().decode(SettingsConfiguration.self, from: savedConfigData) {
            settingsConfig = decodedConfig
        }
    }
    
    // MARK: Click Count Management
    struct ClickData: Codable {
        var clicks: Int
        var wasClicked: Bool
    }
    
    @Published var characterClickCounts: [String: ClickData] = [:] // Dictionary to track character clicks
    //@Published var localClickCounts: [String: Int] = [:]
                                                                                                                       
    let characterClicksKey = "characterClicksKey" // Key for saving character clicks
                                                                                                                   
    // Method to update character click counts
    func updateCharacterClickCounts(for phrase: PhraseBlock) {
        for character in phrase.selectedLanguage {
            guard let unicodeScalar = character.unicodeScalars.first,
                  !CharacterSet.punctuationCharacters.contains(unicodeScalar),
                  !CharacterSet.whitespacesAndNewlines.contains(unicodeScalar),
                  !CharacterSet.symbols.contains(unicodeScalar) else {
                continue
            }
                                                                                                                    
            let characterStr = String(character)
            // Update local clicks for the current segment
            if let _ = characterClickCounts[characterStr] {
                characterClickCounts[characterStr]?.wasClicked = true
            } else {
                characterClickCounts[characterStr] = ClickData(clicks: 0,wasClicked: true)
            }
        }
        saveCharacterClickCounts()
    }
    
    func resetCharacterClickCounts() {
        characterClickCounts.removeAll()
        saveCharacterClickCounts()
    }
    
    func updateClickedCharacters(decrement: Bool) {
        for character in characterClickCounts.keys {
            if characterClickCounts[character]!.wasClicked {
                characterClickCounts[character] = ClickData(clicks: characterClickCounts[character]!.clicks + 1, wasClicked: false)
            } else {
                if decrement {
                    let newCount = characterClickCounts[character]!.clicks / 2
                    if newCount == 0 {
                        // Remove the character from the dictionary if the count reaches zero
                        characterClickCounts.removeValue(forKey: character)
                    } else {
                        // Otherwise, update the count
                        characterClickCounts[character] = ClickData(clicks: newCount, wasClicked: true)
                    }
                }
            }
        }
        // Clear local clicks for the new story segment
        saveCharacterClickCounts()
    }
                                                                                                                   
    // Function to save character click counts to UserDefaults
    func saveCharacterClickCounts() {
        if let encoded = try? JSONEncoder().encode(characterClickCounts) {
            UserDefaults.standard.set(encoded, forKey: characterClicksKey)
        }
    }
                                                                                                                   
    // Function to load character click counts from UserDefaults
    func loadCharacterClickCounts() {
        if let savedData = UserDefaults.standard.data(forKey: characterClicksKey),
           let decodedCounts = try? JSONDecoder().decode([String: ClickData].self, from: savedData) {
            characterClickCounts = decodedCounts
        }
    }
    
    // Get Frequent Clicked Characters
    private func getTopClickedCharacters() -> [String] {
        let qualifiedCharacters = characterClickCounts.filter { $0.value.clicks >= 4 }
        let sortedCharacters = qualifiedCharacters.sorted { $0.value.clicks > $1.value.clicks }
        return Array(sortedCharacters.prefix(3).map { $0.key }) // Get top 3 characters
    }
}

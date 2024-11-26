import Foundation
import AVFoundation

class StoryAssistantService {
    private let baseURL = "https://api.openai.com/v1"
    private let bearerTokenOpenAI: String
    private let bearerTokenElevenLabs: String
    private var threadID: String?

    init(bearerTokenOpenAI: String, bearerTokenElevenLabs: String) {
        self.bearerTokenOpenAI = bearerTokenOpenAI
        self.bearerTokenElevenLabs = bearerTokenElevenLabs
    }
                                                                                                                   
    // MARK: - Save and Load Thread ID
    func saveThreadID() {
        UserDefaults.standard.set(threadID, forKey: "threadIDKey")
    }
                                                                                                                   
    func loadThreadID() -> Bool {
        // Check if the file exists at the specified path
        if let loadedThreadID = UserDefaults.standard.string(forKey: "threadIDKey") {
            self.threadID = loadedThreadID
            return true
        } else {
            print("No thread ID found")
            return false
        }
    }
    
    func saveTranslationToCache(content: String, fileName: String) throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
             
    func loadTranslationFromCache(fileName: String) -> String? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }    

    // MARK: - Create Assistant
    func createAssistant(instructions: String, responseFormat: [String: Any]? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/assistants")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    
        var body: [String: Any] = [
            "instructions": instructions,
            "model": "gpt-4o-2024-08-06"
        ]
        // If a responseFormat is provided, include it in the body
        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
                                                                                                                   
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String {
            return id
        } else {
            throw NSError(domain: "AssistantCreationError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Create Thread
    func createThread() async throws {
        let url = URL(string: "\(baseURL)/threads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String {
            self.threadID = id
        } else {
            throw NSError(domain: "ThreadCreationError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Create Message
    func createMessage(role: String, content: String) async throws -> String {
        guard let threadID = threadID else { throw NSError(domain: "ThreadIDMissing", code: 1, userInfo: nil) }

        let url = URL(string: "\(baseURL)/threads/\(threadID)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let body: [String: Any] = [
            "role": role,
            "content": content
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messageID = json["id"] as? String {
            return messageID
        } else {
            throw NSError(domain: "MessageCreationError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Create and Run
    func createRun(assistantID: String) async throws -> String {
        guard let threadID = threadID else {
            throw NSError(domain: "RunCreationError", code: 1, userInfo: nil)
        }

        let url = URL(string: "\(baseURL)/threads/\(threadID)/runs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let body: [String: Any] = [
            "assistant_id": assistantID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let runID = json["id"] as? String {
            return runID
        } else {
            throw NSError(domain: "RunCreationError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Poll Run Status
    func pollRunStatus(runID: String) async throws -> Bool {
        guard let threadID = threadID else { throw NSError(domain: "ThreadIDMissing", code: 1, userInfo: nil) }

        let url = URL(string: "\(baseURL)/threads/\(threadID)/runs/\(runID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            return status == "completed"
        } else {
            throw NSError(domain: "RunStatusError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Get Latest Message
    func getLatestMessageID() async throws -> String {
        guard let threadID = threadID else { throw NSError(domain: "ThreadIDMissing", code: 1, userInfo: nil) }

        let url = URL(string: "\(baseURL)/threads/\(threadID)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let lastID = json["first_id"] as? String { // note that "first" means the latest message. last_id means the oldest. confusing naming convention from openai
            return lastID
        } else {
            throw NSError(domain: "LatestMessageIDError", code: 1, userInfo: nil)
        }
    }

    // MARK: - Message Posting

    func postMessage(userPrompt: String, assistantID: String, getResponse: Bool) async throws -> String {
        // Step 1: Create a user message
        _ = try await createMessage(role: "user", content: userPrompt)

        // Step 2: Create and run the assistant
        let runID = try await createRun(assistantID: assistantID)

        // Step 3: Poll until the run is complete
        var isCompleted = false
        while !isCompleted {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 2 seconds before polling again
            isCompleted = try await pollRunStatus(runID: runID)
        }
        
        if getResponse {
            // Step 4: Get the latest message ID using the new function
            let latestMessageID = try await getLatestMessageID()

            // Step 5: Retrieve the latest message content
            return try await retrieveMessage(messageID: latestMessageID)
        } else {
            return ""
        }
        

    }
    
    func resumeStory() async throws -> String {
        // Retrieve the last message ID
        let latestMessageID = try await getLatestMessageID()

        // Retrieve the latest message content
        return try await retrieveMessage(messageID: latestMessageID)
    }

    // MARK: - Retrieve Message
    func retrieveMessage(messageID: String) async throws -> String {
        guard let threadID = threadID else { throw NSError(domain: "ThreadIDMissing", code: 1, userInfo: nil) }

        let url = URL(string: "\(baseURL)/threads/\(threadID)/messages/\(messageID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let contentArray = json["content"] as? [[String: Any]],
           let textDict = contentArray.first?["text"] as? [String: Any],
           let value = textDict["value"] as? String {
            return value
        } else {
            throw NSError(domain: "MessageRetrievalError", code: 1, userInfo: nil)
        }
    }
    
    //MARK: Translation Services
    func getDetailedTranslation(phrase: String, contextSentence: String, language: Language, languageLevel: String) async throws -> String {
        // 1. Set up the URL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }

        // 2. Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")
        var assistantPrompt: String
        var userPrompt: String
        if phrase == contextSentence {
            assistantPrompt = """
                You will be given a sentence in \(language.name) for which will provide a detailed translation. You will respond with the following:
                - for each character, you will print "<character> (<\(language.romanizationSystem)>): <a concise in-context translation for the character>."
                - Provide analysis or two to help an English reader better understand this sentence.  Limit it to 350 characters. Ensure the analysis is appropriate for someone reading \(language.name) at a CEFR level of \(languageLevel).
                 Your output must be machine readable so you must not provide any extra text outside the per-character analysis and extra analysis sentence(s).
                """
            userPrompt = phrase
        } else {
            assistantPrompt = """
                You will be given a phrase in \(language.name) as well as parent sentence for context. You will provide a detailed translation of the contents of the phrase. You will respond with the following:
                - for each character in the phrase, you will print "<character> (<\(language.romanizationSystem)>): <a concise in-context translation for the character>." Only include characters from the phrase, do not include characters from the parent sentence.
                - Provide an extra sentence or two to help an English reader better understand this phrase in the context of the provided sentence. This could be idiomatic meaning, grammar structure, or explanation for choice of phrases. Your reader will have a limited vocabulary and may only know one way to say certain things. Using different phrases with similar meanings might confuse them, so it's important to explain why those phrases were chosen, if applicable.
                 Your output must be machine readable so you must not provide any extra text outside the per-character analysis and extra analysis sentence(s).
                """
            userPrompt = "Phrase: \(phrase), context sentence: \(contextSentence)"
        }

        // 3. Create the JSON body
        let jsonBody: [String: Any] = [
            "model": "gpt-4o-2024-08-06",
            "messages": [
                [
                    "role": "system",
                    "content": assistantPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]

        // 4. Convert the JSON body to Data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"])
        }

        request.httpBody = httpBody

        // 5. Use URLSession to send the request asynchronously
        let (data, response) = try await URLSession.shared.data(for: request)

        // 6. Check the response status code
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 7. Parse the response JSON
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let assistantResponse = message["content"] as? String {
            return assistantResponse
        } else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
    }
    
    func translateSentencePhrases(phrases: [PhraseBlock], language: Language) async throws -> ([String], [String], String) {
        // 1. Set up the URL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }

        // 2. Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerTokenOpenAI)", forHTTPHeaderField: "Authorization")

        let assistantPrompt = """
            You will receive a list of phrases written in \(language.name). You have two tasks:
            1. Translate each phrase into both the romanization (\(language.romanizationSystem)) and English individually. While translating each phrase, you may use the other phrases for context, but your translation should focus on the meaning of the individual phrase. It is critical that you translate each phrase you are provided. They will be separated with new line characters. 
            2.  Combine the translated phrases into a full sentence and provide a contextual translation of the full sentence into English. Pay special attention to English Grammar and setence structure to ensure that the translated sentence reads natrually in English. 
            """
        let userPrompt = phrases.map { $0.selectedLanguage }.joined(separator: "\n")
        let responseFormat: [String: Any] = [
            "type": "json_schema",
            "json_schema": [
                "name": "translateText",
                "schema": [
                    "type": "object",
                    "properties": [
                        "romanizedPhrases": [
                            "type": "array",
                            "items": [
                                "type": "string"
                            ]
                        ],
                        "englishPhrases": [
                            "type": "array",
                            "items": [
                                "type": "string"
                            ]
                        ],
                        "englishSentence": [
                            "type": "string",
                        ]
                    ],
                    "required": ["romanizedPhrases", "englishPhrases", "englishSentence"],
                    "additionalProperties": false
                ],
                "strict": true
            ]
        ]
        

        // 3. Create the JSON body
        let jsonBody: [String: Any] = [
            "model": "gpt-4o-2024-08-06",
            "messages": [
                [
                    "role": "system",
                    "content": assistantPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "response_format": responseFormat
        ]

        // 4. Convert the JSON body to Data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"])
        }

        request.httpBody = httpBody

        // 5. Use URLSession to send the request asynchronously
        let (data, response) = try await URLSession.shared.data(for: request)

        // 6. Check the response status code
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 7. Parse the response JSON
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let contentString = message["content"] as? String {
               // Convert the contentString (which is a JSON string) into a dictionary
           if let contentData = contentString.data(using: .utf8),
              let assistantResponse = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
               
               // Extract the translatedPhrases and translatedSentence from the assistantResponse
               if let romanizedPhrases = assistantResponse["romanizedPhrases"] as? [String],
                  let englishPhrases = assistantResponse["englishPhrases"] as? [String],
                  let englishSentence = assistantResponse["englishSentence"] as? String {
                   
                   // Return both translatedPhrases and translatedSentence as a tuple
                   return (romanizedPhrases, englishPhrases, englishSentence)
               } else {
                   throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing keys in assistant response"])
               }
           } else {
               throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse assistant response"])
           }
       } else {
           throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
       }
   }
    
    // Function to create audio
    func createAudio(text: String, fileURL: URL) async throws {
        // 1. Set up the URL
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/ByhETIclHirOlWnWKhHc?output_format=mp3_22050_32") else {
            throw URLError(.badURL)
        }

        // 2. Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(bearerTokenElevenLabs, forHTTPHeaderField: "xi-api-key")

        // 3. Create the JSON body
        let jsonBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 1,
                "style": 0
            ]
        ]

        // 4. Convert the JSON body to Data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"])
        }

        request.httpBody = httpBody

        // 5. Use URLSession to send the request asynchronously
        let (data, response) = try await URLSession.shared.data(for: request)

        // 6. Check the response status code
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 7. Save the MP3 file to the provided URL
        try data.write(to: fileURL)

        // 8. No need to return anything
    }
    
    // Function to clear all generated audio files
    func clearGeneratedAudios() {
        let fileManager = FileManager.default
        let tempDirectoryURL = fileManager.temporaryDirectory

        do {
            // Get the contents of the temporary directory
            let fileURLs = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil)

            // Filter for .mp3 files
            let mp3Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp3" }

            // Delete each .mp3 file
            for fileURL in mp3Files {
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted: \(fileURL.lastPathComponent)")
                } catch {
                    print("Error deleting \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }

            print("Finished deleting temporary .mp3 files.")
        } catch {
            print("Error accessing temporary directory: \(error.localizedDescription)")
        }
    }
                                                                                                                   
    // Function to play the MP3
    var audioPlayer: AVAudioPlayer?
                                                                                                                   
    func playAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
}

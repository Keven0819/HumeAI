//
//  EVIMessage.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import Foundation

struct EVIMessage: Codable, Identifiable {
    let id = UUID()
    let type: String
    let content: String?
    let timestamp: Date
    let isUser: Bool
    let emotions: [String: Double]?
    
    enum CodingKeys: String, CodingKey {
        case type, content, emotions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        emotions = try container.decodeIfPresent([String: Double].self, forKey: .emotions)
        timestamp = Date()
        isUser = type == "user_message"
    }
    
    init(type: String, content: String?, isUser: Bool, emotions: [String: Double]? = nil) {
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.isUser = isUser
        self.emotions = emotions
    }
}

struct EmotionData {
    let dominantEmotion: String
    let confidence: Double
    let allEmotions: [String: Double]
    
    init() {
        self.dominantEmotion = "neutral"
        self.confidence = 0.0
        self.allEmotions = [:]
    }
    
    init(emotions: [String: Double]) {
        self.allEmotions = emotions
        if let dominant = emotions.max(by: { $0.value < $1.value }) {
            self.dominantEmotion = dominant.key
            self.confidence = dominant.value
        } else {
            self.dominantEmotion = "neutral"
            self.confidence = 0.0
        }
    }
}

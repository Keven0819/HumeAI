//
//  EmotionDisplayView.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import SwiftUI

struct EmotionDisplayView: View {
    let emotionData: EmotionData
    
    var body: some View {
        VStack {
            Text("當前情感狀態")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                VStack {
                    Text("主要情感")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(emotionData.dominantEmotion)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colorForEmotion(emotionData.dominantEmotion))
                }
                
                Spacer()
                
                VStack {
                    Text("信心度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", emotionData.confidence * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            if !emotionData.allEmotions.isEmpty {
                Divider()
                    .padding(.vertical, 10)
                
                Text("所有情感")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 5) {
                    ForEach(Array(emotionData.allEmotions.keys.sorted()), id: \.self) { emotion in
                        VStack {
                            Text(emotion)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(String(format: "%.2f", emotionData.allEmotions[emotion] ?? 0))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(5)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 2)
    }
    
    private func colorForEmotion(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "joy", "happiness":
            return .yellow
        case "sadness":
            return .blue
        case "anger":
            return .red
        case "fear":
            return .purple
        case "surprise":
            return .orange
        case "disgust":
            return .green
        default:
            return .gray
        }
    }
}

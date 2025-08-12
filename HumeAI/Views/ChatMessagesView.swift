//
//  ChatMessagesView.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import SwiftUI

struct ChatMessagesView: View {
    let messages: [EVIMessage]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(messages) { message in
                    ChatBubbleView(message: message)
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding()
    }
}

struct ChatBubbleView: View {
    let message: EVIMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                if let content = message.content {
                    Text(content)
                        .padding()
                        .background(message.isUser ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(15)
                }
                
                if let emotions = message.emotions, !emotions.isEmpty {
                    Text("情感: \(topEmotions(emotions))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func topEmotions(_ emotions: [String: Double]) -> String {
        let sorted = emotions.sorted { $0.value > $1.value }
        let top3 = Array(sorted.prefix(3))
        return top3.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

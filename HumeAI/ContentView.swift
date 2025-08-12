//
//  ContentView.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var eviManager = EVIManager()
    @State private var isConnected = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 標題
                Text("Hume AI EVI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 連接狀態
                HStack {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 10, height: 10)
                    Text(connectionStatusText)
                        .foregroundColor(connectionColor)
                }
                .padding()
                
                // 情感分析顯示
                EmotionDisplayView(emotionData: eviManager.currentEmotion)
                    .padding()
                
                // 聊天訊息
                ChatMessagesView(messages: eviManager.chatMessages)
                
                Spacer()
                
                // 控制按鈕
                VStack(spacing: 20) {
                    // 連接/斷開按鈕
                    Button(action: {
                        Task {
                            if isConnected {
                                await MainActor.run {
                                    eviManager.disconnect()
                                }
                            } else {
                                await eviManager.connect()
                            }
                        }
                    }) {
                        Text(isConnected ? "斷開連接" : "連接")
                            .foregroundColor(.white)
                            .padding()
                            .background(isConnected ? Color.red : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(eviManager.connectionState == .connecting)
                    
                    // 錄音按鈕
                    Button(action: {
                        if eviManager.isRecording {
                            eviManager.stopRecording()
                        } else {
                            Task {
                                await eviManager.startRecording()
                            }
                        }
                    }) {
                        Image(systemName: eviManager.isRecording ? "mic.fill" : "mic")
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                            .padding()
                            .background(eviManager.isRecording ? Color.red : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(!isConnected)
                    
                    // 靜音按鈕
                    Button(action: {
                        eviManager.toggleMute()
                    }) {
                        Image(systemName: eviManager.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                            .padding()
                            .background(eviManager.isMuted ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(!isConnected)
                }
                .padding()
            }
        }
        .onReceive(eviManager.$connectionState) { state in
            isConnected = (state == .connected)
        }
    }
    
    private var connectionColor: Color {
        switch eviManager.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        switch eviManager.connectionState {
        case .connected:
            return "已連接"
        case .connecting:
            return "連接中..."
        case .error:
            return "連接錯誤"
        case .disconnected:
            return "未連接"
        }
    }
}

#Preview {
    ContentView()
}

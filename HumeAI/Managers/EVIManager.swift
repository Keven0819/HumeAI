//
//  EVIManager.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import Foundation
import AVFoundation
import Combine

enum ConnectionState {
    case disconnected, connecting, connected, error
}

class EVIManager: NSObject, ObservableObject {
    @Published var chatMessages: [EVIMessage] = []
    @Published var currentEmotion = EmotionData()
    @Published var isRecording = false
    @Published var isMuted = false
    @Published var connectionState: ConnectionState = .disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioManager: AudioManager?
    
    // 替換為您的實際 API 密鑰和配置 ID
    private let apiKey = "m1bQuPz0A11nrrceGgGEerQPSaBGoGjLdlZwnBKBnJalQY9U"
    private let configId = "c947d7f7-ba90-4cda-80a9-19650bf6f536" // 需要在 Hume AI 後台創建配置
    private let websocketURL = "wss://api.hume.ai/v0/evi/chat"
    
    override init() {
        super.init()
        setupAudioManager()
    }
    
    private func setupAudioManager() {
        audioManager = AudioManager()
        audioManager?.delegate = self
    }
    
    @MainActor
    func connect() async {
        guard connectionState != .connected && connectionState != .connecting else { return }
        
        connectionState = .connecting
        
        // 確保先斷開舊連接
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        var urlComponents = URLComponents(string: websocketURL)
        
        // 如果有配置 ID，使用配置 ID，否則使用 API 密鑰直接連接
        if !configId.isEmpty && configId != "YOUR_CONFIG_ID" {
            urlComponents?.queryItems = [
                URLQueryItem(name: "config_id", value: configId),
                URLQueryItem(name: "verbose_transcription", value: "true")
            ]
        } else {
            // 備用方法：直接使用 API 密鑰
            urlComponents?.queryItems = [
                URLQueryItem(name: "verbose_transcription", value: "true")
            ]
        }
        
        guard let url = urlComponents?.url else {
            connectionState = .error
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Hume-Api-Key")
        request.timeoutInterval = 30
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 開始接收訊息
        receiveMessage()
        
        // 等待收到 chat_metadata 後再設定為已連接
        // connectionState 會在 processMessageData 中設定
    }
    
    @MainActor
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        stopRecording()
        audioManager?.stopEngine()
    }
    
    private func sendSessionSettings() async {
        // 根據最新文檔，簡化會話設定，只包含必要的音訊配置
        let sessionSettings: [String: Any] = [
            "type": "session_settings",
            "audio": [
                "encoding": "linear16",
                "sample_rate": 44100,
                "channels": 1
            ]
        ]
        
        print("發送會話設定: \(sessionSettings)")
        await sendMessage(sessionSettings)
    }
    
    private func sendMessage(_ message: [String: Any]) async {
        guard let webSocketTask = webSocketTask, connectionState == .connected else {
            print("WebSocket 未連接，無法發送訊息")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let wsMessage = URLSessionWebSocketTask.Message.data(data)
            try await webSocketTask.send(wsMessage)
        } catch {
            print("發送訊息錯誤: \(error)")
            await MainActor.run {
                connectionState = .error
            }
        }
    }
    
    private func receiveMessage() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            switch result {
            case .success(let message):
                Task {
                    await self?.handleMessage(message)
                    // 只有在連接狀態為 connected 時才繼續接收
                    if await self?.connectionState == .connected {
                        self?.receiveMessage()
                    }
                }
            case .failure(let error):
                print("接收訊息錯誤: \(error)")
                Task { @MainActor in
                    self?.connectionState = .error
                    // 嘗試重新連接
                    self?.attemptReconnection()
                }
            }
        }
    }
    
    @MainActor
    private func attemptReconnection() {
        guard connectionState == .error else { return }
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 等待 2 秒
            if connectionState == .error {
                await connect()
            }
        }
    }
    
    @MainActor
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            await processMessageData(data)
        case .string(let string):
            if let data = string.data(using: .utf8) {
                await processMessageData(data)
            }
        @unknown default:
            break
        }
    }
    
    private func processMessageData(_ data: Data) async {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }
            
            await MainActor.run {
                switch type {
                case "audio_output":
                    if let audioData = json["audio"] as? String {
                        playAudioFromBase64(audioData)
                    }
                    
                case "user_message", "assistant_message":
                    if let content = json["content"] as? String {
                        let emotions = extractEmotions(from: json)
                        let message = EVIMessage(
                            type: type,
                            content: content,
                            isUser: type == "user_message",
                            emotions: emotions
                        )
                        chatMessages.append(message)
                        
                        if let emotions = emotions, !emotions.isEmpty {
                            currentEmotion = EmotionData(emotions: emotions)
                        }
                    }
                
                case "chat_metadata":
                    // 處理聊天元資料 - 這表示連接成功
                    print("收到聊天元資料: \(json)")
                    if let conversationId = json["chat_id"] as? String {
                        print("對話 ID: \(conversationId)")
                    }
                    
                    // 收到 chat_metadata 後設定為已連接
                    if connectionState == .connecting {
                        connectionState = .connected
                        // 不需要立即發送會話設定，等到開始錄音時再發送
                    }
                    
                case "user_interruption":
                    print("用戶中斷")
                    
                case "error":
                    if let errorMessage = json["message"] as? String {
                        print("EVI 錯誤: \(errorMessage)")
                        connectionState = .error
                    }
                    
                default:
                    print("未處理的訊息類型: \(type)")
                }
            }
        } catch {
            print("處理訊息資料錯誤: \(error)")
        }
    }
    
    private func extractEmotions(from json: [String: Any]) -> [String: Double]? {
        if let prosody = json["prosody"] as? [String: Any] {
            return prosody.compactMapValues { $0 as? Double }
        }
        return nil
    }
    
    func startRecording() async {
        guard connectionState == .connected else { return }
        
        do {
            try await audioManager?.requestPermission()
            
            // 在開始錄音前發送會話設定
            await sendSessionSettings()
            
            try audioManager?.startRecording()
            await MainActor.run {
                isRecording = true
            }
        } catch {
            print("開始錄音錯誤: \(error)")
        }
    }
    
    @MainActor
    func stopRecording() {
        audioManager?.stopRecording()
        isRecording = false
    }
    
    @MainActor
    func toggleMute() {
        isMuted.toggle()
        audioManager?.setMuted(isMuted)
    }
    
    private func playAudioFromBase64(_ base64String: String) {
        guard let data = Data(base64Encoded: base64String) else { return }
        audioManager?.playAudio(data: data)
    }
}

extension EVIManager: AudioManagerDelegate {
    func audioManager(_ manager: AudioManager, didCaptureAudioData data: String) {
        guard connectionState == .connected else { return }
        
        let audioInput: [String: Any] = [
            "type": "audio_input",
            "data": data
        ]
        
        Task {
            await sendMessage(audioInput)
        }
    }
}

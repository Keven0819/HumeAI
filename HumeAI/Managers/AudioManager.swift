//
//  AudioManager.swift
//  HumeAI
//
//  Created by imac-3570 on 2025/8/12.
//

import AVFoundation
import Foundation

protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didCaptureAudioData data: String)
}

class AudioManager: NSObject {
    weak var delegate: AudioManagerDelegate?
    
    private var audioEngine: AVAudioEngine!
    private var audioSession: AVAudioSession!
    private var audioPlayer: AVAudioPlayer?
    private var isMuted = false
    
    override init() {
        super.init()
        setupAudio()
    }
    
    private func setupAudio() {
        audioEngine = AVAudioEngine()
        audioSession = AVAudioSession.sharedInstance()
        
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
            try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffer
        } catch {
            print("音訊會話設定錯誤: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixerNode = audioEngine.mainMixerNode
        
        audioEngine.connect(mainMixerNode, to: outputNode, format: nil)
        
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            try outputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("語音處理設定錯誤: \(error)")
        }
    }
    
    func requestPermission() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AudioError.permissionDenied)
                }
            }
        }
    }
    
    func startRecording() throws {
        let inputNode = audioEngine.inputNode
        let nativeInputFormat = inputNode.inputFormat(forBus: 0)
        let inputBufferSize = UInt32(nativeInputFormat.sampleRate * 0.02)
        
        guard let desiredInputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.formatError
        }
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: inputBufferSize,
            format: nativeInputFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, nativeFormat: nativeInputFormat, desiredFormat: desiredInputFormat)
        }
        
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, nativeFormat: AVAudioFormat, desiredFormat: AVAudioFormat) {
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: 1024),
              let inputAudioConverter = AVAudioConverter(from: nativeFormat, to: desiredFormat) else {
            return
        }
        
        var error: NSError?
        let status = inputAudioConverter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if let error = error {
            print("音訊轉換錯誤: \(error)")
            return
        }
        
        if status == .haveData {
            let byteLength = Int(convertedBuffer.frameLength) * Int(convertedBuffer.format.streamDescription.pointee.mBytesPerFrame)
            
            let audioData: Data
            if isMuted {
                // 發送靜音資料
                audioData = Data(repeating: 0, count: byteLength)
            } else {
                guard let bufferData = convertedBuffer.audioBufferList.pointee.mBuffers.mData else { return }
                audioData = Data(bytes: bufferData, count: byteLength)
            }
            
            let base64String = audioData.base64EncodedString()
            delegate?.audioManager(self, didCaptureAudioData: base64String)
        }
    }
    
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
    }
    
    func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("音訊播放錯誤: \(error)")
        }
    }
    
    func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

enum AudioError: Error {
    case permissionDenied
    case formatError
}

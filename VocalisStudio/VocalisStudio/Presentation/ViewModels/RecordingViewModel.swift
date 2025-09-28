import Foundation
import Combine
import SwiftUI

@MainActor
public class RecordingViewModel: ObservableObject {
    @Published public var isRecording = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var currentRecording: Recording?
    @Published public var recordings: [Recording] = []
    @Published public var errorMessage: String?
    
    private let startRecordingUseCase: StartRecordingUseCase
    private let stopRecordingUseCase: StopRecordingUseCase
    private let recordingRepository: RecordingRepository
    
    private var timer: Timer?
    
    public init(
        startRecordingUseCase: StartRecordingUseCase,
        stopRecordingUseCase: StopRecordingUseCase,
        recordingRepository: RecordingRepository
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.recordingRepository = recordingRepository
        
        Task {
            await loadRecordings()
        }
    }
    
    public func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    private func startRecording() async {
        do {
            let recording = try await startRecordingUseCase.execute()
            currentRecording = recording
            isRecording = true
            startTimer()
            errorMessage = nil
        } catch {
            errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
        }
    }
    
    private func stopRecording() async {
        guard let recording = currentRecording else { return }
        
        do {
            let updatedRecording = try await stopRecordingUseCase.execute(recording)
            currentRecording = updatedRecording
            isRecording = false
            stopTimer()
            await loadRecordings()
        } catch {
            errorMessage = "録音を停止できませんでした: \(error.localizedDescription)"
        }
    }
    
    public func loadRecordings() async {
        do {
            recordings = try await recordingRepository.findAll()
        } catch {
            errorMessage = "録音の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    public func deleteRecording(_ recording: Recording) async {
        do {
            try await recordingRepository.delete(recording.id)
            await loadRecordings()
        } catch {
            errorMessage = "録音の削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
    }
}
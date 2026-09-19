import Foundation
import Combine

/// Manages all timer-related functionality
/// Extracts timer logic from SudokuGameViewModel
@MainActor
final class TimerManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var timeElapsed: Int = 0
    @Published var isTimerRunning: Bool = false
    @Published var isPaused: Bool = false
    
    // MARK: - Private State
    
    private var gameTimer: Timer?
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    
    // Conditions for running
    var isSettingsPresented: Bool = false
    var isRulesPresented: Bool = false
    var isGameComplete: Bool = false
    var isSolved: Bool = false
    
    private var shouldRunTimer: Bool {
        !isPaused && !isSettingsPresented && !isRulesPresented && !isGameComplete && !isSolved
    }
    
    // MARK: - Timer Control
    
    func start() {
        guard !isSolved && !isGameComplete else { return }
        
        if gameTimer == nil {
            isTimerRunning = true
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.shouldRunTimer {
                        self.timeElapsed += 1
                    }
                }
            }
        }
    }
    
    func stop() {
        isTimerRunning = false
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        isPaused = false
    }
    
    func reset() {
        stop()
        timeElapsed = 0
        pausedTime = 0
        startTime = nil
    }
    
    // MARK: - Formatted Time
    
    var formattedTime: String {
        formatTime(seconds: timeElapsed)
    }
    
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        gameTimer?.invalidate()
        gameTimer = nil
    }
}

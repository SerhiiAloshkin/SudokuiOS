import Foundation
import Combine

/// Manages hint system with cooldowns and rewards
/// Extracts hint logic from SudokuGameViewModel
@MainActor
final class HintSystemManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var hintsUsed: Int = 0
    @Published var hintCooldownRemaining: Int = 0
    @Published var isRewardedAdLoading: Bool = false
    @Published var showHintErrorAlert: Bool = false
    var hintErrorMessage: String = ""
    
    // MARK: - Configuration
    
    private let cooldownDuration: TimeInterval = 300 // 5 minutes
    private let cooldownKey = "nextHintAvailableDate"
    
    // MARK: - Private State
    
    private var cooldownTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        startCooldownTimer()
    }
    
    // MARK: - Hint Logic
    
    func requestHint(
        board: [Int],
        solution: [Int],
        isAdsRemoved: Bool,
        onHintFound: @escaping (Int, Int) -> Void,
        onNoHintsAvailable: @escaping () -> Void,
        onShowRewardedAd: @escaping (@escaping (Bool) -> Void) -> Void
    ) {
        // Check cooldown
        guard hintCooldownRemaining == 0 else {
            showError("Hint on cooldown. Wait \(hintCooldownRemaining)s")
            return
        }
        
        // Find empty cell with solution
        guard let (index, digit) = findHintCell(board: board, solution: solution) else {
            onNoHintsAvailable()
            return
        }
        
        // If ads removed, give hint immediately
        if isAdsRemoved {
            applyHint(index: index, digit: digit, onHintFound: onHintFound)
            return
        }
        
        // Otherwise, show rewarded ad
        isRewardedAdLoading = true
        onShowRewardedAd { [weak self] success in
            guard let self = self else { return }
            self.isRewardedAdLoading = false
            
            if success {
                self.applyHint(index: index, digit: digit, onHintFound: onHintFound)
            } else {
                self.showError("Watch ad to get hint")
            }
        }
    }
    
    private func applyHint(index: Int, digit: Int, onHintFound: @escaping (Int, Int) -> Void) {
        hintsUsed += 1
        startCooldown()
        onHintFound(index, digit)
    }
    
    private func findHintCell(board: [Int], solution: [Int]) -> (index: Int, digit: Int)? {
        guard board.count == 81, solution.count == 81 else { return nil }
        
        // Find first empty cell with solution
        for i in 0..<81 {
            if board[i] == 0 && solution[i] != 0 {
                return (i, solution[i])
            }
        }
        
        return nil
    }
    
    // MARK: - Cooldown Management
    
    private func startCooldown() {
        let targetDate = Date().addingTimeInterval(cooldownDuration)
        UserDefaults.standard.set(targetDate, forKey: cooldownKey)
        startCooldownTimer()
    }
    
    private func startCooldownTimer() {
        cooldownTimer?.invalidate()
        updateCooldownRemaining()
        
        guard hintCooldownRemaining > 0 else { return }
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateCooldownRemaining()
            }
        }
    }
    
    private func updateCooldownRemaining() {
        guard let targetDate = UserDefaults.standard.object(forKey: cooldownKey) as? Date else {
            hintCooldownRemaining = 0
            cooldownTimer?.invalidate()
            return
        }
        
        let remaining = Int(targetDate.timeIntervalSinceNow)
        if remaining > 0 {
            hintCooldownRemaining = remaining
        } else {
            hintCooldownRemaining = 0
            cooldownTimer?.invalidate()
            UserDefaults.standard.removeObject(forKey: cooldownKey)
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        hintErrorMessage = message
        showHintErrorAlert = true
    }
    
    // MARK: - Reset
    
    func reset() {
        hintsUsed = 0
        hintCooldownRemaining = 0
        UserDefaults.standard.removeObject(forKey: cooldownKey)
        cooldownTimer?.invalidate()
    }
    
    // MARK: - Cleanup
    
    deinit {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
}

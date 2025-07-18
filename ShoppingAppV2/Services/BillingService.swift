
import Foundation

class BillingService: ObservableObject {
    @Published var initialCredits: Double {
        didSet {
            UserDefaults.standard.set(initialCredits, forKey: "initial_api_credits")
        }
    }
    
    @Published var manualSpentAdjustment: Double {
        didSet {
            UserDefaults.standard.set(manualSpentAdjustment, forKey: "manual_spent_credits")
        }
    }
    
    @Published var totalSpentAllTime: Double = 0.0
    
    var remainingCredits: Double {
        return max(0, initialCredits - totalSpent)
    }
    
    var creditsUsedPercentage: Double {
        guard initialCredits > 0 else { return 0 }
        return min(1.0, totalSpent / initialCredits)
    }
    
    var totalSpent: Double {
        return manualSpentAdjustment + totalSpentAllTime
    }
    
    init() {
        self.initialCredits = UserDefaults.standard.object(forKey: "initial_api_credits") as? Double ?? 0.0
        self.manualSpentAdjustment = UserDefaults.standard.object(forKey: "manual_spent_credits") as? Double ?? 0.0
        self.totalSpentAllTime = UserDefaults.standard.object(forKey: "total_spent_all_time") as? Double ?? 0.0
    }
    
    func addCost(amount: Double) {
        totalSpentAllTime += amount
        UserDefaults.standard.set(totalSpentAllTime, forKey: "total_spent_all_time")
    }
    
    func reset() {
        initialCredits = 0.0
        manualSpentAdjustment = 0.0
        totalSpentAllTime = 0.0
        UserDefaults.standard.removeObject(forKey: "initial_api_credits")
        UserDefaults.standard.removeObject(forKey: "manual_spent_credits")
        UserDefaults.standard.removeObject(forKey: "total_spent_all_time")
    }
}


import Foundation

class HistoryService: ObservableObject {
    @Published var promptHistory: [PromptHistoryItem] = []
    
    private let historyKey = "prompt_history"
    
    var totalInteractionCount: Int {
        return promptHistory.count
    }
    
    init() {
        load()
    }
    
    func add(item: PromptHistoryItem) {
        promptHistory.insert(item, at: 0)
        save()
    }

    func clearAll() {
        promptHistory.removeAll()
        save()
    }
    
    func remove(at index: Int) {
        guard index < promptHistory.count else { return }
        promptHistory.remove(at: index)
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(promptHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([PromptHistoryItem].self, from: data) {
            promptHistory = decoded
        }
    }
}

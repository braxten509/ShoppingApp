import Foundation
import Combine

class CustomPriceListStore: ObservableObject {
    @Published var customPriceLists: [CustomPriceList] = [] {
        didSet {
            saveLists()
        }
    }
    
    @Published var defaultCustomPriceListId: String? {
        didSet {
            UserDefaults.standard.set(defaultCustomPriceListId, forKey: "defaultCustomPriceListId")
        }
    }
    
    private let listsKey = "custom_price_lists"
    
    init() {
        loadLists()
        loadDefaultListId()
    }
    
    // MARK: - List Management
    
    func addList(_ list: CustomPriceList) {
        customPriceLists.append(list)
    }
    
    func removeList(at index: Int) {
        guard index < customPriceLists.count else { return }
        let removedList = customPriceLists[index]
        
        // If removing the default list, clear the default
        if defaultCustomPriceListId == removedList.id.uuidString {
            defaultCustomPriceListId = nil
        }
        
        // Clear CalculatorView's selected custom price list if it matches the deleted one
        if let savedListId = UserDefaults.standard.string(forKey: "calculatorView_selectedCustomPriceListId"),
           removedList.id.uuidString == savedListId {
            UserDefaults.standard.removeObject(forKey: "calculatorView_selectedCustomPriceListId")
        }
        
        customPriceLists.remove(at: index)
    }
    
    func updateList(at index: Int, with list: CustomPriceList) {
        guard index < customPriceLists.count else { return }
        
        // Create a deep copy of the current lists to ensure SwiftUI detects the change
        var updatedLists = customPriceLists
        updatedLists[index] = list
        
        // Update the published property (this automatically triggers objectWillChange)
        customPriceLists = updatedLists
    }
    
    func getList(by id: UUID) -> CustomPriceList? {
        return customPriceLists.first { $0.id == id }
    }
    
    func getListIndex(by id: UUID) -> Int? {
        return customPriceLists.firstIndex { $0.id == id }
    }
    
    // MARK: - Item Management
    
    func addItem(_ item: CustomPriceItem, to listId: UUID) {
        print("🏪 CustomPriceListStore.addItem() called")
        print("🏪 item: \(item)")
        print("🏪 listId: \(listId)")
        print("🏪 customPriceLists count: \(customPriceLists.count)")
        
        guard let index = getListIndex(by: listId) else { 
            print("❌ Could not find list with id \(listId)")
            return 
        }
        
        print("🏪 Found list at index \(index)")
        print("🏪 List name: \(customPriceLists[index].name)")
        print("🏪 Current items count: \(customPriceLists[index].items.count)")
        
        // Create a deep copy of the current lists to ensure SwiftUI detects the change
        var updatedLists = customPriceLists
        updatedLists[index].addItem(item)
        
        // Update the published property (this automatically triggers objectWillChange)
        customPriceLists = updatedLists
        
        print("🏪 After adding item, count: \(customPriceLists[index].items.count)")
        print("🏪 Updated customPriceLists array and triggered objectWillChange")
    }
    
    func removeItem(at itemIndex: Int, from listId: UUID) {
        guard let listIndex = getListIndex(by: listId) else { return }
        
        // Create a deep copy of the current lists to ensure SwiftUI detects the change
        var updatedLists = customPriceLists
        updatedLists[listIndex].removeItem(at: itemIndex)
        
        // Update the published property (this automatically triggers objectWillChange)
        customPriceLists = updatedLists
    }
    
    func updateItem(at itemIndex: Int, with item: CustomPriceItem, in listId: UUID) {
        guard let listIndex = getListIndex(by: listId) else { return }
        
        // Create a deep copy of the current lists to ensure SwiftUI detects the change
        var updatedLists = customPriceLists
        updatedLists[listIndex].updateItem(at: itemIndex, with: item)
        
        // Update the published property (this automatically triggers objectWillChange)
        customPriceLists = updatedLists
    }
    
    // MARK: - Default List Management
    
    func setDefaultList(_ list: CustomPriceList) {
        defaultCustomPriceListId = list.id.uuidString
    }
    
    func getDefaultList() -> CustomPriceList? {
        guard let defaultId = defaultCustomPriceListId,
              let uuid = UUID(uuidString: defaultId) else {
            return customPriceLists.first
        }
        return getList(by: uuid) ?? customPriceLists.first
    }
    
    func isDefaultList(_ list: CustomPriceList) -> Bool {
        guard let defaultId = defaultCustomPriceListId,
              let _ = UUID(uuidString: defaultId) else {
            return customPriceLists.first?.id == list.id
        }
        return list.id.uuidString == defaultId
    }
    
    func clearDefaultList() {
        defaultCustomPriceListId = nil
    }
    
    // MARK: - Search
    
    func searchAllLists(query: String) -> [(list: CustomPriceList, items: [CustomPriceItem])] {
        guard !query.isEmpty else { return [] }
        
        var results: [(list: CustomPriceList, items: [CustomPriceItem])] = []
        
        for list in customPriceLists {
            let matchingItems = list.searchItems(query: query)
            if !matchingItems.isEmpty {
                results.append((list: list, items: matchingItems))
            }
        }
        
        return results
    }
    
    func searchInList(_ listId: UUID, query: String) -> [CustomPriceItem] {
        guard let list = getList(by: listId) else { return [] }
        return list.searchItems(query: query)
    }
    
    // MARK: - Persistence
    
    private func saveLists() {
        if let encoded = try? JSONEncoder().encode(customPriceLists) {
            UserDefaults.standard.set(encoded, forKey: listsKey)
        }
    }
    
    private func loadLists() {
        if let data = UserDefaults.standard.data(forKey: listsKey),
           let decoded = try? JSONDecoder().decode([CustomPriceList].self, from: data) {
            customPriceLists = decoded.sorted(by: { $0.lastModified > $1.lastModified })
        }
    }
    
    private func loadDefaultListId() {
        defaultCustomPriceListId = UserDefaults.standard.string(forKey: "defaultCustomPriceListId")
    }
    
    // MARK: - Utility
    
    var hasLists: Bool {
        return !customPriceLists.isEmpty
    }
    
    var totalItemsCount: Int {
        return customPriceLists.reduce(0) { $0 + $1.items.count }
    }
    
    func createSampleList() -> CustomPriceList {
        var sampleList = CustomPriceList(name: "Sample Store")
        
        let sampleItems = [
            CustomPriceItem(name: "Milk", price: 3.99, description: "1 gallon whole milk"),
            CustomPriceItem(name: "Bread", price: 2.49, description: "Whole wheat loaf"),
            CustomPriceItem(name: "Eggs", price: 2.99, description: "Dozen large eggs"),
            CustomPriceItem(name: "Bananas", price: 0.68, description: "Per pound"),
            CustomPriceItem(name: "Chicken Breast", price: 5.99, description: "Per pound, boneless")
        ]
        
        for item in sampleItems {
            sampleList.addItem(item)
        }
        
        return sampleList
    }
}

import Foundation
import Combine


class SettingsService: ObservableObject {
    
    @Published var useAIModels: Bool {
        didSet {
            UserDefaults.standard.set(useAIModels, forKey: "useAIModels")
        }
    }

    @Published var selectedModelForTaxRate: String {
        didSet {
            // Always enforce sonar-pro for tax rate analysis
            if selectedModelForTaxRate != "sonar-pro" {
                selectedModelForTaxRate = "sonar-pro"
            }
            UserDefaults.standard.set(selectedModelForTaxRate, forKey: "selectedModelForTaxRate")
        }
    }

    @Published var selectedModelForPhotoPrice: String {
        didSet {
            UserDefaults.standard.set(selectedModelForPhotoPrice, forKey: "selectedModelForPhotoPrice")
        }
    }


    @Published var openAIAPIKey: String {
        didSet {
            UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey")
        }
    }

    @Published var perplexityAPIKey: String {
        didSet {
            UserDefaults.standard.set(perplexityAPIKey, forKey: "perplexityAPIKey")
        }
    }
    
    @Published var locationAccessEnabled: Bool {
        didSet {
            UserDefaults.standard.set(locationAccessEnabled, forKey: "locationAccessEnabled")
            if !locationAccessEnabled && !useManualTaxRate {
                useManualTaxRate = true
            }
        }
    }
    
    @Published var aiEnabled: Bool {
        didSet {
            print("🔧 SettingsService: aiEnabled set to \(aiEnabled)")
            UserDefaults.standard.set(aiEnabled, forKey: "aiEnabled")
            if !aiEnabled {
                print("🔧 SettingsService: AI disabled - disabling location access, auto-search, and forcing manual tax")
                // When AI is disabled, also disable location access and force manual tax
                locationAccessEnabled = false
                if !useManualTaxRate {
                    useManualTaxRate = true
                }
                // Also disable auto-search features
                autoOpenSearchAfterPhoto = false
                alwaysSearchIgnorePrice = false
            }
        }
    }
    
    @Published var internetAccessEnabled: Bool {
        didSet {
            print("🔧 SettingsService: internetAccessEnabled set to \(internetAccessEnabled)")
            UserDefaults.standard.set(internetAccessEnabled, forKey: "internetAccessEnabled")
            if !internetAccessEnabled {
                print("🔧 SettingsService: Internet disabled - disabling AI, location access, and auto-search")
                // When Internet is disabled, also disable AI and location access
                aiEnabled = false
                locationAccessEnabled = false
                if !useManualTaxRate {
                    useManualTaxRate = true
                }
                // Also disable auto-search features
                autoOpenSearchAfterPhoto = false
                alwaysSearchIgnorePrice = false
            }
        }
    }
    
    @Published var useManualTaxRate: Bool {
        didSet {
            UserDefaults.standard.set(useManualTaxRate, forKey: "useManualTaxRate")
        }
    }
    
    @Published var manualTaxRate: Double {
        didSet {
            UserDefaults.standard.set(manualTaxRate, forKey: "manualTaxRate")
        }
    }
    
    @Published var stores: [Store] {
        didSet {
            saveStores()
        }
    }
    
    @Published var defaultStoreId: String? {
        didSet {
            UserDefaults.standard.set(defaultStoreId, forKey: "defaultStoreId")
        }
    }
    
    @Published var autoOpenSearchAfterPhoto: Bool {
        didSet {
            print("🔧 SettingsService: autoOpenSearchAfterPhoto set to \(autoOpenSearchAfterPhoto)")
            UserDefaults.standard.set(autoOpenSearchAfterPhoto, forKey: "autoOpenSearchAfterPhoto")
            if !autoOpenSearchAfterPhoto {
                print("🔧 SettingsService: Auto-open search disabled - also disabling always search ignore price")
                alwaysSearchIgnorePrice = false
            }
        }
    }
    
    @Published var alwaysSearchIgnorePrice: Bool {
        didSet {
            print("🔧 SettingsService: alwaysSearchIgnorePrice set to \(alwaysSearchIgnorePrice)")
            UserDefaults.standard.set(alwaysSearchIgnorePrice, forKey: "alwaysSearchIgnorePrice")
        }
    }
    
    @Published var customPriceListsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(customPriceListsEnabled, forKey: "customPriceListsEnabled")
        }
    }
    
    @Published var replaceItemNameFromPriceList: Bool {
        didSet {
            UserDefaults.standard.set(replaceItemNameFromPriceList, forKey: "replaceItemNameFromPriceList")
        }
    }
    
    @Published var useMultiAttemptTaxDetection: Bool {
        didSet {
            UserDefaults.standard.set(useMultiAttemptTaxDetection, forKey: "useMultiAttemptTaxDetection")
        }
    }
    
    @Published var taxDetectionAttempts: Int {
        didSet {
            UserDefaults.standard.set(taxDetectionAttempts, forKey: "taxDetectionAttempts")
        }
    }
    
    @Published var taxSearchContextSize: String {
        didSet {
            UserDefaults.standard.set(taxSearchContextSize, forKey: "taxSearchContextSize")
        }
    }
    
    @Published var taxSearchRecencyFilter: String? {
        didSet {
            UserDefaults.standard.set(taxSearchRecencyFilter, forKey: "taxSearchRecencyFilter")
        }
    }
    
    // Tax rate caching for consistency
    @Published var cachedTaxRates: [String: Double] {
        didSet {
            if let encoded = try? JSONEncoder().encode(cachedTaxRates) {
                UserDefaults.standard.set(encoded, forKey: "cachedTaxRates")
            }
        }
    }
    
    // Credit tracking
    @Published var openAICredits: Double {
        didSet {
            UserDefaults.standard.set(openAICredits, forKey: "openAICredits")
        }
    }
    
    @Published var perplexityCredits: Double {
        didSet {
            UserDefaults.standard.set(perplexityCredits, forKey: "perplexityCredits")
        }
    }
    
    @Published var lastSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        }
    }
    

    let aiModels = [
        // OpenAI Models
        "gpt-4o-mini",
        
        // Perplexity Models
        "sonar-pro",
        "sonar"
    ]
    
    // Computed property to determine if manual tax should be forced
    var shouldForceManualTax: Bool {
        return !locationAccessEnabled || !aiEnabled || !internetAccessEnabled
    }

    init() {
        self.useAIModels = UserDefaults.standard.bool(forKey: "useAIModels")
        // Always use sonar-pro for tax rate analysis
        self.selectedModelForTaxRate = "sonar-pro"
        UserDefaults.standard.set("sonar-pro", forKey: "selectedModelForTaxRate")
        self.selectedModelForPhotoPrice = UserDefaults.standard.string(forKey: "selectedModelForPhotoPrice") ?? "gpt-4o-mini"
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        self.perplexityAPIKey = UserDefaults.standard.string(forKey: "perplexityAPIKey") ?? ""
        
        // Check if values exist in UserDefaults, if not set defaults to true
        if UserDefaults.standard.object(forKey: "locationAccessEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "locationAccessEnabled")
        }
        if UserDefaults.standard.object(forKey: "aiEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "aiEnabled")
        }
        if UserDefaults.standard.object(forKey: "internetAccessEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "internetAccessEnabled")
        }
        
        self.locationAccessEnabled = UserDefaults.standard.bool(forKey: "locationAccessEnabled")
        self.aiEnabled = UserDefaults.standard.bool(forKey: "aiEnabled")
        self.internetAccessEnabled = UserDefaults.standard.bool(forKey: "internetAccessEnabled")
        
        // Force manual tax rate if location or AI is disabled
        let storedManualTax = UserDefaults.standard.bool(forKey: "useManualTaxRate")
        self.useManualTaxRate = storedManualTax
        // Set a reasonable default tax rate if none exists (6% is a common US average)
        let storedTaxRate = UserDefaults.standard.double(forKey: "manualTaxRate")
        self.manualTaxRate = storedTaxRate > 0 ? storedTaxRate : 6.0
        self.defaultStoreId = UserDefaults.standard.string(forKey: "defaultStoreId")
        
        // Temporarily initialize auto-search settings (will be corrected below)
        self.autoOpenSearchAfterPhoto = UserDefaults.standard.bool(forKey: "autoOpenSearchAfterPhoto")
        self.alwaysSearchIgnorePrice = UserDefaults.standard.bool(forKey: "alwaysSearchIgnorePrice")
        
        // Initialize credit tracking with default "Unknown" state (-1 indicates unknown)
        self.openAICredits = UserDefaults.standard.object(forKey: "openAICredits") as? Double ?? -1.0
        self.perplexityCredits = UserDefaults.standard.object(forKey: "perplexityCredits") as? Double ?? -1.0
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        
        // Initialize custom price lists setting
        if UserDefaults.standard.object(forKey: "customPriceListsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "customPriceListsEnabled")
        }
        self.customPriceListsEnabled = UserDefaults.standard.bool(forKey: "customPriceListsEnabled")
        
        // Initialize replace item name from price list setting (default false to preserve existing behavior)
        if UserDefaults.standard.object(forKey: "replaceItemNameFromPriceList") == nil {
            UserDefaults.standard.set(false, forKey: "replaceItemNameFromPriceList")
        }
        self.replaceItemNameFromPriceList = UserDefaults.standard.bool(forKey: "replaceItemNameFromPriceList")
        
        // Initialize multi-attempt tax detection settings
        if UserDefaults.standard.object(forKey: "useMultiAttemptTaxDetection") == nil {
            UserDefaults.standard.set(false, forKey: "useMultiAttemptTaxDetection")
        }
        self.useMultiAttemptTaxDetection = UserDefaults.standard.bool(forKey: "useMultiAttemptTaxDetection")
        
        if UserDefaults.standard.object(forKey: "taxDetectionAttempts") == nil {
            UserDefaults.standard.set(3, forKey: "taxDetectionAttempts")
        }
        self.taxDetectionAttempts = UserDefaults.standard.integer(forKey: "taxDetectionAttempts")
        
        // Initialize tax search settings
        if UserDefaults.standard.object(forKey: "taxSearchContextSize") == nil {
            UserDefaults.standard.set("high", forKey: "taxSearchContextSize")
        }
        self.taxSearchContextSize = UserDefaults.standard.string(forKey: "taxSearchContextSize") ?? "high"
        
        self.taxSearchRecencyFilter = UserDefaults.standard.string(forKey: "taxSearchRecencyFilter")
        
        // Initialize cached tax rates
        if let data = UserDefaults.standard.data(forKey: "cachedTaxRates"),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.cachedTaxRates = decoded
        } else {
            self.cachedTaxRates = [:]
        }
        
        self.stores = []
        loadStores()
        
        // Now enforce dependency rules for auto-search settings (after all properties are initialized)
        let storedAutoOpenSearch = self.autoOpenSearchAfterPhoto
        let storedAlwaysSearchIgnore = self.alwaysSearchIgnorePrice
        
        // Auto-search features require both AI and Internet to be enabled
        if !self.aiEnabled || !self.internetAccessEnabled {
            // Force disable auto-search features if AI or Internet is disabled
            self.autoOpenSearchAfterPhoto = false
            self.alwaysSearchIgnorePrice = false
        } else if !storedAutoOpenSearch {
            // If auto-open search is disabled, also disable always search ignore price
            self.alwaysSearchIgnorePrice = false
        }
    }
    
    
    func getTaxRatePrompt(itemName: String, location: String?) -> String {
        if let location = location {
            return """
            What is the sales tax for \(itemName) in \(location)? Please respond with the answer in this format: XX3.00XX (3% would be XX3.00XX). Please provide the answer at the end of your analysis, and only once.
            """
        } else {
            return """
            What is the typical sales tax for \(itemName)? Please respond with the answer in this format: XX3.00XX (3% would be XX3.00XX).
            """
        }
    }
    
    
    func resetAllModels() {
        // Tax rate is always sonar-pro, only reset photo model
        selectedModelForPhotoPrice = "gpt-4o-mini"
    }
    
    // MARK: - Store Management
    
    private func saveStores() {
        if let encoded = try? JSONEncoder().encode(stores) {
            UserDefaults.standard.set(encoded, forKey: "stores")
        }
    }
    
    private func loadStores() {
        if let data = UserDefaults.standard.data(forKey: "stores"),
           let decoded = try? JSONDecoder().decode([Store].self, from: data) {
            stores = decoded
        } else {
            // Load default stores if none exist
            stores = Store.defaultStores
        }
    }
    
    func addStore(name: String, url: String) {
        let newStore = Store(name: name, url: url)
        stores.append(newStore)
    }
    
    func deleteStore(at index: Int) {
        guard index < stores.count else { return }
        let deletedStore = stores[index]
        
        // Clear CalculatorView's selected store if it matches the deleted one
        if let savedStoreId = UserDefaults.standard.string(forKey: "calculatorView_selectedStoreId"),
           deletedStore.id.uuidString == savedStoreId {
            UserDefaults.standard.removeObject(forKey: "calculatorView_selectedStoreId")
        }
        
        stores.remove(at: index)
    }
    
    func updateStore(at index: Int, name: String, url: String) {
        stores[index].name = name
        stores[index].url = url
    }
    
    func resetToDefaultStores() {
        // Clear CalculatorView's selected store since we're resetting to defaults
        UserDefaults.standard.removeObject(forKey: "calculatorView_selectedStoreId")
        
        stores = Store.defaultStores
    }
    
    func buildSearchURL(for storeName: String, searchTerm: String) -> String? {
        print("🏢 SettingsService.buildSearchURL: Input storeName='\(storeName)', searchTerm='\(searchTerm)'")
        print("🏢 SettingsService.buildSearchURL: Available stores count = \(stores.count)")
        for (index, store) in stores.enumerated() {
            print("🏢 SettingsService.buildSearchURL: Store[\(index)] = '\(store.name)' -> '\(store.url)'")
        }
        
        // Ensure we have a valid store name and term
        let trimmedStoreName = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🏢 SettingsService.buildSearchURL: Trimmed storeName='\(trimmedStoreName)', trimmed searchTerm='\(trimmedSearchTerm)'")
        
        guard !trimmedStoreName.isEmpty, !trimmedSearchTerm.isEmpty else {
            print("❌ SettingsService.buildSearchURL: Empty storeName or searchTerm")
            return nil
        }
        
        guard let store = stores.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedStoreName }) else {
            print("❌ SettingsService.buildSearchURL: No store found matching '\(trimmedStoreName)'")
            return nil
        }
        
        print("🏢 SettingsService.buildSearchURL: Found matching store: '\(store.name)' -> '\(store.url)'")
        let encodedSearchTerm = trimmedSearchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedSearchTerm
        print("🏢 SettingsService.buildSearchURL: Encoded search term: '\(encodedSearchTerm)'")
        let finalURL = store.url.replacingOccurrences(of: "%s", with: encodedSearchTerm)
        print("🏢 SettingsService.buildSearchURL: Final URL: '\(finalURL)'")
        return finalURL
    }
    
    func setDefaultStore(_ store: Store) {
        defaultStoreId = store.id.uuidString
    }
    
    func getDefaultStore() -> Store? {
        guard let defaultId = defaultStoreId,
              let uuid = UUID(uuidString: defaultId) else {
            return stores.first
        }
        return stores.first(where: { $0.id == uuid }) ?? stores.first
    }
    
    func isDefaultStore(_ store: Store) -> Bool {
        guard let defaultId = defaultStoreId,
              let uuid = UUID(uuidString: defaultId) else {
            return stores.first?.id == store.id
        }
        return store.id.uuidString == defaultId
    }
    
    // MARK: - Credit Management
    
    func updateOpenAICredits(_ credits: Double) {
        print("📝 SettingsService: Updating OpenAI credits from \(openAICredits) to \(credits)")
        openAICredits = credits
        lastSyncDate = Date()
        print("📝 SettingsService: OpenAI credits updated successfully")
    }
    
    func updatePerplexityCredits(_ credits: Double) {
        print("📝 SettingsService: Updating Perplexity credits from \(perplexityCredits) to \(credits)")
        perplexityCredits = credits
        lastSyncDate = Date()
        print("📝 SettingsService: Perplexity credits updated successfully")
    }
    
    func deductOpenAICredits(_ amount: Double) {
        if openAICredits > 0 {
            openAICredits = max(0, openAICredits - amount)
        }
    }
    
    func deductPerplexityCredits(_ amount: Double) {
        if perplexityCredits > 0 {
            perplexityCredits = max(0, perplexityCredits - amount)
        }
    }
    
    func formatCredits(_ credits: Double) -> String {
        if credits < 0 {
            return "Unknown"
        }
        return String(format: "%.2f", credits)
    }
}

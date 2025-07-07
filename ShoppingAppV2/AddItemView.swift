import SwiftUI

struct AddItemView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var costString = ""
    @State private var taxMode: TaxMode = .autoDetect
    @State private var customTaxRateString = "0.00"
    @State private var detectedTaxRate: Double? = nil
    @State private var isDetectingTax = false
    @State private var isAnalyzingAdditives = false
    @State private var isGuessingPrice = false
    @State private var showingPriceGuessAlert = false
    @State private var priceGuessLocation = ""
    @State private var priceGuessBrand = ""
    @State private var priceGuessDetails = ""
    @State private var priceSourceURL: String? = nil
    @State private var showingUnableToDeterminePriceAlert = false
    @State private var riskyAdditives = 0
    @State private var nonRiskyAdditives = 0
    @State private var additiveDetails: [AdditiveInfo] = []
    
    enum TaxMode: String, CaseIterable {
        case autoDetect = "Auto Detect"
        case customValue = "Custom Value"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $costString)
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Tax Mode", selection: $taxMode) {
                            ForEach(TaxMode.allCases, id: \.id) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .disabled(isDetectingTax)
                        
                        if taxMode == .customValue {
                            HStack {
                                TextField("0.00", text: $customTaxRateString)
                                    .keyboardType(.decimalPad)
                                Text("% Tax")
                            }
                        } else if isDetectingTax {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Detecting tax rate...")
                                    .foregroundColor(.secondary)
                            }
                        } else if let detected = detectedTaxRate {
                            HStack {
                                Text("\(detected, specifier: "%.2f")% (Auto-detected)")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                
                if settingsStore.healthTrackingEnabled {
                    Section(header: Text("Health Analysis")) {
                        if isAnalyzingAdditives {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analyzing additives...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text("Risky Additives:")
                                Spacer()
                                Text("\(riskyAdditives)")
                                    .foregroundColor(riskyAdditives > 0 ? .red : .secondary)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Safe Additives:")
                                Spacer()
                                Text("\(nonRiskyAdditives)")
                                    .foregroundColor(nonRiskyAdditives > 0 ? .green : .secondary)
                                    .fontWeight(.medium)
                            }
                            
                            if riskyAdditives == 0 && nonRiskyAdditives == 0 {
                                if name.isEmpty {
                                    Text("Unknown Additives")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                } else {
                                    Button("Analyze Additives") {
                                        analyzeAdditives()
                                    }
                                    .disabled(isAnalyzingAdditives)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    if isGuessingPrice {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Guessing price...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Guess Price") {
                            setupPriceGuess()
                        }
                        .foregroundColor(.purple)
                        .disabled(name.isEmpty || isGuessingPrice)
                        
                        if priceSourceURL != nil {
                            Button("Click here to see price source") {
                                openPriceSource()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Preview")) {
                    HStack {
                        Text("Subtotal:")
                        Spacer()
                        Text("$\(Double(costString) ?? 0, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Tax:")
                        Spacer()
                        let taxRate = getCurrentTaxRate()
                        Text("$\((Double(costString) ?? 0) * taxRate / 100, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Total:")
                            .fontWeight(.bold)
                        Spacer()
                        let taxRate = getCurrentTaxRate()
                        Text("$\((Double(costString) ?? 0) + (Double(costString) ?? 0) * taxRate / 100, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if taxMode == .autoDetect && detectedTaxRate == nil && !name.isEmpty {
                            detectTaxRate()
                        } else {
                            addItem()
                        }
                    }
                    .disabled(costString.isEmpty || isDetectingTax)
                }
            }
            .alert("Guess Price", isPresented: $showingPriceGuessAlert) {
                TextField("Store name (e.g., Walmart, Target)", text: $priceGuessLocation)
                TextField("Brand (e.g., Nike, Apple)", text: $priceGuessBrand)
                TextField("Item details/specifics", text: $priceGuessDetails)
                Button("Cancel", role: .cancel) { }
                Button("Guess") {
                    performPriceGuess()
                }
            } message: {
                Text("Help AI estimate the price for \"\(name)\" by providing optional details. All fields are optional.")
            }
            .alert("Unable to Determine Price", isPresented: $showingUnableToDeterminePriceAlert) {
                Button("OK") { }
            } message: {
                Text("Sorry, we couldn't determine a price for this item. Please try entering a more specific item name or additional details.")
            }
        }
    }
    
    private func getCurrentTaxRate() -> Double {
        switch taxMode {
        case .autoDetect:
            return detectedTaxRate ?? 0.0
        case .customValue:
            return Double(customTaxRateString) ?? 0.0
        }
    }
    
    private func isAmbiguousName(_ name: String) -> Bool {
        let lowercased = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ambiguousNames = ["test", "item", "thing", "product", "unknown", "unknown item"]
        
        // Check if it's a common ambiguous name
        if ambiguousNames.contains(lowercased) {
            return true
        }
        
        // Check if it's mostly numbers
        if lowercased.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
            return true
        }
        
        // Check if it's very short and non-descriptive
        if lowercased.count <= 2 {
            return true
        }
        
        return false
    }
    
    private func detectTaxRate() {
        isDetectingTax = true
        
        let locationString: String? = {
            guard let placemark = locationManager.placemark else { return nil }
            
            var components: [String] = []
            
            if let locality = placemark.locality {
                components.append(locality)
            }
            if let county = placemark.subAdministrativeArea {
                components.append("\(county) County")
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }()
        
        Task {
            do {
                let detectedTaxRate = try await openAIService.analyzeItemForTax(itemName: name, location: locationString)
                
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = detectedTaxRate
                    self.addItem()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = nil
                    self.addItem()
                }
            }
        }
    }
    
    private func addItem() {
        let finalTaxRate = getCurrentTaxRate()
        let hasUnknownTax = (taxMode == .autoDetect && detectedTaxRate == nil)
        let item = ShoppingItem(
            name: name.isEmpty ? "Unnamed Item" : name,
            cost: Double(costString) ?? 0,
            taxRate: finalTaxRate,
            hasUnknownTax: hasUnknownTax,
            riskyAdditives: settingsStore.healthTrackingEnabled ? riskyAdditives : 0,
            nonRiskyAdditives: settingsStore.healthTrackingEnabled ? nonRiskyAdditives : 0,
            additiveDetails: settingsStore.healthTrackingEnabled ? additiveDetails : []
        )
        store.addItem(item)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func analyzeAdditives() {
        guard settingsStore.healthTrackingEnabled && !name.isEmpty else { return }
        
        isAnalyzingAdditives = true
        
        Task {
            do {
                if let result = try await openAIService.analyzeProductForAdditiveCounts(productName: name) {
                    DispatchQueue.main.async {
                        self.riskyAdditives = result.risky
                        self.nonRiskyAdditives = result.safe
                        self.additiveDetails = result.additiveDetails
                        self.isAnalyzingAdditives = false
                    }
                } else {
                    // Fallback to ingredient-based analysis
                    if let ingredients = try await openAIService.analyzeProductForAdditives(productName: name) {
                        let analysis = FoodAdditives.analyzeAdditives(in: ingredients)
                        let details = FoodAdditives.createAdditiveDetails(riskyFound: analysis.riskyFound, nonRiskyFound: analysis.nonRiskyFound)
                        DispatchQueue.main.async {
                            self.riskyAdditives = analysis.risky
                            self.nonRiskyAdditives = analysis.nonRisky
                            self.additiveDetails = details
                            self.isAnalyzingAdditives = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isAnalyzingAdditives = false
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAnalyzingAdditives = false
                    print("Error analyzing product for additives: \(error)")
                }
            }
        }
    }
    
    private func setupPriceGuess() {
        // Clear all fields - user will enter them
        priceGuessLocation = ""
        priceGuessBrand = ""
        priceGuessDetails = ""
        priceSourceURL = nil
        showingPriceGuessAlert = true
    }
    
    private func performPriceGuess() {
        guard !name.isEmpty else { return }
        
        print("🎯 AddItemView: Starting price guess for '\(name)'")
        isGuessingPrice = true
        
        // Get actual location for the AI
        let actualLocationString: String? = {
            guard let placemark = locationManager.placemark else { return nil }
            
            var components: [String] = []
            
            if let locality = placemark.locality {
                components.append(locality)
            }
            if let county = placemark.subAdministrativeArea {
                components.append("\(county) County")
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }()
        
        Task {
            do {
                let storeName = priceGuessLocation.isEmpty ? nil : priceGuessLocation
                let brand = priceGuessBrand.isEmpty ? nil : priceGuessBrand
                let details = priceGuessDetails.isEmpty ? nil : priceGuessDetails
                
                let result = try await openAIService.guessPrice(
                    itemName: name,
                    location: actualLocationString,
                    storeName: storeName,
                    brand: brand,
                    additionalDetails: details
                )
                
                DispatchQueue.main.async {
                    if let estimatedPrice = result.price {
                        print("✅ AddItemView: Price updated to \(estimatedPrice)")
                        self.costString = String(format: "%.2f", estimatedPrice)
                        self.priceSourceURL = result.sourceURL
                    } else {
                        print("❌ AddItemView: No price returned from API")
                        self.showingUnableToDeterminePriceAlert = true
                    }
                    self.isGuessingPrice = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGuessingPrice = false
                    print("Error guessing price: \(error)")
                }
            }
        }
    }
    
    private func openPriceSource() {
        guard let urlString = priceSourceURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
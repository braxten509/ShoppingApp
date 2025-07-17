import SwiftUI

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

struct VerifyItemView: View {
    let extractedInfo: PriceTagInfo
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var aiService: AIService
    @Environment(\.presentationMode) var presentationMode
    let onRetakePhoto: (() -> Void)?
    let originalImage: UIImage?
    let locationString: String?
    
    @State private var name: String
    @State private var costString: String
    @State private var taxRateString: String
    @State private var hasUnknownTax: Bool
    @State private var taxDescription: String?
    @State private var isAnalyzingAdditives = false
    @State private var isRetryingAnalysis = false
    @State private var isForcingTaxCalculation = false
    @State private var isGuessingPrice = false
    @State private var showingPriceGuessAlert = false
    @State private var priceGuessLocation = ""
    @State private var priceGuessBrand = ""
    @State private var priceGuessDetails = ""
    @State private var priceSourceURL: String? = nil
    @State private var showingUnableToDeterminePriceAlert = false
    @State private var retryCounter = 0
    @State private var riskyAdditives = 0
    @State private var nonRiskyAdditives = 0
    @State private var additiveDetails: [AdditiveInfo] = []
    
    init(extractedInfo: PriceTagInfo, store: ShoppingListStore, settingsStore: SettingsStore, aiService: AIService, onRetakePhoto: (() -> Void)? = nil, originalImage: UIImage? = nil, locationString: String? = nil) {
        self.extractedInfo = extractedInfo
        self.store = store
        self.settingsStore = settingsStore
        self.aiService = aiService
        self.onRetakePhoto = onRetakePhoto
        self.originalImage = originalImage
        self.locationString = locationString
        self._name = State(initialValue: extractedInfo.name)
        self._costString = State(initialValue: String(format: "%.2f", extractedInfo.price))
        self._taxRateString = State(initialValue: String(format: "%.2f", extractedInfo.taxRate ?? 0.0))
        self._hasUnknownTax = State(initialValue: extractedInfo.taxDescription == "Unknown Taxes" || extractedInfo.taxRate == nil)
        self._taxDescription = State(initialValue: extractedInfo.taxDescription)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Verify Scanned Information")) {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $costString)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        TextField("0.00", text: $taxRateString)
                            .keyboardType(.decimalPad)
                        Text("% Tax")
                    }
                    
                    if let taxDesc = taxDescription {
                        HStack {
                            Text("Tax Info:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(taxDesc)
                                .foregroundColor(.secondary)
                                .font(.caption)
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
                                Text("Unknown Additives")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    if let originalImage = originalImage {
                        if isRetryingAnalysis {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .id("retry-progress-\(retryCounter)")
                                Text("Retrying analysis...")
                                    .foregroundColor(.secondary)
                            }
                            .id("retry-loading-\(retryCounter)")
                        } else {
                            Button("Retry Analysis") {
                                Task { @MainActor in
                                    retryCounter += 1
                                    isRetryingAnalysis = true
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    await retryAnalysis(with: originalImage)
                                }
                            }
                            .foregroundColor(.blue)
                            .disabled(isRetryingAnalysis)
                        }
                    }
                    
                    // Force Tax Calculation button - shows when tax is unknown
                    if hasUnknownTax {
                        if isForcingTaxCalculation {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Calculating tax...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("Force Tax Calculation") {
                                Task { @MainActor in
                                    await forceTaxCalculation()
                                }
                            }
                            .foregroundColor(.green)
                            .disabled(isForcingTaxCalculation || name.isEmpty)
                        }
                    }
                    
                    // Guess Price button
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
                    
                    if let onRetakePhoto = onRetakePhoto {
                        Button("Retry & Take New Photo") {
                            onRetakePhoto()
                        }
                        .foregroundColor(.orange)
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
                        Text("$\((Double(costString) ?? 0) * (Double(taxRateString) ?? 0) / 100, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Total:")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\((Double(costString) ?? 0) + (Double(costString) ?? 0) * (Double(taxRateString) ?? 0) / 100, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Verify Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Item") {
                        let item = ShoppingItem(
                            name: name.isEmpty ? "Unnamed Item" : name,
                            cost: Double(costString) ?? 0,
                            taxRate: Double(taxRateString) ?? 0,
                            hasUnknownTax: hasUnknownTax,
                            riskyAdditives: settingsStore.healthTrackingEnabled ? riskyAdditives : 0,
                            nonRiskyAdditives: settingsStore.healthTrackingEnabled ? nonRiskyAdditives : 0,
                            additiveDetails: settingsStore.healthTrackingEnabled ? additiveDetails : []
                        )
                        store.addItem(item)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if settingsStore.healthTrackingEnabled {
                    analyzeAdditives()
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
    
    private func analyzeAdditives() {
        guard settingsStore.healthTrackingEnabled else { return }
        
        // First check if we have ingredients from the image
        if let ingredients = extractedInfo.ingredients, !ingredients.isEmpty {
            let analysis = FoodAdditives.analyzeAdditives(in: ingredients)
            let details = FoodAdditives.createAdditiveDetails(riskyFound: analysis.riskyFound, nonRiskyFound: analysis.nonRiskyFound)
            self.riskyAdditives = analysis.risky
            self.nonRiskyAdditives = analysis.nonRisky
            self.additiveDetails = details
        } else {
            // No ingredients found in image, try to analyze product name
            isAnalyzingAdditives = true
            
            Task {
                do {
                    if let result = try await aiService.analyzeProductForAdditives(productName: name) {
                        DispatchQueue.main.async {
                            self.riskyAdditives = result.risky
                            self.nonRiskyAdditives = result.safe
                            self.additiveDetails = result.additiveDetails
                            self.isAnalyzingAdditives = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isAnalyzingAdditives = false
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
    }
    
    @MainActor
    private func retryAnalysis(with image: UIImage) async {
        do {
            let newInfo = try await aiService.analyzePriceTag(image: image, location: locationString)
            
            self.name = newInfo.name
            self.costString = String(format: "%.2f", newInfo.price)
            self.taxRateString = String(format: "%.2f", newInfo.taxRate ?? 0.0)
            self.hasUnknownTax = newInfo.taxDescription == "Unknown Taxes" || newInfo.taxRate == nil
            self.taxDescription = newInfo.taxDescription
            self.isRetryingAnalysis = false
            
            // Re-analyze additives with the new name if health tracking is enabled
            if settingsStore.healthTrackingEnabled && name != extractedInfo.name {
                analyzeAdditives()
            }
        } catch {
            self.isRetryingAnalysis = false
            print("Error retrying analysis: \(error)")
        }
    }
    
    @MainActor
    private func forceTaxCalculation() async {
        guard !name.isEmpty else { return }
        
        isForcingTaxCalculation = true
        
        do {
            // Call the tax analysis with the current name and location
            if let detectedTaxRate = try await aiService.analyzeItemForTax(itemName: name, location: locationString) {
                self.taxRateString = String(format: "%.2f", detectedTaxRate)
                self.hasUnknownTax = false
                self.taxDescription = locationString != nil ? "\(detectedTaxRate)% (Auto-detected)" : "\(detectedTaxRate)% (Default rate)"
            } else {
                // Tax rate still couldn't be determined
                self.hasUnknownTax = true
                self.taxDescription = "Unknown Taxes"
            }
            
            isForcingTaxCalculation = false
        } catch {
            isForcingTaxCalculation = false
            print("Error forcing tax calculation: \(error)")
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
        
        isGuessingPrice = true
        
        Task {
            do {
                let storeName = priceGuessLocation.isEmpty ? nil : priceGuessLocation
                let brand = priceGuessBrand.isEmpty ? nil : priceGuessBrand
                let details = priceGuessDetails.isEmpty ? nil : priceGuessDetails
                
                let result = try await aiService.guessPrice(
                    itemName: name,
                    location: locationString,
                    storeName: storeName,
                    brand: brand,
                    additionalDetails: details
                )
                
                DispatchQueue.main.async {
                    if let estimatedPrice = result.price {
                        self.costString = String(format: "%.2f", estimatedPrice)
                        self.priceSourceURL = result.sourceURL
                    } else {
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
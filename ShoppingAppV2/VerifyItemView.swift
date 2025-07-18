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
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    let onRetakePhoto: (() -> Void)?
    let originalImage: UIImage?
    let locationString: String?
    
    @State private var name: String
    @State private var costString: String
    @State private var taxMode: TaxMode = .defaultMode
    @State private var customTaxRateString: String
    @State private var detectedTaxRate: Double? = nil
    @State private var hasUnknownTax: Bool
    @State private var taxDescription: String?
    @State private var isAnalyzingAdditives = false
    @State private var isRetryingAnalysis = false
    @State private var isDetectingTax = false
    @State private var showingPriceSearchAlert = false
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = "Broulim's"
    @State private var priceSourceURL: String? = nil
    @State private var showingPriceSearchWebView = false
    @State private var webViewSelectedPrice: Double? = nil
    @State private var webViewSelectedItemName: String? = nil
    @State private var retryCounter = 0
    @State private var riskyAdditives = 0
    @State private var nonRiskyAdditives = 0
    @State private var additiveDetails: [AdditiveInfo] = []
    @State private var dynamicAnalysisIssues: [String] = []
    
    
    enum TaxMode: String, CaseIterable {
        case defaultMode = "Default"
        case ai = "AI"
        case customValue = "Custom"
        
        var id: String { self.rawValue }
    }

    init(extractedInfo: PriceTagInfo, store: ShoppingListStore, settingsStore: SettingsStore, aiService: AIService, settingsService: SettingsService, onRetakePhoto: (() -> Void)? = nil, originalImage: UIImage? = nil, locationString: String? = nil) {
        self.extractedInfo = extractedInfo
        self.store = store
        self.settingsStore = settingsStore
        self.aiService = aiService
        self.settingsService = settingsService
        self.onRetakePhoto = onRetakePhoto
        self.originalImage = originalImage
        self.locationString = locationString
        self._name = State(initialValue: extractedInfo.name)
        self._costString = State(initialValue: String(format: "%.2f", extractedInfo.price))
        self._customTaxRateString = State(initialValue: String(format: "%.2f", extractedInfo.taxRate ?? 0.0))
        self._hasUnknownTax = State(initialValue: extractedInfo.taxDescription == "Unknown Taxes" || extractedInfo.taxRate == nil)
        self._taxDescription = State(initialValue: extractedInfo.taxDescription)
        self._dynamicAnalysisIssues = State(initialValue: extractedInfo.analysisIssues ?? [])
        
        // Initialize detected tax rate if available from extracted info
        if let extractedTaxRate = extractedInfo.taxRate {
            self._detectedTaxRate = State(initialValue: extractedTaxRate)
        }
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Tax Mode", selection: $taxMode) {
                            ForEach(TaxMode.allCases, id: \.id) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .disabled(isDetectingTax)
                        
                        taxModeView
                    }
                }
                
                // Display analysis issues if any
                if !dynamicAnalysisIssues.isEmpty {
                    Section(header: Text("Analysis Notes")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(dynamicAnalysisIssues, id: \.self) { issue in
                                HStack(alignment: .top) {
                                    Image(systemName: issue.contains("succeeded") ? "checkmark.circle" : "exclamationmark.triangle")
                                        .foregroundColor(issue.contains("succeeded") ? .green : .orange)
                                        .font(.caption)
                                        .padding(.top, 2)
                                    
                                    Text(issue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.vertical, 4)
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
                    
                    
                    // Search Price button
                    Button("Search Price") {
                        setupPriceSearch()
                    }
                    .foregroundColor(.purple)
                    .disabled(name.isEmpty)
                    
                    if priceSourceURL != nil {
                        Button("Click here to see price source") {
                            openPriceSource()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
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
                        if shouldDetectTaxRate() {
                            detectTaxRate()
                        } else {
                            addItem()
                        }
                    }
                    .disabled(costString.isEmpty || isDetectingTax)
                }
            }
            .onAppear {
                if settingsStore.healthTrackingEnabled {
                    analyzeAdditives()
                }
            }
.sheet(isPresented: $showingPriceSearchAlert) {
                NavigationView {
                    Form {
                        Section(header: Text("Search Details")) {
                            TextField("Item Name", text: .constant(name))
                                .disabled(true)
                                .foregroundColor(.secondary)
                            
                            TextField("Size/Weight/Count (e.g., 12 oz, 6-pack)", text: $priceSearchSpecification)
                            
                            Picker("Website", selection: $selectedWebsite) {
                                Text("Broulim's").tag("Broulim's")
                                Text("Walmart").tag("Walmart")
                                Text("Target").tag("Target")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    .navigationTitle("Search Price")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingPriceSearchAlert = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Search") {
                                showingPriceSearchAlert = false
                                showingPriceSearchWebView = true
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingPriceSearchWebView) {
                PriceSearchView(
                    itemName: name,
                    specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                    website: selectedWebsite,
                    selectedPrice: $webViewSelectedPrice,
                    selectedItemName: $webViewSelectedItemName
                )
            }
            .onChange(of: webViewSelectedPrice) { price in
                if let price = price {
                    // Dismiss the web view first
                    showingPriceSearchWebView = false
                    
                    // Then update the price
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        costString = String(format: "%.2f", price)
                        
                        // Build the source URL for reference
                        let searchTerm = priceSearchSpecification.isEmpty ? name : "\(name) \(priceSearchSpecification)"
                        let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
                        
                        switch selectedWebsite {
                        case "Broulim's":
                            priceSourceURL = "https://shop.rosieapp.com/broulims_rexburg/search/\(encodedSearchTerm)"
                        case "Walmart":
                            priceSourceURL = "https://www.walmart.com/search?q=\(encodedSearchTerm)"
                        case "Target":
                            priceSourceURL = "https://www.target.com/s?searchTerm=\(encodedSearchTerm)"
                        default:
                            priceSourceURL = nil
                        }
                        
                        // Update analysis issues
                        dynamicAnalysisIssues.removeAll { $0.contains("price search") }
                        let issueText = "Price search succeeded - selected \(webViewSelectedItemName ?? "item") at $\(String(format: "%.2f", price)) from \(selectedWebsite)"
                        dynamicAnalysisIssues.append(issueText)
                        
                        // Reset for next search
                        webViewSelectedPrice = nil
                        webViewSelectedItemName = nil
                    }
                }
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
            self.customTaxRateString = String(format: "%.2f", newInfo.taxRate ?? 0.0)
            self.detectedTaxRate = newInfo.taxRate
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
    
    private func getCurrentTaxRate() -> Double {
        switch taxMode {
        case .defaultMode:
            if settingsService.useManualTaxRate {
                return settingsService.manualTaxRate
            } else {
                return detectedTaxRate ?? 0.0
            }
        case .ai:
            return detectedTaxRate ?? 0.0
        case .customValue:
            return Double(customTaxRateString) ?? 0.0
        }
    }
    
    private func detectTaxRate() {
        isDetectingTax = true
        
        Task {
            do {
                let detectedTaxRate = try await aiService.analyzeItemForTax(itemName: name, location: locationString)
                
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = detectedTaxRate
                    self.addItem()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = nil
                    self.addItem() // Still proceed with adding the item
                }
            }
        }
    }
    
    private func shouldDetectTaxRate() -> Bool {
        switch taxMode {
        case .defaultMode:
            return !settingsService.useManualTaxRate && detectedTaxRate == nil && !name.isEmpty
        case .ai:
            return detectedTaxRate == nil && !name.isEmpty
        case .customValue:
            return false
        }
    }
    
    private func addItem() {
        let finalTaxRate = getCurrentTaxRate()
        let hasUnknownTax: Bool = {
            switch taxMode {
            case .defaultMode:
                return !settingsService.useManualTaxRate && detectedTaxRate == nil
            case .ai:
                return detectedTaxRate == nil
            case .customValue:
                return false
            }
        }()
        
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
    
    private func setupPriceSearch() {
        priceSearchSpecification = ""
        priceSourceURL = nil
        showingPriceSearchAlert = true
    }
    
    
    private func openPriceSource() {
        guard let urlString = priceSourceURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    @ViewBuilder
    private var taxModeView: some View {
        if taxMode == .customValue {
            HStack {
                TextField("0.00", text: $customTaxRateString)
                    .keyboardType(.decimalPad)
                Text("% Tax")
            }
        } else if taxMode == .defaultMode {
            if settingsService.useManualTaxRate {
                HStack {
                    Text("\(settingsService.manualTaxRate, specifier: "%.2f")% (Manual Setting)")
                        .foregroundColor(.secondary)
                    Spacer()
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
                    Text("\(detected, specifier: "%.2f")% (AI-detected)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let taxDesc = taxDescription {
                HStack {
                    Text("Tax Info:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taxDesc)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } else if taxMode == .ai {
            if isDetectingTax {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting tax rate...")
                        .foregroundColor(.secondary)
                }
            } else if let detected = detectedTaxRate {
                HStack {
                    Text("\(detected, specifier: "%.2f")% (AI-detected)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let taxDesc = taxDescription {
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
    }
}
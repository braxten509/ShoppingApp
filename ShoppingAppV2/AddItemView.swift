import SwiftUI

struct AddItemView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var aiService: AIService
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var costString = ""
    @State private var taxMode: TaxMode = .defaultMode
    @State private var customTaxRateString = "0.00"
    @State private var detectedTaxRate: Double? = nil
    @State private var isDetectingTax = false
    @State private var isAnalyzingAdditives = false
    @State private var showingPriceSearchAlert = false
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = "Broulim's"
    @State private var priceSourceURL: String? = nil
    @State private var showingPriceSearchWebView = false
    @State private var webViewSelectedPrice: Double? = nil
    @State private var webViewSelectedItemName: String? = nil
    @State private var showingTaxErrorAlert = false
    @State private var showingAdditiveErrorAlert = false
    @State private var showingPriceErrorAlert = false
    @State private var currentErrorMessage = ""
    @State private var riskyAdditives = 0
    @State private var nonRiskyAdditives = 0
    @State private var additiveDetails: [AdditiveInfo] = []
    
    enum TaxMode: String, CaseIterable {
        case defaultMode = "Default"
        case ai = "AI"
        case customValue = "Custom"
        
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
                        
                        taxModeView
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
                    // Calculate taxes button - shows when AI tax detection is enabled
                    if shouldDetectTaxRate() && !isDetectingTax {
                        Button("Calculate Taxes") {
                            detectTaxRate(andAddItem: false)
                        }
                        .foregroundColor(.green)
                        .disabled(name.isEmpty)
                    } else if isDetectingTax {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Calculating taxes...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
                        if shouldDetectTaxRate() {
                            detectTaxRate()
                        } else {
                            addItem()
                        }
                    }
                    .disabled(costString.isEmpty || isDetectingTax)
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
                        
                        // Reset for next search
                        webViewSelectedPrice = nil
                        webViewSelectedItemName = nil
                    }
                }
            }
            .alert("Tax Rate Error", isPresented: $showingTaxErrorAlert) {
                Button("OK") { 
                    addItem() // Still proceed with adding the item
                }
            } message: {
                Text(currentErrorMessage)
            }
            .alert("Additive Analysis Error", isPresented: $showingAdditiveErrorAlert) {
                Button("OK") { }
            } message: {
                Text(currentErrorMessage)
            }
            .alert("Price Guess Error", isPresented: $showingPriceErrorAlert) {
                Button("OK") { }
            } message: {
                Text(currentErrorMessage)
            }
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
    
    private func detectTaxRate(andAddItem: Bool = true) {
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
                let detectedTaxRate = try await aiService.analyzeItemForTax(itemName: name, location: locationString)
                
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = detectedTaxRate
                    if andAddItem {
                        self.addItem()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.detectedTaxRate = nil
                    self.currentErrorMessage = error.localizedDescription
                    self.showingTaxErrorAlert = true
                    if andAddItem {
                        // Still proceed with adding the item even if tax detection failed
                        self.addItem()
                    }
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
    
    private func analyzeAdditives() {
        guard settingsStore.healthTrackingEnabled && !name.isEmpty else { return }
        
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
                    self.currentErrorMessage = error.localizedDescription
                    self.showingAdditiveErrorAlert = true
                }
            }
        }
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
            }
        }
    }
}
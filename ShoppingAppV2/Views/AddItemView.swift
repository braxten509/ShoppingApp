import SwiftUI

struct AddItemView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var aiService: AIService
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    
    // Optional prefill parameters
    let prefillName: String?
    let prefillPrice: Double?
    
    @State private var name = ""
    @State private var costString = ""
    @State private var taxMode: TaxMode = .defaultMode
    @State private var customTaxRateString = "0.00"
    @State private var detectedTaxRate: Double? = nil
    @State private var isDetectingTax = false
    @State private var isAnalyzingAdditives = false
    @State private var showingPriceSearchAlert = false
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = ""
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
    @State private var isPriceByMeasurement = false
    @State private var measurementQuantity = 1.0
    @State private var measurementQuantityString = "1.0"
    @State private var selectedMeasurementUnit = MeasurementUnit.units
    
    // Initializer to support prefilled data
    init(store: ShoppingListStore, locationManager: LocationManager, aiService: AIService, settingsService: SettingsService, prefillName: String? = nil, prefillPrice: Double? = nil) {
        self.store = store
        self.locationManager = locationManager
        self.aiService = aiService
        self.settingsService = settingsService
        self.prefillName = prefillName
        self.prefillPrice = prefillPrice
    }
    
    enum TaxMode: String, CaseIterable {
        case defaultMode = "Default"
        case ai = "AI"
        case customValue = "Custom"
        
        var id: String { self.rawValue }
    }
    
    private var actualCost: Double {
        let baseCost = Double(costString) ?? 0
        if isPriceByMeasurement {
            return baseCost * measurementQuantity
        }
        return baseCost
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
                        
                        Button(action: {
                            setupPriceSearch()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.purple)
                        }
                        .disabled(name.isEmpty)
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
                
                Section(header: Text("Price by Measurement")) {
                    Toggle("Price by Measurement", isOn: $isPriceByMeasurement)
                    
                    if isPriceByMeasurement {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Base price is per unit of measurement")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Quantity", text: $measurementQuantityString)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                
                                Picker("Unit", selection: $selectedMeasurementUnit) {
                                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            if let cost = Double(costString), let quantity = Double(measurementQuantityString) {
                                Text("Total: $\(cost * quantity, specifier: "%.2f") ($\(cost, specifier: "%.2f") per \(selectedMeasurementUnit.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.green)
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
                        Text("$\(actualCost, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Tax:")
                        Spacer()
                        let taxRate = getCurrentTaxRate()
                        Text("$\(actualCost * taxRate / 100, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Total:")
                            .fontWeight(.bold)
                        Spacer()
                        let taxRate = getCurrentTaxRate()
                        Text("$\(actualCost + actualCost * taxRate / 100, specifier: "%.2f")")
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
                                ForEach(settingsService.stores, id: \.id) { store in
                                    Text(store.name).tag(store.name)
                                }
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
                    selectedItemName: $webViewSelectedItemName,
                    settingsService: settingsService
                )
            }
            .onChange(of: webViewSelectedPrice) { _, price in
                if let price = price {
                    // Dismiss the web view first
                    showingPriceSearchWebView = false
                    
                    // Then update the price
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        costString = String(format: "%.2f", price)
                        
                        // Build the source URL for reference
                        let searchTerm = priceSearchSpecification.isEmpty ? name : "\(name) \(priceSearchSpecification)"
                        priceSourceURL = settingsService.buildSearchURL(for: selectedWebsite, searchTerm: searchTerm)
                        
                        // Reset for next search
                        webViewSelectedPrice = nil
                        webViewSelectedItemName = nil
                    }
                }
            }
            .onChange(of: measurementQuantityString) { _, newValue in
                measurementQuantity = Double(newValue) ?? 1.0
            }
            .onAppear {
                if selectedWebsite.isEmpty && !settingsService.stores.isEmpty {
                    if let defaultStore = settingsService.getDefaultStore() {
                        selectedWebsite = defaultStore.name
                    } else {
                        selectedWebsite = settingsService.stores.first!.name
                    }
                }
                
                // Apply prefilled data if available
                if let prefillName = prefillName, !prefillName.isEmpty {
                    name = prefillName
                }
                if let prefillPrice = prefillPrice {
                    costString = String(format: "%.2f", prefillPrice)
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
                // If AI detection failed, return 0 and mark as unknown tax
                return detectedTaxRate ?? 0.0
            }
        case .ai:
            // If AI detection failed, return 0 and mark as unknown tax
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
        
        // Update measurement quantity from string
        measurementQuantity = Double(measurementQuantityString) ?? 1.0
        
        let item = ShoppingItem(
            name: name.isEmpty ? "Unnamed Item" : name,
            cost: Double(costString) ?? 0,
            taxRate: finalTaxRate,
            hasUnknownTax: hasUnknownTax,
            riskyAdditives: riskyAdditives,
            nonRiskyAdditives: nonRiskyAdditives,
            additiveDetails: additiveDetails,
            isPriceByMeasurement: isPriceByMeasurement,
            measurementQuantity: measurementQuantity,
            measurementUnit: selectedMeasurementUnit.rawValue
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

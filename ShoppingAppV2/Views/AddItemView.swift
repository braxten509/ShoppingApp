import SwiftUI

struct AddItemView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var aiService: AIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    @Environment(\.presentationMode) var presentationMode
    
    // Optional prefill parameters
    let prefillName: String?
    let prefillPrice: Double?
    let selectedStore: Store?
    
    @State private var name: String
    @State private var costString: String
    @State private var taxMode: TaxMode
    @State private var customTaxRateString = "0.00"
    @State private var detectedTaxRate: Double? = nil
    @State private var isDetectingTax = false
    @State private var taxDetectionProgress = (current: 0, total: 0)
    @State private var showingPriceSearchAlert = false
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = ""
    @State private var priceSourceURL: String? = nil
    @State private var showingPriceSearchWebView = false
    @State private var webViewSelectedPrice: Double? = nil
    @State private var webViewSelectedItemName: String? = nil
    @State private var showingTaxErrorAlert = false
    @State private var showingPriceErrorAlert = false
    @State private var currentErrorMessage = ""
    @State private var isPriceByMeasurement = false
    @State private var measurementQuantity = 1.0
    @State private var measurementQuantityString = "1.0"
    @State private var selectedMeasurementUnit = MeasurementUnit.units
    @State private var showingCustomPriceSearch = false
    
    // Initializer to support prefilled data
    init(store: ShoppingListStore, locationManager: LocationManager, aiService: AIService, settingsService: SettingsService, customPriceListStore: CustomPriceListStore, prefillName: String? = nil, prefillPrice: Double? = nil, selectedStore: Store? = nil) {
        print("🏗️ AddItemView init called with prefillName: '\(prefillName ?? "nil")', prefillPrice: \(prefillPrice?.description ?? "nil")")
        self.store = store
        self.locationManager = locationManager
        self.aiService = aiService
        self.settingsService = settingsService
        self.customPriceListStore = customPriceListStore
        self.prefillName = prefillName
        self.prefillPrice = prefillPrice
        self.selectedStore = selectedStore
        
        // Initialize @State variables with prefill values
        self._name = State(initialValue: prefillName ?? "")
        self._costString = State(initialValue: prefillPrice != nil ? String(format: "%.2f", prefillPrice!) : "")
        
        // Set initial tax mode based on settings
        let initialTaxMode: TaxMode = settingsService.useManualTaxRate ? .defaultMode : .ai
        self._taxMode = State(initialValue: initialTaxMode)
        
        // Initialize selectedWebsite properly to avoid empty string issues
        let websiteToUse: String
        if let selectedStore = selectedStore {
            websiteToUse = selectedStore.name
        } else if let defaultStore = settingsService.getDefaultStore() {
            websiteToUse = defaultStore.name
        } else {
            websiteToUse = settingsService.stores.first?.name ?? ""
        }
        self._selectedWebsite = State(initialValue: websiteToUse)
        
        print("🏗️ Initialized name: '\(prefillName ?? "")', costString: '\(prefillPrice != nil ? String(format: "%.2f", prefillPrice!) : "")', selectedWebsite: '\(websiteToUse)'")
    }
    
    enum TaxMode: String, CaseIterable {
        case defaultMode = "Manual"
        case ai = "AI"
        case customValue = "Custom"
        
        var id: String { self.rawValue }
    }
    
    private var availableTaxModes: [TaxMode] {
        if settingsService.aiEnabled && settingsService.internetAccessEnabled {
            return TaxMode.allCases
        } else {
            return TaxMode.allCases.filter { $0 != .ai }
        }
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
            formContent
                .navigationTitle("Add Item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarItems
                }
                .sheet(isPresented: $showingPriceSearchAlert) {
                    priceSearchSheet
                }
                .fullScreenCover(isPresented: $showingPriceSearchWebView) {
                    priceSearchWebView
                }
                .sheet(isPresented: $showingCustomPriceSearch) {
                    let _ = print("🔍 AddItemView: Opening CustomPriceSearch - selectedStore: \(selectedStore?.name ?? "None"), always searching ALL lists")
                    
                    CustomPriceSearchView(
                        customPriceListStore: customPriceListStore,
                        onItemSelected: { item, list in
                            costString = String(format: "%.2f", item.price)
                            // Use the new setting to determine whether to replace the item name
                            if name.isEmpty || settingsService.replaceItemNameFromPriceList {
                                name = item.name
                            }
                            showingCustomPriceSearch = false
                        },
                        initialSearchText: name,
                        searchAllLists: true, // Always search all lists in manual/photo add context
                        selectedListId: nil
                    )
                }
                .onChange(of: webViewSelectedPrice) { _, price in
                    handlePriceSelection(price)
                }
                .onChange(of: measurementQuantityString) { _, newValue in
                    measurementQuantity = Double(newValue) ?? 1.0
                }
                .onAppear {
                    setupInitialValues()
                }
                .alert("Tax Rate Error", isPresented: $showingTaxErrorAlert) {
                    Button("OK") { 
                        addItem()
                    }
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
    
    @ViewBuilder
    private var formContent: some View {
        Form {
            itemDetailsSection
            measurementSection
            actionsSection
            previewSection
        }
    }
    
    @ViewBuilder
    private var itemDetailsSection: some View {
        Section(header: Text("Item Details")) {
            TextField("Item Name", text: $name)
            
            priceInputRow
            
            taxModeSection
        }
    }
    
    @ViewBuilder
    private var priceInputRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text("$")
                TextField("0.00", text: $costString)
                    .keyboardType(.decimalPad)
            }
            
            HStack(spacing: 20) {
                // Web search button
                Button(action: {
                    setupPriceSearch()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Search Price")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor((name.isEmpty || !settingsService.internetAccessEnabled) ? .gray : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((name.isEmpty || !settingsService.internetAccessEnabled) ? Color.gray.opacity(0.3) : Color.purple)
                    .cornerRadius(8)
                }
                .disabled(name.isEmpty || !settingsService.internetAccessEnabled)
                .buttonStyle(PlainButtonStyle())
                
                // Custom price search button
                Button(action: {
                    showingCustomPriceSearch = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Search Price List")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCustomPriceSearchDisabled ? .gray : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCustomPriceSearchDisabled ? Color.gray.opacity(0.3) : Color.orange)
                    .cornerRadius(8)
                }
                .disabled(isCustomPriceSearchDisabled)
                .buttonStyle(PlainButtonStyle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var taxModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Tax Mode", selection: $taxMode) {
                ForEach(availableTaxModes, id: \.id) { mode in
                    Text(mode.rawValue)
                        .foregroundColor(mode == .ai && !settingsService.aiEnabled ? .secondary : .primary)
                        .tag(mode)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(isDetectingTax)
            
            taxModeView
        }
    }
    
    @ViewBuilder
    private var measurementSection: some View {
        Section(header: Text("Price by Measurement")) {
            Toggle("Price by Measurement", isOn: $isPriceByMeasurement)
            
            if isPriceByMeasurement {
                measurementDetails
            }
        }
    }
    
    @ViewBuilder
    private var measurementDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Base price is per unit of measurement")
                .font(.caption)
                .foregroundColor(.secondary)
            
            measurementInputRow
            
            measurementTotal
        }
    }
    
    @ViewBuilder
    private var measurementInputRow: some View {
        HStack {
            TextField("Quantity", text: $measurementQuantityString)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 80)
            
            Text(selectedMeasurementUnit.displayText(for: Double(measurementQuantityString) ?? 1.0))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Picker("", selection: $selectedMeasurementUnit) {
                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .labelsHidden()
        }
    }
    
    @ViewBuilder
    private var measurementTotal: some View {
        if let cost = Double(costString), let quantity = Double(measurementQuantityString) {
            let totalCost = cost * quantity
            let taxRate = getCurrentTaxRate()
            // Fix: Use proper rounding for tax calculation
            let taxAmount = round(totalCost * taxRate) / 100.0
            let totalWithTax = totalCost + taxAmount
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Total: $\(String(format: "%.2f", totalCost)) ($\(String(format: "%.2f", cost)) per \(selectedMeasurementUnit.singularForm))")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("With Tax: $\(String(format: "%.2f", totalWithTax))")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var actionsSection: some View {
        Section(header: Text("Actions")) {
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
                    if settingsService.useMultiAttemptTaxDetection && taxDetectionProgress.total > 0 {
                        Text("Calculating taxes... (\(taxDetectionProgress.current)/\(taxDetectionProgress.total))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Calculating taxes...")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var previewSection: some View {
        Section(header: Text("Preview")) {
            subtotalRow
            taxRow
            totalRow
        }
    }
    
    @ViewBuilder
    private var subtotalRow: some View {
        HStack {
            Text("Subtotal:")
            Spacer()
            Text("$\(actualCost, specifier: "%.2f")")
        }
    }
    
    @ViewBuilder
    private var taxRow: some View {
        HStack {
            Text("Tax:")
            Spacer()
            let taxRate = getCurrentTaxRate()
            // Fix: Use proper rounding for currency calculation
            let taxAmount = round(actualCost * taxRate) / 100.0
            Text("$\(taxAmount, specifier: "%.2f")")
        }
    }

    @ViewBuilder
    private var totalRow: some View {
        HStack {
            Text("Total:")
                .fontWeight(.bold)
            Spacer()
            let taxRate = getCurrentTaxRate()
            // Fix: Use proper rounding for currency calculation
            let taxAmount = round(actualCost * taxRate) / 100.0
            let totalAmount = actualCost + taxAmount
            Text("$\(totalAmount, specifier: "%.2f")")
                .fontWeight(.bold)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
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
        
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                UIApplication.shared.endEditing()
            }
        }
    }
    
    @ViewBuilder
    private var priceSearchSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Search Details")) {
                    TextField("Item Name", text: .constant(name))
                        .disabled(true)
                        .foregroundColor(.secondary)
                    
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
    
    private var isCustomPriceSearchDisabled: Bool {
        // Allow search when setting is enabled even if name is empty, otherwise require name
        if settingsService.replaceItemNameFromPriceList {
            return !customPriceListStore.hasLists
        } else {
            return name.isEmpty || !customPriceListStore.hasLists
        }
    }
    
    private var priceSearchWebView: some View {
        PriceSearchView(
            itemName: name,
            specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
            website: selectedWebsite,
            selectedPrice: $webViewSelectedPrice,
            selectedItemName: $webViewSelectedItemName,
            settingsService: settingsService
        )
    }
    
    private func handlePriceSelection(_ price: Double?) {
        guard let price = price else { return }
        
        showingPriceSearchWebView = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            costString = String(format: "%.2f", price)
            
            let searchTerm = priceSearchSpecification.isEmpty ? name : "\(name) \(priceSearchSpecification)"
            priceSourceURL = settingsService.buildSearchURL(for: selectedWebsite, searchTerm: searchTerm)
            
            webViewSelectedPrice = nil
            webViewSelectedItemName = nil
        }
    }
    
    private func setupInitialValues() {
        print("📋 AddItemView setupInitialValues called")
        print("📋 Current name: '\(name)'")
        print("📋 Current costString: '\(costString)'")
        
        if selectedWebsite.isEmpty && !settingsService.stores.isEmpty {
            if let selectedStore = selectedStore {
                // Use the selected store from CalculatorView
                selectedWebsite = selectedStore.name
            } else if let defaultStore = settingsService.getDefaultStore() {
                selectedWebsite = defaultStore.name
            } else {
                selectedWebsite = settingsService.stores.first!.name
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
                let countyText = county.hasSuffix("County") ? county : "\(county) County"
                components.append(countyText)
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }()
        
        Task {
            do {
                // Set up initial progress for multi-attempt detection
                if settingsService.useMultiAttemptTaxDetection {
                    DispatchQueue.main.async {
                        self.taxDetectionProgress = (current: 0, total: settingsService.taxDetectionAttempts)
                    }
                }
                
                let detectedTaxRate = try await aiService.analyzeItemForTax(itemName: name, location: locationString) { current, total in
                    DispatchQueue.main.async {
                        self.taxDetectionProgress = (current: current, total: total)
                    }
                }
                
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.taxDetectionProgress = (current: 0, total: 0)
                    self.detectedTaxRate = detectedTaxRate
                    if andAddItem {
                        self.addItem()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDetectingTax = false
                    self.taxDetectionProgress = (current: 0, total: 0)
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
        
        // Fix: Calculate tax with proper rounding
        let baseCost = Double(costString) ?? 0
        let taxAmount = round(baseCost * finalTaxRate) / 100.0
        
        let item = ShoppingItem(
            name: name.isEmpty ? "Unnamed Item" : name,
            cost: baseCost,
            taxRate: finalTaxRate,
            hasUnknownTax: hasUnknownTax,
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
        
        if let selectedStore = selectedStore {
            // If store is selected, skip the prompt and directly open search
            selectedWebsite = selectedStore.name
            showingPriceSearchWebView = true
        } else {
            // Show the prompt to select store
            showingPriceSearchAlert = true
        }
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
                    if settingsService.useMultiAttemptTaxDetection && taxDetectionProgress.total > 0 {
                        Text("Detecting tax rate... (\(taxDetectionProgress.current)/\(taxDetectionProgress.total))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Detecting tax rate...")
                            .foregroundColor(.secondary)
                    }
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
                    if settingsService.useMultiAttemptTaxDetection && taxDetectionProgress.total > 0 {
                        Text("Detecting tax rate... (\(taxDetectionProgress.current)/\(taxDetectionProgress.total))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Detecting tax rate...")
                            .foregroundColor(.secondary)
                    }
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

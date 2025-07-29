import SwiftUI

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

struct VerifyItemView: View {
    let extractedInfo: PriceTagInfo
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var aiService: AIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    @Environment(\.presentationMode) var presentationMode
    let onRetakePhoto: (() -> Void)?
    let originalImage: UIImage?
    let locationString: String?
    let selectedStore: Store?
    let onItemAdded: ((String) -> Void)?
    
    @State private var name: String
    @State private var costString: String
    @State private var taxMode: TaxMode = .defaultMode
    @State private var customTaxRateString: String
    @State private var detectedTaxRate: Double? = nil
    @State private var hasUnknownTax: Bool
    @State private var taxDescription: String?
    @State private var isRetryingAnalysis = false
    @State private var isDetectingTax = false
    @State private var showingPriceSearchAlert = false
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = ""
    @State private var priceSourceURL: String? = nil
    @State private var showingPriceSearchWebView = false
    @State private var webViewSelectedPrice: Double? = nil
    @State private var webViewSelectedItemName: String? = nil
    @State private var retryCounter = 0
    @State private var dynamicAnalysisIssues: [String] = []
    @State private var isPriceByMeasurement = false
    @State private var measurementQuantity = 1.0
    @State private var measurementQuantityString = "1.0"
    @State private var selectedMeasurementUnit = MeasurementUnit.units
    @State private var shouldAutoOpenSearch = false
    @State private var showingCustomPriceSearch = false
    
    
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

    init(extractedInfo: PriceTagInfo, store: ShoppingListStore, aiService: AIService, settingsService: SettingsService, customPriceListStore: CustomPriceListStore, onRetakePhoto: (() -> Void)? = nil, originalImage: UIImage? = nil, locationString: String? = nil, selectedStore: Store? = nil, onItemAdded: ((String) -> Void)? = nil, shouldAutoOpenSearch: Bool = false) {
        self.extractedInfo = extractedInfo
        self.store = store
        self.aiService = aiService
        self.settingsService = settingsService
        self.customPriceListStore = customPriceListStore
        self.onRetakePhoto = onRetakePhoto
        self.originalImage = originalImage
        self.locationString = locationString
        self.selectedStore = selectedStore
        self.onItemAdded = onItemAdded
        self._name = State(initialValue: extractedInfo.name)
        self._costString = State(initialValue: String(format: "%.2f", extractedInfo.price))
        self._customTaxRateString = State(initialValue: String(format: "%.2f", extractedInfo.taxRate ?? 0.0))
        self._hasUnknownTax = State(initialValue: extractedInfo.taxDescription == "Unknown Taxes" || extractedInfo.taxRate == nil)
        self._taxDescription = State(initialValue: extractedInfo.taxDescription)
        self._dynamicAnalysisIssues = State(initialValue: extractedInfo.analysisIssues ?? [])
        
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
        self._shouldAutoOpenSearch = State(initialValue: shouldAutoOpenSearch)
        
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
                                .foregroundColor(name.isEmpty ? .gray : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(name.isEmpty ? Color.gray.opacity(0.3) : Color.purple)
                                .cornerRadius(8)
                            }
                            .disabled(name.isEmpty)
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
                                
                                Text(selectedMeasurementUnit.displayText(for: Double(measurementQuantityString) ?? 1.0))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                
                                Picker("Unit", selection: $selectedMeasurementUnit) {
                                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            if let cost = Double(costString), let quantity = Double(measurementQuantityString) {
                                Text("Total: $\(cost * quantity, specifier: "%.2f") ($\(cost, specifier: "%.2f") per \(selectedMeasurementUnit.singularForm))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
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
                        print("📝 VerifyItemView: 'Add Item' button clicked")
                        if shouldDetectTaxRate() {
                            print("📝 VerifyItemView: Detecting tax rate first")
                            detectTaxRate()
                        } else {
                            print("📝 VerifyItemView: Adding item directly")
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
.sheet(isPresented: $showingPriceSearchAlert) {
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
            .sheet(isPresented: $showingCustomPriceSearch) {
                let _ = print("🔍 VerifyItemView: Opening CustomPriceSearch - selectedStore: \(selectedStore?.name ?? "None"), always searching ALL lists")
                
                CustomPriceSearchView(
                    customPriceListStore: customPriceListStore,
                    onItemSelected: { item, list in
                        costString = String(format: "%.2f", item.price)
                        // Use the new setting to determine whether to replace the item name
                        if name.isEmpty || settingsService.replaceItemNameFromPriceList {
                            name = item.name
                        }
                        
                        // Update analysis issues
                        dynamicAnalysisIssues.removeAll { $0.contains("custom price") }
                        let issueText = "Custom price selected - \(item.name) at $\(String(format: "%.2f", item.price)) from \(list.name)"
                        dynamicAnalysisIssues.append(issueText)
                        
                        showingCustomPriceSearch = false
                    },
                    initialSearchText: name,
                    searchAllLists: true, // Always search all lists in manual/photo add context
                    selectedListId: nil
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
                        priceSourceURL = settingsService.buildSearchURL(for: selectedWebsite, searchTerm: searchTerm)
                        
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
            .onChange(of: measurementQuantityString) { _, newValue in
                measurementQuantity = Double(newValue) ?? 1.0
            }
            .onAppear {
                print("📝 VerifyItemView: onAppear called - extractedInfo.name='\(extractedInfo.name)', price=\(extractedInfo.price)")
                print("📝 VerifyItemView: shouldAutoOpenSearch = \(shouldAutoOpenSearch)")
                print("📝 VerifyItemView: onItemAdded callback = \(onItemAdded != nil ? "present" : "nil")")
                
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
                
                // Auto-open search if requested
                if shouldAutoOpenSearch {
                    print("📝 VerifyItemView: Auto-opening search for '\(extractedInfo.name)'")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingPriceSearchWebView = true
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
        
        // Update measurement quantity from string
        measurementQuantity = Double(measurementQuantityString) ?? 1.0
        
        let item = ShoppingItem(
            name: name.isEmpty ? "Unnamed Item" : name,
            cost: Double(costString) ?? 0,
            taxRate: finalTaxRate,
            hasUnknownTax: hasUnknownTax,
            isPriceByMeasurement: isPriceByMeasurement,
            measurementQuantity: measurementQuantity,
            measurementUnit: selectedMeasurementUnit.rawValue
        )
        store.addItem(item)
        
        // Notify parent about item addition (no auto-search logic should trigger here)
        print("📝 VerifyItemView: Calling onItemAdded with item.name='\(item.name)'")
        onItemAdded?(item.name)
        
        print("📝 VerifyItemView: Dismissing VerifyItemView")
        presentationMode.wrappedValue.dismiss()
    }
    
    private func setupPriceSearch() {
        priceSearchSpecification = ""
        priceSourceURL = nil
        
        // Ensure selectedWebsite is set before opening search
        if selectedWebsite.isEmpty {
            if let selectedStore = selectedStore {
                selectedWebsite = selectedStore.name
            } else if let defaultStore = settingsService.getDefaultStore() {
                selectedWebsite = defaultStore.name
            } else if let firstStore = settingsService.stores.first {
                selectedWebsite = firstStore.name
            }
        }
        
        // If we have a valid website, open search directly
        if !selectedWebsite.isEmpty {
            showingPriceSearchWebView = true
        } else {
            // Show the prompt to select store if no stores available
            showingPriceSearchAlert = true
        }
    }
    
    
    private func openPriceSource() {
        guard let urlString = priceSourceURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    private var isCustomPriceSearchDisabled: Bool {
        // Allow search when setting is enabled even if name is empty, otherwise require name
        if settingsService.replaceItemNameFromPriceList {
            return !customPriceListStore.hasLists
        } else {
            return name.isEmpty || !customPriceListStore.hasLists
        }
    }
    
    private var taxModeView: some View {
        Group {
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
}

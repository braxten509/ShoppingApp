import SwiftUI

struct ItemEditView: View {
    @Binding var item: ShoppingItem
    @ObservedObject var aiService: AIService
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String
    @State private var costString: String
    @State private var quantityString: String
    @State private var taxRateString: String
    @State private var isReanalyzingTax = false
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
    @State private var hasUnknownTax: Bool
    @State private var isPriceByMeasurement: Bool
    @State private var measurementQuantity: Double
    @State private var measurementQuantityString: String
    @State private var selectedMeasurementUnit: MeasurementUnit
    @State private var showingCustomPriceSearch = false
    
    init(item: Binding<ShoppingItem>, aiService: AIService, locationManager: LocationManager, settingsService: SettingsService, customPriceListStore: CustomPriceListStore) {
        self._item = item
        self.aiService = aiService
        self.locationManager = locationManager
        self.settingsService = settingsService
        self.customPriceListStore = customPriceListStore
        self._name = State(initialValue: item.wrappedValue.name)
        self._costString = State(initialValue: String(format: "%.2f", item.wrappedValue.cost))
        self._quantityString = State(initialValue: String(item.wrappedValue.quantity))
        self._taxRateString = State(initialValue: String(format: "%.2f", item.wrappedValue.taxRate))
        self._hasUnknownTax = State(initialValue: item.wrappedValue.hasUnknownTax)
        self._isPriceByMeasurement = State(initialValue: item.wrappedValue.isPriceByMeasurement)
        self._measurementQuantity = State(initialValue: item.wrappedValue.measurementQuantity)
        self._measurementQuantityString = State(initialValue: String(format: "%.1f", item.wrappedValue.measurementQuantity))
        self._selectedMeasurementUnit = State(initialValue: MeasurementUnit(rawValue: item.wrappedValue.measurementUnit) ?? .units)
        
        // Initialize selectedWebsite properly to avoid empty string issues
        let websiteToUse: String
        if let defaultStore = settingsService.getDefaultStore() {
            websiteToUse = defaultStore.name
        } else {
            websiteToUse = settingsService.stores.first?.name ?? ""
        }
        self._selectedWebsite = State(initialValue: websiteToUse)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("$")
                            TextField("0.00", text: $costString)
                                .keyboardType(.decimalPad)
                            Text("per item")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                                .foregroundColor(name.isEmpty || !customPriceListStore.hasLists ? .gray : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(name.isEmpty || !customPriceListStore.hasLists ? Color.gray.opacity(0.3) : Color.orange)
                                .cornerRadius(8)
                            }
                            .disabled(name.isEmpty || !customPriceListStore.hasLists)
                            .buttonStyle(PlainButtonStyle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    HStack {
                        Text("Quantity:")
                        TextField("1", text: $quantityString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    HStack {
                        TextField("0.00", text: $taxRateString)
                            .keyboardType(.decimalPad)
                        Text("% Tax")
                        if hasUnknownTax {
                            Text("(Unknown)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
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
                            
                            // Replace the measurement total calculation with this:
                            if let cost = Double(costString), let quantity = Double(measurementQuantityString) {
                                let totalCost = cost * quantity
                                let taxRate = Double(taxRateString) ?? 0
                                let taxAmount = round(totalCost * taxRate) / 100.0
                                let totalWithTax = totalCost + taxAmount
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total: $\(totalCost, specifier: "%.2f") ($\(cost, specifier: "%.2f") per \(selectedMeasurementUnit.singularForm))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Text("With Tax: $\(totalWithTax, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    if isReanalyzingTax {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Reanalyzing tax...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Reanalyze Taxes") {
                            Task { @MainActor in
                                await reanalyzeTaxes()
                            }
                        }
                        .foregroundColor(.blue)
                        .disabled(isReanalyzingTax || name.isEmpty)
                    }
                    
                    
                }
                
                
                // Replace the preview section in the Form with this corrected version:
                Section(header: Text("Preview")) {
                    let quantity = max(1, Int(quantityString) ?? 1)
                    let unitPrice = Double(costString) ?? 0
                    let subtotal = unitPrice * Double(quantity)
                    
                    // Fix: Use proper rounding for tax calculation
                    let taxRate = Double(taxRateString) ?? 0
                    let taxAmount = round(subtotal * taxRate) / 100.0
                    let total = subtotal + taxAmount
                    
                    if quantity > 1 {
                        HStack {
                            Text("Unit Price:")
                            Spacer()
                            Text("$\(unitPrice, specifier: "%.2f") × \(quantity)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Subtotal:")
                        Spacer()
                        Text("$\(subtotal, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Tax:")
                        Spacer()
                        Text("$\(taxAmount, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Total:")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(total, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        item.name = name
                        item.cost = Double(costString) ?? 0
                        item.quantity = max(1, Int(quantityString) ?? 1)
                        item.taxRate = Double(taxRateString) ?? 0
                        item.hasUnknownTax = hasUnknownTax
                        item.isPriceByMeasurement = isPriceByMeasurement
                        item.measurementQuantity = Double(measurementQuantityString) ?? 1.0
                        item.measurementUnit = selectedMeasurementUnit.rawValue
                        presentationMode.wrappedValue.dismiss()
                    }
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
            .sheet(isPresented: $showingCustomPriceSearch) {
                CustomPriceSearchView(customPriceListStore: customPriceListStore) { item, list in
                    costString = String(format: "%.2f", item.price)
                    if name.isEmpty {
                        name = item.name
                    }
                    showingCustomPriceSearch = false
                }
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
            }
            .alert("Tax Rate Error", isPresented: $showingTaxErrorAlert) {
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
    
    @MainActor
    private func reanalyzeTaxes() async {
        guard !name.isEmpty else { return }
        
        isReanalyzingTax = true
        
        // Get location string
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
        
        do {
            // Call the tax analysis with the current name and location
            if let detectedTaxRate = try await aiService.analyzeItemForTax(itemName: name, location: locationString) {
                self.taxRateString = String(format: "%.2f", detectedTaxRate)
                self.hasUnknownTax = false
            } else {
                // Tax rate still couldn't be determined
                self.hasUnknownTax = true
            }
            
            isReanalyzingTax = false
        } catch {
            isReanalyzingTax = false
            currentErrorMessage = error.localizedDescription
            showingTaxErrorAlert = true
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
}

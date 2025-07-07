import SwiftUI

struct ItemEditView: View {
    @Binding var item: ShoppingItem
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String
    @State private var costString: String
    @State private var quantityString: String
    @State private var taxRateString: String
    @State private var showingAdditiveDetail = false
    @State private var isReanalyzingTax = false
    @State private var isGuessingPrice = false
    @State private var showingPriceGuessAlert = false
    @State private var priceGuessLocation = ""
    @State private var priceGuessBrand = ""
    @State private var priceGuessDetails = ""
    @State private var priceSourceURL: String? = nil
    @State private var showingUnableToDeterminePriceAlert = false
    @State private var hasUnknownTax: Bool
    
    init(item: Binding<ShoppingItem>, openAIService: OpenAIService, locationManager: LocationManager) {
        self._item = item
        self.openAIService = openAIService
        self.locationManager = locationManager
        self._name = State(initialValue: item.wrappedValue.name)
        self._costString = State(initialValue: String(format: "%.2f", item.wrappedValue.cost))
        self._quantityString = State(initialValue: String(item.wrappedValue.quantity))
        self._taxRateString = State(initialValue: String(format: "%.2f", item.wrappedValue.taxRate))
        self._hasUnknownTax = State(initialValue: item.wrappedValue.hasUnknownTax)
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
                        Text("per item")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                
                if !item.additiveDetails.isEmpty {
                    Section(header: Text("Health Information")) {
                        Button(action: {
                            showingAdditiveDetail = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Additives Analysis")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 12) {
                                        if item.riskyAdditives > 0 {
                                            Text("\(item.riskyAdditives) Risky")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .fontWeight(.medium)
                                        }
                                        if item.nonRiskyAdditives > 0 {
                                            Text("\(item.nonRiskyAdditives) Safe")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(header: Text("Preview")) {
                    let quantity = max(1, Int(quantityString) ?? 1)
                    let unitPrice = Double(costString) ?? 0
                    let subtotal = unitPrice * Double(quantity)
                    let taxAmount = subtotal * (Double(taxRateString) ?? 0) / 100
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
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAdditiveDetail) {
                AdditiveDetailView(additives: item.additiveDetails, productName: item.name)
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
                components.append("\(county) County")
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }()
        
        do {
            // Call the tax analysis with the current name and location
            if let detectedTaxRate = try await openAIService.analyzeItemForTax(itemName: name, location: locationString) {
                self.taxRateString = String(format: "%.2f", detectedTaxRate)
                self.hasUnknownTax = false
            } else {
                // Tax rate still couldn't be determined
                self.hasUnknownTax = true
            }
            
            isReanalyzingTax = false
        } catch {
            isReanalyzingTax = false
            print("Error reanalyzing taxes: \(error)")
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
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
    @ObservedObject var openAIService: OpenAIService
    @Environment(\.presentationMode) var presentationMode
    let onRetakePhoto: (() -> Void)?
    let originalImage: UIImage?
    let locationString: String?
    
    @State private var name: String
    @State private var costString: String
    @State private var taxRateString: String
    @State private var isAnalyzingAdditives = false
    @State private var isRetryingAnalysis = false
    @State private var retryCounter = 0
    @State private var riskyAdditives = 0
    @State private var nonRiskyAdditives = 0
    @State private var additiveDetails: [AdditiveInfo] = []
    
    init(extractedInfo: PriceTagInfo, store: ShoppingListStore, settingsStore: SettingsStore, openAIService: OpenAIService, onRetakePhoto: (() -> Void)? = nil, originalImage: UIImage? = nil, locationString: String? = nil) {
        self.extractedInfo = extractedInfo
        self.store = store
        self.settingsStore = settingsStore
        self.openAIService = openAIService
        self.onRetakePhoto = onRetakePhoto
        self.originalImage = originalImage
        self.locationString = locationString
        self._name = State(initialValue: extractedInfo.name)
        self._costString = State(initialValue: String(format: "%.2f", extractedInfo.price))
        self._taxRateString = State(initialValue: String(format: "%.2f", extractedInfo.taxRate ?? 0.0))
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
                    
                    if let taxDescription = extractedInfo.taxDescription {
                        HStack {
                            Text("Tax Info:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(taxDescription)
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
                        let hasUnknownTax = extractedInfo.taxDescription == "Unknown Taxes" || extractedInfo.taxRate == nil
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
    }
    
    @MainActor
    private func retryAnalysis(with image: UIImage) async {
        do {
            let newInfo = try await openAIService.analyzePriceTag(image: image, location: locationString)
            
            self.name = newInfo.name
            self.costString = String(format: "%.2f", newInfo.price)
            self.taxRateString = String(format: "%.2f", newInfo.taxRate ?? 0.0)
            self.isRetryingAnalysis = false
        } catch {
            self.isRetryingAnalysis = false
            print("Error retrying analysis: \(error)")
        }
    }
}
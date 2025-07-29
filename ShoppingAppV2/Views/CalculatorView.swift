import SwiftUI

struct CalculatorView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var historyStore: ShoppingHistoryStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var billingService: BillingService
    @ObservedObject var historyService: HistoryService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    // Note: onSwitchToSearchTab removed - auto-search now happens within VerifyItemView
    
    private var aiService: AIService {
        AIService(settingsService: settingsService, billingService: billingService, historyService: historyService)
    }
    
    @State private var showingCamera = false
    @State private var showingAddItem = false
    @State private var showingItemEdit = false
    @State private var showingVerifyItem = false
    @State private var shouldAutoOpenSearch = false
    @State private var selectedImage: UIImage?
    @State private var editingItem: ShoppingItem?
    @State private var extractedInfo: PriceTagInfo?
    @State private var lastProcessedImage: UIImage?
    @State private var lastLocationString: String?
    @State private var isProcessingImage = false
    @State private var showingFinishConfirmation = false
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLocationRetry = false
    @State private var showingLocationSync = false
    @State private var selectedStore: Store? {
        didSet {
            if let store = selectedStore {
                UserDefaults.standard.set(store.id.uuidString, forKey: "calculatorView_selectedStoreId")
            } else {
                UserDefaults.standard.removeObject(forKey: "calculatorView_selectedStoreId")
            }
        }
    }
    @State private var selectedCustomPriceList: CustomPriceList? {
        didSet {
            if let list = selectedCustomPriceList {
                UserDefaults.standard.set(list.id.uuidString, forKey: "calculatorView_selectedCustomPriceListId")
            } else {
                UserDefaults.standard.removeObject(forKey: "calculatorView_selectedCustomPriceListId")
            }
        }
    }
    
    var body: some View {
        let _ = print("🔄 CalculatorView.body computed - Store: \(selectedStore?.name ?? "nil"), CustomList: \(selectedCustomPriceList?.name ?? "nil")")
        return NavigationView {
            VStack(spacing: 0) {
                List {
                    // Location Header Section
                    Section {
                        locationHeaderContent
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    
                    // Calculator Section
                    Section {
                        calculatorSectionContent
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    
                    // Items Section
                    if !store.items.isEmpty {
                        Section("Items") {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                itemRow(item: item, index: index)
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                
                // Action Buttons - Fixed at bottom
                actionButtonsContent
                    .background(Color(.systemBackground))
            }
            .navigationTitle("Shopping Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Finish Shopping") {
                        showingFinishConfirmation = true
                    }
                    .disabled(store.items.isEmpty)
                }
            }
            .alert("Finish Shopping", isPresented: $showingFinishConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Finish", role: .destructive) {
                    finishShopping()
                }
            } message: {
                Text("Are you sure you want to finish shopping? This will save your trip to history and clear your current items.")
            }
            .alert("Processing Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Retry Location", isPresented: $showingLocationRetry) {
                Button("Cancel", role: .cancel) { }
                Button("Retry") {
                    locationManager.requestLocation()
                }
            } message: {
                Text("Would you like to retry finding your location?")
            }
            .alert("Sync Location", isPresented: $showingLocationSync) {
                Button("Cancel", role: .cancel) { }
                Button("Sync") {
                    locationManager.requestLocation()
                }
            } message: {
                Text("Sync?")
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(store: store, locationManager: locationManager, aiService: aiService, settingsService: settingsService, customPriceListStore: customPriceListStore, selectedStore: selectedStore)
            }
            .sheet(item: $editingItem) { item in
                ItemEditView(
                    item: bindingForItem(item),
                    aiService: aiService,
                    locationManager: locationManager,
                    settingsService: settingsService,
                    customPriceListStore: customPriceListStore
                )
            }
            .sheet(isPresented: $showingVerifyItem) {
                if let info = extractedInfo {
                    VerifyItemView(
                        extractedInfo: info, 
                        store: store,
                        aiService: aiService,
                        settingsService: settingsService,
                        customPriceListStore: customPriceListStore,
                        onRetakePhoto: {
                            // Retake photo callback
                            showingVerifyItem = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingCamera = true
                            }
                        },
                        originalImage: lastProcessedImage,
                        locationString: lastLocationString,
                        selectedStore: selectedStore,
                        onItemAdded: { itemName in
                            print("📷 CalculatorView: onItemAdded called with itemName='\(itemName)' (no auto-search logic here anymore)")
                            // Note: Auto-search logic has been moved to trigger immediately after photo processing
                        },
                        shouldAutoOpenSearch: shouldAutoOpenSearch
                    )
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(openAIService: openAIService, settingsService: settingsService, store: store, historyService: historyService, customPriceListStore: customPriceListStore)
            }
            .onChange(of: selectedImage) { _, image in
                if let image = image {
                    processImage(image)
                }
            }
        }
    }
    
    private var locationHeaderContent: some View {
        VStack(spacing: 4) {
            HStack {
                // Location section
                if settingsService.locationAccessEnabled {
                    if locationManager.isLoadingLocation {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Finding location...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if locationManager.hasLocationFailed {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.red)
                            Text("Unable to find location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            showingLocationRetry = true
                        }
                    } else if let placemark = locationManager.placemark {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                if let city = placemark.locality, let state = placemark.administrativeArea {
                                    Text("\(city), \(state)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                if let county = placemark.subAdministrativeArea {
                                    let countyText = county.hasSuffix("County") ? county : "\(county) County"
                                    Text(countyText)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onTapGesture {
                            showingLocationSync = true
                        }
                    }
                }
                
                Spacer()
                
                // Custom Price List Selection
                if customPriceListStore.hasLists {
                    Menu {
                        Button(action: {
                            print("🔘 Custom Price List Menu: Selecting 'None'")
                            selectedCustomPriceList = nil
                        }) {
                            HStack {
                                Text("None")
                                Spacer()
                                if selectedCustomPriceList == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(customPriceListStore.customPriceLists, id: \.id) { list in
                            Button(action: {
                                print("🔘 Custom Price List Menu: Selecting '\(list.name)'")
                                selectedCustomPriceList = list
                            }) {
                                HStack {
                                    Text(list.name)
                                    Spacer()
                                    if selectedCustomPriceList?.id == list.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        let _ = print("🔘 CustomPriceList Menu Label - Current: \(selectedCustomPriceList?.name ?? "None")")
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.orange)
                            Text(selectedCustomPriceList?.name ?? "None")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Store selection
                Menu {
                    Button(action: {
                        print("🏪 Store Menu: Selecting 'None'")
                        selectedStore = nil
                    }) {
                        HStack {
                            Text("None")
                            Spacer()
                            if selectedStore == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(settingsService.stores, id: \.id) { store in
                        Button(action: {
                            print("🏪 Store Menu: Selecting '\(store.name)'")
                            selectedStore = store
                        }) {
                            HStack {
                                Text(store.name)
                                Spacer()
                                if selectedStore?.id == store.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    let _ = print("🏪 Store Menu Label - Current: \(selectedStore?.name ?? "None")")
                    HStack {
                        Image(systemName: "storefront.fill")
                            .foregroundColor(.purple)
                        Text(selectedStore?.name ?? "None")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            print("🔄 CalculatorView.onAppear - Store: \(selectedStore?.name ?? "nil"), CustomList: \(selectedCustomPriceList?.name ?? "nil")")
            
            // Load saved selections from UserDefaults (default to None)
            if selectedStore == nil {
                if let savedStoreId = UserDefaults.standard.string(forKey: "calculatorView_selectedStoreId"),
                   let uuid = UUID(uuidString: savedStoreId),
                   let store = settingsService.stores.first(where: { $0.id == uuid }) {
                    print("🔄 Loading saved selectedStore: \(store.name)")
                    selectedStore = store
                } else {
                    print("🔄 No saved store found - defaulting to None")
                    selectedStore = nil
                }
            }
            
            // Load saved custom price list selection (default to None)
            if selectedCustomPriceList == nil {
                if let savedListId = UserDefaults.standard.string(forKey: "calculatorView_selectedCustomPriceListId"),
                   let uuid = UUID(uuidString: savedListId),
                   let list = customPriceListStore.customPriceLists.first(where: { $0.id == uuid }) {
                    print("🔄 Loading saved selectedCustomPriceList: \(list.name)")
                    selectedCustomPriceList = list
                } else {
                    print("🔄 No saved custom price list found - defaulting to None")
                    selectedCustomPriceList = nil
                }
            }
        }
        .onChange(of: settingsService.stores) { _, _ in
            // Check if currently selected store still exists
            if let currentStore = selectedStore,
               !settingsService.stores.contains(where: { $0.id == currentStore.id }) {
                print("🔄 Selected store was deleted - resetting to None")
                selectedStore = nil
            }
        }
        .onChange(of: customPriceListStore.customPriceLists) { _, _ in
            // Check if currently selected custom price list still exists
            if let currentList = selectedCustomPriceList,
               !customPriceListStore.customPriceLists.contains(where: { $0.id == currentList.id }) {
                print("🔄 Selected custom price list was deleted - resetting to None")
                selectedCustomPriceList = nil
            }
        }
    }
    
    private var calculatorSectionContent: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal:")
                    .font(.headline)
                Spacer()
                Text("$\(store.subtotal, specifier: "%.2f")")
                    .font(.headline)
            }
            
            HStack {
                Text("Tax:")
                    .font(.headline)
                Spacer()
                Text("$\(store.totalTax, specifier: "%.2f")")
                    .font(.headline)
            }
            
            Divider()
            
            HStack {
                Text("Total:")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("$\(store.grandTotal, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func itemRow(item: ShoppingItem, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    if item.isPriceByMeasurement {
                                        Text("$\(item.cost, specifier: "%.2f") per \(item.measurementUnit)")
                                    } else {
                                        if item.quantity > 1 {
                                            Text("$\(item.unitCost, specifier: "%.2f") each")
                                        } else {
                                            Text("$\(item.cost, specifier: "%.2f")")
                                        }
                                    }
                                    if item.hasUnknownTax {
                                        Text("+ Unknown tax")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("+ \(item.taxRate, specifier: "%.1f")% tax")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if item.isPriceByMeasurement {
                                    Text("\(item.measurementQuantity, specifier: "%.1f") \(item.measurementUnit) = $\(item.actualCost, specifier: "%.2f")")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .font(.caption)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingItem = item
                        }
                        
                        Spacer()
                        
                        // Quantity controls
                        HStack(spacing: 8) {
                            Button(action: {
                                decreaseQuantity(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(item.quantity > 1 ? .red : .gray)
                                    .font(.system(size: 22))
                            }
                            .disabled(item.quantity <= 1)
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("\(item.quantity)")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(minWidth: 25)
                            
                            Button(action: {
                                increaseQuantity(at: index)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 8)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(item.totalCost, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.medium)
                    Text("($\(item.taxAmount, specifier: "%.2f") tax)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var actionButtonsContent: some View {
        VStack(spacing: 12) {
            if isProcessingImage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing image...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan Tag/Item")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isProcessingImage || !settingsService.aiEnabled || !settingsService.internetAccessEnabled ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isProcessingImage || !settingsService.aiEnabled || !settingsService.internetAccessEnabled)
                
                Button(action: {
                    showingAddItem = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Manually")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isProcessingImage ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isProcessingImage)
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            store.removeItem(at: index)
        }
    }
    
    private func increaseQuantity(at index: Int) {
        guard index < store.items.count else { return }
        store.items[index].quantity += 1
    }
    
    private func decreaseQuantity(at index: Int) {
        guard index < store.items.count && store.items[index].quantity > 1 else { return }
        store.items[index].quantity -= 1
    }
    
    private func finishShopping() {
        guard !store.items.isEmpty else { return }
        
        let completedTrip = CompletedShoppingTrip(items: store.items)
        historyStore.addCompletedTrip(completedTrip)
        store.clearAll()
    }
    
    private func bindingForItem(_ item: ShoppingItem) -> Binding<ShoppingItem> {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else {
            fatalError("Item not found")
        }
        return $store.items[index]
    }
    
    private func processImage(_ image: UIImage) {
        isProcessingImage = true
        lastProcessedImage = image
        
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
        
        lastLocationString = locationString
        
        Task {
            do {
                let priceTagInfo = try await aiService.analyzePriceTag(image: image, location: locationString)
                
                DispatchQueue.main.async {
                    print("📷 CalculatorView: Photo processed successfully - showing VerifyItemView")
                    print("📷 CalculatorView: Extracted info - name='\(priceTagInfo.name)', price=\(priceTagInfo.price)")
                    self.extractedInfo = priceTagInfo
                    self.isProcessingImage = false
                    self.selectedImage = nil
                    
                    // Auto-search functionality - check immediately after photo processing
                    print("📷 CalculatorView: Checking auto-search settings:")
                    print("  - autoOpenSearchAfterPhoto: \(self.settingsService.autoOpenSearchAfterPhoto)")
                    print("  - aiEnabled: \(self.settingsService.aiEnabled)")
                    print("  - internetAccessEnabled: \(self.settingsService.internetAccessEnabled)")
                    
                    let shouldAutoSearch = self.settingsService.autoOpenSearchAfterPhoto && 
                                          self.settingsService.aiEnabled && 
                                          self.settingsService.internetAccessEnabled
                    
                    if shouldAutoSearch {
                        let priceWasCaptured = priceTagInfo.price > 0
                        let shouldSearch = self.settingsService.alwaysSearchIgnorePrice || !priceWasCaptured
                        print("📷 CalculatorView: Auto-search evaluation:")
                        print("  - shouldAutoSearch=\(shouldAutoSearch)")
                        print("  - priceWasCaptured=\(priceWasCaptured) (price=\(priceTagInfo.price))")
                        print("  - alwaysSearchIgnorePrice=\(self.settingsService.alwaysSearchIgnorePrice)")
                        print("  - shouldSearch=\(shouldSearch)")
                        
                        if shouldSearch {
                            print("📷 ✅ CalculatorView: Auto-search enabled - will show VerifyItemView with auto-search")
                            // Show VerifyItemView with auto-search flag
                            self.shouldAutoOpenSearch = true
                            self.showingVerifyItem = true
                        } else {
                            print("📷 ❌ CalculatorView: Not triggering auto-search - price was captured (\(priceTagInfo.price)) and 'Always search (ignore captured price)' is disabled")
                            print("💡 To enable auto-search even when price is captured, go to Settings > AI Settings > 'Always search (ignore captured price)'")
                            // Show VerifyItemView without auto-search
                            self.shouldAutoOpenSearch = false
                            self.showingVerifyItem = true
                        }
                    } else {
                        print("📷 CalculatorView: Auto-search disabled due to settings - showing VerifyItemView")
                        // Show VerifyItemView since auto-search is disabled
                        self.shouldAutoOpenSearch = false
                        self.showingVerifyItem = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingImage = false
                    self.selectedImage = nil
                    self.errorMessage = "Failed to process image: \(error.localizedDescription)"
                    self.showingError = true
                    print("Error processing image: \(error)")
                }
            }
        }
    }
}

#Preview {
    CalculatorView(
        store: ShoppingListStore(),
        historyStore: ShoppingHistoryStore(),
        locationManager: LocationManager(),
        openAIService: OpenAIService(),
        settingsService: SettingsService(),
        billingService: BillingService(),
        historyService: HistoryService(),
        customPriceListStore: CustomPriceListStore()
    )
}

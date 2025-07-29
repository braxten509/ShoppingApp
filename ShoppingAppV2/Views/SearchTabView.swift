import SwiftUI
import WebKit

// Data structure for prefill information
struct PrefillData {
    let name: String
    let price: Double
}

// Dedicated state manager for prefill data persistence
class PrefillDataManager: ObservableObject {
    @Published var data: PrefillData?
    private var lastSetData: PrefillData? // Fallback storage
    
    func setPrefillData(name: String, price: Double) {
        let newData = PrefillData(name: name, price: price)
        data = newData
        lastSetData = newData // Store fallback copy
    }
    
    func clearData() {
        data = nil
        lastSetData = nil
    }
    
    func getCurrentData() -> PrefillData? {
        // Fallback mechanism: if main data is nil but we have a backup, restore it
        if data == nil && lastSetData != nil {
            data = lastSetData
        }
        
        return data
    }
    
    func hasValidData() -> Bool {
        return data != nil || lastSetData != nil
    }
}

struct SearchTabView: View {
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var aiService: AIService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    let prefillItemName: String
    
    init(store: ShoppingListStore, locationManager: LocationManager, settingsService: SettingsService, aiService: AIService, customPriceListStore: CustomPriceListStore, prefillItemName: String = "") {
        self.store = store
        self.locationManager = locationManager
        self.settingsService = settingsService
        self.aiService = aiService
        self.customPriceListStore = customPriceListStore
        self.prefillItemName = prefillItemName
        
        // Initialize selectedWebsite with empty string - will be set in onAppear
        self._selectedWebsite = State(initialValue: "")
    }
    
    @State private var itemName = ""
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = ""
    @State private var selectItemsMode = false
    @State private var showingPriceSearchWebView = false
    @State private var showingAddItem = false
    @State private var showingCustomListSearch = false
    @State private var searchMode: SearchMode = .store
    @State private var selectedListId: UUID?
    @State private var searchAllLists = true
    @StateObject private var prefillManager = PrefillDataManager()
    @FocusState private var isTextFieldFocused: Bool
    
    enum SearchMode: String, CaseIterable {
        case store = "Store Search"
        case list = "List Search"
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    headerView
                    formFieldsView
                    controlsView
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showingPriceSearchWebView) {
                let websiteToUse = selectedWebsite.isEmpty ? (settingsService.getDefaultStore()?.name ?? settingsService.stores.first?.name ?? "") : selectedWebsite
                let _ = print("🔍 SearchTabView.fullScreenCover: selectedWebsite='\(selectedWebsite)', websiteToUse='\(websiteToUse)', selectItemsMode=\(selectItemsMode)")
                
                if selectItemsMode {
                    SearchWithManualEntryView(
                        itemName: itemName,
                        specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                        website: websiteToUse,
                        settingsService: settingsService,
                        onItemAdded: { price, name in
                            // Set prefill data using the manager
                            prefillManager.setPrefillData(name: name, price: price)
                            
                            // Properly sequence the sheet transitions
                            showingPriceSearchWebView = false
                            
                            // Delay opening the new sheet to ensure clean transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingAddItem = true
                            }
                        }
                    )
                } else {
                    SearchPriceWebView(
                        itemName: itemName,
                        specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                        website: websiteToUse,
                        selectedPrice: .constant(nil),
                        selectedItemName: .constant(nil),
                        settingsService: settingsService,
                        selectItemsMode: false
                    )
                }
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                // Clear prefill data when sheet is dismissed
                prefillManager.clearData()
            }) {
                Group {
                    let currentData = prefillManager.getCurrentData()
                    AddItemView(
                        store: store,
                        locationManager: locationManager,
                        aiService: aiService,
                        settingsService: settingsService,
                        customPriceListStore: customPriceListStore,
                        prefillName: currentData?.name,
                        prefillPrice: currentData?.price
                    )
                }
            }
            .sheet(isPresented: $showingCustomListSearch) {
                CustomPriceSearchView(
                    customPriceListStore: customPriceListStore,
                    onItemSelected: { item, list in
                        // Set prefill data with the selected item from the list
                        prefillManager.setPrefillData(name: item.name, price: item.price)
                        
                        // Close the list search and open add item
                        showingCustomListSearch = false
                        
                        // Delay opening the new sheet to ensure clean transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingAddItem = true
                        }
                    },
                    initialSearchText: itemName,
                    searchAllLists: searchAllLists,
                    selectedListId: searchAllLists ? nil : selectedListId
                )
            }
            .onAppear {
                print("🔍 SearchTabView onAppear: selectedWebsite = '\(selectedWebsite)', stores count = \(settingsService.stores.count)")
                
                // Set default store if not already set
                if selectedWebsite.isEmpty && !settingsService.stores.isEmpty {
                    if let defaultStore = settingsService.getDefaultStore() {
                        selectedWebsite = defaultStore.name
                        print("🔍 SearchTabView onAppear: Set default store '\(defaultStore.name)'")
                    } else {
                        selectedWebsite = settingsService.stores.first!.name
                        print("🔍 SearchTabView onAppear: Set first store '\(settingsService.stores.first!.name)'")
                    }
                }
            }
            .onChange(of: prefillItemName) { _, newValue in
                print("🔍 SearchTabView: prefillItemName changed to: '\(newValue)' (selectedWebsite='\(selectedWebsite)')")
                if !newValue.isEmpty {
                    print("🔍 SearchTabView: Setting itemName to '\(newValue)'")
                    itemName = newValue
                    isTextFieldFocused = true
                    // Automatically enable select items mode and open search when coming from photo entry
                    selectItemsMode = true
                    
                    // Ensure we have a valid store selected before auto-search
                    if selectedWebsite.isEmpty && !settingsService.stores.isEmpty {
                        if let defaultStore = settingsService.getDefaultStore() {
                            selectedWebsite = defaultStore.name
                            print("🔍 SearchTabView: Auto-fixed selectedWebsite to default store '\(defaultStore.name)'")
                        } else {
                            selectedWebsite = settingsService.stores.first!.name
                            print("🔍 SearchTabView: Auto-fixed selectedWebsite to first store '\(settingsService.stores.first!.name)'")
                        }
                    }
                    
                    if !selectedWebsite.isEmpty {
                        print("🔍 SearchTabView: Scheduling auto-search in 0.5 seconds with selectedWebsite='\(selectedWebsite)'")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Double-check that selectedWebsite is still valid before opening search
                            let finalSelectedWebsite = selectedWebsite.isEmpty ? (settingsService.getDefaultStore()?.name ?? settingsService.stores.first?.name ?? "") : selectedWebsite
                            print("🔍 SearchTabView: Executing auto-search now with finalSelectedWebsite='\(finalSelectedWebsite)', selectItemsMode=\(selectItemsMode)")
                            
                            if !finalSelectedWebsite.isEmpty {
                                // Update selectedWebsite if it was empty
                                if selectedWebsite.isEmpty {
                                    selectedWebsite = finalSelectedWebsite
                                    print("🔍 SearchTabView: Updated selectedWebsite to '\(finalSelectedWebsite)' before search")
                                }
                                showingPriceSearchWebView = true
                            } else {
                                print("❌ SearchTabView: No valid website available for auto-search")
                            }
                        }
                    } else {
                        print("❌ SearchTabView: selectedWebsite is still empty after auto-fix, cannot auto-search")
                    }
                } else {
                    print("🔍 SearchTabView: prefillItemName is empty, no action taken")
                }
            }
            .onChange(of: selectedListId) { _, newValue in
                // When a specific list is selected, automatically set searchAllLists to false
                if newValue != nil && searchAllLists {
                    print("🔍 SearchTabView: selectedListId changed to specific list, setting searchAllLists to false")
                    searchAllLists = false
                }
            }
            .onChange(of: searchAllLists) { _, newValue in
                // When switching to "Specific List" mode, select the default list if none is selected
                if !newValue && selectedListId == nil {
                    if let defaultList = customPriceListStore.getDefaultList() {
                        print("🔍 SearchTabView: Switched to specific list mode, selecting default list '\(defaultList.name)'")
                        selectedListId = defaultList.id
                    } else if let firstList = customPriceListStore.customPriceLists.first {
                        print("🔍 SearchTabView: Switched to specific list mode, selecting first list '\(firstList.name)'")
                        selectedListId = firstList.id
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search for Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchMode == .store ? "Search for items across different stores. Enable 'Select Items?' to browse and manually add prices using the floating button." : "Search for items in your custom price lists. Find items you've previously saved with their prices.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var formFieldsView: some View {
        Group {
            // Search Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Mode")
                    .font(.headline)
                
                Picker("Search Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Item Name")
                    .font(.headline)
                
                TextField("Enter item name", text: $itemName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Store search specific fields
            if searchMode == .store {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specification (Optional)")
                        .font(.headline)
                    
                    TextField("Enter specifications", text: $priceSearchSpecification)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Select Store")
                            .font(.headline)
                        
                        Spacer()
                        
                        Picker("Store", selection: $selectedWebsite) {
                            ForEach(settingsService.stores, id: \.id) { store in
                                Text(store.name).tag(store.name)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // List search specific fields
            if searchMode == .list {
                if !customPriceListStore.hasLists {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Custom Price Lists")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("You don't have any custom price lists yet. Create one in Settings > Custom Price Lists to use this search mode.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Search In")
                            .font(.headline)
                        
                        Spacer()
                        
                        Picker("Search Scope", selection: $searchAllLists) {
                            Text("All Lists").tag(true)
                            Text("Specific List").tag(false)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                if !searchAllLists {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Select List")
                                .font(.headline)
                            
                            Spacer()
                            
                            Picker("List", selection: $selectedListId) {
                                ForEach(customPriceListStore.customPriceLists, id: \.id) { list in
                                    Text(list.name).tag(Optional(list.id))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                }
            }
        }
    }
    
    private var controlsView: some View {
        Group {
            // Show Select Items toggle only for store search
            if searchMode == .store {
                HStack {
                    Text("Select Items?")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $selectItemsMode)
                        .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Button(action: {
                print("🔍 SearchTabView: Search button tapped - searchMode=\(searchMode), selectedWebsite='\(selectedWebsite)', selectItemsMode=\(selectItemsMode)")
                isTextFieldFocused = false
                
                if searchMode == .store {
                    showingPriceSearchWebView = true
                } else {
                    showingCustomListSearch = true
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(searchMode == .store ? "Search Price" : "Search Lists")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(searchButtonBackgroundColor)
                .cornerRadius(12)
            }
            .disabled(searchButtonDisabled)
            .padding(.horizontal)
        }
    }
    
    private var searchButtonBackgroundColor: Color {
        if searchButtonDisabled {
            return Color.gray
        }
        return searchMode == .store ? Color.purple : Color.orange
    }
    
    private var searchButtonDisabled: Bool {
        if itemName.isEmpty {
            return true
        }
        
        if searchMode == .store {
            return selectedWebsite.isEmpty
        } else {
            if !customPriceListStore.hasLists {
                return true
            }
            // When selectedListId is nil, we should always search all lists (that's the "None"/default option)
            // This is always valid as long as we have lists
            return false
        }
    }
}

struct SearchWithManualEntryView: View {
    let itemName: String
    let specification: String?
    let website: String
    @ObservedObject var settingsService: SettingsService
    let onItemAdded: (Double, String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showingHelpAlert = false
    
    init(itemName: String, specification: String?, website: String, settingsService: SettingsService, onItemAdded: @escaping (Double, String) -> Void) {
        self.itemName = itemName
        self.specification = specification
        self.website = website
        self.settingsService = settingsService
        self.onItemAdded = onItemAdded
        print("🏗️ SearchWithManualEntryView init: website='\(website)', itemName='\(itemName)'")
    }
    
    private var searchURL: URL? {
        let searchTerm = specification != nil ? "\(itemName) \(specification!)" : itemName
        print("🔗 SearchWithManualEntryView: Building URL for website='\(website)', searchTerm='\(searchTerm)'")
        
        // Add guard to ensure website is not empty
        guard !website.isEmpty else {
            print("❌ SearchWithManualEntryView: website parameter is empty")
            return nil
        }
        
        guard let urlString = settingsService.buildSearchURL(for: website, searchTerm: searchTerm) else {
            print("❌ SearchWithManualEntryView: buildSearchURL returned nil")
            return nil
        }
        print("🔗 SearchWithManualEntryView: Built URL string: \(urlString)")
        let url = URL(string: urlString)
        print("🔗 SearchWithManualEntryView: Final URL: \(url?.absoluteString ?? "nil")")
        return url
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = searchURL {
                    ZStack {
                        SimpleWebView(url: url)
                        
                        // Manual price entry overlay
                        ManualPriceEntryOverlay(
                            itemName: itemName,
                            onPriceSelected: { price, name in
                                onItemAdded(price, name)
                            }
                        )
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Unable to Load Search")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        if website.isEmpty {
                            Text("No store selected. Please select a store from the search tab.")
                        } else {
                            Text("Invalid website selection: '\(website)'")
                        }
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Item - \(website)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Help") {
                        showingHelpAlert = true
                    }
                }
            }
            .alert("How to Use", isPresented: $showingHelpAlert) {
                Button("OK") { }
            } message: {
                Text("Browse the website to find the item you want. When you find it, tap the 'Add Price' button in the bottom right corner to manually enter the price.")
            }
        }
    }
}

struct SimpleWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        // Simple coordinator with no JavaScript injection
    }
}

struct SearchPriceWebView: View {
    let itemName: String
    let specification: String?
    let website: String
    @Binding var selectedPrice: Double?
    @Binding var selectedItemName: String?
    @ObservedObject var settingsService: SettingsService
    let selectItemsMode: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showingHelpAlert = false
    // Removed price confirmation states since we only capture names now
    
    init(itemName: String, specification: String?, website: String, selectedPrice: Binding<Double?>, selectedItemName: Binding<String?>, settingsService: SettingsService, selectItemsMode: Bool) {
        self.itemName = itemName
        self.specification = specification
        self.website = website
        self._selectedPrice = selectedPrice
        self._selectedItemName = selectedItemName
        self.settingsService = settingsService
        self.selectItemsMode = selectItemsMode
        print("🏗️ SearchPriceWebView init: website='\(website)', itemName='\(itemName)', selectItemsMode=\(selectItemsMode)")
    }
    
    private var searchURL: URL? {
        let searchTerm = specification != nil ? "\(itemName) \(specification!)" : itemName
        print("🔗 SearchPriceWebView: Building URL for website='\(website)', searchTerm='\(searchTerm)'")
        
        // Add guard to ensure website is not empty
        guard !website.isEmpty else {
            print("❌ SearchPriceWebView: website parameter is empty")
            return nil
        }
        
        guard let urlString = settingsService.buildSearchURL(for: website, searchTerm: searchTerm) else {
            print("❌ SearchPriceWebView: buildSearchURL returned nil")
            return nil
        }
        print("🔗 SearchPriceWebView: Built URL string: \(urlString)")
        let url = URL(string: urlString)
        print("🔗 SearchPriceWebView: Final URL: \(url?.absoluteString ?? "nil")")
        return url
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = searchURL {
                    ZStack {
                        SimpleWebView(url: url)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Unable to Load Search")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        if website.isEmpty {
                            Text("No store selected. Please select a store from the search tab.")
                        } else {
                            Text("Invalid website selection: '\(website)'")
                        }
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle(selectItemsMode ? "Select Item - \(website)" : "Browse - \(website)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Help") {
                        showingHelpAlert = true
                    }
                }
            }
            .alert("How to Use", isPresented: $showingHelpAlert) {
                Button("OK") { }
            } message: {
                Text("Browse the website to view items and prices. Use this for research and price comparison.")
            }
        }
    }
}
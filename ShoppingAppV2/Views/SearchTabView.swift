import SwiftUI
import WebKit

// Data structure for prefill information
struct PrefillData {
    let name: String
    let price: Double
    
    var description: String {
        return "name='\(name)', price=\(price)"
    }
}

// Dedicated state manager for prefill data persistence
class PrefillDataManager: ObservableObject {
    @Published var data: PrefillData?
    private var lastSetData: PrefillData? // Fallback storage
    
    func setPrefillData(name: String, price: Double) {
        print("🔧 PrefillDataManager: Setting data - name='\(name)', price=\(price)")
        let newData = PrefillData(name: name, price: price)
        data = newData
        lastSetData = newData // Store fallback copy
        print("🔧 PrefillDataManager: Data set successfully - \(data!.description)")
    }
    
    func clearData() {
        print("🔧 PrefillDataManager: Clearing data")
        data = nil
        lastSetData = nil
    }
    
    func getCurrentData() -> PrefillData? {
        print("🔧 PrefillDataManager: Getting current data - \(data?.description ?? "nil")")
        
        // Fallback mechanism: if main data is nil but we have a backup, restore it
        if data == nil && lastSetData != nil {
            print("🔧 PrefillDataManager: Data was lost! Restoring from fallback - \(lastSetData!.description)")
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
    
    @State private var itemName = ""
    @State private var priceSearchSpecification = ""
    @State private var selectedWebsite = ""
    @State private var selectItemsMode = false
    @State private var showingPriceSearchWebView = false
    @State private var showingAddItem = false
    @StateObject private var prefillManager = PrefillDataManager()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with top padding
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search for Items")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Search for items across different stores. Enable 'Select Items?' to browse and manually add prices using the floating button.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20) // Add top padding so content doesn't stick
                    
                    // Item Name Field
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
                    
                    // Specification Field
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
                    
                    // Store Selection
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
                    
                    // Select Items Toggle
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
                    
                    // Search Button
                    Button(action: {
                        isTextFieldFocused = false
                        showingPriceSearchWebView = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search Price")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(itemName.isEmpty || selectedWebsite.isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(itemName.isEmpty || selectedWebsite.isEmpty)
                    .padding(.horizontal)
                    
                    // Bottom spacer
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTextFieldFocused = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showingPriceSearchWebView) {
                if selectItemsMode {
                    SearchWithManualEntryView(
                        itemName: itemName,
                        specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                        website: selectedWebsite,
                        settingsService: settingsService,
                        onItemAdded: { price, name in
                            print("🔄 Starting prefill process: name='\(name)', price=\(price)")
                            
                            // Set prefill data using the manager
                            prefillManager.setPrefillData(name: name, price: price)
                            
                            // Properly sequence the sheet transitions
                            print("📝 Closing search sheet...")
                            showingPriceSearchWebView = false
                            
                            // Delay opening the new sheet to ensure clean transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                print("📝 Opening AddItem sheet with data: \(prefillManager.getCurrentData()?.description ?? "nil")")
                                showingAddItem = true
                            }
                        }
                    )
                } else {
                    SearchPriceWebView(
                        itemName: itemName,
                        specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                        website: selectedWebsite,
                        selectedPrice: .constant(nil),
                        selectedItemName: .constant(nil),
                        settingsService: settingsService,
                        selectItemsMode: false
                    )
                }
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                // Clear prefill data when sheet is dismissed
                print("🗂️ AddItem sheet dismissed, clearing prefill data")
                prefillManager.clearData()
            }) {
                Group {
                    let currentData = prefillManager.getCurrentData()
                    let _ = print("🗂️ Creating AddItemView sheet with data: \(currentData?.description ?? "nil")")
                    AddItemView(
                        store: store,
                        locationManager: locationManager,
                        aiService: aiService,
                        settingsService: settingsService,
                        prefillName: currentData?.name,
                        prefillPrice: currentData?.price
                    )
                }
            }
            .onAppear {
                // Initialize selected website if empty
                if selectedWebsite.isEmpty && !settingsService.stores.isEmpty {
                    if let defaultStore = settingsService.getDefaultStore() {
                        selectedWebsite = defaultStore.name
                    } else {
                        selectedWebsite = settingsService.stores.first!.name
                    }
                }
            }
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
    
    private var searchURL: URL? {
        let searchTerm = specification != nil ? "\(itemName) \(specification!)" : itemName
        guard let urlString = settingsService.buildSearchURL(for: website, searchTerm: searchTerm) else {
            return nil
        }
        return URL(string: urlString)
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
                    Text("Invalid website selection")
                        .foregroundColor(.red)
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
    
    private var searchURL: URL? {
        let searchTerm = specification != nil ? "\(itemName) \(specification!)" : itemName
        guard let urlString = settingsService.buildSearchURL(for: website, searchTerm: searchTerm) else {
            return nil
        }
        return URL(string: urlString)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = searchURL {
                    ZStack {
                        SimpleWebView(url: url)
                    }
                } else {
                    Text("Invalid website selection")
                        .foregroundColor(.red)
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


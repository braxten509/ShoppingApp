import SwiftUI
import WebKit

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
    @State private var webViewSelectedPrice: Double?
    @State private var webViewSelectedItemName: String?
    @State private var showingAddItem = false
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
                        
                        Text("Search for items across different stores. Enable 'Select Items?' to capture item names and manually enter prices, just like photo/manual input.")
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
                SearchPriceWebView(
                    itemName: itemName,
                    specification: priceSearchSpecification.isEmpty ? nil : priceSearchSpecification,
                    website: selectedWebsite,
                    selectedPrice: $webViewSelectedPrice,
                    selectedItemName: $webViewSelectedItemName,
                    settingsService: settingsService,
                    selectItemsMode: selectItemsMode
                )
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(
                    store: store,
                    locationManager: locationManager,
                    aiService: aiService,
                    settingsService: settingsService,
                    prefillName: webViewSelectedItemName ?? itemName,
                    prefillPrice: nil  // Don't prefill price when coming from search
                )
            }
            .onChange(of: webViewSelectedItemName) { _, itemName in
                if let _ = itemName, selectItemsMode {
                    // Reset the search state
                    showingPriceSearchWebView = false
                    
                    // Open AddItemView with prefilled name only (no price)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingAddItem = true
                    }
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
                        SearchWebView(
                            url: url,
                            selectedPrice: $selectedPrice,
                            selectedItemName: $selectedItemName,
                            selectItemsMode: selectItemsMode,
                            onDismiss: {
                                presentationMode.wrappedValue.dismiss()
                            },
                            onNameSelected: selectItemsMode ? { itemName in
                                selectedItemName = itemName
                                presentationMode.wrappedValue.dismiss()
                            } : nil
                        )
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
                if selectItemsMode {
                    Text("Tap directly on any item to select it. The app will capture the item name and let you enter the price manually, just like photo/manual input.")
                } else {
                    Text("Browse the website to view items and prices. Items will not be added to your cart unless 'Select Items?' is enabled.")
                }
            }
        }
    }
}

struct SearchWebView: UIViewRepresentable {
    let url: URL
    @Binding var selectedPrice: Double?
    @Binding var selectedItemName: String?
    let selectItemsMode: Bool
    var onDismiss: () -> Void
    var onNameSelected: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Enable user interaction
        webView.isUserInteractionEnabled = true
        webView.scrollView.isUserInteractionEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        
        // Only inject JavaScript if select items mode is enabled
        if selectItemsMode {
            // Use the same JavaScript code from PriceSearchWebView
            let jsCode = """
            function setupPriceSelection() {
                // Remove any existing event listeners
                document.removeEventListener('click', handleClick);
                
                // Add click handler
                document.addEventListener('click', handleClick);
            }
            
            function handleClick(event) {
                let element = event.target;
                
                // Try to find the product container first
                let productContainer = findProductContainer(element);
                if (productContainer) {
                    element = productContainer;
                }
                
                // Try to find price and item name from clicked element or its parents
                let priceText = findPrice(element);
                let itemName = findItemName(element);
                
                console.log('Clicked element:', element);
                console.log('Found item name:', itemName);
                
                if (itemName) {
                    // Send only the item name back to Swift
                    window.webkit.messageHandlers.priceSelection.postMessage({
                        itemName: itemName
                    });
                } else {
                    // Show visual feedback that we're trying to capture the item name
                    console.log('Could not find item name');
                }
            }
            
            function findProductContainer(element) {
                // Look for common product container classes
                const containerSelectors = [
                    '.product-item',
                    '.item-tile',
                    '.product-tile',
                    '.search-result-item',
                    '.product-card',
                    '.item-card',
                    '.product-container',
                    '.search-item',
                    '.grid-item',
                    '.catalog-item',
                    '.item-container',
                    '[data-product-id]',
                    '[data-item]',
                    '[data-testid*="product"]',
                    '[data-test*="product"]',
                    '.product-row',
                    '.product-grid-item',
                    '.search-result',
                    '.item-result'
                ];
                
                for (let i = 0; i < 10; i++) {
                    if (!element) break;
                    
                    for (const selector of containerSelectors) {
                        if (element.matches && element.matches(selector)) {
                            return element;
                        }
                    }
                    
                    element = element.parentElement;
                }
                
                return null;
            }
            
            function findPrice(element) {
                // Website-specific price selectors
                const priceSelectors = [
                    '.price',
                    '.cost',
                    '.amount',
                    '.product-price',
                    '.item-price',
                    '.current-price',
                    '.sale-price',
                    '.regular-price',
                    '.price-current',
                    '.price-display',
                    '[data-testid*="price"]',
                    '[data-test*="price"]',
                    '[data-automation-id*="price"]',
                    '[aria-label*="dollar"]',
                    '[aria-label*="price"]',
                    '.price-container',
                    '.price-wrapper',
                    '.currency',
                    '.money'
                ];
                
                let foundPrices = [];
                
                // First try to find price using specific selectors within the clicked area
                for (let i = 0; i < 8; i++) {
                    if (!element) break;
                    
                    for (const selector of priceSelectors) {
                        const priceElements = element.querySelectorAll(selector);
                        for (const priceElement of priceElements) {
                            const price = extractPriceFromText(priceElement.textContent || priceElement.innerText || '');
                            if (price) {
                                foundPrices.push({
                                    price: price,
                                    element: priceElement,
                                    text: priceElement.textContent || priceElement.innerText || ''
                                });
                            }
                        }
                    }
                    
                    // Also check if current element matches any selector
                    for (const selector of priceSelectors) {
                        if (element.matches && element.matches(selector)) {
                            const price = extractPriceFromText(element.textContent || element.innerText || '');
                            if (price) {
                                foundPrices.push({
                                    price: price,
                                    element: element,
                                    text: element.textContent || element.innerText || ''
                                });
                            }
                        }
                    }
                    
                    element = element.parentElement;
                }
                
                // If we found multiple prices, prefer the main price over unit prices
                if (foundPrices.length > 1) {
                    return selectMainPrice(foundPrices);
                } else if (foundPrices.length === 1) {
                    return foundPrices[0].price;
                }
                
                // Fallback: look for price patterns in text content
                element = arguments[0]; // Reset to original element
                for (let i = 0; i < 5; i++) {
                    if (!element) break;
                    
                    let text = element.textContent || element.innerText || '';
                    const price = extractPriceFromText(text);
                    if (price) return price;
                    
                    element = element.parentElement;
                }
                
                return null;
            }
            
            function selectMainPrice(priceObjects) {
                // Filter out unit prices (containing /oz, /lb, /ct, /100ct, etc.)
                const mainPrices = priceObjects.filter(p => !isUnitPrice(p.text));
                if (mainPrices.length > 0) {
                    // Among main prices, prefer the one with better styling (bold, larger font, etc.)
                    return selectBestStyledPrice(mainPrices) || mainPrices[0].price;
                }
                
                // If all are unit prices, return the first one
                return priceObjects[0].price;
            }
            
            function isUnitPrice(text) {
                const unitPricePatterns = [
                    /\\/\\s*(oz|lb|lbs|gram|g|kg|ct|count|100ct|fl\\s*oz|ml|l|each|ea)\\b/i,
                    /per\\s+(oz|lb|lbs|gram|g|kg|ct|count|100ct|fl\\s*oz|ml|l|each|ea)\\b/i
                ];
                return unitPricePatterns.some(pattern => pattern.test(text));
            }
            
            function selectBestStyledPrice(priceObjects) {
                // Prefer prices that are styled prominently (bold, larger font, etc.)
                for (const priceObj of priceObjects) {
                    const style = window.getComputedStyle(priceObj.element);
                    const fontSize = parseInt(style.fontSize);
                    const fontWeight = style.fontWeight;
                    
                    // Prefer bold or larger text
                    if (fontWeight === 'bold' || fontWeight >= 600 || fontSize >= 16) {
                        return priceObj.price;
                    }
                }
                return null;
            }
            
            function extractPriceFromText(text) {
                if (!text) return null;
                
                // Remove common non-price text
                text = text.replace(/was|orig|msrp|list|compare at|you save|sale|off/gi, '');
                
                // Match various price formats: $1.99, 1.99, $1,234.99, 1.234,99 (European)
                const pricePatterns = [
                    /\\$([0-9,]+\\.[0-9]{2})/,  // $1,234.56
                    /\\$([0-9,]+)/,         // $1,234
                    /([0-9,]+\\.[0-9]{2})/,    // 1,234.56
                    /([0-9]+,[0-9]{2})/,      // European format 1234,56
                    /([0-9]+\\.[0-9]{2})/      // 1234.56
                ];
                
                for (const pattern of pricePatterns) {
                    const match = text.match(pattern);
                    if (match) {
                        let priceStr = match[1].replace(/,/g, '');
                        const price = parseFloat(priceStr);
                        if (price > 0 && price < 10000) { // Reasonable price range
                            return priceStr;
                        }
                    }
                }
                
                return null;
            }
            
            function findItemName(element) {
                // Website-specific title selectors
                const titleSelectors = [
                    '.item-name',
                    '.product-name',
                    '.title',
                    'h1', 'h2', 'h3',
                    '.product-description',
                    '.item-title',
                    '.product-title',
                    '.product-title-link',
                    '[data-testid*="title"]',
                    '[data-test*="title"]',
                    '[data-automation-id*="title"]',
                    'a[title]',
                    '.name',
                    '.item-description',
                    '.product-link'
                ];
                
                // Look for item name using specific selectors
                for (let i = 0; i < 5; i++) {
                    if (!element) break;
                    
                    for (const selector of titleSelectors) {
                        const nameElement = element.querySelector(selector);
                        if (nameElement) {
                            const text = (nameElement.textContent || nameElement.innerText || nameElement.getAttribute('title') || '').trim();
                            if (text && text.length > 3 && text.length < 200 && !isPriceText(text)) {
                                return text;
                            }
                        }
                    }
                    
                    // Check if current element matches any selector and has good text
                    for (const selector of titleSelectors) {
                        if (element.matches && element.matches(selector)) {
                            const text = (element.textContent || element.innerText || element.getAttribute('title') || '').trim();
                            if (text && text.length > 3 && text.length < 200 && !isPriceText(text)) {
                                return text;
                            }
                        }
                    }
                    
                    element = element.parentElement;
                }
                
                // Fallback: look for meaningful text in the clicked area
                element = arguments[0]; // Reset to original element
                for (let i = 0; i < 3; i++) {
                    if (!element) break;
                    
                    let text = (element.textContent || element.innerText || '').trim();
                    if (text.length > 5 && text.length < 150 && !isPriceText(text) && !isGenericText(text)) {
                        return text;
                    }
                    
                    element = element.parentElement;
                }
                
                return 'Selected Item';
            }
            
            function isPriceText(text) {
                return /^\\$?[0-9,]+\\.?[0-9]*$/.test(text.trim());
            }
            
            function isGenericText(text) {
                const genericWords = ['add to cart', 'buy now', 'select', 'choose', 'view', 'more', 'details', 'info', 'price', 'sale', 'new', 'hot', 'popular'];
                const lowerText = text.toLowerCase();
                return genericWords.some(word => lowerText === word || lowerText.includes(word));
            }
            
            // Set up when page loads
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupPriceSelection);
            } else {
                setupPriceSelection();
            }
            
            // Also set up after any dynamic content loads
            setTimeout(setupPriceSelection, 2000);
            setTimeout(setupPriceSelection, 5000); // Additional delay for slow-loading content
            """
            
            let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            webView.configuration.userContentController.addUserScript(userScript)
            webView.configuration.userContentController.add(context.coordinator, name: "priceSelection")
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: SearchWebView
        
        init(_ parent: SearchWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard parent.selectItemsMode else { return }
            
            if message.name == "priceSelection", let data = message.body as? [String: Any] {
                if let itemName = data["itemName"] as? String {
                    DispatchQueue.main.async {
                        if let onNameSelected = self.parent.onNameSelected {
                            onNameSelected(itemName)
                        } else {
                            // Fallback to original behavior
                            self.parent.selectedItemName = itemName
                            self.parent.onDismiss()
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only re-inject JavaScript if select items mode is enabled
            guard parent.selectItemsMode else { return }
            
            let jsCode = """
            setTimeout(function() {
                setupPriceSelection();
            }, 1000);
            """
            webView.evaluateJavaScript(jsCode)
        }
    }
}
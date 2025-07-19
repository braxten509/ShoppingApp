import SwiftUI
import WebKit

struct PriceSearchWebView: UIViewRepresentable {
    let url: URL
    @Binding var selectedPrice: Double?
    @Binding var selectedItemName: String?
    var onDismiss: () -> Void
    var onPriceSelected: (Double, String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        print("🏗️ Creating WKWebView for PriceSearchWebView")
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Enable user interaction
        webView.isUserInteractionEnabled = true
        webView.scrollView.isUserInteractionEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        
        // Simple JavaScript to test message handler only
        let jsCode = """
        function debugLog(message) {
            console.log(message);
            try {
                window.webkit.messageHandlers.debugLog.postMessage(message);
            } catch(e) {
                console.log('Debug log failed:', e);
            }
        }
        
        debugLog('🚀 JavaScript loaded - no automatic price detection');
        
        // Test if message handler is available
        function testMessageHandler() {
            debugLog('🧪 Testing message handler...');
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.priceSelection) {
                debugLog('✅ Message handler is available');
            } else {
                debugLog('❌ Message handler is NOT available');
                debugLog('window.webkit: ' + (window.webkit ? 'exists' : 'undefined'));
            }
        }
        
        // Test message handler when page loads
        debugLog('📄 Document ready state: ' + document.readyState);
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', testMessageHandler);
        } else {
            testMessageHandler();
        }
        """
        
        let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
        webView.configuration.userContentController.add(context.coordinator, name: "priceSelection")
        webView.configuration.userContentController.add(context.coordinator, name: "debugLog")
        
        print("📝 JavaScript user script added with length: \(jsCode.count) characters")
        print("🔗 Message handler 'priceSelection' added")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("🌐 Loading URL: \(url)")
        webView.load(URLRequest(url: url))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: PriceSearchWebView
        
        init(_ parent: PriceSearchWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("📱 Received message: \(message.name)")
            print("📱 Message body: \(message.body)")
            
            if message.name == "debugLog" {
                print("🟨 JS Debug: \(message.body)")
                return
            }
            
            if message.name == "priceSelection", let data = message.body as? [String: Any] {
                print("📱 Processing priceSelection message")
                print("📱 Data: \(data)")
                
                if let priceString = data["price"] as? String,
                   let price = Double(priceString),
                   let itemName = data["itemName"] as? String {
                    
                    print("📱 Successfully parsed price: \(price), itemName: \(itemName)")
                    
                    DispatchQueue.main.async {
                        self.parent.onPriceSelected(price, itemName)
                    }
                } else {
                    print("📱 Failed to parse price or itemName from data")
                }
            } else {
                print("📱 Message name doesn't match 'priceSelection' or data isn't dictionary")
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading navigation")
            
            // Re-inject JavaScript after page loads completely
            let jsCode = """
            setTimeout(function() {
                debugLog('⏰ Delayed JavaScript execution triggered');
                testMessageHandler();
                setupPriceHighlighting();
            }, 1000);
            """
            webView.evaluateJavaScript(jsCode) { (result, error) in
                if let error = error {
                    print("❌ JavaScript evaluation error: \(error)")
                } else {
                    print("✅ JavaScript evaluation successful")
                }
            }
        }
    }
}

struct PriceSearchView: View {
    let itemName: String
    let specification: String?
    let website: String
    @Binding var selectedPrice: Double?
    @Binding var selectedItemName: String?
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingHelpAlert = false
    @State private var showingManualPriceEntry = false
    @State private var manualPriceText: String = ""
    
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
                        PriceSearchWebView(
                            url: url,
                            selectedPrice: $selectedPrice,
                            selectedItemName: $selectedItemName,
                            onDismiss: {
                                presentationMode.wrappedValue.dismiss()
                            },
                            onPriceSelected: { _, _ in
                                // No automatic price detection anymore
                            }
                        )
                        
                        // Manual price entry overlay
                        if showingManualPriceEntry {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        showingManualPriceEntry = false
                                    }
                                    manualPriceText = ""
                                }
                            
                            VStack(spacing: 20) {
                                Text("Add Price")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                TextField("$0.00", text: $manualPriceText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                    .keyboardToolbar()
                                    .font(.title)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 150)
                                
                                HStack(spacing: 20) {
                                    Button("Cancel") {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            showingManualPriceEntry = false
                                        }
                                        manualPriceText = ""
                                    }
                                    .foregroundColor(.red)
                                    .font(.headline)
                                    
                                    Button("Done") {
                                        if let manualPrice = Double(manualPriceText), manualPrice > 0 {
                                            selectedPrice = manualPrice
                                            selectedItemName = "Selected Item"
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    }
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .disabled(manualPriceText.isEmpty || Double(manualPriceText) == nil || Double(manualPriceText) ?? 0 <= 0)
                                }
                            }
                            .padding(30)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(radius: 20)
                            .frame(maxWidth: 300)
                            .scaleEffect(showingManualPriceEntry ? 1.0 : 0.1)
                            .opacity(showingManualPriceEntry ? 1.0 : 0.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingManualPriceEntry)
                        }
                        
                        // Floating "Add Price" button
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        showingManualPriceEntry = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Add Price")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .scaleEffect(showingManualPriceEntry ? 0.0 : 1.0)
                                .opacity(showingManualPriceEntry ? 0.0 : 1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingManualPriceEntry)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
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

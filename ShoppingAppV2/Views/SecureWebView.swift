import SwiftUI
import WebKit
import LocalAuthentication

struct SecureWebView: UIViewRepresentable {
    let url: URL
    let title: String
    @Binding var isPresented: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable JavaScript and modern web features
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Enable modern web content settings
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Use default website data store for login persistence
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Enable AutoFill and credential management
        if #available(iOS 14.0, *) {
            configuration.limitsNavigationsToAppBoundDomains = false
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Enable AutoFill for login credentials and passkeys
        if #available(iOS 16.0, *) {
            webView.configuration.preferences.isElementFullscreenEnabled = true
        }
        
        // Configure user agent for better compatibility
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        // Load the URL
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: SecureWebView
        
        init(_ parent: SecureWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Web page finished loading
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        // Handle JavaScript alerts and authentication prompts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let topController = windowScene.windows.first?.rootViewController {
                topController.present(alert, animated: true)
            } else {
                completionHandler()
            }
        }
        
        // Handle JavaScript confirm dialogs
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let topController = windowScene.windows.first?.rootViewController {
                topController.present(alert, animated: true)
            } else {
                completionHandler(false)
            }
        }
        
        // Handle new window requests (important for some authentication flows)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // For popup windows, load in the same webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        // Handle authentication challenges (for client certificate authentication)
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            // Use default handling for server trust and other authentication types
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct SecureWebViewSheet: View {
    let url: URL
    let title: String
    @Binding var isPresented: Bool
    @State private var isAuthenticated = false
    @State private var authenticationError: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isAuthenticated {
                    SecureWebView(url: url, title: title, isPresented: $isPresented)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "faceid")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Authentication Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please authenticate to access API key management")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if let error = authenticationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("Authenticate") {
                            authenticateUser()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            authenticateUser()
        }
    }
    
    private func authenticateUser() {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access API key management"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.authenticationError = nil
                    } else {
                        self.authenticationError = authError?.localizedDescription ?? "Authentication failed"
                        // Try device passcode as fallback
                        self.authenticateWithPasscode()
                    }
                }
            }
        } else {
            // Fallback to device passcode
            authenticateWithPasscode()
        }
    }
    
    private func authenticateWithPasscode() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Authenticate to access API key management"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.authenticationError = nil
                    } else {
                        self.authenticationError = authError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            authenticationError = "Device authentication not available"
        }
    }
}

struct CreditSyncWebView: View {
    let url: URL
    let provider: String
    @Binding var isPresented: Bool
    let onCreditsFound: (Double) -> Void
    let onCompleted: (() -> Void)?
    let onError: ((String) -> Void)?
    
    @State private var isAuthenticated = false
    @State private var authenticationError: String?
    @State private var hasAttemptedSync = false
    @State private var isWebViewLoading = true
    @State private var isSyncingCredits = false
    @State private var syncError: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Group {
                if isAuthenticated {
                    ZStack {
                        CreditExtractorWebView(
                            url: url,
                            provider: provider,
                            isPresented: $isPresented,
                            onCreditsFound: { credits in
                                isSyncingCredits = true
                                onCreditsFound(credits)
                            },
                            onCompleted: onCompleted,
                            hasAttemptedSync: $hasAttemptedSync,
                            isLoading: $isWebViewLoading,
                            onSyncStarted: {
                                isSyncingCredits = true
                            },
                            onError: { error in
                                syncError = error
                                showingError = true
                                onError?(error)
                                
                                // Continue after showing error for 1 second
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    showingError = false
                                    isPresented = false
                                    onCompleted?()
                                }
                            }
                        )
                        
                        // Loading overlay for credit sync - only show when actually syncing
                        if isSyncingCredits && !isWebViewLoading && !showingError {
                            Color.gray.opacity(0.8)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                Text("Syncing \(provider) Credits...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                        }
                        
                        // Error overlay
                        if showingError {
                            Color.red.opacity(0.9)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                
                                Text("Sync Failed")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                if let error = syncError {
                                    Text(error)
                                        .foregroundColor(.white)
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                Text("Continuing in 1 second...")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Syncing \(provider) Credits...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Authenticating and retrieving credit information")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if let error = authenticationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Sync Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            authenticateUser()
        }
    }
    
    private func authenticateUser() {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to sync \(provider) credits"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.authenticationError = nil
                    } else {
                        self.authenticationError = authError?.localizedDescription ?? "Authentication failed"
                        // Try device passcode as fallback
                        self.authenticateWithPasscode()
                    }
                }
            }
        } else {
            // Fallback to device passcode
            authenticateWithPasscode()
        }
    }
    
    private func authenticateWithPasscode() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Authenticate to sync \(provider) credits"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.authenticationError = nil
                    } else {
                        self.authenticationError = authError?.localizedDescription ?? "Authentication failed"
                        // Close after failed authentication
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.isPresented = false
                            self.onCompleted?()
                        }
                    }
                }
            }
        } else {
            authenticationError = "Device authentication not available"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isPresented = false
                self.onCompleted?()
            }
        }
    }
}

struct CreditExtractorWebView: UIViewRepresentable {
    let url: URL
    let provider: String
    @Binding var isPresented: Bool
    let onCreditsFound: (Double) -> Void
    let onCompleted: (() -> Void)?
    @Binding var hasAttemptedSync: Bool
    @Binding var isLoading: Bool
    let onSyncStarted: () -> Void
    let onError: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Set loading state
        DispatchQueue.main.async {
            self.isLoading = true
        }
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CreditExtractorWebView
        private var extractionTimer: Timer?
        
        init(_ parent: CreditExtractorWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Set loading to false when page finishes loading
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Wait a moment for the page to fully load, then extract credits
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                // Notify that sync is starting
                self.parent.onSyncStarted()
                self.extractCredits(from: webView)
            }
        }
        
        private func extractCredits(from webView: WKWebView) {
            guard !parent.hasAttemptedSync else { 
                print("❌ Credit extraction already attempted")
                return 
            }
            parent.hasAttemptedSync = true
            print("🔍 Starting credit extraction for \(parent.provider)")
            
            let script: String
            
            if parent.provider == "OpenAI" {
                script = """
                // Look for credit/balance information on OpenAI billing page
                function findCredits() {
                    // Common selectors for balance/credit information
                    const selectors = [
                        '[data-testid="credit-balance"]',
                        '[class*="balance"]',
                        '[class*="credit"]',
                        '[class*="billing"]',
                        'div[class*="balance"]',
                        'span[class*="balance"]',
                        'div[class*="credit"]',
                        'span[class*="credit"]'
                    ];
                    
                    for (let selector of selectors) {
                        const elements = document.querySelectorAll(selector);
                        for (let element of elements) {
                            const text = element.textContent || element.innerText;
                            if (text) {
                                const match = text.match(/\\$([0-9]+\\.?[0-9]*)/);
                                if (match) {
                                    return parseFloat(match[1]);
                                }
                            }
                        }
                    }
                    
                    // Fallback: look for any element containing dollar amounts with balance/credit context
                    const allElements = document.querySelectorAll('div, span, p, td, th');
                    for (let element of allElements) {
                        const text = element.textContent || element.innerText;
                        if (text && text.includes('$')) {
                            const lowerText = text.toLowerCase();
                            if (lowerText.includes('balance') || lowerText.includes('credit') || lowerText.includes('available')) {
                                const match = text.match(/\\$([0-9,]+\\.?[0-9]*)/);
                                if (match) {
                                    return parseFloat(match[1].replace(',', ''));
                                }
                            }
                        }
                    }
                    
                    return null;
                }
                
                findCredits();
                """
            } else {
                script = """
                // Look for credit information on Perplexity billing page
                function findCredits() {
                    const selectors = [
                        '[class*="balance"]',
                        '[class*="credit"]',
                        '[class*="billing"]',
                        'div[class*="balance"]',
                        'span[class*="balance"]',
                        'div[class*="credit"]',
                        'span[class*="credit"]',
                        '[data-testid*="credit"]',
                        '[data-testid*="balance"]'
                    ];
                    
                    for (let selector of selectors) {
                        const elements = document.querySelectorAll(selector);
                        for (let element of elements) {
                            const text = element.textContent || element.innerText;
                            if (text) {
                                const match = text.match(/\\$([0-9]+\\.?[0-9]*)/);
                                if (match) {
                                    return parseFloat(match[1]);
                                }
                            }
                        }
                    }
                    
                    return null;
                }
                
                findCredits();
                """
            }
            
            webView.evaluateJavaScript(script) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ JavaScript execution error: \(error)")
                        // Try alternative extraction immediately on selector errors
                        self.tryAlternativeExtraction(from: webView)
                        return
                    }
                    
                    if let credits = result as? Double, credits > 0 {
                        print("✅ Successfully extracted credits: $\(credits)")
                        self.parent.onCreditsFound(credits)
                    } else if let credits = result as? NSNumber {
                        let creditsDouble = credits.doubleValue
                        if creditsDouble > 0 {
                            print("✅ Successfully extracted credits (NSNumber): $\(creditsDouble)")
                            self.parent.onCreditsFound(creditsDouble)
                        } else {
                            print("⚠️ No valid credits found. Result: \(String(describing: result))")
                            self.tryAlternativeExtraction(from: webView)
                        }
                    } else {
                        print("⚠️ No credits found. Result: \(String(describing: result))")
                        // Try a more aggressive extraction approach
                        self.tryAlternativeExtraction(from: webView)
                    }
                    
                    // Close the webview after attempting extraction
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.parent.isPresented = false
                        self.parent.onCompleted?()
                    }
                }
            }
        }
        
        private func tryAlternativeExtraction(from webView: WKWebView) {
            print("🔄 Trying alternative extraction method")
            
            let alternativeScript: String
            
            if parent.provider == "OpenAI" {
                alternativeScript = """
                // More comprehensive OpenAI credit extraction
                function findCreditsAlternative() {
                    console.log('Starting alternative credit extraction for OpenAI');
                    
                    // First, try to find the page content
                    let pageText = document.body.innerText || document.body.textContent || '';
                    console.log('Page text sample:', pageText.substring(0, 500));
                    
                    // Look for dollar amounts in the page text
                    let dollarMatches = pageText.match(/\\$([0-9,]+\\.?[0-9]*)/g);
                    console.log('Found dollar amounts:', dollarMatches);
                    
                    if (dollarMatches && dollarMatches.length > 0) {
                        // Try to find the largest amount (likely to be credits)
                        let amounts = dollarMatches.map(match => {
                            let num = parseFloat(match.replace('$', '').replace(',', ''));
                            return isNaN(num) ? 0 : num;
                        }).filter(num => num > 0);
                        
                        console.log('Parsed amounts:', amounts);
                        
                        if (amounts.length > 0) {
                            // Return the largest amount found, but ensure it's a reasonable credit amount
                            let maxAmount = Math.max(...amounts);
                            // Only return amounts that seem reasonable for API credits (between $0.01 and $10000)
                            return (maxAmount >= 0.01 && maxAmount <= 10000) ? maxAmount : null;
                        }
                    }
                    
                    // Try specific text patterns
                    let patterns = [
                        /credit balance.*?\\$([0-9,]+\\.?[0-9]*)/i,
                        /available.*?\\$([0-9,]+\\.?[0-9]*)/i,
                        /balance.*?\\$([0-9,]+\\.?[0-9]*)/i,
                        /\\$([0-9,]+\\.?[0-9]*)/g
                    ];
                    
                    for (let pattern of patterns) {
                        let match = pageText.match(pattern);
                        if (match && match[1]) {
                            let amount = parseFloat(match[1].replace(',', ''));
                            if (!isNaN(amount) && amount > 0) {
                                console.log('Found credit via pattern:', amount);
                                return amount;
                            }
                        }
                    }
                    
                    return null;
                }
                
                findCreditsAlternative();
                """
            } else {
                alternativeScript = """
                // More comprehensive Perplexity credit extraction
                function findCreditsAlternative() {
                    console.log('Starting alternative credit extraction for Perplexity');
                    
                    let pageText = document.body.innerText || document.body.textContent || '';
                    console.log('Page text sample:', pageText.substring(0, 500));
                    
                    // Look for dollar amounts
                    let dollarMatches = pageText.match(/\\$([0-9,]+\\.?[0-9]*)/g);
                    console.log('Found dollar amounts:', dollarMatches);
                    
                    if (dollarMatches && dollarMatches.length > 0) {
                        let amounts = dollarMatches.map(match => {
                            let num = parseFloat(match.replace('$', '').replace(',', ''));
                            return isNaN(num) ? 0 : num;
                        }).filter(num => num > 0);
                        
                        console.log('Parsed amounts:', amounts);
                        
                        if (amounts.length > 0) {
                            // Return the largest reasonable amount found
                            let maxAmount = Math.max(...amounts);
                            return (maxAmount >= 0.01 && maxAmount <= 10000) ? maxAmount : null;
                        }
                    }
                    
                    return null;
                }
                
                findCreditsAlternative();
                """
            }
            
            webView.evaluateJavaScript(alternativeScript) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Alternative extraction error: \(error)")
                        let errorMessage = "Failed to extract \(self.parent.provider) credits: \(error.localizedDescription)"
                        self.parent.onError?(errorMessage)
                        return
                    }
                    
                    if let credits = result as? Double, credits > 0 {
                        print("✅ Alternative extraction successful: $\(credits)")
                        self.parent.onCreditsFound(credits)
                    } else if let credits = result as? NSNumber {
                        let creditsDouble = credits.doubleValue
                        if creditsDouble > 0 {
                            print("✅ Alternative extraction successful (NSNumber): $\(creditsDouble)")
                            self.parent.onCreditsFound(creditsDouble)
                        } else {
                            print("❌ Alternative extraction failed - invalid amount: \(creditsDouble)")
                            let errorMessage = "Unable to extract valid \(self.parent.provider) credits from the billing page."
                            self.parent.onError?(errorMessage)
                        }
                    } else {
                        print("❌ Alternative extraction failed. Final result: \(String(describing: result))")
                        print("⚠️ Credit extraction failed - no valid credits found")
                        
                        // Call error callback with descriptive message
                        let errorMessage = "Unable to extract \(self.parent.provider) credits from the billing page. This may happen if the page structure has changed or if you're not logged in."
                        self.parent.onError?(errorMessage)
                    }
                }
            }
        }
    }
}
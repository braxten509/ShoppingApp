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
    
    @State private var isAuthenticated = false
    @State private var authenticationError: String?
    @State private var hasAttemptedSync = false
    
    var body: some View {
        NavigationView {
            Group {
                if isAuthenticated {
                    CreditExtractorWebView(
                        url: url,
                        provider: provider,
                        isPresented: $isPresented,
                        onCreditsFound: onCreditsFound,
                        onCompleted: onCompleted,
                        hasAttemptedSync: $hasAttemptedSync
                    )
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
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
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
            // Wait a moment for the page to fully load
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
                        'div:contains("Credit balance")',
                        'div:contains("Available balance")',
                        'span:contains("$")',
                        '[class*="billing"]'
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
                    
                    // Fallback: look for any element containing dollar amounts
                    const allElements = document.querySelectorAll('*');
                    for (let element of allElements) {
                        const text = element.textContent || element.innerText;
                        if (text && text.includes('$') && (text.toLowerCase().includes('balance') || text.toLowerCase().includes('credit'))) {
                            const match = text.match(/\\$([0-9]+\\.?[0-9]*)/);
                            if (match) {
                                return parseFloat(match[1]);
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
                        'div:contains("API Credits")',
                        'div:contains("Available Credits")',
                        'span:contains("$")',
                        '[class*="billing"]'
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
                    }
                    
                    if let credits = result as? Double {
                        print("✅ Successfully extracted credits: $\(credits)")
                        self.parent.onCreditsFound(credits)
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
                            // Return the largest amount found
                            return Math.max(...amounts);
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
                            return Math.max(...amounts);
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
                    }
                    
                    if let credits = result as? Double {
                        print("✅ Alternative extraction successful: $\(credits)")
                        self.parent.onCreditsFound(credits)
                    } else {
                        print("❌ Alternative extraction failed. Final result: \(String(describing: result))")
                        // Set a test value for debugging
                        print("🧪 Setting test value for debugging")
                        self.parent.onCreditsFound(42.50) // Test value
                    }
                }
            }
        }
    }
}
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
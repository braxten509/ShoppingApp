import SwiftUI

struct APIKeysView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if settingsService.openAIAPIKey.isEmpty {
                        Button(action: {
                            apiKeyInput = ""
                            showingAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(settingsService.openAIAPIKey.suffix(4)))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.green)
                        Text("Get API Key from OpenAI")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            } header: {
                Text("OpenAI Configuration")
            }
            
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if settingsService.perplexityAPIKey.isEmpty {
                        Button(action: {
                            perplexityApiKeyInput = ""
                            showingPerplexityAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(settingsService.perplexityAPIKey.suffix(4)))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showingDeletePerplexityConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Link(destination: URL(string: "https://www.perplexity.ai/settings/api")!) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                        Text("Get API Key from Perplexity")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Perplexity Configuration")
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Set OpenAI API Key", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKeyInput)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                settingsService.openAIAPIKey = apiKeyInput
            }
        } message: {
            Text("Enter your OpenAI API key. You can find this in your OpenAI account settings.")
        }
        .alert("Delete API Key", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsService.openAIAPIKey = ""
            }
        } message: {
            Text("Are you sure you want to delete your API key? You'll need to enter it again to use the app's AI features.")
        }
        .alert("Set Perplexity API Key", isPresented: $showingPerplexityAPIKeyAlert) {
            TextField("API Key", text: $perplexityApiKeyInput)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                settingsService.perplexityAPIKey = perplexityApiKeyInput
            }
        } message: {
            Text("Enter your Perplexity API key. You can find this in your Perplexity account settings.")
        }
        .alert("Delete Perplexity API Key", isPresented: $showingDeletePerplexityConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsService.perplexityAPIKey = ""
            }
        } message: {
            Text("Are you sure you want to delete your Perplexity API key? You'll need to enter it again to use price search features.")
        }
    }
}

#Preview {
    NavigationView {
        APIKeysView(settingsService: SettingsService())
    }
}

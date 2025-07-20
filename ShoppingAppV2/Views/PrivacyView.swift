import SwiftUI

struct PrivacyView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Enable Location Access", isOn: $settingsService.locationAccessEnabled)
                        .font(.headline)
                        .disabled(!settingsService.aiEnabled || !settingsService.internetAccessEnabled)
                        .foregroundColor((!settingsService.aiEnabled || !settingsService.internetAccessEnabled) ? .secondary : .primary)
                    
                    Toggle("Enable AI", isOn: $settingsService.aiEnabled)
                        .font(.headline)
                        .disabled(!settingsService.internetAccessEnabled)
                        .foregroundColor(!settingsService.internetAccessEnabled ? .secondary : .primary)
                    
                    Toggle("Enable Internet Access", isOn: $settingsService.internetAccessEnabled)
                        .font(.headline)
                } header: {
                    Text("App Features")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !settingsService.internetAccessEnabled {
                            Text("• Internet disabled: All network-dependent features disabled")
                        } else if !settingsService.aiEnabled {
                            Text("• AI disabled: AI features and location access disabled")
                        } else if !settingsService.locationAccessEnabled {
                            Text("• Location disabled: Manual tax rate will be required")
                        } else {
                            Text("All features enabled")
                        }
                    }
                    .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Usage")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Location: Used for tax rate detection")
                            Text("• AI Services: Process images and text for price recognition")
                            Text("• Internet: Required for AI services and price search")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Privacy Information")
                } footer: {
                    Text("ShoppingApp processes data locally when possible. AI features require internet connectivity to external services.")
                        .font(.caption)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PrivacyView(settingsService: SettingsService())
}
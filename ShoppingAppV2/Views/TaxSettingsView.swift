import SwiftUI

struct TaxSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Use Manual Tax Rate", isOn: $settingsService.useManualTaxRate)
                        .font(.headline)
                        .disabled(settingsService.shouldForceManualTax)
                        .foregroundColor(settingsService.shouldForceManualTax ? .secondary : .primary)
                    
                    if settingsService.useManualTaxRate || settingsService.shouldForceManualTax {
                        HStack {
                            Text("Tax Rate:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            TextField("0.0", value: $settingsService.manualTaxRate, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .keyboardType(.decimalPad)
                                .keyboardToolbar()
                            
                            Text("%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Manual Tax Override")
                } footer: {
                    if settingsService.shouldForceManualTax {
                        Text("Manual tax rate is required when Location Access or AI is disabled.")
                    } else if settingsService.useManualTaxRate {
                        Text("Manual tax rate will override AI-based tax detection for all items.")
                    } else {
                        Text("AI will determine tax rates based on your settings above.")
                    }
                }
                
                if settingsService.locationAccessEnabled && !settingsService.useManualTaxRate && !settingsService.shouldForceManualTax {
                    Section {
                        Toggle("Item Specific Tax", isOn: $settingsService.useItemSpecificTax)
                            .font(.headline)
                    } header: {
                        Text("Tax Detection Method")
                    } footer: {
                        Text(settingsService.useItemSpecificTax ? 
                             "AI will attempt to determine exact tax rates for specific items based on item type and location." :
                             "Use general state and county tax rates for all items.")
                    }
                }
                
                if !settingsService.useManualTaxRate && !settingsService.shouldForceManualTax {
                    Section {
                        Toggle("Multi-Attempt Tax Detection", isOn: $settingsService.useMultiAttemptTaxDetection)
                            .font(.headline)
                        
                        if settingsService.useMultiAttemptTaxDetection {
                            HStack {
                                Text("Detection Attempts:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("Attempts", selection: $settingsService.taxDetectionAttempts) {
                                    ForEach(1...5, id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }
                    } header: {
                        Text("Advanced Tax Detection")
                    } footer: {
                        Text("Multiple attempts can improve accuracy but will increase API costs.")
                    }
                    
                    Section {
                        Picker("Search Depth", selection: $settingsService.taxSearchContextSize) {
                            Text("Low").tag("low")
                            Text("Medium").tag("medium")
                            Text("High").tag("high")
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Picker("Recency Filter", selection: Binding(
                            get: { settingsService.taxSearchRecencyFilter ?? "none" },
                            set: { newValue in
                                settingsService.taxSearchRecencyFilter = newValue == "none" ? nil : newValue
                            }
                        )) {
                            Text("None").tag("none")
                            Text("Last 6 months").tag("6months")
                            Text("Last year").tag("1year")
                            Text("Last 2 years").tag("2years")
                        }
                        .pickerStyle(MenuPickerStyle())
                    } header: {
                        Text("Search Parameters")
                    } footer: {
                        Text("Higher context size and recent data filters can improve accuracy but may increase costs.")
                    }
                }
            }
            .navigationTitle("Tax Settings")
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
    TaxSettingsView(settingsService: SettingsService())
}

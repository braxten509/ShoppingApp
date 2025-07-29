import SwiftUI

struct AISettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var historyService: HistoryService
    @State private var showingResetModelsAlert = false
    
    var body: some View {
        List {
            Section("AI Model Selection") {
                HStack {
                    Text("Tax Rate Analysis")
                    Spacer()
                    Text("sonar-pro")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.secondary)
                
                Picker("Photo Analysis", selection: $settingsService.selectedModelForPhotoPrice) {
                    ForEach(settingsService.aiModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Button("Reset All Models") {
                    showingResetModelsAlert = true
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section("Tax Detection Settings") {
                Toggle("Multi-attempt tax detection", isOn: $settingsService.useMultiAttemptTaxDetection)
                    .disabled(!settingsService.aiEnabled || !settingsService.internetAccessEnabled || settingsService.useManualTaxRate)
                    .foregroundColor((!settingsService.aiEnabled || !settingsService.internetAccessEnabled || settingsService.useManualTaxRate) ? .secondary : .primary)
                
                if settingsService.useMultiAttemptTaxDetection {
                    HStack {
                        Text("Number of attempts:")
                        Spacer()
                        Stepper("\(settingsService.taxDetectionAttempts)", value: $settingsService.taxDetectionAttempts, in: 2...10)
                            .labelsHidden()
                        Text("\(settingsService.taxDetectionAttempts)")
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                    
                    Text("Tax detection will try \(settingsService.taxDetectionAttempts) times and use the most common answer for better accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Search depth:")
                            Spacer()
                            Picker("Search Depth", selection: $settingsService.taxSearchContextSize) {
                                Text("Low (Fast)").tag("low")
                                Text("Medium").tag("medium")
                                Text("High (Thorough)").tag("high")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Text("Search recency:")
                            Spacer()
                            Picker("Search Recency", selection: Binding<String>(
                                get: { settingsService.taxSearchRecencyFilter ?? "none" },
                                set: { newValue in
                                    settingsService.taxSearchRecencyFilter = newValue == "none" ? nil : newValue
                                }
                            )) {
                                Text("Any time").tag("none")
                                Text("Past month").tag("month")
                                Text("Past week").tag("week")
                                Text("Past day").tag("day")
                                Text("Past hour").tag("hour")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        Text("Higher search depth provides more accurate tax rates but takes longer. Recent results may be more accurate for current tax rates.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            
            Section("Auto-Search Settings") {
                Toggle("Auto-open search after photo", isOn: $settingsService.autoOpenSearchAfterPhoto)
                    .disabled(!settingsService.aiEnabled || !settingsService.internetAccessEnabled)
                    .foregroundColor((!settingsService.aiEnabled || !settingsService.internetAccessEnabled) ? .secondary : .primary)
                
                Toggle("Always search (ignore captured price)", isOn: $settingsService.alwaysSearchIgnorePrice)
                    .disabled(!settingsService.aiEnabled || !settingsService.internetAccessEnabled || !settingsService.autoOpenSearchAfterPhoto)
                    .foregroundColor((!settingsService.aiEnabled || !settingsService.internetAccessEnabled || !settingsService.autoOpenSearchAfterPhoto) ? .secondary : .primary)
            }
            
            Section("AI Interactions") {
                NavigationLink(destination: PromptsHistoryView(historyService: historyService)) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Prompts History")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(historyService.totalInteractionCount)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset All Models", isPresented: $showingResetModelsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                settingsService.resetAllModels()
            }
        } message: {
            Text("Reset Photo Analysis to gpt-4o-mini? (Tax Rate Analysis is always sonar-pro)")
        }
        // Note: Auto-search dependency logic is now handled directly in SettingsService property setters
    }
}

#Preview {
    NavigationView {
        AISettingsView(settingsService: SettingsService(), historyService: HistoryService())
    }
}
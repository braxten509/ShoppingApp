import SwiftUI

struct AISettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var historyService: HistoryService
    @State private var showingResetModelsAlert = false
    
    var body: some View {
        List {
            Section("AI Model Selection") {
                Picker("Tax Rate Analysis", selection: $settingsService.selectedModelForTaxRate) {
                    ForEach(settingsService.aiModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Photo Price Analysis", selection: $settingsService.selectedModelForPhotoPrice) {
                    ForEach(settingsService.aiModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Tag Identification", selection: $settingsService.selectedModelForTagIdentification) {
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
            
            Section("Advanced Settings") {
                NavigationLink(destination: PromptCustomizationView(settingsService: settingsService)) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("Customize AI Prompts")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
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
            Text("Reset all AI models to sonar-pro?")
        }
    }
}

#Preview {
    NavigationView {
        AISettingsView(settingsService: SettingsService(), historyService: HistoryService())
    }
}
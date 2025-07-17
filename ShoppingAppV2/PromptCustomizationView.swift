import SwiftUI

struct PromptCustomizationView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingResetAllAlert = false
    
    var body: some View {
        List {
            Section {
                ForEach(PromptType.allCases, id: \.self) { promptType in
                    NavigationLink(destination: PromptEditView(settingsService: settingsService, promptType: promptType)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(promptType.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(promptType.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // Show custom status
                            if let customPrompt = settingsService.customPrompts[promptType], customPrompt.isEnabled {
                                Text("Custom")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            } else {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("AI Prompts")
            } footer: {
                Text("Customize the prompts sent to AI models for different tasks. Tap any prompt to edit it.")
                    .font(.caption)
            }
            
            Section {
                Button("Reset All Prompts") {
                    showingResetAllAlert = true
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
            } footer: {
                Text("This will reset all prompts to their default values. Custom prompts will be disabled.")
                    .font(.caption)
            }
        }
        .navigationTitle("Customize Prompts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("Reset All Prompts", isPresented: $showingResetAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                resetAllPrompts()
            }
        } message: {
            Text("Are you sure you want to reset all prompts to their defaults? This cannot be undone.")
        }
    }
    
    private func resetAllPrompts() {
        settingsService.resetAllPrompts()
    }
}

struct PromptEditView: View {
    @ObservedObject var settingsService: SettingsService
    let promptType: PromptType
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editingPrompt: String = ""
    @State private var isEnabled: Bool = false
    @State private var showingResetAlert = false
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Info
            VStack(alignment: .leading, spacing: 8) {
                Text(promptType.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(promptType.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Enable/Disable Toggle
                Toggle("Use Custom Prompt", isOn: $isEnabled)
                    .padding(.vertical, 8)
                    .onChange(of: isEnabled) { _, _ in
                        hasUnsavedChanges = true
                    }
            }
            .padding(.horizontal)
            
            // Available Placeholders
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Placeholders:")
                    .font(.headline)
                
                Text(getPlaceholders(for: promptType))
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Text("Use these placeholders in your prompt template. They will be replaced with actual values when the AI is called.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Prompt Preview & Edit Button
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Prompt Template:")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Reset to Default") {
                        showingResetAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                
                // Prompt Preview
                ScrollView {
                    Text(editingPrompt.isEmpty ? "No prompt configured" : editingPrompt)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(editingPrompt.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)
                
                // Edit Button
                NavigationLink(destination: PromptEditorModal(
                    promptText: $editingPrompt,
                    promptType: promptType,
                    onSave: {
                        hasUnsavedChanges = true
                    }
                )) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                        Text("Edit Prompt")
                            .font(.subheadline)
                    }
                    .foregroundColor(isEnabled ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEnabled ? Color.blue : Color.secondary, lineWidth: 1)
                    )
                }
                .disabled(!isEnabled)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Save Button
            Button("Save Changes") {
                savePrompt()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasUnsavedChanges ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!hasUnsavedChanges)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Edit Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        loadPrompt() // Revert changes
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePrompt()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadPrompt()
        }
        .alert("Reset Prompt", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetPrompt()
            }
        } message: {
            Text("Are you sure you want to reset this prompt to its default? Your custom changes will be lost.")
        }
    }
    
    private func loadPrompt() {
        let customPrompt = settingsService.customPrompts[promptType]
        editingPrompt = customPrompt?.template ?? settingsService.getPrompt(for: promptType)
        isEnabled = customPrompt?.isEnabled ?? false
        hasUnsavedChanges = false
    }
    
    private func savePrompt() {
        settingsService.updateCustomPrompt(
            type: promptType,
            template: editingPrompt,
            isEnabled: isEnabled
        )
        hasUnsavedChanges = false
    }
    
    private func resetPrompt() {
        settingsService.resetPrompt(type: promptType)
        loadPrompt()
    }
    
    private func getPlaceholders(for type: PromptType) -> String {
        switch type {
        case .taxRate:
            return "{itemName}, {locationContext}"
        case .priceTagAnalysis:
            return "{locationContext}"
        case .priceGuessing:
            return "{itemName}, {brand}, {additionalDetails}, {storeName}"
        case .additiveAnalysis:
            return "{productName}"
        }
    }
}

struct PromptEditorModal: View {
    @Binding var promptText: String
    let promptType: PromptType
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var localPromptText: String = ""
    @State private var hasChanges = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit \(promptType.displayName)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Available placeholders: \(getPlaceholders(for: promptType))")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Text Editor
            TextEditor(text: $localPromptText)
                .font(.system(size: 16, design: .monospaced))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: localPromptText) { _, _ in
                    hasChanges = true
                }
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Edit Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    promptText = localPromptText
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!hasChanges)
            }
        }
        .onAppear {
            localPromptText = promptText
            hasChanges = false
        }
    }
    
    private func getPlaceholders(for type: PromptType) -> String {
        switch type {
        case .taxRate:
            return "{itemName}, {locationContext}"
        case .priceTagAnalysis:
            return "{locationContext}"
        case .priceGuessing:
            return "{itemName}, {brand}, {additionalDetails}, {storeName}"
        case .additiveAnalysis:
            return "{productName}"
        }
    }
}

#Preview {
    PromptCustomizationView(settingsService: SettingsService())
}

#Preview {
    PromptEditView(settingsService: SettingsService(), promptType: .taxRate)
}

#Preview {
    PromptEditorModal(
        promptText: .constant("Sample prompt with {itemName} and {locationContext}"),
        promptType: .taxRate,
        onSave: {}
    )
}
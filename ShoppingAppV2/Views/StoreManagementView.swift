import SwiftUI

struct StoreManagementView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddStore = false
    @State private var editingStore: Store?
    @State private var showingDeleteAlert = false
    @State private var storeToDelete: Int?
    
    var body: some View {
        List {
            Section(header: Text("Stores"), footer: Text("Use %s in the URL where the search term should be placed (optional)")) {
                ForEach(Array(settingsService.stores.enumerated()), id: \.element.id) { index, store in
                    StoreRowView(store: store, settingsService: settingsService) {
                        editingStore = store
                    } onDelete: {
                        storeToDelete = index
                        showingDeleteAlert = true
                    } onSetDefault: {
                        settingsService.setDefaultStore(store)
                    }
                }
            }
            
            Section {
                Button(action: {
                    showingAddStore = true
                }) {
                    Label("Add Store", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    settingsService.resetToDefaultStores()
                }) {
                    Label("Reset to Default Stores", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingAddStore) {
            AddEditStoreView(settingsService: settingsService, store: nil)
        }
        .sheet(item: $editingStore) { store in
            AddEditStoreView(settingsService: settingsService, store: store)
        }
        .alert("Delete Store", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let index = storeToDelete {
                    settingsService.deleteStore(at: index)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this store?")
        }
    }
}

struct StoreRowView: View {
    let store: Store
    @ObservedObject var settingsService: SettingsService
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(store.name)
                            .font(.headline)
                        if settingsService.isDefaultStore(store) {
                            Text("DEFAULT")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                Menu {
                    if !settingsService.isDefaultStore(store) {
                        Button(action: onSetDefault) {
                            Label("Set as Default", systemImage: "star")
                        }
                    }
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            
            Text(store.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

struct AddEditStoreView: View {
    @ObservedObject var settingsService: SettingsService
    let store: Store?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    var isEditing: Bool {
        store != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Store Information")) {
                    TextField("Store Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Store URL (use %s for search term - optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Store URL", text: $url, axis: .vertical)
                            .lineLimit(3...6)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(footer: Text("Example: https://www.walmart.com/search?q=%s\nThe %s will be replaced with the search term. URLs without %s will open as-is.")) {
                    EmptyView()
                }
            }
            .navigationTitle(isEditing ? "Edit Store" : "Add Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveStore()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
        .onAppear {
            if let store = store {
                name = store.name
                url = store.url
            }
        }
        .alert("Invalid Store", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private func saveStore() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please provide both a store name and URL."
            showingValidationAlert = true
            return
        }
        
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEditing, let store = store,
           let index = settingsService.stores.firstIndex(where: { $0.id == store.id }) {
            settingsService.updateStore(at: index, name: name.trimmingCharacters(in: .whitespacesAndNewlines), url: trimmedURL)
        } else {
            settingsService.addStore(name: name.trimmingCharacters(in: .whitespacesAndNewlines), url: trimmedURL)
        }
        
        dismiss()
    }
}

#Preview {
    StoreManagementView(settingsService: SettingsService())
}
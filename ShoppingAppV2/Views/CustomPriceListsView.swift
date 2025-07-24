import SwiftUI

struct EditingItemWrapper: Identifiable {
    let id = UUID()
    let item: CustomPriceItem
    let index: Int
    let listId: UUID
}

struct CustomPriceListsView: View {
    @ObservedObject var customPriceListStore: CustomPriceListStore
    @ObservedObject var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddList = false
    @State private var editingList: CustomPriceList?
    @State private var showingDeleteAlert = false
    @State private var listToDelete: Int?
    @State private var expandedListId: UUID?
    
    var body: some View {
        List {
            if customPriceListStore.hasLists {
                Section(header: Text("Custom Price Lists"), footer: Text("Tap a list to expand and view items. Set a default list to use across the app.")) {
                    ForEach(Array(customPriceListStore.customPriceLists.enumerated()), id: \.element.id) { index, list in
                        CustomPriceListRowView(
                            list: list,
                            customPriceListStore: customPriceListStore,
                            isExpanded: expandedListId == list.id,
                            onToggleExpansion: {
                                expandedListId = expandedListId == list.id ? nil : list.id
                            },
                            onEdit: {
                                editingList = list
                            },
                            onDelete: {
                                listToDelete = index
                                showingDeleteAlert = true
                            },
                            onSetDefault: {
                                customPriceListStore.setDefaultList(list)
                            }
                        )
                    }
                }
            } else {
                Section(header: Text("Getting Started")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No Custom Price Lists")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create custom price lists to store your own items and prices. These work like personal stores where you can set your own pricing.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Create Sample List") {
                            let sampleList = customPriceListStore.createSampleList()
                            customPriceListStore.addList(sampleList)
                            customPriceListStore.setDefaultList(sampleList)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                Button(action: {
                    showingAddList = true
                }) {
                    Label("Add Custom Price List", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Custom Price Lists")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddList) {
            AddEditCustomPriceListView(
                customPriceListStore: customPriceListStore,
                list: nil
            )
        }
        .sheet(item: $editingList) { list in
            AddEditCustomPriceListView(
                customPriceListStore: customPriceListStore,
                list: list
            )
        }
        .alert("Delete Price List", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let index = listToDelete {
                    customPriceListStore.removeList(at: index)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this custom price list? This action cannot be undone.")
        }
    }
}

struct CustomPriceListRowView: View {
    let list: CustomPriceList
    @ObservedObject var customPriceListStore: CustomPriceListStore
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    @State private var editingItemWrapper: EditingItemWrapper?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(list.name)
                            .font(.headline)
                        if customPriceListStore.isDefaultList(list) {
                            Text("DEFAULT")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onToggleExpansion) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Menu {
                        if !customPriceListStore.isDefaultList(list) {
                            Button(action: onSetDefault) {
                                Label("Set as Default", systemImage: "star")
                            }
                        }
                        Button(action: onEdit) {
                            Label("Edit List", systemImage: "pencil")
                        }
                        Button(action: onDelete) {
                            Label("Delete List", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if isExpanded {
                Divider()
                
                if list.items.isEmpty {
                    Text("No items in this list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(list.items, id: \.id) { item in
                            if let itemIndex = list.items.firstIndex(where: { $0.id == item.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let description = item.description, !description.isEmpty {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("$\(item.price, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItemWrapper = EditingItemWrapper(
                                        item: item,
                                        index: itemIndex,
                                        listId: list.id
                                    )
                                }
                                .contextMenu {
                                    Button(action: {
                                        editingItemWrapper = EditingItemWrapper(
                                            item: item,
                                            index: itemIndex,
                                            listId: list.id
                                        )
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        customPriceListStore.removeItem(at: itemIndex, from: list.id)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                
                                if itemIndex < list.items.count - 1 {
                                    Divider()
                                        .padding(.leading, 8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .contentShape(Rectangle())
        .sheet(item: $editingItemWrapper) { wrapper in
            AddEditCustomPriceItemView(
                customPriceListStore: customPriceListStore,
                listId: wrapper.listId,
                item: wrapper.item,
                itemIndex: wrapper.index
            )
        }
    }
}

struct AddEditCustomPriceListView: View {
    @ObservedObject var customPriceListStore: CustomPriceListStore
    let list: CustomPriceList?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingAddItem = false
    @State private var editingItemWrapper: EditingItemWrapper?
    
    var isEditing: Bool {
        list != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Information")) {
                    TextField("List Name", text: $name)
                }
                
                if isEditing, let list = list {
                    Section(header: Text("Items (\(list.items.count))")) {
                        if list.items.isEmpty {
                            Text("No items yet")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                        if let description = item.description, !description.isEmpty {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("$\(item.price, specifier: "%.2f")")
                                        .foregroundColor(.green)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItemWrapper = EditingItemWrapper(
                                        item: item,
                                        index: index,
                                        listId: list.id
                                    )
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    customPriceListStore.removeItem(at: index, from: list.id)
                                }
                            }
                        }
                        
                        Button(action: {
                            showingAddItem = true
                        }) {
                            Label("Add Item", systemImage: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit List" : "Add List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveList()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            if let list = list {
                name = list.name
            }
        }
        .sheet(isPresented: $showingAddItem) {
            if let list = list {
                AddEditCustomPriceItemView(
                    customPriceListStore: customPriceListStore,
                    listId: list.id,
                    item: nil,
                    itemIndex: nil
                )
            }
        }
        .sheet(item: $editingItemWrapper) { wrapper in
            AddEditCustomPriceItemView(
                customPriceListStore: customPriceListStore,
                listId: wrapper.listId,
                item: wrapper.item,
                itemIndex: wrapper.index
            )
        }
        .alert("Invalid List", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    
    private func saveList() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please provide a list name."
            showingValidationAlert = true
            return
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEditing, let list = list,
           let index = customPriceListStore.getListIndex(by: list.id) {
            var updatedList = list
            updatedList.updateName(trimmedName)
            customPriceListStore.updateList(at: index, with: updatedList)
        } else {
            let newList = CustomPriceList(name: trimmedName)
            customPriceListStore.addList(newList)
            
            // Set as default if it's the first list
            if customPriceListStore.customPriceLists.count == 1 {
                customPriceListStore.setDefaultList(newList)
            }
        }
        
        dismiss()
    }
}

struct AddEditCustomPriceItemView: View {
    @ObservedObject var customPriceListStore: CustomPriceListStore
    let listId: UUID
    let item: CustomPriceItem?
    let itemIndex: Int?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var priceString: String
    @State private var description: String
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    init(customPriceListStore: CustomPriceListStore, listId: UUID, item: CustomPriceItem?, itemIndex: Int?) {
        self.customPriceListStore = customPriceListStore
        self.listId = listId
        self.item = item
        self.itemIndex = itemIndex
        
        // Initialize @State variables properly
        if let item = item {
            self._name = State(initialValue: item.name)
            self._priceString = State(initialValue: String(format: "%.2f", item.price))
            self._description = State(initialValue: item.description ?? "")
        } else {
            self._name = State(initialValue: "")
            self._priceString = State(initialValue: "")
            self._description = State(initialValue: "")
        }
    }
    
    var isEditing: Bool {
        item != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Information")) {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $priceString)
                            .keyboardType(.decimalPad)
                            .onChange(of: priceString) { _, newValue in
                                // Clean the input to prevent NaN issues
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    priceString = filtered
                                }
                            }
                    }
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || priceString.isEmpty)
                }
            }
        }
        .alert("Invalid Item", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private func saveItem() {
        print("🔍 saveItem() called")
        print("🔍 name: '\(name)'")
        print("🔍 priceString: '\(priceString)'")
        print("🔍 description: '\(description)'")
        print("🔍 isEditing: \(isEditing)")
        print("🔍 listId: \(listId)")
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !priceString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Validation failed: empty name or price")
            validationMessage = "Please provide both item name and price."
            showingValidationAlert = true
            return
        }
        
        // Clean and validate price string
        let cleanedPriceString = priceString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPriceString.isEmpty else {
            print("❌ Validation failed: empty cleaned price string")
            validationMessage = "Please enter a price."
            showingValidationAlert = true
            return
        }
        
        guard let price = Double(cleanedPriceString), price >= 0, !price.isNaN, !price.isInfinite else {
            print("❌ Validation failed: invalid price conversion from '\(cleanedPriceString)'")
            validationMessage = "Please enter a valid price (e.g., 5.99)."
            showingValidationAlert = true
            return
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        
        print("✅ Validation passed - trimmedName: '\(trimmedName)', price: \(price)")
        
        if isEditing, let itemIndex = itemIndex {
            print("🔄 Updating existing item at index \(itemIndex)")
            var updatedItem = item!
            updatedItem.updateItem(name: trimmedName, price: price, description: finalDescription)
            customPriceListStore.updateItem(at: itemIndex, with: updatedItem, in: listId)
        } else {
            print("➕ Adding new item to list \(listId)")
            let newItem = CustomPriceItem(name: trimmedName, price: price, description: finalDescription)
            print("🔍 Created new item: \(newItem)")
            customPriceListStore.addItem(newItem, to: listId)
            print("✅ Called addItem on store")
        }
        
        print("📱 Dismissing view")
        dismiss()
    }
}

#Preview {
    let store = CustomPriceListStore()
    let settings = SettingsService()
    return CustomPriceListsView(customPriceListStore: store, settingsService: settings)
}

import SwiftUI

struct CustomPriceSearchView: View {
    @ObservedObject var customPriceListStore: CustomPriceListStore
    let onItemSelected: (CustomPriceItem, CustomPriceList) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedListId: UUID?
    @State private var showingAllLists = true
    
    private var filteredResults: [(list: CustomPriceList, items: [CustomPriceItem])] {
        if searchText.isEmpty {
            if showingAllLists {
                return customPriceListStore.customPriceLists.map { list in
                    (list: list, items: list.items)
                }
            } else if let selectedId = selectedListId,
                      let selectedList = customPriceListStore.getList(by: selectedId) {
                return [(list: selectedList, items: selectedList.items)]
            } else {
                return []
            }
        } else {
            if showingAllLists {
                return customPriceListStore.searchAllLists(query: searchText)
            } else if let selectedId = selectedListId {
                let items = customPriceListStore.searchInList(selectedId, query: searchText)
                if let list = customPriceListStore.getList(by: selectedId), !items.isEmpty {
                    return [(list: list, items: items)]
                }
                return []
            } else {
                return []
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter controls
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search items...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // List selector
                    HStack {
                        Text("Search in:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Menu {
                            Button("All Lists") {
                                showingAllLists = true
                                selectedListId = nil
                            }
                            
                            ForEach(customPriceListStore.customPriceLists, id: \.id) { list in
                                Button(list.name) {
                                    showingAllLists = false
                                    selectedListId = list.id
                                }
                            }
                        } label: {
                            HStack {
                                Text(showingAllLists ? "All Lists" : (customPriceListStore.getList(by: selectedListId ?? UUID())?.name ?? "Select List"))
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Results
                if customPriceListStore.customPriceLists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Custom Price Lists")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create custom price lists in Settings to search and select items.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Go to Settings") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No Items" : "No Results")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? 
                             "The selected list doesn't contain any items." :
                             "No items found matching '\(searchText)'.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredResults, id: \.list.id) { result in
                                CustomPriceSearchListSection(
                                    list: result.list,
                                    items: result.items,
                                    searchText: searchText,
                                    showListName: showingAllLists || filteredResults.count > 1,
                                    onItemSelected: { item in
                                        onItemSelected(item, result.list)
                                    }
                                )
                                
                                if result.list.id != filteredResults.last?.list.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Set default list if available
            if let defaultList = customPriceListStore.getDefaultList() {
                selectedListId = defaultList.id
                showingAllLists = false
            }
        }
    }
}

struct CustomPriceSearchListSection: View {
    let list: CustomPriceList
    let items: [CustomPriceItem]
    let searchText: String
    let showListName: Bool
    let onItemSelected: (CustomPriceItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showListName {
                HStack {
                    Text(list.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                CustomPriceSearchItemRow(
                    item: item,
                    searchText: searchText,
                    onTap: {
                        onItemSelected(item)
                    }
                )
                
                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }
}

struct CustomPriceSearchItemRow: View {
    let item: CustomPriceItem
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HighlightedText(
                        text: item.name,
                        highlight: searchText,
                        font: .subheadline,
                        fontWeight: .medium
                    )
                    
                    if let description = item.description, !description.isEmpty {
                        HighlightedText(
                            text: description,
                            highlight: searchText,
                            font: .caption,
                            color: .secondary
                        )
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HighlightedText: View {
    let text: String
    let highlight: String
    let font: Font
    var fontWeight: Font.Weight = .regular
    var color: Color = .primary
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .font(font)
                .fontWeight(fontWeight)
                .foregroundColor(color)
        } else {
            let parts = text.components(separatedBy: highlight)
            let highlightColor = Color.yellow
            
            if parts.count > 1 {
                HStack(spacing: 0) {
                    ForEach(0..<parts.count, id: \.self) { index in
                        Group {
                            Text(parts[index])
                                .font(font)
                                .fontWeight(fontWeight)
                                .foregroundColor(color)
                            
                            if index < parts.count - 1 {
                                Text(highlight)
                                    .font(font)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .background(highlightColor.opacity(0.3))
                            }
                        }
                    }
                }
            } else {
                Text(text)
                    .font(font)
                    .fontWeight(fontWeight)
                    .foregroundColor(color)
            }
        }
    }
}

#Preview {
    let store = CustomPriceListStore()
    
    // Add sample data
    let sampleList = store.createSampleList()
    store.addList(sampleList)
    
    return CustomPriceSearchView(customPriceListStore: store) { item, list in
        print("Selected: \(item.name) from \(list.name)")
    }
}
//
//  ContentView.swift
//  ShoppingAppV2
//
//  Created by Braxten Chenay on 6/16/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ShoppingListStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var settingsStore = SettingsStore()
    
    @State private var showingCamera = false
    @State private var showingAddItem = false
    @State private var showingItemEdit = false
    @State private var showingVerifyItem = false
    @State private var selectedImage: UIImage?
    @State private var editingItem: ShoppingItem?
    @State private var extractedInfo: PriceTagInfo?
    @State private var lastProcessedImage: UIImage?
    @State private var lastLocationString: String?
    @State private var isProcessingImage = false
    @State private var showingClearConfirmation = false
    @State private var showingSettings = false
    @State private var showingAdditiveDetail = false
    @State private var selectedItemForAdditives: ShoppingItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Location Header
                locationHeader
                
                // Calculator Section
                calculatorSection
                
                // Items List
                itemsList
                
                // Action Buttons
                actionButtons
            }
            .navigationTitle("Shopping Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        showingClearConfirmation = true
                    }
                    .disabled(store.items.isEmpty)
                }
            }
            .alert("Clear All Items", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    store.clearAll()
                }
            } message: {
                Text("Are you sure you want to remove all \(store.items.count) item\(store.items.count == 1 ? "" : "s") from your shopping list? This action cannot be undone.")
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(store: store, locationManager: locationManager, openAIService: openAIService, settingsStore: settingsStore)
            }
            .sheet(item: $editingItem) { item in
                ItemEditView(item: bindingForItem(item))
            }
            .sheet(isPresented: $showingVerifyItem) {
                if let info = extractedInfo {
                    VerifyItemView(
                        extractedInfo: info, 
                        store: store, 
                        settingsStore: settingsStore, 
                        openAIService: openAIService,
                        onRetakePhoto: {
                            // Retake photo callback
                            showingVerifyItem = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingCamera = true
                            }
                        },
                        originalImage: lastProcessedImage,
                        locationString: lastLocationString
                    )
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(openAIService: openAIService, settingsStore: settingsStore)
            }
            .sheet(isPresented: $showingAdditiveDetail) {
                if let item = selectedItemForAdditives {
                    AdditiveDetailView(additives: item.additiveDetails, productName: item.name)
                }
            }
            .onChange(of: selectedImage) { _, image in
                if let image = image {
                    processImage(image)
                }
            }
        }
    }
    
    private var locationHeader: some View {
        VStack(spacing: 4) {
            if let placemark = locationManager.placemark {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        if let city = placemark.locality, let state = placemark.administrativeArea {
                            Text("\(city), \(state)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let county = placemark.subAdministrativeArea {
                            Text("\(county) County")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
        }
    }
    
    private var calculatorSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal:")
                    .font(.headline)
                Spacer()
                Text("$\(store.subtotal, specifier: "%.2f")")
                    .font(.headline)
            }
            
            HStack {
                Text("Tax:")
                    .font(.headline)
                Spacer()
                Text("$\(store.totalTax, specifier: "%.2f")")
                    .font(.headline)
            }
            
            Divider()
            
            HStack {
                Text("Total:")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("$\(store.grandTotal, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var itemsList: some View {
        List {
            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        HStack {
                            Text("$\(item.cost, specifier: "%.2f")")
                            if item.hasUnknownTax {
                                Text("+ Unknown tax")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("+ \(item.taxRate, specifier: "%.1f")% tax")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if settingsStore.healthTrackingEnabled {
                            if item.riskyAdditives > 0 || item.nonRiskyAdditives > 0 {
                                HStack(spacing: 8) {
                                    if item.riskyAdditives > 0 {
                                        Button(action: {
                                            selectedItemForAdditives = item
                                            showingAdditiveDetail = true
                                        }) {
                                            Text("\(item.riskyAdditives) Risky Additives")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                                .fontWeight(.medium)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    if item.nonRiskyAdditives > 0 {
                                        Button(action: {
                                            selectedItemForAdditives = item
                                            showingAdditiveDetail = true
                                        }) {
                                            Text("\(item.nonRiskyAdditives) Safe")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            } else {
                                Text("Unknown Additives")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Text("$\(item.totalCost, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.medium)
                        Text("($\(item.taxAmount, specifier: "%.2f") tax)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingItem = item
                }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(PlainListStyle())
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isProcessingImage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing image...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan Tag")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(isProcessingImage ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isProcessingImage)
                
                Button(action: {
                    showingAddItem = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Manually")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(isProcessingImage ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isProcessingImage)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            store.removeItem(at: index)
        }
    }
    
    private func bindingForItem(_ item: ShoppingItem) -> Binding<ShoppingItem> {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else {
            fatalError("Item not found")
        }
        return $store.items[index]
    }
    
    private func processImage(_ image: UIImage) {
        isProcessingImage = true
        lastProcessedImage = image
        
        let locationString: String? = {
            guard let placemark = locationManager.placemark else { return nil }
            
            var components: [String] = []
            
            if let locality = placemark.locality {
                components.append(locality)
            }
            if let county = placemark.subAdministrativeArea {
                components.append("\(county) County")
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }()
        
        lastLocationString = locationString
        
        Task {
            do {
                let priceTagInfo = try await openAIService.analyzePriceTag(image: image, location: locationString)
                
                DispatchQueue.main.async {
                    self.extractedInfo = priceTagInfo
                    self.isProcessingImage = false
                    self.selectedImage = nil
                    self.showingVerifyItem = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingImage = false
                    self.selectedImage = nil
                    // In a real app, you'd show an error alert here
                    print("Error processing image: \(error)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

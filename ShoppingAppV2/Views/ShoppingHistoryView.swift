import SwiftUI

struct ShoppingHistoryView: View {
    @ObservedObject var historyStore: ShoppingHistoryStore
    @ObservedObject var shoppingListStore: ShoppingListStore
    @State private var selectedTrip: CompletedShoppingTrip?
    @State private var shareDocument: ShoppingDataDocument?
    @State private var tripToShare: CompletedShoppingTrip?
    @State private var showingFileExporter = false
    
    var body: some View {
        NavigationView {
            VStack {
                if historyStore.completedTrips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cart")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No shopping trips yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Complete your first shopping trip to see it here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(historyStore.completedTrips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip, shoppingListStore: shoppingListStore, historyStore: historyStore)) {
                                TripRowView(trip: trip, onShare: { tripToShare in
                                    shareTrip(tripToShare)
                                })
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Shopping History")
            .navigationBarTitleDisplayMode(.large)
            .fileExporter(
                isPresented: $showingFileExporter,
                document: shareDocument,
                contentType: .json,
                defaultFilename: "Trip-\(tripToShare?.completedDate.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")"
            ) { result in
                switch result {
                case .success(_):
                    break // File exported successfully
                case .failure(let error):
                    print("File export failed: \(error)")
                }
            }
        }
    }
    
    private func shareTrip(_ trip: CompletedShoppingTrip) {
        tripToShare = trip
        let document = FileMigrationManager.shared.createExportDocument(items: trip.items)
        shareDocument = document
        showingFileExporter = true
    }
}

struct TripRowView: View {
    let trip: CompletedShoppingTrip
    let onShare: (CompletedShoppingTrip) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var itemSummary: String {
        let totalQuantity = trip.items.reduce(0) { $0 + $1.quantity }
        let uniqueItems = trip.items.count
        
        if totalQuantity > uniqueItems {
            return "\(totalQuantity) item\(totalQuantity == 1 ? "" : "s") (\(uniqueItems) unique)"
        } else {
            return "\(uniqueItems) item\(uniqueItems == 1 ? "" : "s")"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    onShare(trip)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .padding(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: trip.completedDate))
                        .font(.headline)
                    Text(itemSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(trip.grandTotal, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Subtotal: $\(trip.subtotal, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Tax: $\(trip.totalTax, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TripDetailView: View {
    let trip: CompletedShoppingTrip
    @ObservedObject var shoppingListStore: ShoppingListStore
    @ObservedObject var historyStore: ShoppingHistoryStore
    @State private var showingRestoreAlert = false
    @State private var showingDeleteTripAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Trip Summary Header
            VStack(spacing: 12) {
                Text(dateFormatter.string(from: trip.completedDate))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtotal:")
                            .font(.headline)
                        Spacer()
                        Text("$\(trip.subtotal, specifier: "%.2f")")
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Tax:")
                            .font(.headline)
                        Spacer()
                        Text("$\(trip.totalTax, specifier: "%.2f")")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total:")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(trip.grandTotal, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Items List
            List {
                ForEach(trip.items) { item in
                    TripItemRowView(item: item, trip: trip, historyStore: historyStore)
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: HStack {
                Button(action: {
                    showingRestoreAlert = true
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    showingDeleteTripAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        )
        .alert("Restore Cart", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Replace Current Cart") {
                restoreCart()
            }
        } message: {
            Text("This will replace your current cart with the items from this trip. Your current cart will be lost.")
        }
        .alert("Delete Trip", isPresented: $showingDeleteTripAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("Are you sure you want to delete this entire shopping trip? This action cannot be undone.")
        }
    }
    
    private func restoreCart() {
        shoppingListStore.clearAll()
        for item in trip.items {
            shoppingListStore.addItem(item)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteTrip() {
        historyStore.deleteTrip(tripId: trip.id)
        presentationMode.wrappedValue.dismiss()
    }
}

struct TripItemRowView: View {
    let item: ShoppingItem
    let trip: CompletedShoppingTrip
    @ObservedObject var historyStore: ShoppingHistoryStore
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if item.isPriceByMeasurement {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("$\(item.cost, specifier: "%.2f") per \(item.measurementUnit)")
                                if item.quantity > 1 {
                                    Text("Quantity: \(item.quantity)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            if item.quantity > 1 {
                                Text("$\(item.unitCost, specifier: "%.2f") each × \(item.quantity)")
                            } else {
                                Text("$\(item.cost, specifier: "%.2f")")
                            }
                        }
                        if item.hasUnknownTax {
                            Text("+ Unknown tax")
                                .foregroundColor(.secondary)
                        } else {
                            Text("+ \(item.taxRate, specifier: "%.1f")% tax")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if item.isPriceByMeasurement {
                        Text("\(item.measurementQuantity, specifier: "%.1f") \(item.measurementUnit) = $\(item.actualCost, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if item.quantity > 1 && !item.isPriceByMeasurement {
                        Text("Quantity: \(item.quantity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(item.totalCost, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.medium)
                Text("($\(item.taxAmount, specifier: "%.2f") tax)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete '\(item.name)' from this trip?")
        }
    }
    
    private func deleteItem() {
        historyStore.deleteItemFromTrip(tripId: trip.id, itemId: item.id)
    }
}

#Preview {
    let historyStore = ShoppingHistoryStore()
    let shoppingListStore = ShoppingListStore()
    return ShoppingHistoryView(historyStore: historyStore, shoppingListStore: shoppingListStore)
}
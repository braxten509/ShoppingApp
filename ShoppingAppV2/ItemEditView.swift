import SwiftUI

struct ItemEditView: View {
    @Binding var item: ShoppingItem
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String
    @State private var costString: String
    @State private var taxRateString: String
    @State private var showingAdditiveDetail = false
    
    init(item: Binding<ShoppingItem>) {
        self._item = item
        self._name = State(initialValue: item.wrappedValue.name)
        self._costString = State(initialValue: String(format: "%.2f", item.wrappedValue.cost))
        self._taxRateString = State(initialValue: String(format: "%.2f", item.wrappedValue.taxRate))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $costString)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        TextField("0.00", text: $taxRateString)
                            .keyboardType(.decimalPad)
                        Text("% Tax")
                    }
                }
                
                if !item.additiveDetails.isEmpty {
                    Section(header: Text("Health Information")) {
                        Button(action: {
                            showingAdditiveDetail = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Additives Analysis")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 12) {
                                        if item.riskyAdditives > 0 {
                                            Text("\(item.riskyAdditives) Risky")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .fontWeight(.medium)
                                        }
                                        if item.nonRiskyAdditives > 0 {
                                            Text("\(item.nonRiskyAdditives) Safe")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(header: Text("Preview")) {
                    HStack {
                        Text("Subtotal:")
                        Spacer()
                        Text("$\(Double(costString) ?? 0, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Tax:")
                        Spacer()
                        Text("$\((Double(costString) ?? 0) * (Double(taxRateString) ?? 0) / 100, specifier: "%.2f")")
                    }
                    
                    HStack {
                        Text("Total:")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\((Double(costString) ?? 0) + (Double(costString) ?? 0) * (Double(taxRateString) ?? 0) / 100, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        item.name = name
                        item.cost = Double(costString) ?? 0
                        item.taxRate = Double(taxRateString) ?? 0
                        // Reset hasUnknownTax when user manually edits
                        item.hasUnknownTax = false
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAdditiveDetail) {
                AdditiveDetailView(additives: item.additiveDetails, productName: item.name)
            }
        }
    }
}
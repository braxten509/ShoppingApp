import SwiftUI

struct ManualPriceEntryOverlay: View {
    let itemName: String
    let onPriceSelected: (Double, String) -> Void
    let buttonText: String
    let buttonIcon: String
    
    @State private var showingManualPriceEntry = false
    @State private var manualPriceText: String = ""
    
    init(
        itemName: String,
        onPriceSelected: @escaping (Double, String) -> Void,
        buttonText: String = "Add Price",
        buttonIcon: String = "plus.circle.fill"
    ) {
        self.itemName = itemName
        self.onPriceSelected = onPriceSelected
        self.buttonText = buttonText
        self.buttonIcon = buttonIcon
    }
    
    var body: some View {
        ZStack {
            // Manual price entry overlay
            if showingManualPriceEntry {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingManualPriceEntry = false
                        }
                        manualPriceText = ""
                    }
                
                VStack(spacing: 20) {
                    Text("Add Price")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter price for:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(itemName)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                    
                    TextField("$0.00", text: $manualPriceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .frame(width: 150)
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingManualPriceEntry = false
                            }
                            manualPriceText = ""
                        }
                        .foregroundColor(.red)
                        .font(.headline)
                        
                        Button("Done") {
                            if let manualPrice = Double(manualPriceText), manualPrice > 0 {
                                onPriceSelected(manualPrice, itemName)
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    showingManualPriceEntry = false
                                }
                                manualPriceText = ""
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .disabled(manualPriceText.isEmpty || Double(manualPriceText) == nil || Double(manualPriceText) ?? 0 <= 0)
                    }
                }
                .padding(30)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 20)
                .frame(maxWidth: 300)
                .scaleEffect(showingManualPriceEntry ? 1.0 : 0.1)
                .opacity(showingManualPriceEntry ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingManualPriceEntry)
            }
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingManualPriceEntry = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(buttonText)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(showingManualPriceEntry ? 0.0 : 1.0)
                    .opacity(showingManualPriceEntry ? 0.0 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingManualPriceEntry)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        // Background content
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .ignoresSafeArea()
        
        // Overlay
        ManualPriceEntryOverlay(
            itemName: "Sample Item Name",
            onPriceSelected: { price, name in
                print("Selected price: \(price) for item: \(name)")
            }
        )
    }
}
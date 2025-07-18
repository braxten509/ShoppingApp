import SwiftUI

struct AdditiveDetailView: View {
    let additives: [AdditiveInfo]
    let productName: String
    @Environment(\.presentationMode) var presentationMode
    
    var riskyAdditives: [AdditiveInfo] {
        additives.filter { $0.isRisky }
    }
    
    var safeAdditives: [AdditiveInfo] {
        additives.filter { !$0.isRisky }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !riskyAdditives.isEmpty {
                    Section(header: Text("Risky Additives")) {
                        ForEach(riskyAdditives) { additive in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(additive.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(additive.riskLevel)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(riskLevelColor(for: additive.riskLevel))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                
                                Text(additive.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if !safeAdditives.isEmpty {
                    Section(header: Text("Safe Additives")) {
                        ForEach(safeAdditives) { additive in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(additive.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("Safe")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                
                                Text(additive.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if riskyAdditives.isEmpty && safeAdditives.isEmpty {
                    Section {
                        Text("No additive information available")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Additives in \(productName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func riskLevelColor(for riskLevel: String) -> Color {
        switch riskLevel.lowercased() {
        case "high risk":
            return .red
        case "medium risk":
            return .orange
        case "low risk":
            return .yellow
        default:
            return .gray
        }
    }
}

#Preview {
    AdditiveDetailView(
        additives: [
            AdditiveInfo(name: "Red Dye #40", isRisky: true, riskLevel: "High Risk", description: "Artificial coloring linked to hyperactivity in children"),
            AdditiveInfo(name: "Citric Acid", isRisky: false, riskLevel: "Safe", description: "Natural preservative derived from citrus fruits")
        ],
        productName: "Sample Product"
    )
}
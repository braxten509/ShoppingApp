import SwiftUI

struct DeveloperToolsView: View {
    @ObservedObject var aiService: AIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var billingService: BillingService
    @ObservedObject var historyService: HistoryService
    
    @State private var isTestingTaxAccuracy = false
    @State private var showingTestResults = false
    @State private var currentTestProgress = 0
    
    var body: some View {
        List {
            Section("Tax Analysis Testing") {
                Button(action: {
                    testTaxAccuracy()
                }) {
                    HStack {
                        if isTestingTaxAccuracy {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing Tax Accuracy... (\(currentTestProgress)/10)")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Test Tax Accuracy")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Run multiple tax queries to test consistency")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTestingTaxAccuracy || !settingsService.aiEnabled || !settingsService.internetAccessEnabled)
                
                if !settingsService.aiEnabled || !settingsService.internetAccessEnabled {
                    Text("AI and Internet access must be enabled for tax accuracy testing")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            
            if let results = settingsService.savedTestResults {
                Section("Latest Test Results") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Total Tests:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(results.totalTests)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Most Common Answer:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(results.mostCommonAnswer)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Times Given:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(results.mostCommonCount)/\(results.totalTests)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Accuracy Score:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(results.accuracyPercentage, specifier: "%.1f")%")
                                .foregroundColor(results.accuracyPercentage >= 80 ? .green : results.accuracyPercentage >= 60 ? .orange : .red)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Test Date:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(results.testDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("View All Responses & Prompt") {
                            showingTestResults = true
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTestResults) {
            if let results = settingsService.savedTestResults {
                TaxAccuracyResultsView(results: results)
            }
        }
    }
    
    private func testTaxAccuracy() {
        isTestingTaxAccuracy = true
        settingsService.savedTestResults = nil
        currentTestProgress = 0
        
        Task {
            let totalTests = 10
            var responses: [String] = []
            
            // Get location string
            let locationString: String? = {
                guard let placemark = locationManager.placemark else { return nil }
                
                var components: [String] = []
                
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let county = placemark.subAdministrativeArea {
                    let countyText = county.hasSuffix("County") ? county : "\(county) County"
                    components.append(countyText)
                }
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                
                return components.isEmpty ? nil : components.joined(separator: ", ")
            }()
            
            // Capture the prompt being used
            let prompt = settingsService.getTaxRatePrompt(itemName: "strawberries", location: locationString)
            
            // Run multiple tests
            for i in 1...totalTests {
                DispatchQueue.main.async {
                    self.currentTestProgress = i
                }
                
                do {
                    let taxRate = try await aiService.analyzeItemForTax(itemName: "strawberries", location: locationString)
                    let responseString: String
                    if let rate = taxRate {
                        responseString = String(format: "%.2f%%", rate)
                    } else {
                        responseString = "No rate returned"
                    }
                    responses.append(responseString)
                    print("Tax test \(i)/\(totalTests): \(responseString)")
                } catch {
                    responses.append("Error: \(error.localizedDescription)")
                    print("Tax test \(i)/\(totalTests) failed: \(error)")
                }
            }
            
            // Analyze results
            let responseCounts = Dictionary(grouping: responses, by: { $0 }).mapValues { $0.count }
            let mostCommon = responseCounts.max(by: { $0.value < $1.value })
            let mostCommonAnswer = mostCommon?.key ?? "No consistent answer"
            let mostCommonCount = mostCommon?.value ?? 0
            let accuracyPercentage = (Double(mostCommonCount) / Double(totalTests)) * 100
            
            let results = TaxAccuracyResults(
                totalTests: totalTests,
                responses: responses,
                mostCommonAnswer: mostCommonAnswer,
                mostCommonCount: mostCommonCount,
                accuracyPercentage: accuracyPercentage,
                prompt: prompt
            )
            
            DispatchQueue.main.async {
                self.settingsService.savedTestResults = results
                self.isTestingTaxAccuracy = false
                self.currentTestProgress = 0
            }
        }
    }
}

struct TaxAccuracyResultsView: View {
    let results: TaxAccuracyResults
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Summary") {
                    HStack {
                        Text("Total Tests:")
                        Spacer()
                        Text("\(results.totalTests)")
                    }
                    
                    HStack {
                        Text("Most Common Answer:")
                        Spacer()
                        Text(results.mostCommonAnswer)
                    }
                    
                    HStack {
                        Text("Accuracy Score:")
                        Spacer()
                        Text("\(results.accuracyPercentage, specifier: "%.1f")%")
                            .foregroundColor(results.accuracyPercentage >= 80 ? .green : results.accuracyPercentage >= 60 ? .orange : .red)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Prompt Used") {
                    Text(results.prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                Section("All Responses") {
                    ForEach(Array(results.responses.enumerated()), id: \.offset) { index, response in
                        HStack {
                            Text("Test \(index + 1):")
                                .fontWeight(.medium)
                            Spacer()
                            Text(response)
                                .foregroundColor(response == results.mostCommonAnswer ? .green : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tax Accuracy Results")
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
}

#Preview {
    NavigationView {
        let settingsService = SettingsService()
        let billingService = BillingService()
        let historyService = HistoryService()
        return DeveloperToolsView(
            aiService: AIService(settingsService: settingsService, billingService: billingService, historyService: historyService),
            settingsService: settingsService,
            locationManager: LocationManager(),
            billingService: billingService,
            historyService: historyService
        )
    }
}
import SwiftUI

struct MainTabView: View {
    @StateObject private var store = ShoppingListStore()
    @StateObject private var historyStore = ShoppingHistoryStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var settingsService = SettingsService()
    @StateObject private var billingService = BillingService()
    @StateObject private var historyService = HistoryService()
    @StateObject private var customPriceListStore = CustomPriceListStore()
    @State private var selectedTab: Int = 0
    @State private var searchItemName: String = ""
    
    private var aiService: AIService {
        AIService(settingsService: settingsService, billingService: billingService, historyService: historyService)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorView(
                store: store,
                historyStore: historyStore,
                locationManager: locationManager,
                openAIService: openAIService,
                settingsService: settingsService,
                billingService: billingService,
                historyService: historyService,
                customPriceListStore: customPriceListStore
            )
            .tabItem {
                Image(systemName: "cart")
                Text("Shop")
            }
            .tag(0)
            
            SearchTabView(
                store: store,
                locationManager: locationManager,
                settingsService: settingsService,
                aiService: aiService,
                customPriceListStore: customPriceListStore,
                prefillItemName: searchItemName
            )
            .tabItem {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(settingsService.internetAccessEnabled ? .primary : .secondary)
                Text("Search")
                    .foregroundColor(settingsService.internetAccessEnabled ? .primary : .secondary)
            }
            .disabled(!settingsService.internetAccessEnabled)
            .tag(1)
            
            ShoppingHistoryView(historyStore: historyStore, shoppingListStore: store)
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 MainTabView: selectedTab changed from \(oldValue) to \(newValue), searchItemName='\(searchItemName)'")
            // Clear search item name when switching away from search tab
            if newValue != 1 {
                print("🔄 MainTabView: Clearing searchItemName because switching away from search tab")
                searchItemName = ""
            }
        }
    }
}

#Preview {
    MainTabView()
}
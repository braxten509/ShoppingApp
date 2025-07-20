import SwiftUI

struct MainTabView: View {
    @StateObject private var store = ShoppingListStore()
    @StateObject private var historyStore = ShoppingHistoryStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var settingsService = SettingsService()
    @StateObject private var billingService = BillingService()
    @StateObject private var historyService = HistoryService()
    
    private var aiService: AIService {
        AIService(settingsService: settingsService, billingService: billingService, historyService: historyService)
    }
    
    var body: some View {
        TabView {
            CalculatorView(
                store: store,
                historyStore: historyStore,
                locationManager: locationManager,
                openAIService: openAIService,
                settingsService: settingsService,
                billingService: billingService,
                historyService: historyService
            )
            .tabItem {
                Image(systemName: "cart")
                Text("Shop")
            }
            
            SearchTabView(
                store: store,
                locationManager: locationManager,
                settingsService: settingsService,
                aiService: aiService
            )
            .tabItem {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(settingsService.internetAccessEnabled ? .primary : .secondary)
                Text("Search")
                    .foregroundColor(settingsService.internetAccessEnabled ? .primary : .secondary)
            }
            .disabled(!settingsService.internetAccessEnabled)
            
            ShoppingHistoryView(historyStore: historyStore, shoppingListStore: store)
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
        }
    }
}

#Preview {
    MainTabView()
}
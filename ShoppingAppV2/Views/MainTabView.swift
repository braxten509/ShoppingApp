import SwiftUI

struct MainTabView: View {
    @StateObject private var store = ShoppingListStore()
    @StateObject private var historyStore = ShoppingHistoryStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var settingsService = SettingsService()
    @StateObject private var billingService = BillingService()
    @StateObject private var historyService = HistoryService()
    
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
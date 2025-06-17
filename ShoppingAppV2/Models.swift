import Foundation
import CoreLocation

struct FoodAdditives {
    static let riskyAdditives = [
        "Red Dye #40", "Red 40", "Allura Red AC", "E129",
        "Yellow Dye #5", "Yellow 5", "Tartrazine", "E102",
        "Yellow Dye #6", "Yellow 6", "Sunset Yellow", "E110",
        "Blue Dye #1", "Blue 1", "Brilliant Blue FCF", "E133",
        "Blue Dye #2", "Blue 2", "Indigotine", "E132",
        "Green Dye #3", "Green 3", "Fast Green FCF", "E143",
        "Sodium Benzoate", "E211",
        "Potassium Benzoate", "E212",
        "Calcium Benzoate", "E213",
        "BHA", "Butylated Hydroxyanisole", "E320",
        "BHT", "Butylated Hydroxytoluene", "E321",
        "TBHQ", "Tertiary Butylhydroquinone", "E319",
        "Sodium Nitrite", "E250",
        "Sodium Nitrate", "E251",
        "Potassium Nitrite", "E249",
        "Potassium Nitrate", "E252",
        "High Fructose Corn Syrup", "HFCS",
        "Aspartame", "E951",
        "Sucralose", "E955", "Splenda",
        "Acesulfame Potassium", "Ace-K", "E950",
        "Saccharin", "E954",
        "Monosodium Glutamate", "MSG", "E621",
        "Disodium Guanylate", "E627",
        "Disodium Inosinate", "E631",
        "Propyl Gallate", "E310",
        "Octyl Gallate", "E311",
        "Dodecyl Gallate", "E312",
        "Sodium Sulfite", "E221",
        "Potassium Sulfite", "E225",
        "Calcium Sulfite", "E226",
        "Sodium Bisulfite", "E222",
        "Potassium Bisulfite", "E228",
        "Carrageenan", "E407",
        "Polysorbate 80", "E433",
        "Polysorbate 60", "E435"
    ]
    
    static let nonRiskyAdditives = [
        "Vitamin C", "Ascorbic Acid", "E300",
        "Vitamin E", "Tocopherols", "E306", "E307", "E308", "E309",
        "Citric Acid", "E330",
        "Lactic Acid", "E270",
        "Acetic Acid", "E260",
        "Sodium Chloride", "Salt",
        "Calcium Carbonate", "E170",
        "Magnesium Carbonate", "E504",
        "Potassium Carbonate", "E501",
        "Sodium Bicarbonate", "Baking Soda", "E500",
        "Calcium Lactate", "E327",
        "Potassium Lactate", "E326",
        "Sodium Lactate", "E325",
        "Lecithin", "E322", "Soy Lecithin", "Sunflower Lecithin",
        "Pectin", "E440",
        "Agar", "E406",
        "Gellan Gum", "E418",
        "Xanthan Gum", "E415",
        "Guar Gum", "E412",
        "Locust Bean Gum", "E410", "Carob Bean Gum",
        "Cellulose", "E460",
        "Methylcellulose", "E461",
        "Hydroxypropyl Methylcellulose", "E464",
        "Sodium Carboxymethylcellulose", "E466",
        "Annatto", "E160b",
        "Beta-Carotene", "E160a",
        "Lycopene", "E160d",
        "Turmeric", "E100", "Curcumin",
        "Paprika Extract", "E160c",
        "Calcium Phosphate", "E341",
        "Sodium Phosphate", "E339",
        "Potassium Phosphate", "E340",
        "Calcium Hydroxide", "E526",
        "Sodium Hydroxide", "E524",
        "Potassium Hydroxide", "E525",
        "Malic Acid", "E296",
        "Tartaric Acid", "E334",
        "Calcium Citrate", "E333",
        "Sodium Citrate", "E331",
        "Potassium Citrate", "E332"
    ]
    
    static func analyzeAdditives(in text: String) -> (risky: Int, nonRisky: Int, riskyFound: [String], nonRiskyFound: [String]) {
        let uppercaseText = text.uppercased()
        var riskyFound: [String] = []
        var nonRiskyFound: [String] = []
        
        for additive in riskyAdditives {
            if uppercaseText.contains(additive.uppercased()) {
                riskyFound.append(additive)
            }
        }
        
        for additive in nonRiskyAdditives {
            if uppercaseText.contains(additive.uppercased()) {
                nonRiskyFound.append(additive)
            }
        }
        
        return (risky: riskyFound.count, nonRisky: nonRiskyFound.count, riskyFound: riskyFound, nonRiskyFound: nonRiskyFound)
    }
    
    static func createAdditiveDetails(riskyFound: [String], nonRiskyFound: [String]) -> [AdditiveInfo] {
        var details: [AdditiveInfo] = []
        
        for additive in riskyFound {
            let riskLevel = getRiskLevel(for: additive)
            let description = getDescription(for: additive)
            details.append(AdditiveInfo(name: additive, isRisky: true, riskLevel: riskLevel, description: description))
        }
        
        for additive in nonRiskyFound {
            details.append(AdditiveInfo(name: additive, isRisky: false, riskLevel: "Safe", description: getSafeDescription(for: additive)))
        }
        
        return details
    }
    
    private static func getRiskLevel(for additive: String) -> String {
        let highRisk = ["Red Dye #40", "Red 40", "Yellow Dye #5", "Yellow 5", "BHA", "BHT", "TBHQ", "Aspartame", "MSG", "High Fructose Corn Syrup"]
        let mediumRisk = ["Sodium Benzoate", "Potassium Benzoate", "Carrageenan", "Polysorbate 80"]
        
        for high in highRisk {
            if additive.uppercased().contains(high.uppercased()) {
                return "High Risk"
            }
        }
        
        for medium in mediumRisk {
            if additive.uppercased().contains(medium.uppercased()) {
                return "Medium Risk"
            }
        }
        
        return "Low Risk"
    }
    
    private static func getDescription(for additive: String) -> String {
        let descriptions: [String: String] = [
            "Red Dye #40": "Artificial coloring linked to hyperactivity in children",
            "Yellow Dye #5": "Artificial coloring that may cause allergic reactions",
            "BHA": "Preservative that may be carcinogenic",
            "BHT": "Preservative with potential health concerns",
            "TBHQ": "Preservative that may affect immune system",
            "Aspartame": "Artificial sweetener with controversial health effects",
            "MSG": "Flavor enhancer that may cause headaches in sensitive individuals",
            "High Fructose Corn Syrup": "Sweetener linked to obesity and diabetes",
            "Sodium Benzoate": "Preservative that may form benzene when combined with vitamin C",
            "Carrageenan": "Thickener that may cause digestive issues"
        ]
        
        for (key, desc) in descriptions {
            if additive.uppercased().contains(key.uppercased()) {
                return desc
            }
        }
        
        return "Potentially harmful additive"
    }
    
    private static func getSafeDescription(for additive: String) -> String {
        let descriptions: [String: String] = [
            "Vitamin C": "Essential nutrient and natural preservative",
            "Citric Acid": "Natural preservative derived from citrus fruits",
            "Lecithin": "Natural emulsifier from soybeans or sunflowers",
            "Pectin": "Natural thickener from fruits",
            "Xanthan Gum": "Natural thickener produced by fermentation",
            "Beta-Carotene": "Natural orange coloring and vitamin A precursor",
            "Turmeric": "Natural yellow coloring with anti-inflammatory properties"
        ]
        
        for (key, desc) in descriptions {
            if additive.uppercased().contains(key.uppercased()) {
                return desc
            }
        }
        
        return "Generally recognized as safe"
    }
}

struct AdditiveInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let isRisky: Bool
    let riskLevel: String // "High Risk", "Medium Risk", "Low Risk", "Safe"
    let description: String
    
    init(name: String, isRisky: Bool, riskLevel: String, description: String) {
        self.id = UUID()
        self.name = name
        self.isRisky = isRisky
        self.riskLevel = riskLevel
        self.description = description
    }
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var cost: Double
    var taxRate: Double
    var hasUnknownTax: Bool = false
    var riskyAdditives: Int = 0
    var nonRiskyAdditives: Int = 0
    var additiveDetails: [AdditiveInfo] = []
    let dateAdded: Date
    
    init(name: String, cost: Double, taxRate: Double, hasUnknownTax: Bool = false, riskyAdditives: Int = 0, nonRiskyAdditives: Int = 0, additiveDetails: [AdditiveInfo] = []) {
        self.id = UUID()
        self.name = name
        self.cost = cost
        self.taxRate = taxRate
        self.hasUnknownTax = hasUnknownTax
        self.riskyAdditives = riskyAdditives
        self.nonRiskyAdditives = nonRiskyAdditives
        self.additiveDetails = additiveDetails
        self.dateAdded = Date()
    }
    var taxAmount: Double {
        return cost * (taxRate / 100)
    }
    var totalCost: Double {
        return cost + taxAmount
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self?.placemark = placemark
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocation()
        }
    }
}

class ShoppingListStore: ObservableObject {
    @Published var items: [ShoppingItem] = [] {
        didSet {
            saveItems()
        }
    }
    
    private let itemsKey = "shopping_items"
    
    init() {
        loadItems()
    }
    
    var subtotal: Double {
        items.reduce(0) { $0 + $1.cost }
    }
    
    var totalTax: Double {
        items.reduce(0) { $0 + $1.taxAmount }
    }
    
    var grandTotal: Double {
        items.reduce(0) { $0 + $1.totalCost }
    }
    
    func addItem(_ item: ShoppingItem) {
        items.insert(item, at: 0) // Insert at beginning for newest-first order
    }
    
    func removeItem(at index: Int) {
        items.remove(at: index)
    }
    
    func updateItem(at index: Int, with item: ShoppingItem) {
        items[index] = item
    }
    
    func clearAll() {
        items.removeAll()
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            items = decoded.sorted(by: { $0.dateAdded > $1.dateAdded }) // Sort newest first
        }
    }
}

class SettingsStore: ObservableObject {
    @Published var healthTrackingEnabled: Bool = false
    
    init() {
        // Health feature is disabled - always return false
        self.healthTrackingEnabled = false
    }
}
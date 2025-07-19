import Foundation
import CoreLocation

struct Store: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: String
    
    init(name: String, url: String) {
        self.id = UUID()
        self.name = name
        self.url = url
    }
    
    static let defaultStores: [Store] = [
        Store(name: "Broulim's", url: "https://shop.rosieapp.com/broulims_rexburg/search/%s"),
        Store(name: "Walmart", url: "https://www.walmart.com/search?q=%s"),
        Store(name: "Target", url: "https://www.target.com/s?searchTerm=%s")
    ]
}

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

// Legacy struct for migration
struct LegacyShoppingItem: Codable {
    let id: UUID
    var name: String
    var cost: Double
    var taxRate: Double
    var hasUnknownTax: Bool
    var riskyAdditives: Int
    var nonRiskyAdditives: Int
    var additiveDetails: [AdditiveInfo]
    let dateAdded: Date
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var cost: Double
    var quantity: Int
    var taxRate: Double
    var hasUnknownTax: Bool = false
    var riskyAdditives: Int = 0
    var nonRiskyAdditives: Int = 0
    var additiveDetails: [AdditiveInfo] = []
    let dateAdded: Date
    
    // Price by measurement fields
    var isPriceByMeasurement: Bool = false
    var measurementQuantity: Double = 1.0
    var measurementUnit: String = "units"
    
    init(name: String, cost: Double, quantity: Int = 1, taxRate: Double, hasUnknownTax: Bool = false, riskyAdditives: Int = 0, nonRiskyAdditives: Int = 0, additiveDetails: [AdditiveInfo] = [], isPriceByMeasurement: Bool = false, measurementQuantity: Double = 1.0, measurementUnit: String = "units") {
        self.id = UUID()
        self.name = name
        self.cost = cost
        self.quantity = quantity
        self.taxRate = taxRate
        self.hasUnknownTax = hasUnknownTax
        self.riskyAdditives = riskyAdditives
        self.nonRiskyAdditives = nonRiskyAdditives
        self.additiveDetails = additiveDetails
        self.isPriceByMeasurement = isPriceByMeasurement
        self.measurementQuantity = measurementQuantity
        self.measurementUnit = measurementUnit
        self.dateAdded = Date()
    }
    var unitCost: Double {
        return cost
    }
    var subtotal: Double {
        return actualCost * Double(quantity)
    }
    var taxAmount: Double {
        return subtotal * (taxRate / 100)
    }
    var totalCost: Double {
        return subtotal + taxAmount
    }
    
    var actualCost: Double {
        if isPriceByMeasurement {
            return cost * measurementQuantity
        }
        return cost
    }
}

enum MeasurementUnit: String, CaseIterable {
    // Weight
    case pounds = "lbs"
    case ounces = "oz"
    case grams = "g"
    case kilograms = "kg"
    case tons = "tons"
    
    // Volume
    case fluidOunces = "fl oz"
    case cups = "cups"
    case pints = "pints"
    case quarts = "quarts"
    case gallons = "gal"
    case milliliters = "ml"
    case liters = "L"
    
    // Length
    case inches = "in"
    case feet = "ft"
    case yards = "yd"
    case meters = "m"
    case centimeters = "cm"
    case millimeters = "mm"
    
    // Area
    case squareFeet = "sq ft"
    case squareMeters = "sq m"
    case squareInches = "sq in"
    
    // Count
    case pieces = "pieces"
    case dozen = "dozen"
    case units = "units"
    case each = "each"
    case pairs = "pairs"
    case packs = "packs"
    case boxes = "boxes"
    case bags = "bags"
    case bottles = "bottles"
    case cans = "cans"
    
    var displayName: String {
        switch self {
        case .pounds: return "Pounds (lbs)"
        case .ounces: return "Ounces (oz)"
        case .grams: return "Grams (g)"
        case .kilograms: return "Kilograms (kg)"
        case .tons: return "Tons"
        case .fluidOunces: return "Fluid Ounces (fl oz)"
        case .cups: return "Cups"
        case .pints: return "Pints"
        case .quarts: return "Quarts"
        case .gallons: return "Gallons (gal)"
        case .milliliters: return "Milliliters (ml)"
        case .liters: return "Liters (L)"
        case .inches: return "Inches (in)"
        case .feet: return "Feet (ft)"
        case .yards: return "Yards (yd)"
        case .meters: return "Meters (m)"
        case .centimeters: return "Centimeters (cm)"
        case .millimeters: return "Millimeters (mm)"
        case .squareFeet: return "Square Feet (sq ft)"
        case .squareMeters: return "Square Meters (sq m)"
        case .squareInches: return "Square Inches (sq in)"
        case .pieces: return "Pieces"
        case .dozen: return "Dozen"
        case .units: return "Units"
        case .each: return "Each"
        case .pairs: return "Pairs"
        case .packs: return "Packs"
        case .boxes: return "Boxes"
        case .bags: return "Bags"
        case .bottles: return "Bottles"
        case .cans: return "Cans"
        }
    }
    
    var singularForm: String {
        switch self {
        case .pounds: return "pound"
        case .ounces: return "ounce"
        case .grams: return "gram"
        case .kilograms: return "kilogram"
        case .tons: return "ton"
        case .fluidOunces: return "fluid ounce"
        case .cups: return "cup"
        case .pints: return "pint"
        case .quarts: return "quart"
        case .gallons: return "gallon"
        case .milliliters: return "milliliter"
        case .liters: return "liter"
        case .inches: return "inch"
        case .feet: return "foot"
        case .yards: return "yard"
        case .meters: return "meter"
        case .centimeters: return "centimeter"
        case .millimeters: return "millimeter"
        case .squareFeet: return "square foot"
        case .squareMeters: return "square meter"
        case .squareInches: return "square inch"
        case .pieces: return "piece"
        case .dozen: return "dozen"
        case .units: return "unit"
        case .each: return "each"
        case .pairs: return "pair"
        case .packs: return "pack"
        case .boxes: return "box"
        case .bags: return "bag"
        case .bottles: return "bottle"
        case .cans: return "can"
        }
    }
    
    var pluralForm: String {
        switch self {
        case .pounds: return "pounds"
        case .ounces: return "ounces"
        case .grams: return "grams"
        case .kilograms: return "kilograms"
        case .tons: return "tons"
        case .fluidOunces: return "fluid ounces"
        case .cups: return "cups"
        case .pints: return "pints"
        case .quarts: return "quarts"
        case .gallons: return "gallons"
        case .milliliters: return "milliliters"
        case .liters: return "liters"
        case .inches: return "inches"
        case .feet: return "feet"
        case .yards: return "yards"
        case .meters: return "meters"
        case .centimeters: return "centimeters"
        case .millimeters: return "millimeters"
        case .squareFeet: return "square feet"
        case .squareMeters: return "square meters"
        case .squareInches: return "square inches"
        case .pieces: return "pieces"
        case .dozen: return "dozen"
        case .units: return "units"
        case .each: return "each"
        case .pairs: return "pairs"
        case .packs: return "packs"
        case .boxes: return "boxes"
        case .bags: return "bags"
        case .bottles: return "bottles"
        case .cans: return "cans"
        }
    }
    
    func displayText(for quantity: Double) -> String {
        let isPlural = quantity != 1.0
        return isPlural ? pluralForm : singularForm
    }
}

struct CompletedShoppingTrip: Identifiable, Codable {
    let id: UUID
    let items: [ShoppingItem]
    let subtotal: Double
    let totalTax: Double
    let grandTotal: Double
    let completedDate: Date
    
    init(items: [ShoppingItem]) {
        self.id = UUID()
        self.items = items
        self.subtotal = items.reduce(0) { $0 + $1.subtotal }
        self.totalTax = items.reduce(0) { $0 + $1.taxAmount }
        self.grandTotal = items.reduce(0) { $0 + $1.totalCost }
        self.completedDate = Date()
    }
    
    init(id: UUID, items: [ShoppingItem], completedDate: Date) {
        self.id = id
        self.items = items
        self.subtotal = items.reduce(0) { $0 + $1.subtotal }
        self.totalTax = items.reduce(0) { $0 + $1.taxAmount }
        self.grandTotal = items.reduce(0) { $0 + $1.totalCost }
        self.completedDate = completedDate
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
        items.reduce(0) { $0 + $1.subtotal }
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
        if let data = UserDefaults.standard.data(forKey: itemsKey) {
            // Try to decode with new structure first
            if let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
                items = decoded.sorted(by: { $0.dateAdded > $1.dateAdded }) // Sort newest first
            } else {
                // If that fails, try legacy structure and migrate
                if let legacyItems = try? JSONDecoder().decode([LegacyShoppingItem].self, from: data) {
                    items = legacyItems.map { legacy in
                        ShoppingItem(
                            name: legacy.name,
                            cost: legacy.cost,
                            quantity: 1, // Default quantity for legacy items
                            taxRate: legacy.taxRate,
                            hasUnknownTax: legacy.hasUnknownTax,
                            riskyAdditives: legacy.riskyAdditives,
                            nonRiskyAdditives: legacy.nonRiskyAdditives,
                            additiveDetails: legacy.additiveDetails,
                            isPriceByMeasurement: false,
                            measurementQuantity: 1.0,
                            measurementUnit: "units"
                        )
                    }.sorted(by: { $0.dateAdded > $1.dateAdded })
                    // Save in new format
                    saveItems()
                }
            }
        }
    }
}

class ShoppingHistoryStore: ObservableObject {
    @Published var completedTrips: [CompletedShoppingTrip] = [] {
        didSet {
            saveTrips()
        }
    }
    
    private let tripsKey = "completed_shopping_trips"
    
    init() {
        loadTrips()
    }
    
    func addCompletedTrip(_ trip: CompletedShoppingTrip) {
        completedTrips.insert(trip, at: 0) // Insert at beginning for newest-first order
    }
    
    func deleteItemFromTrip(tripId: UUID, itemId: UUID) {
        if let tripIndex = completedTrips.firstIndex(where: { $0.id == tripId }) {
            let currentTrip = completedTrips[tripIndex]
            let updatedItems = currentTrip.items.filter { $0.id != itemId }
            
            // Create a new trip with updated items
            let updatedTrip = CompletedShoppingTrip(
                id: currentTrip.id,
                items: updatedItems,
                completedDate: currentTrip.completedDate
            )
            
            completedTrips[tripIndex] = updatedTrip
        }
    }
    
    func deleteTrip(tripId: UUID) {
        completedTrips.removeAll { $0.id == tripId }
    }
    
    private func saveTrips() {
        if let encoded = try? JSONEncoder().encode(completedTrips) {
            UserDefaults.standard.set(encoded, forKey: tripsKey)
        }
    }
    
    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: tripsKey),
           let decoded = try? JSONDecoder().decode([CompletedShoppingTrip].self, from: data) {
            completedTrips = decoded.sorted(by: { $0.completedDate > $1.completedDate })
        }
    }
}

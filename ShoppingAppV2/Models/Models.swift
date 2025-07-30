import Foundation
import CoreLocation

struct TaxAccuracyResults: Codable {
    let totalTests: Int
    let responses: [String]
    let mostCommonAnswer: String
    let mostCommonCount: Int
    let accuracyPercentage: Double
    let prompt: String
    let testDate: Date
    
    init(totalTests: Int, responses: [String], mostCommonAnswer: String, mostCommonCount: Int, accuracyPercentage: Double, prompt: String) {
        self.totalTests = totalTests
        self.responses = responses
        self.mostCommonAnswer = mostCommonAnswer
        self.mostCommonCount = mostCommonCount
        self.accuracyPercentage = accuracyPercentage
        self.prompt = prompt
        self.testDate = Date()
    }
}

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


// Legacy struct for migration
struct LegacyShoppingItem: Codable {
    let id: UUID
    var name: String
    var cost: Double
    var taxRate: Double
    var hasUnknownTax: Bool
    let dateAdded: Date
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var cost: Double
    var quantity: Int
    var taxRate: Double
    var hasUnknownTax: Bool = false
    let dateAdded: Date
    
    // Price by measurement fields
    var isPriceByMeasurement: Bool = false
    var measurementQuantity: Double = 1.0
    var measurementUnit: String = "units"
    
    init(name: String, cost: Double, quantity: Int = 1, taxRate: Double, hasUnknownTax: Bool = false, isPriceByMeasurement: Bool = false, measurementQuantity: Double = 1.0, measurementUnit: String = "units") {
        self.id = UUID()
        self.name = name
        self.cost = cost
        self.quantity = quantity
        self.taxRate = taxRate
        self.hasUnknownTax = hasUnknownTax
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
        // Fix: Calculate tax per item and then multiply by quantity for proper financial calculation
        let taxPerItem = round(actualCost * taxRate) / 100.0
        return taxPerItem * Double(quantity)
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
    @Published var isLoadingLocation: Bool = false
    @Published var hasLocationFailed: Bool = false
    
    private var locationTimer: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        isLoadingLocation = true
        hasLocationFailed = false
        
        // Start 30-second timeout timer
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoadingLocation = false
                self?.hasLocationFailed = true
            }
        }
        
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.locationTimer?.invalidate()
                self?.isLoadingLocation = false
                
                if let placemark = placemarks?.first {
                    self?.placemark = placemark
                    self?.hasLocationFailed = false
                } else {
                    self?.hasLocationFailed = true
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationTimer?.invalidate()
            self.isLoadingLocation = false
            self.hasLocationFailed = true
        }
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

struct CustomPriceItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var price: Double
    var description: String?
    let dateAdded: Date
    var lastModified: Date
    
    init(name: String, price: Double, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.price = price
        self.description = description
        self.dateAdded = Date()
        self.lastModified = Date()
    }
    
    mutating func updateItem(name: String, price: Double, description: String? = nil) {
        self.name = name
        self.price = price
        self.description = description
        self.lastModified = Date()
    }
}

struct CustomPriceList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var items: [CustomPriceItem]
    let dateCreated: Date
    var lastModified: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.items = []
        self.dateCreated = Date()
        self.lastModified = Date()
    }
    
    mutating func addItem(_ item: CustomPriceItem) {
        items.append(item)
        lastModified = Date()
    }
    
    mutating func removeItem(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
        lastModified = Date()
    }
    
    mutating func updateItem(at index: Int, with item: CustomPriceItem) {
        guard index < items.count else { return }
        items[index] = item
        lastModified = Date()
    }
    
    mutating func updateName(_ newName: String) {
        self.name = newName
        self.lastModified = Date()
    }
    
    func searchItems(query: String) -> [CustomPriceItem] {
        guard !query.isEmpty else { return items }
        let lowercaseQuery = query.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(lowercaseQuery) ||
            (item.description?.lowercased().contains(lowercaseQuery) ?? false)
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

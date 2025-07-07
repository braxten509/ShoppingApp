//
//  DataMigration.swift
//  Combined
//
//  Created by Assistant on 6/18/25.
//

import Foundation

// App Group identifier - you'll need to create this in your app capabilities
let appGroupIdentifier = "group.com.yourcompany.shoppingapp"

struct MigrationData: Codable {
    let items: [ShoppingItem]
    let migrationDate: Date
    let sourceApp: String
    
    init(items: [ShoppingItem], sourceApp: String) {
        self.items = items
        self.migrationDate = Date()
        self.sourceApp = sourceApp
    }
}

class DataMigrationManager {
    static let shared = DataMigrationManager()
    
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
    private let migrationKey = "migrationData"
    private let migrationCompleteKey = "migrationComplete"
    
    // Export data from ShoppingAppV2
    func exportData(items: [ShoppingItem]) -> Bool {
        guard let sharedDefaults = sharedDefaults else { return false }
        
        let migrationData = MigrationData(items: items, sourceApp: "ShoppingAppV2")
        
        if let encoded = try? JSONEncoder().encode(migrationData) {
            sharedDefaults.set(encoded, forKey: migrationKey)
            sharedDefaults.set(false, forKey: migrationCompleteKey)
            return true
        }
        
        return false
    }
    
    // Import data to Combined app
    func importData() -> [ShoppingItem]? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: migrationKey),
              let migrationData = try? JSONDecoder().decode(MigrationData.self, from: data) else {
            return nil
        }
        
        return migrationData.items
    }
    
    // Check if there's data available to import
    func hasDataToImport() -> Bool {
        guard let sharedDefaults = sharedDefaults else { return false }
        
        return sharedDefaults.data(forKey: migrationKey) != nil &&
               !sharedDefaults.bool(forKey: migrationCompleteKey)
    }
    
    // Mark migration as complete
    func markMigrationComplete() {
        sharedDefaults?.set(true, forKey: migrationCompleteKey)
    }
    
    // Clear migration data
    func clearMigrationData() {
        sharedDefaults?.removeObject(forKey: migrationKey)
        sharedDefaults?.removeObject(forKey: migrationCompleteKey)
    }
}

// Extension to detect if ShoppingAppV2 is installed
extension DataMigrationManager {
    func isShoppingAppV2Installed() -> Bool {
        // Check if we can access shared data, which indicates the app is installed
        guard let sharedDefaults = sharedDefaults else { return false }
        
        // Check if there's any data in the shared container from ShoppingAppV2
        // This assumes ShoppingAppV2 writes some data to the shared container
        return sharedDefaults.object(forKey: "ShoppingAppV2_Installed") != nil
    }
    
    // Method to be called from ShoppingAppV2 to mark it as installed
    func markShoppingAppV2AsInstalled() {
        sharedDefaults?.set(true, forKey: "ShoppingAppV2_Installed")
    }
}
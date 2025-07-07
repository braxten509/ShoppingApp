//
//  FileMigration.swift
//  Combined
//
//  Created by Assistant on 6/18/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// We'll use .json files for broader compatibility without paid developer account

// Data structure for file export
struct ShoppingDataExport: Codable {
    let version: String
    let exportDate: Date
    let items: [ShoppingItem]
    let source: String
    
    init(items: [ShoppingItem], source: String = "ShoppingAppV2") {
        self.version = "1.0"
        self.exportDate = Date()
        self.items = items
        self.source = source
    }
}

// Document type for shopping data
struct ShoppingDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var exportData: ShoppingDataExport
    
    init(exportData: ShoppingDataExport) {
        self.exportData = exportData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        exportData = try JSONDecoder().decode(ShoppingDataExport.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        return FileWrapper(regularFileWithContents: data)
    }
}

// File manager for import/export operations
class FileMigrationManager {
    static let shared = FileMigrationManager()
    
    private init() {}
    
    // Create export data
    func createExportDocument(items: [ShoppingItem]) -> ShoppingDataDocument {
        let exportData = ShoppingDataExport(items: items)
        return ShoppingDataDocument(exportData: exportData)
    }
    
    // Generate filename with date
    func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: Date())
        return "ShoppingList-\(dateString).json"
    }
    
    // Import data from file
    func importData(from document: ShoppingDataDocument) -> [ShoppingItem] {
        return document.exportData.items
    }
    
    // Import from URL (for opening files from other apps)
    func importData(from url: URL) throws -> [ShoppingItem] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ShoppingDataExport.self, from: data)
        return exportData.items
    }
}
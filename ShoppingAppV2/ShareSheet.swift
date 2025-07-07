//
//  ShareSheet.swift
//  ShoppingAppV2
//
//  Created by Assistant on 6/18/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let document: ShoppingDataDocument
    let filename: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            // Encode the data directly to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document.exportData)
            try data.write(to: tempURL)
        } catch {
            print("Error creating file: \(error)")
        }
        
        let activityController = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        activityController.completionWithItemsHandler = { _, _, _, _ in
            // Clean up temp file after sharing
            try? FileManager.default.removeItem(at: tempURL)
            presentationMode.wrappedValue.dismiss()
        }
        
        return activityController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

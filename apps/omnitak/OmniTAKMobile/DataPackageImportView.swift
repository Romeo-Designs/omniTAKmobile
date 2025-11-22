//
//  DataPackageImportView.swift
//  OmniTAKMobile
//
//  UI for importing data packages via file picker
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataPackageImportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var packageManager = DataPackageManager()
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importResult: PackageImportResult?
    @State private var importError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if isImporting {
                        importingView
                    } else if let result = importResult {
                        resultView(result: result)
                    } else if let error = importError {
                        errorView(error: error)
                    } else {
                        selectionView
                    }
                }
                .padding()
            }
            .navigationTitle("Import Data Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFilePicker) {
            DataPackageFilePicker(
                allowedTypes: [.zip, .data],
                onPick: handleFilePicked
            )
        }
    }
    
    // MARK: - Selection View
    
    private var selectionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "#00BCD4"))
            
            VStack(spacing: 12) {
                Text("Import Data Package")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Select a .zip, .dpkg, or .tak file to import")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showFilePicker = true }) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Browse Files")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#00BCD4"))
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Importing View
    
    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView(value: importProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#00BCD4")))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(Int(importProgress * 100))% Complete")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Extracting and processing package...")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#AAAAAA"))
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Result View
    
    private func resultView(result: PackageImportResult) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(result.success ? Color(hex: "#4CAF50") : Color(hex: "#FF9800"))
            
            VStack(spacing: 12) {
                Text(result.success ? "Import Successful" : "Import Complete with Warnings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(result.package.name)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                resultRow(icon: "doc.fill", label: "Files", value: "\(result.package.contents.count)")
                resultRow(icon: "map.fill", label: "Overlays", value: "\(result.overlaysImported)")
                resultRow(icon: "photo.fill", label: "Icons", value: "\(result.iconsImported)")
                
                if !result.warnings.isEmpty {
                    resultRow(icon: "exclamationmark.triangle", label: "Warnings", value: "\(result.warnings.count)")
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#00BCD4"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "#F44336"))
            
            VStack(spacing: 12) {
                Text("Import Failed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                importError = nil
                showFilePicker = true
            }) {
                Text("Try Again")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#00BCD4"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Views
    
    private func resultRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#00BCD4"))
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(Color(hex: "#AAAAAA"))
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Import Handling
    
    private func handleFilePicked(url: URL) {
        isImporting = true
        importProgress = 0
        importResult = nil
        importError = nil
        
        Task {
            do {
                // Animate progress
                for i in 1...3 {
                    await MainActor.run {
                        importProgress = Double(i) * 0.2
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                
                // Perform actual import
                let result = try await packageManager.importPackage(from: url)
                
                await MainActor.run {
                    importProgress = 1.0
                    isImporting = false
                    importResult = result
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Document Picker

struct DataPackageFilePicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy to temporary location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onPick(tempURL)
            } catch {
                print("❌ Error copying file: \(error)")
            }
        }
    }
}

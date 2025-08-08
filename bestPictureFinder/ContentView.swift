//
//  ContentView.swift
//  bestPictureFinder
//
//  Created by Snehal Mulchandani on 8/7/25.
//

import SwiftUI
import PhotosUI
import Vision
import Photos
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct ContentView: View {
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var processedImages: [ProcessedImage] = []
    @State private var isProcessing = false
    @State private var processingProgress = 0
    @State private var totalPhotos = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var hasError = false
    #if canImport(UIKit)
    @State private var showIOSAssetPicker = false
    #endif
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
        VStack {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Best Picture Finder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Select photos to find the most aesthetic ones")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Selection Buttons
                HStack(spacing: 12) {
                    #if canImport(UIKit)
                    Button {
                        showIOSAssetPicker = true
                    } label: {
                        Label("Pick from Library", systemImage: "photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .sheet(isPresented: $showIOSAssetPicker) {
                        IOSAssetPicker(isPresented: $showIOSAssetPicker) { ids in
                            Task { await processPHAssetsByIdentifiers(ids) }
                        }
                    }
                    #endif

                    PhotosPicker(
                        selection: $selectedPhotos,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Select (fallback)", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedPhotos) { newItems in
                        Task { await processSelectedPhotos(newItems) }
                    }
                }
                
                // Processing Status
                if isProcessing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing photos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if totalPhotos > 0 {
                            Text("\(processingProgress) of \(totalPhotos) photos processed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // Results Section
                if !processedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Results")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(processedImages.count) photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(Array(processedImages.enumerated()), id: \.offset) { index, image in
                                    ImageResultRow(image: image, rank: index + 1)
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                        
                        // Stats
                        VStack(spacing: 10) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Best Score")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", processedImages.first?.score ?? 0.0))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Worst Score")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", processedImages.last?.score ?? 0.0))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            // Analysis Summary
                            let avgScore = processedImages.map { $0.score }.reduce(0, +) / Double(processedImages.count)
                            HStack {
                                Text("Average Score:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", avgScore))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("Photos analyzed:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(processedImages.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Create Album Button
                        Button(action: createAlbum) {
                            HStack {
                                Image(systemName: "photo.stack")
                                Text("Create Album with Sorted Photos")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .disabled(isProcessing)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
        .alert("Alert", isPresented: $showingAlert) {
            #if os(macOS)
            Button("Open Settings") { openPhotosPrivacySettings() }
            Button("OK") { }
            #else
            Button("OK") { }
            #endif
        } message: {
            Text(alertMessage)
        }
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        processingProgress = 0
        totalPhotos = items.count
        processedImages.removeAll()

        for (index, item) in items.enumerated() {
            // Try to resolve the underlying PHAsset using the picker's itemIdentifier first
            var asset: PHAsset? = nil
            if let localId = item.itemIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                asset = fetchResult.firstObject
            } else if let assetId: String = try? await item.loadTransferable(type: String.self) {
                // Some picker contexts may still vend a string identifier
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                asset = fetchResult.firstObject
            } else if let fileURL: URL = try? await item.loadTransferable(type: URL.self) {
                // As a last resort, fetch by local identifier from resource if resolvable
                if let assetId = PHAsset.fetchAssets(withALAssetURLs: [fileURL], options: nil).firstObject?.localIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                    asset = fetchResult.firstObject
                }
            }

            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                guard let image = UIImage(data: data) else { continue }
                #else
                guard let image = NSImage(data: data) else { continue }
                #endif

                let score = await calculateAestheticScore(for: image)
                let processedImage = ProcessedImage(image: image, score: score, originalIndex: index, asset: asset)
                processedImages.append(processedImage)

                await MainActor.run {
                    processingProgress = index + 1
                }
            }
        }

        // Sort by aesthetic score (highest first)
        processedImages.sort { $0.score > $1.score }

        isProcessing = false
    }
    
    private func calculateAestheticScore(for image: CrossPlatformImage) async -> Double {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return 0.0 }
        #else
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0.0 }
        #endif
        
        // Use the proper CalculateImageAestheticsScoresRequest
        let aestheticRequest = VNCalculateImageAestheticsScoresRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([aestheticRequest])
            
            // Use only VNCalculateImageAestheticsScoresRequest as requested
            if let results = aestheticRequest.results, !results.isEmpty {
                // The VNCalculateImageAestheticsScoresRequest returns VNObservation objects
                // We need to access the score through the observation's properties
                if let observation = results.first as? VNImageAestheticsScoresObservation {
                    // Try to get the aesthetic score from the observation
                    if let scoreValue = observation.value(forKey: "aestheticScore") as? Double {
                        return scoreValue * 100.0
                    } else if let scoreValue = observation.value(forKey: "score") as? Double {
                        return scoreValue * 100.0
                    } else {
                        print("Error: Could not find aesthetic score in observation")
                        await MainActor.run {
                            hasError = true
                            alertMessage = "Aesthetic analysis failed: No score found in result"
                            showingAlert = true
                        }
                    }
                } else {
                    // Fail if the requested API doesn't work as expected
                    print("Error: VNCalculateImageAestheticsScoresRequest did not return expected observation type")
                    await MainActor.run {
                        hasError = true
                        alertMessage = "Aesthetic analysis failed: Unexpected result from Vision framework"
                        showingAlert = true
                    }
                }
            }
        } catch {
            print("Error calculating aesthetic score: \(error)")
            await MainActor.run {
                hasError = true
                alertMessage = "Error analyzing image: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        
        return 0.0
    }
    
    // MARK: - Photos Authorization
    private func requestPhotoAuthorization(_ completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, macOS 11, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                completion(status)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                completion(status)
            }
        }
    }
    
    #if os(macOS)
    private func openPhotosPrivacySettings() {
        // Open System Settings to the Photos privacy pane
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") else { return }
        NSWorkspace.shared.open(url)
    }
    #endif
    
    private func createAlbum() {
        guard !processedImages.isEmpty else {
            alertMessage = "No photos to add to album"
            showingAlert = true
            return
        }
        
        print("Requesting Photos authorization...")
        requestPhotoAuthorization { status in
            DispatchQueue.main.async {
                print("Photos authorization status: \(status.rawValue)")
                switch status {
                case .authorized, .limited:
                    print("Photos access granted, creating album...")
                    self.saveImagesToAlbum()
                case .denied, .restricted:
                    #if os(macOS)
                    self.alertMessage = "Photo library access was denied. Please enable it in System Settings > Privacy & Security > Photos."
                    #else
                    self.alertMessage = "Photo library access was denied. Please enable it in Settings > Privacy > Photos."
                    #endif
                    self.showingAlert = true
                case .notDetermined:
                    self.alertMessage = "Photo library access not determined. Please try again."
                    self.showingAlert = true
                @unknown default:
                    self.alertMessage = "Unknown authorization status: \(status.rawValue)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func saveImagesToAlbum() {
        let albumName = "Best Pictures - \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        // First, create the album
        PHPhotoLibrary.shared().performChanges {
            let albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        } completionHandler: { success, error in
            if success {
                // Now add images to the created album
                self.addImagesToAlbum(albumName: albumName)
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to create album: \(error?.localizedDescription ?? "Unknown error")"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func addImagesToAlbum(albumName: String) {
        // Find the album we just created
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let album = collections.firstObject else {
            DispatchQueue.main.async {
                self.alertMessage = "Could not find created album"
                self.showingAlert = true
            }
            return
        }

        // Add existing assets to the album if available; otherwise create new assets
        PHPhotoLibrary.shared().performChanges {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            let placeholders = NSMutableArray()

            for processedImage in self.processedImages {
                if let asset = processedImage.asset {
                    albumChangeRequest?.addAssets([asset] as NSFastEnumeration)
                } else {
                    #if canImport(UIKit)
                    let imageRequest = PHAssetChangeRequest.creationRequestForAsset(from: processedImage.image)
                    #else
                    let imageRequest = PHAssetChangeRequest.creationRequestForAsset(from: processedImage.image)
                    #endif
                    if let ph = imageRequest.placeholderForCreatedAsset {
                        placeholders.add(ph)
                    }
                }
            }

            if placeholders.count > 0 {
                albumChangeRequest?.addAssets(placeholders)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Album '\(albumName)' created successfully with \(self.processedImages.count) photos!"
                } else {
                    self.alertMessage = "Failed to add photos to album: \(error?.localizedDescription ?? "Unknown error")"
                }
                self.showingAlert = true
            }
        }
    }

    // iOS-only: process assets by identifiers from PHPicker so we don't duplicate assets
    #if canImport(UIKit)
    private func processPHAssetsByIdentifiers(_ ids: [String]) async {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        await processPHAssets(assets)
    }

    private func requestImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func processPHAssets(_ assets: [PHAsset]) async {
        isProcessing = true
        processingProgress = 0
        totalPhotos = assets.count
        processedImages.removeAll()

        for (index, asset) in assets.enumerated() {
            guard let data = await requestImageData(for: asset) else { continue }
            guard let image = UIImage(data: data) else { continue }
            let score = await calculateAestheticScore(for: image)
            let processed = ProcessedImage(image: image, score: score, originalIndex: index, asset: asset)
            processedImages.append(processed)
            await MainActor.run { processingProgress = index + 1 }
        }

        processedImages.sort { $0.score > $1.score }
        isProcessing = false
    }
    #endif
}

#if canImport(UIKit)
typealias CrossPlatformImage = UIImage
#else
typealias CrossPlatformImage = NSImage
#endif

struct ProcessedImage {
    let image: CrossPlatformImage
    let score: Double
    let originalIndex: Int
    let asset: PHAsset?
}

struct ImageResultRow: View {
    let image: ProcessedImage
    let rank: Int
    
    var body: some View {
        HStack(spacing: 15) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 30, height: 30)
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Thumbnail
            #if canImport(UIKit)
            Image(uiImage: image.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
            #else
            Image(nsImage: image.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
            #endif
            
            // Score and info
            VStack(alignment: .leading, spacing: 4) {
                Text("Aesthetic Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", image.score))
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Original: #\(image.originalIndex + 1)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score indicator
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < Int(image.score / 20) ? Color.yellow : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

#Preview {
    ContentView()
}

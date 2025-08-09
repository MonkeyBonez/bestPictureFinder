//
//  ContentView.swift
//  bestPictureFinder
//
//  Created by Snehal Mulchandani on 8/7/25.
//

import SwiftUI
import Vision
import Photos
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showIOSAssetPicker = false
    @State private var pendingIOSPickerResults: [PHPickerResult] = []
    @State private var processedImages: [ProcessedImage] = []
    @State private var selectedIds: Set<String> = []
    @State private var isProcessing = false
    @State private var processingProgress = 0
    @State private var totalPhotos = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var hasError = false
    @State private var shareItems: [Any] = []
    @State private var isPresentingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignColors.appBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                // Selection Button (iOS only)
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
                    IOSAssetPicker(isPresented: $showIOSAssetPicker) { results in
                        pendingIOSPickerResults = results
                        Task { await processIOSPickerResults(results) }
                    }
                }

                // Processing Status
                if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        if totalPhotos > 0 {
                            Text("Analyzing photos… \(processingProgress)/\(totalPhotos)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Results List
                if !processedImages.isEmpty {
                    PhotoResultsListView(
                        processedImages: processedImages,
                        selectedIds: selectedIds,
                        onToggleSelection: { img in toggleSelection(for: img) },
                        onShare: { img in Task { await share(img) } },
                        onDelete: { img in delete(img) }
                    )

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
                
                Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .toolbarBackground(DesignColors.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Alert", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $isPresentingShareSheet, content: {
            ShareSheet(activityItems: shareItems)
        })
    }

    // iOS image loading helper and picker processing
    private func loadUIImage(from provider: NSItemProvider) async throws -> UIImage {
        if provider.canLoadObject(ofClass: UIImage.self) {
            return try await withCheckedThrowingContinuation { cont in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error { cont.resume(throwing: error); return }
                    guard let image = object as? UIImage else {
                        cont.resume(throwing: NSError(domain: "Picker", code: -1))
                        return
                    }
                    cont.resume(returning: image)
                }
            }
        }
        let data = try await withCheckedThrowingContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data { cont.resume(returning: data) }
                else { cont.resume(throwing: error ?? NSError(domain: "Picker", code: -2)) }
            }
        }
        guard let image = UIImage(data: data) else { throw NSError(domain: "Picker", code: -3) }
        return image
    }

    private func processIOSPickerResults(_ results: [PHPickerResult]) async {
        isProcessing = true
        processingProgress = 0
        totalPhotos = results.count
        processedImages.removeAll()

        for (index, result) in results.enumerated() {
            do {
                let image = try await loadUIImage(from: result.itemProvider)
                let score = await calculateAestheticScore(for: image)
                var phAsset: PHAsset? = nil
                if let id = result.assetIdentifier {
                    let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                    phAsset = fetched.firstObject
                }
                let identifier = phAsset?.localIdentifier ?? UUID().uuidString
                let processed = ProcessedImage(id: identifier, image: image, score: score, originalIndex: index, asset: phAsset)
                processedImages.append(processed)
            } catch {
                print("Failed to load UIImage: \(error)")
            }
            await MainActor.run { processingProgress = index + 1 }
        }

        processedImages.sort { $0.score > $1.score }
        isProcessing = false
    }


    private func calculateAestheticScore(for image: CrossPlatformImage) async -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        let aestheticRequest = VNCalculateImageAestheticsScoresRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([aestheticRequest]) } catch { return 0.0 }
        if let obs = aestheticRequest.results?.first as? VNImageAestheticsScoresObservation {
            // Convert to -100..100 range for downstream normalization (0..5) and hue mapping
            return Double(obs.overallScore) * 100.0
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
    
    private func createAlbum() {
        guard !processedImages.isEmpty else {
            alertMessage = "No photos to add to album"
            showingAlert = true
            return
        }

        // Temporarily disable Photos writes to avoid any permission prompts
        alertMessage = "Album creation is temporarily disabled to avoid Photos permission prompts. We’ll re-enable this with proper permissions later."
        showingAlert = true
    }

    private func handleAuthAndSave(status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited:
            self.saveImagesToAlbum()
        case .denied, .restricted:
            #if os(iOS)
            alertMessage = "Photo additions denied. Enable in Settings > Privacy > Photos."
            #else
            alertMessage = "Photo library access was denied. Enable in System Settings > Privacy & Security > Photos."
            #endif
            showingAlert = true
        case .notDetermined:
            alertMessage = "Photo library access not determined. Please try again."
            showingAlert = true
        @unknown default:
            alertMessage = "Unknown authorization status."
            showingAlert = true
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

    // iOS helpers
    private func ensurePhotoAccess(_ handled: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard current == .notDetermined else { handled(current); return }
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async { handled(status) }
            }
        } else {
            let current = PHPhotoLibrary.authorizationStatus()
            guard current == .notDetermined else { handled(current); return }
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { handled(status) }
            }
        }
    }

    private func toggleSelection(for image: ProcessedImage) {
        if selectedIds.contains(image.id) { selectedIds.remove(image.id) } else { selectedIds.insert(image.id) }
    }

    private func delete(_ image: ProcessedImage) {
        processedImages.removeAll { $0.id == image.id }
        selectedIds.remove(image.id)
    }

    private func share(_ image: ProcessedImage) async {
        if let asset = image.asset {
            await shareOriginalAsset(asset)
        } else {
            await shareImageDataFallback(image.image)
        }
    }

    private func shareOriginalAsset(_ asset: PHAsset) async {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first else {
            await MainActor.run {
                alertMessage = "Unable to access original resource for sharing."
                showingAlert = true
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        do {
            try? FileManager.default.removeItem(at: tempURL)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: nil) { error in
                    if let error = error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
            await MainActor.run {
                shareItems = [tempURL]
                isPresentingShareSheet = true
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to prepare original for sharing: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    private func shareImageDataFallback(_ uiImage: UIImage) async {
        guard let data = uiImage.jpegData(compressionQuality: 0.95) else {
            await MainActor.run {
                alertMessage = "Failed to prepare image for sharing."
                showingAlert = true
            }
            return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: tempURL)
            await MainActor.run {
                shareItems = [tempURL]
                isPresentingShareSheet = true
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to write temp image for sharing."
                showingAlert = true
            }
        }
    }

    // Deep link to app settings for Photos permissions
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // Optional: let user expand Limited access without leaving the app
    private func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
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
            let identifier = asset.localIdentifier
            let processed = ProcessedImage(id: identifier, image: image, score: score, originalIndex: index, asset: asset)
            processedImages.append(processed)
            await MainActor.run { processingProgress = index + 1 }
        }

        processedImages.sort { $0.score > $1.score }
        isProcessing = false
    }
}

typealias CrossPlatformImage = UIImage

// DesignColors moved to DesignColors.swift

struct ProcessedImage: Identifiable {
    let id: String
    let image: CrossPlatformImage
    let score: Double
    let originalIndex: Int
    let asset: PHAsset?
}

#Preview {
    ContentView()
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}


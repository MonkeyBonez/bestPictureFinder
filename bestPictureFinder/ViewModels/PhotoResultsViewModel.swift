//
//  PhotoResultsViewModel.swift
//  bestPictureFinder
//

import SwiftUI
import Photos
import PhotosUI
import Combine
import CryptoKit

@MainActor
final class PhotoResultsViewModel: ObservableObject {
    // Published state
    @Published var processedImages: [ProcessedImage] = []
    @Published var selectedIds: Set<String> = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Int = 0
    @Published var totalPhotos: Int = 0
    @Published var alertMessage: String = ""
    @Published var isPresentingShareSheet: Bool = false
    @Published var shareItems: [Any] = []
    @Published var isPresentingAlbumNamePrompt: Bool = false
    @Published var albumNameInput: String = ""
    @Published var toastMessage: String = ""

    // Dependencies
    private let vision: VisionScoringServiceProtocol
    private let photos: PhotoLibraryServiceProtocol

    init(vision: VisionScoringServiceProtocol = VisionScoringService(),
         photos: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
        self.vision = vision
        self.photos = photos
    }

    // MARK: - Intents
    func handlePicker(results: [PHPickerResult]) async {
        isProcessing = true
        processingProgress = 0
        totalPhotos = results.count
        // Append newly picked photos to existing results instead of replacing

        var existingIds = Set(processedImages.map { $0.id })

        for (idx, result) in results.enumerated() {
            do {
                let uiImage = try await loadUIImage(from: result.itemProvider)
                let score = await vision.calculateScore(for: uiImage)
                // Do NOT resolve PHAsset here to avoid prompting; capture the local identifier instead
                let pickedLocalId: String? = result.assetIdentifier
                // Prefer Photos asset ID for stable dedup; otherwise derive a deterministic digest from image bytes
                let identifier: String = {
                    if let localId = pickedLocalId { return localId }
                    if let digest = computeStableImageDigest(for: uiImage) { return digest }
                    return UUID().uuidString
                }()

                // Deduplicate: skip if we've already added this identifier
                if existingIds.contains(identifier) {
                    // Already present; skip adding a duplicate
                    continue
                }
                let processed = ProcessedImage(
                    id: identifier,
                    image: uiImage,
                    score: score,
                    originalIndex: idx,
                    assetLocalIdentifier: pickedLocalId,
                    asset: nil
                )
                processedImages.append(processed)
                existingIds.insert(identifier)
            } catch {
                print("Picker load failed: \(error)")
            }
            processingProgress = idx + 1
        }
        processedImages.sort { $0.score > $1.score }
        isProcessing = false
    }

    func toggleSelection(id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    func selectTop(count: Int) {
        let limited = max(0, min(count, processedImages.count))
        selectedIds = Set(processedImages.prefix(limited).map { $0.id })
    }

    func selectAll() {
        selectedIds = Set(processedImages.map { $0.id })
    }
    
    func deselectAll() {
        selectedIds = Set()
    }

    func delete(image: ProcessedImage) {
        processedImages.removeAll { $0.id == image.id }
        selectedIds.remove(image.id)
    }

    func deleteSelected() {
        processedImages.removeAll { selectedIds.contains($0.id) }
        selectedIds.removeAll()
    }

    func share(image: ProcessedImage) async {
        await shareItemsFor(images: [image])
    }

    func shareSelected() async {
        let images = processedImages.filter { selectedIds.contains($0.id) }
        await shareItemsFor(images: images)
    }

    func showAlbumNamePrompt() {
        let defaultName = ""
        albumNameInput = defaultName
        isPresentingAlbumNamePrompt = true
    }

    func createAlbum() async {
        guard !processedImages.isEmpty else {
            alertMessage = "No photos to add to album"
            return
        }
        
        let status = await photos.ensureReadWriteAuthorization()
        guard status == .authorized || status == .limited else {
            alertMessage = "Photo additions denied. Enable in Settings > Privacy > Photos."
            return
        }
        
        // Use the user-provided album name, or fallback to default if empty
        let albumName = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Aesthesis"
            : albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let unique = photos.uniqueAlbumName(base: albumName)
        
        do {
            let album = try await photos.createAlbum(named: unique)
            var addedCount = 0
            
            // Try to add PHAssets first (original quality)
            // Add items in the displayed (aesthetic) order, deduping and preferring original assets
            var addedAssetLocalIds = Set<String>()
            var addedDigests = Set<String>()
            for item in processedImages {
                // Try original asset first
                if let localId = item.assetLocalIdentifier,
                   !addedAssetLocalIds.contains(localId),
                   let asset = photos.fetchAsset(by: localId) {
                    do {
                        try await photos.addAssets([asset], to: album)
                        addedAssetLocalIds.insert(localId)
                        addedCount += 1
                        continue
                    } catch {
                        print("Failed to add asset \(localId): \(error)")
                        // fall through to data
                    }
                }

                // Fallback to image data (dedupe by digest)
                if let digest = computeStableImageDigest(for: item.image), addedDigests.contains(digest) {
                    continue
                }
                if let data = item.image.jpegData(compressionQuality: 0.95) {
                    do {
                        try await photos.addImageData(data, to: album)
                        if let digest = computeStableImageDigest(for: item.image) { addedDigests.insert(digest) }
                        addedCount += 1
                    } catch {
                        print("Failed to add image data: \(error)")
                    }
                }
            }
            
            if addedCount > 0 {
                // Show toast; lifecycle managed by LiquidGlassToast
                toastMessage = "Album '\(unique)' created in Photos."
            } else {
                alertMessage = "Failed to add any photos to album."
            }
        } catch {
            alertMessage = "Failed to create album: \(error.localizedDescription)"
        }
        
        // Reset the prompt state
        isPresentingAlbumNamePrompt = false
        albumNameInput = ""
    }

    // MARK: - Helpers
    private func loadUIImage(from provider: NSItemProvider) async throws -> UIImage {
        if provider.canLoadObject(ofClass: UIImage.self) {
            return try await withCheckedThrowingContinuation { cont in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error { cont.resume(throwing: error); return }
                    guard let image = object as? UIImage else {
                        cont.resume(throwing: NSError(domain: "Picker", code: -1)); return
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

    private func shareItemsFor(images: [ProcessedImage]) async {
        guard !images.isEmpty else {
            alertMessage = "must select photos"
            return
        }
        let assets = images.compactMap { $0.asset }
        if !assets.isEmpty {
            do {
                let urls = try await photos.exportOriginalResources(for: assets)
                shareItems = urls
                isPresentingShareSheet = true
                return
            } catch {
                alertMessage = "Failed to export originals: \(error.localizedDescription)"
            }
        }
        // Fallback: share JPEGs of in-memory images
        var urls: [URL] = []
        for img in images.map({ $0.image }) {
            if let data = img.jpegData(compressionQuality: 0.95) {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")
                try? data.write(to: url)
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            shareItems = urls
            isPresentingShareSheet = true
        } else {
            alertMessage = "Failed to prepare images for sharing."
        }
    }

    // Creates a stable digest for non-asset images to allow deduplication across sessions/picks
    private func computeStableImageDigest(for image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}


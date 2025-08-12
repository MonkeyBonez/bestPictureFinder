//
//  PhotoResultsViewModel.swift
//  bestPictureFinder
//

import SwiftUI
import Photos
import PhotosUI
import Combine

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

        for (idx, result) in results.enumerated() {
            do {
                let uiImage = try await loadUIImage(from: result.itemProvider)
                let score = await vision.calculateScore(for: uiImage)
                var phAsset: PHAsset? = nil
                if let id = result.assetIdentifier { phAsset = photos.fetchAsset(by: id) }
                let identifier = phAsset?.localIdentifier ?? UUID().uuidString
                let processed = ProcessedImage(id: identifier, image: uiImage, score: score, originalIndex: idx, asset: phAsset)
                processedImages.append(processed)
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
        let base = "TO NAME \(Date().formatted(date: .abbreviated, time: .shortened))"
        let unique = photos.uniqueAlbumName(base: base)
        do {
            let album = try await photos.createAlbum(named: unique)
            let assets: [PHAsset] = processedImages.compactMap { $0.asset }
            if !assets.isEmpty {
                try await photos.addAssets(assets, to: album)
            }
            alertMessage = "Album '\(unique)' created."
        } catch {
            alertMessage = "Failed to create album: \(error.localizedDescription)"
        }
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
}


//
//  PhotoLibraryService.swift
//  bestPictureFinder
//

import UIKit
import Photos

protocol PhotoLibraryServiceProtocol {
    func ensureReadWriteAuthorization() async -> PHAuthorizationStatus
    func fetchAsset(by id: String) -> PHAsset?
    func requestImageData(asset: PHAsset) async -> Data?
    func exportOriginalResources(for assets: [PHAsset]) async throws -> [URL]
    func uniqueAlbumName(base: String) -> String
    func createAlbum(named: String) async throws -> PHAssetCollection
    func addAssets(_ assets: [PHAsset], to album: PHAssetCollection) async throws
    func addImageData(_ imageData: Data, to album: PHAssetCollection) async throws
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    func ensureReadWriteAuthorization() async -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if current == .notDetermined {
                return await withCheckedContinuation { (cont: CheckedContinuation<PHAuthorizationStatus, Never>) in
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        cont.resume(returning: status)
                    }
                }
            }
            return current
        } else {
            let current = PHPhotoLibrary.authorizationStatus()
            if current == .notDetermined {
                return await withCheckedContinuation { (cont: CheckedContinuation<PHAuthorizationStatus, Never>) in
                    PHPhotoLibrary.requestAuthorization { status in
                        cont.resume(returning: status)
                    }
                }
            }
            return current
        }
    }

    func fetchAsset(by id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    func requestImageData(asset: PHAsset) async -> Data? {
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

    func exportOriginalResources(for assets: [PHAsset]) async throws -> [URL] {
        try await withThrowingTaskGroup(of: URL.self) { group in
            for asset in assets {
                group.addTask {
                    let resources = PHAssetResource.assetResources(for: asset)
                    let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first!
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try? FileManager.default.removeItem(at: url)
                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: nil) { error in
                            if let error = error { cont.resume(throwing: error) } else { cont.resume() }
                        }
                    }
                    return url
                }
            }
            var urls: [URL] = []
            for try await u in group { urls.append(u) }
            return urls
        }
    }

    func uniqueAlbumName(base: String) -> String {
        var name = base
        var suffix = 2
        while PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumFetchOptions(named: name)).firstObject != nil {
            name = "\(base) (\(suffix))"
            suffix += 1
        }
        return name
    }

    func createAlbum(named: String) async throws -> PHAssetCollection {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PHAssetCollection, Error>) in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: named)
                placeholder = req.placeholderForCreatedAssetCollection
            } completionHandler: { success, error in
                if let error = error { cont.resume(throwing: error); return }
                guard success, let ph = placeholder else {
                    cont.resume(throwing: NSError(domain: "Album", code: -1)); return
                }
                let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [ph.localIdentifier], options: nil)
                if let col = collections.firstObject { cont.resume(returning: col) }
                else { cont.resume(throwing: NSError(domain: "Album", code: -2)) }
            }
        }
    }

    func addAssets(_ assets: [PHAsset], to album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let changeRequest = PHAssetCollectionChangeRequest(for: album)
                changeRequest?.addAssets(assets as NSFastEnumeration)
            } completionHandler: { success, error in
                if let error = error { cont.resume(throwing: error) }
                else if success { cont.resume() }
                else { cont.resume(throwing: NSError(domain: "Album", code: -3)) }
            }
        }
    }
    
    func addImageData(_ imageData: Data, to album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                // Convert Data to UIImage first
                guard let image = UIImage(data: imageData) else {
                    cont.resume(throwing: NSError(domain: "Album", code: -5))
                    return
                }
                
                // Create a new asset from the image
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                
                // Add the new asset to the album
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets([assetRequest.placeholderForCreatedAsset!] as NSFastEnumeration)
            } completionHandler: { success, error in
                if let error = error { cont.resume(throwing: error) }
                else if success { cont.resume() }
                else { cont.resume(throwing: NSError(domain: "Album", code: -4)) }
            }
        }
    }

    private func albumFetchOptions(named: String) -> PHFetchOptions {
        let fo = PHFetchOptions()
        fo.predicate = NSPredicate(format: "title = %@", named)
        return fo
    }
}


//
//  IOSAssetPicker.swift
//  bestPictureFinder
//
//  Created to provide an iOS-only PHPicker wrapper that yields PHAsset identifiers.
//

#if canImport(UIKit)
import SwiftUI
import Photos
import PhotosUI

struct IOSAssetPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPicked: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0 // unlimited
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: IOSAssetPicker
        init(_ parent: IOSAssetPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            defer { parent.isPresented = false }
            // Collect asset identifiers for items that are from Photos library
            let ids = results.compactMap { $0.assetIdentifier }
            parent.onPicked(ids)
        }
    }
}
#endif
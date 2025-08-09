//
//  IOSAssetPicker.swift
//  bestPictureFinder
//
//  Created to provide an iOS-only PHPicker wrapper that yields PHPickerResult values with asset identifiers.
//

import SwiftUI
import Photos
import PhotosUI

struct IOSAssetPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPickedResults: ([PHPickerResult]) -> Void

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
            parent.onPickedResults(results)
        }
    }
}
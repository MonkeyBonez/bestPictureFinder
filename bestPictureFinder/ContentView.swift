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
    @StateObject private var viewModel = PhotoResultsViewModel()
    @State private var showIOSAssetPicker = false
    @State private var pendingIOSPickerResults: [PHPickerResult] = []

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
                if viewModel.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        if viewModel.totalPhotos > 0 {
                            Text("Analyzing photos… \(viewModel.processingProgress)/\(viewModel.totalPhotos)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Results List
                if !viewModel.processedImages.isEmpty {
                    PhotoResultsListView(
                        processedImages: viewModel.processedImages,
                        selectedIds: viewModel.selectedIds,
                        onToggleSelection: { img in viewModel.toggleSelection(id: img.id) },
                        onShare: { img in Task { await viewModel.share(image: img) } },
                        onDelete: { img in viewModel.delete(image: img) }
                    )

                    // Create Album Button
                    Button(action: { Task { await viewModel.createAlbum() } }) {
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
                    .disabled(viewModel.isProcessing)
                }
                
                Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .toolbarBackground(DesignColors.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Alert", isPresented: .constant(!viewModel.alertMessage.isEmpty)) {
            Button("OK") { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.isPresentingShareSheet, content: {
            ShareSheet(activityItems: viewModel.shareItems)
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
        await viewModel.handlePicker(results: results)
    }


    // Scoring moved to VisionScoringService via ViewModel
    
    // Removed legacy album helpers; handled by ViewModel and PhotoLibraryService

    // Selection/share/delete delegated to ViewModel

    // Share moved into ViewModel

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

    // Asset processing handled by ViewModel
}

typealias CrossPlatformImage = UIImage

// DesignColors moved to DesignColors.swift


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


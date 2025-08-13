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
    @State private var overlayPresentation: (images: [UIImage], index: Int, sourceId: String)? = nil
    @Namespace private var heroNS
    @State private var thumbnailFrames: [String: CGRect] = [:]
    @State private var compactToolbar: Bool = false
    @State private var leftSlotWidth: CGFloat = 0
    @State private var rightSlotWidth: CGFloat = 0
    private let toolbarSpacing: CGFloat = 21
    
    var navTitle: String {
        let selectedCount = viewModel.selectedIds.count
        
        if selectedCount == 0 {
            return "No photos selected"
        }
        if selectedCount == 1 {
            return "1 photo selected"
        }
        
        return "\(selectedCount) photos selected"
    }
    
    var isFullscreen: Bool {
        overlayPresentation != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignColors.appBackground.ignoresSafeArea()
                // Results List
                if !viewModel.processedImages.isEmpty {
                    ZStack {
                        PhotoResultsListView(
                            processedImages: viewModel.processedImages,
                            selectedIds: viewModel.selectedIds,
                            onToggleSelection: { img in viewModel.toggleSelection(id: img.id) },
                            onShare: { img in Task { await viewModel.share(image: img) } },
                            onDelete: { img in viewModel.delete(image: img) },
                            onOpenOverlay: { images, startIndex, sourceId in
                                // Expand toolbar to full set during animation, then compact
                                compactToolbar = false
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.overlayPresentation = (images, startIndex, sourceId)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    compactToolbar = true
                                }
                            },
                            heroNamespace: heroNS,
                            activeSourceId: overlayPresentation?.sourceId,
                            onReportThumbnailFrame: { id, frame in thumbnailFrames[id] = frame }
                        )
                        
                        if viewModel.isProcessing {
                            VStack(spacing: 8) {
                                ProgressView().scaleEffect(1.2)
                                if viewModel.totalPhotos > 0 {
                                    Text("Analyzing photos… \(viewModel.processingProgress)/\(viewModel.totalPhotos)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(radius: 10)
                        }
                    }
                    
                    // (Moved) Create Album action is now in the bottom toolbar
                }
            }
            .navigationTitle(isFullscreen ? "" : navTitle)
            .navigationBarTitleDisplayMode(.inline)
            
            //            .toolbarBackground(.visible, for: .navigationBar)
            //            .toolbarBackground(DesignColors.appBackground, for: .navigationBar)
            //            .toolbarBackground(.visible, for: .navigationBar)
            //            .toolbarBackground(DesignColors.appBackground, for: .bottomBar)
            //            .toolbarBackground(.visible, for: .bottomBar)
            .toolbar {

                // Sticky header placeholder (top bar)
                //                ToolbarItem(placement: .topBarLeading) {
                //                    Color.clear.frame(width: 1, height: 44)
                //                        .accessibilityHidden(true)
                //                }
                if !isFullscreen {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            // "Select Top 5"
                            if viewModel.processedImages.count >= 5 {
                                Button("Select Top 5") {
                                    viewModel.selectTop(count: 5)
                                }
                            }
                            // "Select Top 10"
                            if viewModel.processedImages.count >= 10 {
                                Button("Select Top 10") {
                                    viewModel.selectTop(count: 10)
                                }
                            }
                            // "Select Top 20"
                            if viewModel.processedImages.count >= 20 {
                                Button("Select Top 20") {
                                    viewModel.selectTop(count: 20)
                                }
                            }
                            // "Select All" (always shown)
                            if !viewModel.processedImages.isEmpty {
                                Button("Select All") {
                                    viewModel.selectAll()
                                }
                            }
                            
                            if !viewModel.selectedIds.isEmpty {
                                Button("Deselect All") {
                                    viewModel.deselectAll()
                                }
                            }
                            
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                        }
                        .font(.headline)
                        .tint(DesignColors.vividLavender)
                        .disabled(viewModel.processedImages.count == 0)
                        
                    }
                }
                // Bottom toolbar actions with in-place sliding/fade animations
                ToolbarItemGroup(placement: .bottomBar) {
                    //                    let isFullscreen = overlayPresentation != nil
                    let current: ProcessedImage? = overlayPresentation.flatMap { overlay in
                        viewModel.processedImages.first { $0.id == overlay.sourceId }
                    }
                    
                    // Left side group (Create Album + Share)
                    HStack(spacing: toolbarSpacing) {
                        // Create Album: present normally in list; during fullscreen keep only during animation, then remove
                        if !isFullscreen {
                            Button("Create Album", systemImage: "photo.stack") {
                                viewModel.showAlbumNamePrompt()
                            }
                            .disabled(viewModel.selectedIds.isEmpty || viewModel.isProcessing)
                            .tint(DesignColors.sunYellow)
                            .accessibilityLabel("Create Album with Selected Photos")
                            .opacity(1)
                            .offset(x: 0)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.onAppear { leftSlotWidth = proxy.size.width }
                                        .onChange(of: proxy.size.width) { newValue in leftSlotWidth = newValue }
                                }
                            )
                        } else if !compactToolbar {
                            Button("Create Album", systemImage: "photo.stack") {
                                viewModel.showAlbumNamePrompt()
                            }
                            .disabled(true)
                            .opacity(0)
                            .offset(x: -24)
                            .accessibilityHidden(true)
                        }
                        
                        // Share switches behavior based on mode
                        Button("Share", systemImage: "square.and.arrow.up.fill") {
                            if let current { Task { await viewModel.share(image: current) } }
                            else { Task { await viewModel.shareSelected() } }
                        }
                        .disabled(isFullscreen ? (current == nil || viewModel.isProcessing)
                                  : (viewModel.selectedIds.isEmpty || viewModel.isProcessing))
                        .tint(.accentColor)
                        .accessibilityLabel(isFullscreen ? "Share This Photo" : "Share Selected Photos")
                        .offset(x: (isFullscreen && !compactToolbar) ? -(leftSlotWidth + toolbarSpacing) + 1 : 0, y: (isFullscreen && !compactToolbar) ? 0 : -2)
                    }
                    .font(.headline)
                    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isFullscreen)
                    
                    Spacer()
                    
                    // Right side group (Remove + Add Photos)
                    HStack(spacing: toolbarSpacing) {
                        // Remove switches label/behavior but stays in place
                        Button(isFullscreen ? "Remove" : "Remove Selected", systemImage: "minus.circle.fill") {
                            if let current, isFullscreen {
                                viewModel.delete(image: current)
                                overlayPresentation = nil
                            } else {
                                removeSelectedPhotos()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .tint(.red)
                        .disabled(isFullscreen ? viewModel.isProcessing : viewModel.selectedIds.isEmpty)
                        .accessibilityLabel(isFullscreen ? "Remove This Photo" : "Remove Selected Photos")
                        .offset(x: (isFullscreen && !compactToolbar) ? (rightSlotWidth + toolbarSpacing) - 1: 0)
                        
                        // Add Photos: present normally in list; during fullscreen keep only during animation, then remove
                        if !isFullscreen {
                            Button("Add Photos", systemImage: "plus.circle.fill") {
                                showIOSAssetPicker = true
                            }
                            .labelStyle(.iconOnly)
                            .tint(DesignColors.mintGreen)
                            .accessibilityLabel("Add Photos")
                            .opacity(1)
                            .offset(x: 0)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.onAppear { rightSlotWidth = proxy.size.width }
                                        .onChange(of: proxy.size.width) { newValue in rightSlotWidth = newValue }
                                }
                            )
                        } else if !compactToolbar {
                            Button("Add Photos", systemImage: "plus.circle.fill") {
                                showIOSAssetPicker = true
                            }
                            .labelStyle(.iconOnly)
                            .disabled(true)
                            .opacity(0)
                            .offset(x: 24)
                            .accessibilityHidden(true)
                        }
                    }
                    .font(.headline)
                    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isFullscreen)
                    .overlay(
                        // Move Remove to the right slot during transition
                        Color.clear
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                    )
                }
            }
            
            .alert("Alert", isPresented: .constant(!viewModel.alertMessage.isEmpty)) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Name Your Album", isPresented: $viewModel.isPresentingAlbumNamePrompt) {
                TextField("Album Name", text: $viewModel.albumNameInput)
                Button("Cancel", role: .cancel) { }
                Button("Create", role: .confirm) {
                    Task { await viewModel.createAlbum() }
                }
            } message: {
                Text("Aesthetically sorted photo album")
            }
            .sheet(isPresented: $viewModel.isPresentingShareSheet, content: {
                ShareSheet(activityItems: viewModel.shareItems)
            })
            .sheet(isPresented: $showIOSAssetPicker) {
                IOSAssetPicker(isPresented: $showIOSAssetPicker) { results in
                    pendingIOSPickerResults = results
                    Task { await processIOSPickerResults(results) }
                }
            }
            .overlay(alignment: .center) {
                if let overlayPresentation {
                    FullScreenImageView(
                        images: overlayPresentation.images,
                        index: overlayPresentation.index,
                        onClose: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                                self.overlayPresentation = nil
                            }
                            // After the slide/fade animation, collapse toolbar to compact layout
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                compactToolbar = false
                            }
                        },
                        heroNamespace: heroNS,
                        sourceId: overlayPresentation.sourceId,
                        targetThumbnailFrame: thumbnailFrames[overlayPresentation.sourceId]
                    )
                    .ignoresSafeArea()
                    //                .transition(.opacity.combined(with: .scale(scale: 0.20)))
                }
            }
            .overlay(alignment: .top) {
                LiquidGlassToast(message: viewModel.toastMessage) {
                    viewModel.toastMessage = ""
                }
                .padding(.top, 10)
            }
            //        .animation(.easeInOut(duration: 1.0), value: overlayPresentation != nil)
        }
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

    private func removeSelectedPhotos() {
        let selected = viewModel.selectedIds
        guard !selected.isEmpty else { return }
        // Remove all selected images
        for img in viewModel.processedImages where selected.contains(img.id) {
            viewModel.delete(image: img)
        }
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

//
//  ThumbnailView.swift
//  bestPictureFinder
//

import SwiftUI

struct ThumbnailView: View {
    let image: UIImage
    var size: CGFloat = 80
    var cornerRadius: CGFloat = 10
    var matchedGeometryId: String? = nil
    var heroNamespace: Namespace.ID? = nil

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(cornerRadius)
            .modifier(MatchedGeometryWrapper(id: matchedGeometryId, ns: heroNamespace))
    }
}

private struct MatchedGeometryWrapper: ViewModifier {
    let id: String?
    let ns: Namespace.ID?
    func body(content: Content) -> some View {
        if let id, let ns {
            content.matchedGeometryEffect(id: id, in: ns, properties: .position)
        } else {
            content
        }
    }
}


#if canImport(UIKit)
import SwiftUI

/// Media browser panel showing imported assets.
public struct MediaBrowserView: View {
    @ObservedObject var mediaLibrary: MediaLibrary
    let onAssetSelected: (MediaLibrary.MediaAsset) -> Void
    let onImportTapped: () -> Void

    public init(
        mediaLibrary: MediaLibrary,
        onAssetSelected: @escaping (MediaLibrary.MediaAsset) -> Void,
        onImportTapped: @escaping () -> Void
    ) {
        self.mediaLibrary = mediaLibrary
        self.onAssetSelected = onAssetSelected
        self.onImportTapped = onImportTapped
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Media")
                    .font(.headline)
                Spacer()
                Button {
                    onImportTapped()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if mediaLibrary.assets.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No media imported")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Import Media") {
                        onImportTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Media grid
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(mediaLibrary.assets) { asset in
                            MediaThumbnailView(asset: asset)
                                .onTapGesture {
                                    onAssetSelected(asset)
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

/// Thumbnail card for a media asset.
struct MediaThumbnailView: View {
    let asset: MediaLibrary.MediaAsset

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .aspectRatio(16.0/9.0, contentMode: .fit)

                Image(systemName: asset.mediaType == .video ? "film" : "waveform")
                    .font(.title2)
                    .foregroundColor(.secondary)

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(asset.formattedDuration)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                }
                .padding(4)
            }

            Text(asset.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}
#endif

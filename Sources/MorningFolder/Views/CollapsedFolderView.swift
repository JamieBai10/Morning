import AppKit
import SwiftUI

struct CollapsedFolderView: View {
    let isPeeking: Bool
    let onOpen: () -> Void
    @State private var isHovering = false

    private var shouldPeekPapers: Bool {
        isPeeking || isHovering
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FolderAssetImage(name: "folder-back-filled", width: 246, height: 218)

            folderPapers

            FolderAssetImage(name: "folder-pocket-glass", width: 246, height: 218)

            crispTitleOverlay

            openHitArea
        }
        .frame(width: 246, height: 218)
        .scaleEffect(isHovering ? 1.018 : 1)
        .offset(y: isHovering ? -4 : 0)
        .animation(MFMotion.fast, value: isHovering)
        .animation(MFMotion.snap, value: isPeeking)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Open Morning Folder")
    }

    private var openHitArea: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 214, height: 164)
            .offset(x: 16, y: 32)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityLabel("Open Morning Folder")
    }

    private var crispTitleOverlay: some View {
        ZStack(alignment: .topLeading) {
            Text("Morning")
                .font(.mfEnglish(29, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 0.4, x: 0, y: 0.4)
                .frame(width: 126, height: 38, alignment: .leading)
                .offset(x: 41, y: 128)

            Text("Daily briefing")
                .font(.mfEnglish(8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 92, height: 13, alignment: .leading)
                .offset(x: 43, y: 164)
        }
        .frame(width: 246, height: 218, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var folderPapers: some View {
        ZStack(alignment: .topLeading) {
            FolderAssetImage(name: "paper-left", width: 246, height: 218)
                .offset(y: shouldPeekPapers ? -4 : 0)

            FolderAssetImage(name: "paper-right", width: 246, height: 218)
                .offset(y: shouldPeekPapers ? -3 : 0)

            FolderAssetImage(name: "paper-front", width: 246, height: 218)
                .offset(y: shouldPeekPapers ? -6 : 0)
        }
        .frame(width: 246, height: 218, alignment: .topLeading)
    }
}

private struct FolderAssetImage: View {
    let name: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        if let image = loadImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .accessibilityHidden(true)
                .frame(width: width, height: height)
        } else {
            Color.clear
                .overlay {
                    Text("Missing \(name)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .frame(width: width, height: height)
        }
    }

    private func loadImage() -> NSImage? {
        for suffix in ["@3x", "@2x", "@1x", ""] {
            if let url = MorningResources.bundle.url(forResource: "\(name)\(suffix)", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }
}

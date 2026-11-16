import AppKit
import CoreText
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Sources/MorningFolder/Resources")
let output = root.appendingPathComponent("Sources/MorningFolder/App/Assets/AppIcon.png")
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = context
let cg = context.cgContext
NSColor.black.setFill()
let iconShape = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
iconShape.fill()
cg.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil))
cg.clip()
// The pocket occupies x=18.5...227.5 and ends at y=191 in the 246×218 artwork.
// Align its left, right, and bottom edges to the icon while scaling all layers equally.
let scale: CGFloat = 824 / 209
let origin = CGPoint(x: 100 - 18.5 * scale, y: 100 - 27 * scale)
for name in ["paper-left", "paper-right", "paper-front", "folder-pocket-glass"] {
    let url = resources.appendingPathComponent("\(name)@3x.png")
    guard let image = NSImage(contentsOf: url) else { fatalError("Missing \(url.path)") }
    image.draw(in: NSRect(x: origin.x, y: origin.y, width: 246 * scale, height: 218 * scale), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)

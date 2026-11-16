import AppKit
import Foundation

let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/MorningFolder/Resources")
for scale in [1, 2, 3] {
    let source = resources.appendingPathComponent("folder-back@\(scale)x.png")
    let output = resources.appendingPathComponent("folder-back-filled@\(scale)x.png")
    guard let image = NSImage(contentsOf: source), let data = try? Data(contentsOf: source), let original = NSBitmapImageRep(data: data) else { fatalError("Missing \(source.path)") }
    let width = original.pixelsWide, height = original.pixelsHigh
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
    let s = CGFloat(scale)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 18.5*s, y: 27*s, width: 209*s, height: 87*s), xRadius: 22*s, yRadius: 22*s).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
}

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let sourceURL = root.appendingPathComponent("Support/cowboy-dog.jpg")
guard let source = NSImage(contentsOf: sourceURL), source.size.width > 0, source.size.height > 0 else {
    fputs("missing cowboy-dog.jpg\n", stderr)
    exit(1)
}

let background = NSColor(calibratedRed: 237 / 255, green: 237 / 255, blue: 237 / 255, alpha: 1)
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bloom.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func write(pixels: Int, name: String) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw NSError(domain: "icon", code: 1) }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    background.setFill()
    let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    bounds.fill()
    let scale = max(bounds.width / source.size.width, bounds.height / source.size.height)
    let width = source.size.width * scale
    let height = source.size.height * scale
    source.draw(in: NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "icon", code: 2) }
    try png.write(to: iconset.appendingPathComponent(name))
}

let files = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]
for item in files {
    try write(pixels: item.0, name: item.1)
}
print(iconset.path)

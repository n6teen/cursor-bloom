import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(red: 1.0, green: 0.78, blue: 0.70, alpha: 1),
    NSColor(red: 0.95, green: 0.55, blue: 0.58, alpha: 1),
    NSColor(red: 0.55, green: 0.45, blue: 0.98, alpha: 1)
])?.draw(in: bounds, angle: -50)

let center = NSPoint(x: 512, y: 500)
for index in 0..<6 {
    let petal = NSBezierPath(roundedRect: NSRect(x: -78, y: 70, width: 156, height: 250), xRadius: 78, yRadius: 78)
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: CGFloat(index) * 60)
    petal.transform(using: transform as AffineTransform)
    NSColor.white.withAlphaComponent(0.94).setFill()
    petal.fill()
}

let face = NSBezierPath(ovalIn: NSRect(x: center.x - 118, y: center.y - 118, width: 236, height: 236))
NSColor.white.setFill()
face.fill()

NSColor(red: 1, green: 0.55, blue: 0.55, alpha: 0.55).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - 78, y: center.y - 28, width: 36, height: 24)).fill()
NSBezierPath(ovalIn: NSRect(x: center.x + 42, y: center.y - 28, width: 36, height: 24)).fill()

NSColor(red: 0.18, green: 0.12, blue: 0.24, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - 46, y: center.y + 8, width: 26, height: 26)).fill()
NSBezierPath(ovalIn: NSRect(x: center.x + 20, y: center.y + 8, width: 26, height: 26)).fill()

let smile = NSBezierPath()
smile.appendArc(withCenter: NSPoint(x: center.x, y: center.y - 18), radius: 42, startAngle: 200, endAngle: 340, clockwise: false)
smile.lineWidth = 10
smile.lineCapStyle = .round
NSColor(red: 0.18, green: 0.12, blue: 0.24, alpha: 1).setStroke()
smile.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("icon render failed\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)

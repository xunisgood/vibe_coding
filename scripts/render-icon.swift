import AppKit

// Vector-drawn, offline app icon. Build products are generated, never fetched.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func drawIcon(_ pixels: Int, to url: URL) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let context = NSGraphicsContext.current!.cgContext
  context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
  let base = NSBezierPath(
    roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 206, yRadius: 206)
  NSGradient(
    starting: NSColor(red: 0.27, green: 0.28, blue: 0.67, alpha: 1),
    ending: NSColor(red: 0.63, green: 0.72, blue: 0.96, alpha: 1))!.draw(in: base, angle: 65)
  NSColor.white.withAlphaComponent(0.26).setStroke()
  base.lineWidth = 3
  base.stroke()
  for (angle, opacity, offset) in [(-14.0, 0.12, -35.0), (9.0, 0.23, 25.0)] {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: 512, byY: 512)
    var rotation = transform
    rotation.rotate(byDegrees: CGFloat(angle))
    rotation.translate(x: -512, y: -512)
    (rotation as NSAffineTransform).concat()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    let tile = NSBezierPath(
      roundedRect: NSRect(x: 235, y: 250 + offset, width: 554, height: 540), xRadius: 100,
      yRadius: 100)
    NSColor.white.withAlphaComponent(opacity).setFill()
    tile.fill()
    NSShadow().set()
    NSColor.white.withAlphaComponent(0.4).setStroke()
    tile.lineWidth = 3
    tile.stroke()
    NSGraphicsContext.restoreGraphicsState()
  }
  func sparkle(x: CGFloat, y: CGFloat, r: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: y + r))
    p.curve(
      to: NSPoint(x: x + r, y: y), controlPoint1: NSPoint(x: x + r * 0.14, y: y + r * 0.22),
      controlPoint2: NSPoint(x: x + r * 0.22, y: y + r * 0.14))
    p.curve(
      to: NSPoint(x: x, y: y - r), controlPoint1: NSPoint(x: x + r * 0.22, y: y - r * 0.14),
      controlPoint2: NSPoint(x: x + r * 0.14, y: y - r * 0.22))
    p.curve(
      to: NSPoint(x: x - r, y: y), controlPoint1: NSPoint(x: x - r * 0.14, y: y - r * 0.22),
      controlPoint2: NSPoint(x: x - r * 0.22, y: y - r * 0.14))
    p.curve(
      to: NSPoint(x: x, y: y + r), controlPoint1: NSPoint(x: x - r * 0.22, y: y + r * 0.14),
      controlPoint2: NSPoint(x: x - r * 0.14, y: y + r * 0.22))
    p.close()
    NSColor.white.withAlphaComponent(0.94).setFill()
    p.fill()
  }
  sparkle(x: 512, y: 535, r: 158)
  sparkle(x: 713, y: 735, r: 38)
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
for size in [16, 32, 128, 256, 512] {
  try drawIcon(size, to: output.appendingPathComponent("icon_\(size)x\(size).png"))
  try drawIcon(size * 2, to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

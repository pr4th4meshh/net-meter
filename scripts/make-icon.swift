// Draws the NetMeter app icon and writes:
//   Resources/AppIcon.icns  (used by the app)
//   docs/icon.png           (512 px, for README / app listings)
//
// Run from the repo root:  ./scripts/make-icon.sh
import AppKit

let canvas: CGFloat = 1024
/// Output pixels per canvas point. Core Graphics shadows ignore the transform, so scale them by hand.
var shadowScale: CGFloat = 1

func drawIcon(in ctx: CGContext) {
    // macOS icon grid: the rounded square is 824 pt inside a 1024 pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft drop shadow under the tile
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * shadowScale), blur: 28 * shadowScale,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient: deep blue at the bottom to bright cyan-blue at the top
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let colors = [NSColor(srgbRed: 0.05, green: 0.27, blue: 0.80, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.10, green: 0.62, blue: 0.98, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: tile.minY),
                           end: CGPoint(x: 512, y: tile.maxY), options: [])

    // Subtle top highlight for depth
    let shine = [NSColor.white.withAlphaComponent(0.18).cgColor,
                 NSColor.white.withAlphaComponent(0).cgColor] as CFArray
    let shineGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: shine, locations: [0, 1])!
    ctx.drawLinearGradient(shineGradient, start: CGPoint(x: 512, y: tile.maxY),
                           end: CGPoint(x: 512, y: tile.midY), options: [])
    ctx.restoreGState()

    // Two arrows: download (left, pointing down) and upload (right, pointing up)
    drawArrow(in: ctx, centerX: 405, pointingUp: false, color: .white)
    drawArrow(in: ctx, centerX: 619, pointingUp: true,
              color: NSColor(srgbRed: 0.78, green: 0.90, blue: 1.0, alpha: 1))
}

/// A bold arrow with rounded corners, centred vertically in the tile.
func drawArrow(in ctx: CGContext, centerX x: CGFloat, pointingUp up: Bool, color: NSColor) {
    let length: CGFloat = 470, shaftWidth: CGFloat = 82, headWidth: CGFloat = 230, headLength: CGFloat = 190
    let tipY = up ? 512 + length / 2 : 512 - length / 2
    let tailY = up ? 512 - length / 2 : 512 + length / 2
    let dir: CGFloat = up ? 1 : -1
    let headBaseY = tipY - dir * headLength

    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: tipY))
    path.addLine(to: CGPoint(x: x + headWidth / 2, y: headBaseY))
    path.addLine(to: CGPoint(x: x + shaftWidth / 2, y: headBaseY))
    path.addLine(to: CGPoint(x: x + shaftWidth / 2, y: tailY))
    path.addLine(to: CGPoint(x: x - shaftWidth / 2, y: tailY))
    path.addLine(to: CGPoint(x: x - shaftWidth / 2, y: headBaseY))
    path.addLine(to: CGPoint(x: x - headWidth / 2, y: headBaseY))
    path.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * shadowScale), blur: 14 * shadowScale,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.setFillColor(color.cgColor)
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(28)          // stroking with round joins softens the corners
    ctx.setLineJoin(.round)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil) // shadow the arrow as a whole
    ctx.addPath(path)
    ctx.drawPath(using: .fillStroke)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    shadowScale = CGFloat(size) / canvas
    ctx.scaleBy(x: shadowScale, y: shadowScale)
    drawIcon(in: ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try render(size: 512).write(to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Resources/AppIcon.icns and docs/icon.png")

import AppKit
import Foundation

func pngData(size: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create icon bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(size) * 0.055
    let tile = canvas.insetBy(dx: inset, dy: inset)
    let tilePath = NSBezierPath(
        roundedRect: tile,
        xRadius: CGFloat(size) * 0.22,
        yRadius: CGFloat(size) * 0.22
    )
    tilePath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(deviceRed: 0.30, green: 0.18, blue: 0.86, alpha: 1),
        NSColor(deviceRed: 0.66, green: 0.34, blue: 0.98, alpha: 1),
        NSColor(deviceRed: 0.25, green: 0.48, blue: 0.95, alpha: 1)
    ])!
    gradient.draw(in: tile, angle: -42)

    let glowRect = NSRect(
        x: CGFloat(size) * 0.50,
        y: CGFloat(size) * 0.48,
        width: CGFloat(size) * 0.42,
        height: CGFloat(size) * 0.42
    )
    NSColor.white.withAlphaComponent(0.13).setFill()
    NSBezierPath(ovalIn: glowRect).fill()

    let center = NSPoint(x: CGFloat(size) * 0.49, y: CGFloat(size) * 0.50)
    let radius = CGFloat(size) * 0.255
    let ring = NSBezierPath()
    ring.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: 36,
        endAngle: 326,
        clockwise: false
    )
    ring.lineWidth = CGFloat(size) * 0.075
    ring.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.96).setStroke()
    ring.stroke()

    let dotSize = CGFloat(size) * 0.09
    let dotRect = NSRect(
        x: center.x + radius * 0.74 - dotSize / 2,
        y: center.y + radius * 0.67 - dotSize / 2,
        width: dotSize,
        height: dotSize
    )
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    let sparkCenter = NSPoint(x: CGFloat(size) * 0.70, y: CGFloat(size) * 0.72)
    let spark = NSBezierPath()
    spark.move(to: NSPoint(x: sparkCenter.x, y: sparkCenter.y + CGFloat(size) * 0.10))
    spark.line(to: NSPoint(x: sparkCenter.x + CGFloat(size) * 0.032, y: sparkCenter.y + CGFloat(size) * 0.032))
    spark.line(to: NSPoint(x: sparkCenter.x + CGFloat(size) * 0.10, y: sparkCenter.y))
    spark.line(to: NSPoint(x: sparkCenter.x + CGFloat(size) * 0.032, y: sparkCenter.y - CGFloat(size) * 0.032))
    spark.line(to: NSPoint(x: sparkCenter.x, y: sparkCenter.y - CGFloat(size) * 0.10))
    spark.line(to: NSPoint(x: sparkCenter.x - CGFloat(size) * 0.032, y: sparkCenter.y - CGFloat(size) * 0.032))
    spark.line(to: NSPoint(x: sparkCenter.x - CGFloat(size) * 0.10, y: sparkCenter.y))
    spark.line(to: NSPoint(x: sparkCenter.x - CGFloat(size) * 0.032, y: sparkCenter.y + CGFloat(size) * 0.032))
    spark.close()
    spark.fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

func bigEndian(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return Data(bytes: &number, count: MemoryLayout<UInt32>.size)
}

let outputDirectory = CommandLine.arguments.dropFirst().first
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let chunks: [(String, Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024)
]

var payload = Data()
for (type, size) in chunks {
    let png = pngData(size: size)
    payload.append(type.data(using: .ascii)!)
    payload.append(bigEndian(png.count + 8))
    payload.append(png)

    if size == 1024 {
        try png.write(to: outputDirectory.appendingPathComponent("AppIcon-1024.png"), options: .atomic)
    }
}

var icns = Data("icns".utf8)
icns.append(bigEndian(payload.count + 8))
icns.append(payload)
try icns.write(to: outputDirectory.appendingPathComponent("AppIcon.icns"), options: .atomic)

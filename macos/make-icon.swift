#!/usr/bin/swift
// 生成 1024×1024 的应用图标主图（PNG）。
// 设计：Big Sur 模板（1024 画布、824 圆角方块居中）+ 品牌蓝渐变 + 白色「译」。
// 用法：swift make-icon.swift <输出路径.png>
import AppKit

let canvas: CGFloat = 1024
let inset: CGFloat = 100
let cornerRadius: CGFloat = 186

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let shape = NSBezierPath(
    roundedRect: NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2),
    xRadius: cornerRadius, yRadius: cornerRadius
)
// 品牌色 #0969da 一族：上亮下深
NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.56, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.32, blue: 0.71, alpha: 1),
])!.draw(in: shape, angle: -90)

let font = NSFont(name: "PingFangSC-Semibold", size: 560)
    ?? NSFont.systemFont(ofSize: 560, weight: .semibold)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -12)
let glyph = NSAttributedString(string: "译", attributes: [
    .font: font,
    .foregroundColor: NSColor.white,
    .shadow: shadow,
])
let size = glyph.size()
glyph.draw(at: NSPoint(x: (canvas - size.width) / 2, y: (canvas - size.height) / 2))

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("已生成 \(output)")

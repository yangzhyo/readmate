#!/usr/bin/swift
// 生成应用图标（PNG）：像素风鹦鹉。像素画用下面的字符网格定义，改网格即可换动物/表情。
// 划词图标与菜单栏图标用的是同一只鹦鹉：改网格或配色时，同步 Sources/Readmate/ParrotSprite.swift
// 与 extension/utils/parrot.ts。
// 用法：
//   swift make-icon.swift <输出.png>          → 1024 的 macOS 图标（白底圆角方块）
//   swift make-icon.swift <输出.png> <边长>   → 透明底、仅精灵（Chrome 插件图标用）
import AppKit

let spriteOnlySize: CGFloat? = CommandLine.arguments.count > 2
    ? Double(CommandLine.arguments[2]).map { CGFloat($0) }
    : nil
let canvas: CGFloat = spriteOnlySize ?? 1024
let inset: CGFloat = 100
let cornerRadius: CGFloat = 186

// D=深色描边 G=绿羽 R=红呆毛 O=橙喙 W=白眼圈 K=瞳孔 L=浅色腹部 P=腮红 .=透明
let sprite = [
    ".........DDD........",
    "........DRRRD.......",
    "...DDDDDDRRRDDDDD...",
    "..DGGGGGGGRGGGGGGD..",
    ".DGGGGGGGGGGGGGGGGD.",
    ".DGGWWWWGGGGWWWWGGD.",
    ".DGGWKKWGGGGWKKWGGD.",
    ".DGGWKKWGGGGWKKWGGD.",
    ".DGGWWWWGGGGWWWWGGD.",
    ".DGGGGGGOOOOGGGGGGD.",
    ".DGGGGGGGOOGGGGGGGD.",
    ".DGGPGGGGGGGGGGPGGD.",
    ".DGGGLLLLLLLLLLGGGD.",
    "..DGGLLLLLLLLLLGGD..",
    "...DGGLLLLLLLLGGD...",
    "....DDGGLLLLGGDD....",
    "......DDDDDDDD......",
]

let palette: [Character: NSColor] = [
    "D": NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.17, alpha: 1),
    "G": NSColor(calibratedRed: 0.24, green: 0.73, blue: 0.35, alpha: 1),
    "R": NSColor(calibratedRed: 0.91, green: 0.31, blue: 0.25, alpha: 1),
    "O": NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.11, alpha: 1),
    "W": .white,
    "K": NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1),
    "L": NSColor(calibratedRed: 0.78, green: 0.93, blue: 0.62, alpha: 1),
    "P": NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.72, alpha: 1),
]

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

if spriteOnlySize == nil {
    let shape = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2),
        xRadius: cornerRadius, yRadius: cornerRadius
    )
    // 白底（微渐变到浅灰，避免死白）
    NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.95, alpha: 1),
    ])!.draw(in: shape, angle: -90)
}

// 逐格画像素
let cell: CGFloat = spriteOnlySize.map { $0 / CGFloat(sprite[0].count) } ?? 40
let cols = sprite[0].count
let rows = sprite.count
let originX = (canvas - CGFloat(cols) * cell) / 2
let originY = (canvas - CGFloat(rows) * cell) / 2
for (rowIndex, row) in sprite.enumerated() {
    for (colIndex, ch) in row.enumerated() {
        guard let color = palette[ch] else { continue }
        color.setFill()
        // 位图 y 轴向上，网格第 0 行在最上
        NSRect(
            x: originX + CGFloat(colIndex) * cell,
            y: originY + CGFloat(rows - 1 - rowIndex) * cell,
            width: cell, height: cell
        ).fill()
    }
}

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("已生成 \(output)")

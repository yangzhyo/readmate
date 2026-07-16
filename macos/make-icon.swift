#!/usr/bin/swift
// 生成 1024×1024 的应用图标主图（PNG）：品牌蓝渐变圆角方块 + 像素风熊猫。
// 像素画用下面的字符网格定义，改网格即可换动物/表情。
// 用法：swift make-icon.swift <输出路径.png>
import AppKit

let canvas: CGFloat = 1024
let inset: CGFloat = 100
let cornerRadius: CGFloat = 186

// K=黑 W=白 P=腮红 .=透明
let sprite = [
    "..KK........KK..",
    ".KKKK......KKKK.",
    ".KKKKKKKKKKKKKK.",
    ".KWWWWWWWWWWWWK.",
    ".KWWWWWWWWWWWWK.",
    ".KWKKKWWWWKKKWK.",
    ".KWKWKWWWWKWKWK.",
    ".KWKKKWWWWKKKWK.",
    ".KWWWWWKKWWWWWK.",
    ".KWPWWWWWWWWPWK.",
    ".KWWWWWWWWWWWWK.",
    "..KKWWWWWWWWKK..",
    "....KKKKKKKK....",
]

let palette: [Character: NSColor] = [
    "K": NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1),
    "W": .white,
    "P": NSColor(calibratedRed: 1.00, green: 0.65, blue: 0.71, alpha: 1),
]

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

// 逐格画像素（整数对齐、无抗锯齿感）
let cell: CGFloat = 44
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

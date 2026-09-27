import AppKit

/// 应用图标里的像素鹦鹉：划词图标用彩色版，菜单栏用单色模板版。
/// 网格与配色须与 macos/make-icon.swift、extension/utils/parrot.ts 保持一致。
enum ParrotSprite {
    // D=深色描边 G=绿羽 R=红呆毛 O=橙喙 W=白眼圈 K=瞳孔 L=浅色腹部 P=腮红 .=透明
    private static let grid = [
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

    private static let palette: [Character: NSColor] = [
        "D": NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.17, alpha: 1),
        "G": NSColor(calibratedRed: 0.24, green: 0.73, blue: 0.35, alpha: 1),
        "R": NSColor(calibratedRed: 0.91, green: 0.31, blue: 0.25, alpha: 1),
        "O": NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.11, alpha: 1),
        "W": .white,
        "K": NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1),
        "L": NSColor(calibratedRed: 0.78, green: 0.93, blue: 0.62, alpha: 1),
        "P": NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.72, alpha: 1),
    ]

    /// 模板图只用透明度表达，颜色交给菜单栏：眼白挖空露出眼睛，腹部半透明，其余实心
    private static let templateAlpha: [Character: CGFloat] = ["W": 0, "L": 0.35]

    static let color = render(template: false)
    static let template = render(template: true)

    /// 每格 1pt。NSImage 按屏幕倍率栅格化，Retina 下每格正好 2 像素，边缘清晰；
    /// 用的地方须按原尺寸显示，缩放到非整数倍会发虚。
    private static func render(template: Bool) -> NSImage {
        let size = NSSize(width: grid[0].count, height: grid.count)
        let image = NSImage(size: size, flipped: true) { _ in
            for (y, row) in grid.enumerated() {
                for (x, cell) in row.enumerated() {
                    guard let color = palette[cell] else { continue }
                    let fill = template ? NSColor.black.withAlphaComponent(templateAlpha[cell] ?? 1) : color
                    fill.setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
            return true
        }
        image.isTemplate = template
        return image
    }
}

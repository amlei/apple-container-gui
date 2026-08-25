import AppKit
import CoreGraphics

extension NSImage {
    /// Renders `self` as a macOS application icon: the source image masked into
    /// the standard rounded "squircle" (824x824, corner radius 185) centred on a
    /// 1024x1024 transparent canvas, matching the Big Sur+ icon grid. macOS no
    /// longer auto-rounds app icons, so this keeps the Dock / Cmd-Tab switcher
    /// from showing hard right-angle corners.
    func macApplicationIcon(size: CGFloat = 1024) -> NSImage {
        let canvas = Int(size)
        let side = CGFloat(824.0 * size / 1024.0)
        let margin = (size - side) / 2.0
        let radius = CGFloat(185.0 * size / 1024.0)

        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return self }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: canvas,
            height: canvas,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        let rect = CGRect(x: margin, y: margin, width: side, height: side)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(cg, in: rect)
        ctx.restoreGState()

        guard let outCG = ctx.makeImage() else { return self }
        return NSImage(cgImage: outCG, size: NSSize(width: size, height: size))
    }
}

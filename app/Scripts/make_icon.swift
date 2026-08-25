#!/usr/bin/env swift
// Renders the project logo into the standard macOS app-icon "squircle":
// an 824x824 rounded square (corner radius 185) centred on a 1024x1024
// transparent canvas (the Big Sur+ icon grid). Run from build.sh to produce
// the source PNG that gets resized into the .icns.

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <input.png> <output.png>\n".utf8))
    exit(1)
}

let input = args[1]
let output = args[2]

guard let image = NSImage(contentsOfFile: input),
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage else {
    FileHandle.standardError.write(Data("make_icon: cannot load \(input)\n".utf8))
    exit(1)
}

let canvas = 1024
let side = 824
let margin = CGFloat(canvas - side) / 2.0
let radius = CGFloat(185)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: canvas,
    height: canvas,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("make_icon: cannot create context\n".utf8))
    exit(1)
}

let rect = CGRect(x: margin, y: margin, width: CGFloat(side), height: CGFloat(side))
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(path)
ctx.clip()
ctx.draw(cg, in: rect)
ctx.restoreGState()

guard let outCG = ctx.makeImage() else {
    FileHandle.standardError.write(Data("make_icon: cannot make image\n".utf8))
    exit(1)
}

let outRep = NSBitmapImageRep(cgImage: outCG)
guard let data = outRep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("make_icon: cannot encode PNG\n".utf8))
    exit(1)
}

do {
    try data.write(to: URL(fileURLWithPath: output))
} catch {
    FileHandle.standardError.write(Data("make_icon: cannot write \(output): \(error)\n".utf8))
    exit(1)
}

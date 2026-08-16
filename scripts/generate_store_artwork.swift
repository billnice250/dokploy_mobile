#!/usr/bin/env swift

import AppKit
import Foundation

struct StoreArtwork {
  let projectRoot: URL

  private var markURL: URL {
    projectRoot.appendingPathComponent("assets/branding/dokploy-mark.png")
  }

  private var outputRoot: URL {
    projectRoot.appendingPathComponent("store_assets")
  }

  func generate() throws {
    guard let mark = NSImage(contentsOf: markURL) else {
      throw NSError(
        domain: "DployGoStoreArtwork",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not load \(markURL.path)"]
      )
    }

    try renderIcon(
      mark: mark,
      size: 1024,
      destination: outputRoot
        .appendingPathComponent("app-store/icon/app-icon-1024.png")
    )
    try renderIcon(
      mark: mark,
      size: 512,
      destination: outputRoot
        .appendingPathComponent("play-store/icon/icon-512.png")
    )
    try renderFeatureGraphic(
      mark: mark,
      destination: outputRoot.appendingPathComponent(
        "play-store/feature-graphic/feature-graphic-1024x500.png"
      )
    )
    try flattenStoreScreenshots(mark: mark)
  }

  private func flattenStoreScreenshots(mark: NSImage) throws {
    guard let files = FileManager.default.enumerator(
      at: outputRoot,
      includingPropertiesForKeys: nil
    ) else { return }

    for case let file as URL in files {
      guard
        file.pathExtension.lowercased() == "png",
        file.pathComponents.contains("screenshots"),
        let sourceData = try? Data(contentsOf: file),
        let representation = NSBitmapImageRep(data: sourceData),
        let image = NSImage(contentsOf: file)
      else { continue }

      try render(
        width: representation.pixelsWide,
        height: representation.pixelsHigh,
        destination: file
      ) { rect in
        NSColor.black.setFill()
        rect.fill()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        if let brandRect = screenshotBrandRect(
          file: file,
          width: representation.pixelsWide,
          height: representation.pixelsHigh
        ) {
          mark.draw(
            in: brandRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
          )
        }
      }
    }
  }

  private func screenshotBrandRect(
    file: URL,
    width: Int,
    height: Int
  ) -> NSRect? {
    let components = file.pathComponents
    let placement: (x: CGFloat, top: CGFloat, size: CGFloat)

    if components.contains("iphone-6.9") {
      placement = (48, 225, 90)
    } else if components.contains("phone") {
      placement = (42, 97, 80)
    } else if width == 2064 && height == 2752 {
      placement = (33, 89, 60)
    } else {
      return nil
    }

    return NSRect(
      x: placement.x,
      y: CGFloat(height) - placement.top - placement.size,
      width: placement.size,
      height: placement.size
    )
  }

  private func renderIcon(mark: NSImage, size: Int, destination: URL) throws {
    try render(width: size, height: size, destination: destination) { rect in
      mark.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
  }

  private func renderFeatureGraphic(mark: NSImage, destination: URL) throws {
    try render(width: 1024, height: 500, destination: destination) { rect in
      NSGradient(colors: [
        NSColor(calibratedRed: 0.025, green: 0.027, blue: 0.035, alpha: 1),
        NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.115, alpha: 1),
        NSColor(calibratedRed: 0.018, green: 0.020, blue: 0.026, alpha: 1),
      ])?.draw(in: rect, angle: 0)

      let glow = NSShadow()
      glow.shadowColor = NSColor(calibratedRed: 0.20, green: 0.52, blue: 1, alpha: 0.38)
      glow.shadowBlurRadius = 75
      glow.shadowOffset = .zero
      glow.set()
      NSColor(calibratedRed: 0.16, green: 0.45, blue: 1, alpha: 0.20).setFill()
      NSBezierPath(ovalIn: NSRect(x: 80, y: 65, width: 330, height: 330)).fill()

      NSGraphicsContext.current?.saveGraphicsState()
      NSShadow().set()
      mark.draw(
        in: NSRect(x: 88, y: 72, width: 356, height: 356),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
      )
      NSGraphicsContext.current?.restoreGraphicsState()

      let titleStyle = NSMutableParagraphStyle()
      titleStyle.alignment = .left
      let title = NSAttributedString(
        string: "DployGo",
        attributes: [
          .font: NSFont.systemFont(ofSize: 76, weight: .bold),
          .foregroundColor: NSColor.white,
          .paragraphStyle: titleStyle,
          .kern: -2.0,
        ]
      )
      title.draw(in: NSRect(x: 490, y: 251, width: 450, height: 100))

      let subtitle = NSAttributedString(
        string: "Your Dokploy command center, anywhere.",
        attributes: [
          .font: NSFont.systemFont(ofSize: 26, weight: .medium),
          .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: 1),
          .paragraphStyle: titleStyle,
        ]
      )
      subtitle.draw(in: NSRect(x: 495, y: 188, width: 470, height: 72))

      NSColor(calibratedRed: 0.28, green: 0.62, blue: 1, alpha: 1).setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 495, y: 153, width: 92, height: 7),
        xRadius: 3.5,
        yRadius: 3.5
      ).fill()
    }
  }

  private func render(
    width: Int,
    height: Int,
    destination: URL,
    drawing: (NSRect) -> Void
  ) throws {
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    guard
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let bitmap = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    else {
      throw NSError(domain: "DployGoStoreArtwork", code: 2)
    }

    let context = NSGraphicsContext(cgContext: bitmap, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = NSImageInterpolation.high
    drawing(NSRect(x: 0, y: 0, width: width, height: height))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard
      let image = bitmap.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(
      using: NSBitmapImageRep.FileType.png,
      properties: [:]
      )
    else {
      throw NSError(domain: "DployGoStoreArtwork", code: 4)
    }
    try data.write(to: destination, options: Data.WritingOptions.atomic)
  }
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
do {
  try StoreArtwork(projectRoot: projectRoot).generate()
  print("Generated DployGo store artwork in \(projectRoot.appendingPathComponent("store_assets").path)")
} catch {
  fputs("Store artwork generation failed: \(error)\n", stderr)
  exit(1)
}

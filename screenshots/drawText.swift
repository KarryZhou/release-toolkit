#!/usr/bin/swift

import Foundation
import Cocoa
import CoreText


/// First, some helpers
///
func commandLineArguments() -> [String : String] {

    return CommandLine.arguments
        .filter{ $0.contains("=") }
        .reduce([String : String](), { (dictionary, argument) -> [String : String] in

            var dictionary = dictionary //shadow for mutability

            var parts = argument.split(separator: "=")
            dictionary[String(parts.remove(at: 0))] = parts.joined(separator: "=")

            return dictionary
        })
}

func printUsageAndExit() -> Never {
    print("""
    Usage: ./draw-text html={file path or quotes-enclosed HTML string} maxWidth={ integer } maxHeight={ integer }
    """)
    exit(1)
}

func printError(_ string: String) {
    let redColor = "\u{001B}[0;31m"
    let endColor = "\u{001B}[0;m"
    fputs("\(redColor)Error: \(string)\(endColor)\n", stderr)
}

let args = commandLineArguments()

let drawingOptions: NSString.DrawingOptions = [
    .usesLineFragmentOrigin,
    .usesFontLeading,
]

guard let maxWidthString = args["maxWidth"] else {
    printError("Missing maxWidth argument")
    printUsageAndExit()
}

guard let maxHeightString = args["maxHeight"] else {
    printError("Missing maxHeight argument")
    printUsageAndExit()
}

guard let maxWidth = Int(maxWidthString) else {
    printError("maxWidth must be an integer")
    printUsageAndExit()
}

guard let maxHeight = Int(maxHeightString) else {
    printError("maxHeight must be an integer")
    printUsageAndExit()
}

let styleString = """
<style>
p{
padding: 0;
margin: 0;
}
</style>
"""

// Read the HTML string out of the args. This can either be raw HTML, or a path to an HTML file
guard let htmlString = args["html"] else {
    printError("Unable to read HTML string")
    printUsageAndExit()
}

let possibleFilePath = NSString(string: htmlString).expandingTildeInPath

// Convert the HTML to data
var htmlData = styleString.data(using: .utf8) ?? Data()
if FileManager.default.fileExists(atPath: possibleFilePath) {

    if let fileContents = FileManager.default.contents(atPath: possibleFilePath) {
        htmlData.append(fileContents)
    }
}
else{
    if let data = htmlString.data(using: .utf8) {
        htmlData.append(data)
    }
}

// Ensure that the HTML data was valid
guard let attributedString = NSMutableAttributedString(html: htmlData, options: [:], documentAttributes: nil) else{
    printError("Unable to read HTML string")
    exit(1)
}

let outputRect = attributedString.boundingRect(with: CGSize(width: maxWidth, height: maxHeight), options: drawingOptions)

/// Ensure that the text can be drawn inside the provided dimensions
let fittingSize = CGSize(width: outputRect.width, height: CGFloat.greatestFiniteMagnitude)
let fittingRect = attributedString.boundingRect(with: fittingSize, options: drawingOptions)

guard fittingRect.height <= outputRect.height else {
    printError("Provided string doesn't fit in the provided dimensions")
    exit(1)
}

// Create a bitmap canvas to draw this image onto
guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(outputRect.width),
    pixelsHigh: Int(outputRect.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bitmapFormat: .alphaFirst,
    bytesPerRow: 0,
    bitsPerPixel: 0
    ) else {
        printError("Invalid HTML String")
        exit(3)
}

/// Set up the graphics context
guard let context = NSGraphicsContext(bitmapImageRep: canvas) else {
    printError("Unable to initialize graphics context")
    exit(4)
}
/// Make it the current context (needed for command-line string drawing)
NSGraphicsContext.current = context

/// Draw the string
let ctx = NSStringDrawingContext()
ctx.minimumScaleFactor = 1.0
attributedString.draw(with: outputRect, options: drawingOptions, context: ctx)

/// Draw the image into a `CIImage`
guard let image = context.cgContext.makeImage()?.cropping(to: ctx.totalBounds) else {
    printError("Unable to draw image")
    exit(5)
}

/// Turn it into a `png`
let rep = NSBitmapImageRep(cgImage: image)
let pngData = rep.representation(using: .png, properties: [:])

/// Write it out to file
let outputPath = args["output"] ?? "output.png"

do {
    let pathString = NSString(string: outputPath).expandingTildeInPath
    let output = NSURL(fileURLWithPath: pathString)

    try pngData?.write(to: output as URL)
}
catch let err {
    printError("Unable to write image to \(outputPath): \(err.localizedDescription)")
    exit(6)
}
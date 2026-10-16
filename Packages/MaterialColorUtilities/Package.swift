// swift-tools-version: 5.8
// A vendored subset of Google's Material Color Utilities (Apache-2.0):
// the image quantizer, colour scoring, HCT colour space and tonal palettes.
// See README.md for the upstream commit.

import PackageDescription

let package = Package(
    name: "MaterialColorUtilities",
    products: [
        .library(name: "MaterialColorUtilities", targets: ["MaterialColorUtilities"])
    ],
    targets: [
        .target(name: "MaterialColorUtilities")
    ]
)

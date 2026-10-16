# Material Color Utilities (vendored subset)

A copy of part of Google's [Material Color Utilities](https://github.com/material-foundation/material-color-utilities) Swift port, used to pick text colours from album artwork (see `Sources/Spooterfy/AlbumTextColors.swift`).

It's vendored because the upstream Swift package lives in a `swift/` subfolder of a multi-language repository, which Swift Package Manager can't depend on directly.

- **Upstream:** `swift/Sources/MaterialColorUtilities` at commit [`dd62982`](https://github.com/material-foundation/material-color-utilities/tree/dd62982dfdefdfc9232ce8d76e122fb1c6d188ae/swift)
- **Included:** Quantize, Score, Dislike, Hct, Palettes/TonalPalette, Contrast, and Utils/ColorUtils and MathUtils. Files are unmodified.
- **License:** Apache License 2.0, copyright Google LLC. See [LICENSE](LICENSE). The project's MIT license does not cover these files.

To update, copy the same files from a newer upstream commit and update the commit above.

import AppKit
import ObjectiveC

/// Makes a window always draw with its active (focused) appearance.
///
/// `NSGlassEffectView` changes its look with the window's active appearance:
/// a different backdrop blur and a brightening layer (see `SteadyGlassView`).
/// AppKit decides that through the private `_hasActiveAppearance` family of
/// methods, so answering YES keeps the glass identical in the background.
/// Same approach as https://github.com/Javis603/token-monitor/pull/820.
/// If a future macOS drops these selectors, nothing is overridden and the
/// window behaves as stock.
@MainActor
enum AlwaysActiveAppearance {
    private static let selectors = [
        "_hasActiveAppearance",
        "_hasActiveAppearanceIgnoringKeyFocus",
        "_hasKeyAppearance",
    ].map(NSSelectorFromString)

    private static var patched = Set<ObjectIdentifier>()

    static func apply(to window: NSWindow) {
        guard let cls = object_getClass(window), !patched.contains(ObjectIdentifier(cls)) else { return }
        patched.insert(ObjectIdentifier(cls))
        let yes: @convention(block) (AnyObject) -> Bool = { _ in true }
        let imp = imp_implementationWithBlock(yes)
        for sel in selectors where class_getInstanceMethod(cls, sel) != nil {
            // Adds to this window class (or replaces its own copy); NSWindow itself is untouched.
            class_replaceMethod(cls, sel, imp, "B@:")
        }
    }
}

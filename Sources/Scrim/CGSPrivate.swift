import CoreGraphics
import IOKit

// Private WindowServer symbol, re-exported through the public CoreGraphics
// framework. Not declared in any public header, so it's bound directly by
// symbol name rather than imported. No public replacement exists for
// disabling a display outright (CGDisplaySetDisplayMode only changes mode).
@_silgen_name("CGSConfigureDisplayEnabled")
func cgsConfigureDisplayEnabled(
    _ config: CGDisplayConfigRef?,
    _ display: CGDirectDisplayID,
    _ enabled: Bool
) -> CGError

// Deprecated since macOS 10.9 with no public replacement. Returns
// MACH_PORT_NULL for virtual/placeholder displays, which is the only way
// left to distinguish them from real hardware panels.
@_silgen_name("CGDisplayIOServicePort")
func cgDisplayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t

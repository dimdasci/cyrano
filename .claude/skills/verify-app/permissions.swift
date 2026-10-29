// Asks macOS for Accessibility and Screen Recording for the process that runs this script and
// prints whether each is granted. Run: swift .claude/skills/verify-app/permissions.swift

import ApplicationServices
import CoreGraphics

let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
print("accessibility:", AXIsProcessTrustedWithOptions(options))
print("screen recording:", CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess())

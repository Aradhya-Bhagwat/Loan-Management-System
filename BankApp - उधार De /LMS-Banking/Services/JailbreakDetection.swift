//
//  JailbreakDetection.swift
//  LMS-Banking
//
//  Detects if the device is jailbroken using multiple checks.
//  If jailbreak is detected, the app exits immediately.
//

import UIKit
import Foundation

enum JailbreakDetector {

    // MARK: - Main Check

    /// Returns true if the device appears to be jailbroken.
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return checkSuspiciousFiles()
            || checkSuspiciousSchemes()
            || checkSandboxViolation()
            || checkDynamicLibraries()
        #endif
    }

    /// Call this at app launch. Exits the app immediately if jailbreak is detected.
    static func exitIfJailbroken() {
        if isJailbroken {
            // Wipe the window so nothing is visible before exit
            DispatchQueue.main.async {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .forEach { $0.isHidden = true }
            }
            // Hard exit
            exit(0)
        }
    }

    // MARK: - Check 1: Suspicious Files

    private static func checkSuspiciousFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/var/lib/cydia",
            "/var/lib/apt",
            "/var/cache/apt",
            "/etc/apt",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/usr/libexec/sftp-server",
            "/private/var/lib/apt",
            "/private/var/stash",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
            if (try? String(contentsOfFile: path, encoding: .utf8)) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Check 2: Suspicious URL Schemes

    private static func checkSuspiciousSchemes() -> Bool {
        let schemes = [
            "cydia://package/com.example.package",
            "sileo://package/com.example.package",
        ]
        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }

    // MARK: - Check 3: Sandbox Violation

    private static func checkSandboxViolation() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "jailbreak_test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Check 4: Suspicious Dynamic Libraries

    private static func checkDynamicLibraries() -> Bool {
        let suspiciousLibs = [
            "MobileSubstrate",
            "substrate",
            "cycript",
            "cynject",
            "libhooker",
            "SubstrateLoader",
            "SSLKillSwitch",
        ]
        let dyldInsertLibraries = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] ?? ""
        for lib in suspiciousLibs {
            if dyldInsertLibraries.lowercased().contains(lib.lowercased()) {
                return true
            }
        }
        let suspiciousPaths = [
            "/Library/MobileSubstrate",
            "/usr/lib/libcycript.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/lib/TweakInject.dylib",
        ]
        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
}

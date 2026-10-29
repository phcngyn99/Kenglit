import Foundation
import KenglishCore

enum Check {
    private static var failures = 0

    static func expect(_ cond: @autoclosure () -> Bool, _ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        if !cond() {
            failures += 1
            fputs("FAIL \(file):\(line): \(msg)\n", stderr)
        }
    }

    static func equal<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        expect(a == b, "\(msg) — got \(a), want \(b)", file: file, line: line)
    }

    static func finish() {
        if failures == 0 {
            print("All checks passed")
            exit(0)
        } else {
            fputs("\(failures) check(s) failed\n", stderr)
            exit(1)
        }
    }
}

// WatchedApps
do {
    let set = Set(WatchedApps.defaults)
    Check.expect(set.contains("com.apple.Terminal"), "defaults contain Terminal")
    Check.expect(set.contains("com.microsoft.VSCode"), "defaults contain VSCode")
    Check.expect(set.contains("dev.warp.Warp-Stable"), "defaults contain Warp")
    Check.equal(
        WatchedApps.normalized(["  com.b ", "com.a", "com.a", "", "  "]),
        ["com.a", "com.b"],
        "normalized trims/dedupes/sorts"
    )
}

Check.finish()

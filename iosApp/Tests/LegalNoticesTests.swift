import XCTest
@testable import WeFlix

/// Settings > About legal notices: the build's source link and the bundled
/// license texts behind Open Source Licenses.
final class LegalNoticesTests: XCTestCase {
    func testStampedReleaseArchiveIsTheSourceLink() {
        // Single-platform tags such as v1.4.0+ios arrive percent-encoded.
        for tag in ["v1.0.0", "v1.4.0%2Bios"] {
            let archive = "https://github.com/Silo-Server/silo-apple/releases/download/\(tag)/"
                + "weflix-source-\(String(repeating: "a", count: 40)).tar.gz"

            XCTAssertEqual(WeFlixLegalLinks.sourceURL(stamped: archive).absoluteString, archive)
        }
    }

    func testMissingOrForeignStampLinksTheRepository() {
        let stamps: [String?] = [
            nil,
            "",
            "$(WEFLIX_SOURCE_URL)",
            "http://github.com/Silo-Server/silo-apple/releases/download/v1/a.tar.gz",
            "https://example.com/Silo-Server/silo-apple/releases/download/v1/a.tar.gz",
            "https://github.com/someone/silo-apple/releases/download/v1/a.tar.gz",
            "https://github.com/Silo-Server/silo-apple-fork/releases/download/v1/a.tar.gz",
        ]

        for stamp in stamps {
            XCTAssertEqual(WeFlixLegalLinks.sourceURL(stamped: stamp), WeFlixLegalLinks.repository, stamp ?? "nil")
        }
    }

    /// Includes LICENSE and APPSTORE-EXCEPTION.md, which project.yml copies
    /// from the repository root rather than OpenSourceLicenses/.
    func testEveryAcknowledgementResourceIsBundled() {
        for resource in OpenSourceAcknowledgements.resources {
            XCTAssertNotNil(OpenSourceAcknowledgements.resourceURL(for: resource), resource.name)
        }
    }
}

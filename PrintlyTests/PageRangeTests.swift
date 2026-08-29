import Foundation
import Testing
@testable import Printly

struct PageRangeTests {
    @Test func parse_blankMeansAllPages() {
        let parsed = PageRange.parse("  ")
        guard case .success(let range) = parsed else {
            Issue.record("Expected success")
            return
        }
        #expect(range.isAllPages)
        #expect(range.contains(1))
        #expect(range.contains(99))
    }

    @Test(arguments: [
        ("1", [1]),
        ("1-3", [1, 2, 3]),
        ("1-3,5", [1, 2, 3, 5]),
        ("8-10", [8, 9, 10]),
        (" 2 - 4 , 7 ", [2, 3, 4, 7]),
    ])
    func parse_validRanges(text: String, included: [Int]) {
        let parsed = PageRange.parse(text)
        guard case .success(let range) = parsed else {
            Issue.record("Expected success for \(text)")
            return
        }
        #expect(range.isAllPages == false)
        for page in included {
            #expect(range.contains(page))
        }
        #expect(range.contains(99) == false)
    }

    @Test(arguments: ["abc", "1-", "-3", "3-1", "0", "1-3,", "1,,3"])
    func parse_invalidRanges(text: String) {
        let parsed = PageRange.parse(text)
        #expect(parsed == .failure(.invalid))
    }
}

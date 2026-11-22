// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit

#if DEBUG
    #error("Run the plot series benchmark in Release.")
#endif

/// Measures style assignment for one draw pass. Rendering and JSON decoding are outside the timer.
@main private enum StudioPlotSeriesBenchmark {
    @inline(never) static func previousSeries(_ marks: [GlifiStudioVisualMark]) -> [String] {
        var names: [String] = []
        for mark in marks where !names.contains(mark.series) { names.append(mark.series) }
        return names
    }

    static func previous(_ marks: [GlifiStudioVisualMark]) -> [Int] {
        marks.compactMap { mark in
            guard mark.kind == .point else { return nil }
            return previousSeries(marks).firstIndex(of: mark.series) ?? 0
        }
    }

    static func indexed(_ marks: [GlifiStudioVisualMark]) -> [Int] {
        let index = StudioPlotSeries(marks)
        return index.points.map { index.styleIndex(for: $0.series) ?? 0 }
    }

    static func marks(count: Int) throws -> [GlifiStudioVisualMark] {
        let rows = (0..<count).map { i in
            let kind = i.isMultiple(of: 8) ? "segment" : "point"
            let series = kind == "segment" ? "edges" : "community.\(i % 7)"
            return """
                {"id":"m\(i)","kind":"\(kind)","series":"\(series)","label":"p\(i)",
                 "x":0,"y":1,"isEmphasized":false,"lineageClass":"exact","sourceRevisionIDs":[]}
                """
        }
        let data = Data(("[" + rows.joined(separator: ",") + "]").utf8)
        return try JSONDecoder().decode([GlifiStudioVisualMark].self, from: data)
    }

    static func measure(_ work: () -> [Int], expected: [Int]) -> Double {
        let start = ContinuousClock.now
        let result = work()
        let duration = start.duration(to: .now).components
        precondition(result == expected)
        return Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
    }

    static func main() throws {
        for count in [60, 1200] {
            let input = try marks(count: count)
            let expected = previous(input)
            precondition(indexed(input) == expected)
            var baseline: [Double] = []
            var candidate: [Double] = []
            for pass in 0..<7 {
                if pass.isMultiple(of: 2) {
                    baseline.append(measure({ previous(input) }, expected: expected))
                    candidate.append(measure({ indexed(input) }, expected: expected))
                } else {
                    candidate.append(measure({ indexed(input) }, expected: expected))
                    baseline.append(measure({ previous(input) }, expected: expected))
                }
            }
            print("marks", count, "points", expected.count)
            print("previous ms", baseline, "median", baseline.sorted()[3])
            print("indexed ms", candidate, "median", candidate.sorted()[3])
        }
    }
}

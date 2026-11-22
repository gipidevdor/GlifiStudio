// SPDX-License-Identifier: BSD-3-Clause

import CoreGraphics
import CoreML
import CoreText
import Foundation
import Vision

// This diagnostic runs outside the app and uses only generated Italian text.
private struct Sample {
    let id: String
    let text: String
}

private struct Reading: Encodable {
    let elapsedMilliseconds: Double
    let recognizedText: String
    let exact: Bool
}

private struct Failure: Encodable {
    let domain: String
    let code: Int
    let reason: String
}

private struct Trial: Encodable {
    let sample: String
    let expected: String
    let mainStagePolicy: String
    var readings: [Reading] = []
    var failure: Failure?
}

private struct ModeReport: Encodable {
    let recognitionLevel: String
    let supportsItalian: Bool
    let supportedMainStageDevices: [String]
    var trials: [Trial] = []
}

private struct Report: Encodable {
    let operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
    let recognitionLanguage = "it-IT"
    let requestRevision = 3
    let repetitionsAfterFirst = 5
    let availableCoreMLDevices = MLComputeDevice.allComputeDevices.map(name).sorted()
    var modes: [ModeReport] = []

    var passed: Bool {
        modes.allSatisfy { mode in
            mode.supportsItalian && !mode.trials.isEmpty
                && mode.trials.allSatisfy { trial in
                    trial.failure == nil && trial.readings.count == 1 + repetitionsAfterFirst
                        && trial.readings.allSatisfy(\.exact)
                }
        }
    }
}

private enum ProbeFailure: Error { case cannotDrawSample }

private func makeSample(_ sample: String) throws -> CGImage {
    let width = 1024
    let height = 120
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw ProbeFailure.cannotDrawSample }

    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("Helvetica" as CFString, 44, nil)
    let text = NSAttributedString(
        string: sample,
        attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                gray: 0, alpha: 1),
        ])
    context.textPosition = CGPoint(x: 20, y: 38)
    CTLineDraw(CTLineCreateWithAttributedString(text), context)
    guard let image = context.makeImage() else { throw ProbeFailure.cannotDrawSample }
    return image
}

private func name(_ device: MLComputeDevice) -> String {
    switch device {
    case .cpu: "CPU"
    case .gpu: "GPU"
    case .neuralEngine: "ANE"
    @unknown default: "unknown"
    }
}

private func recognize(
    _ request: RecognizeTextRequest, sample: Sample, image: CGImage,
    policy: String, repetitions: Int
) async -> Trial {
    var trial = Trial(sample: sample.id, expected: sample.text, mainStagePolicy: policy)
    for _ in 0...repetitions {
        do {
            let start = ContinuousClock.now
            let observations = try await request.perform(on: image)
            let duration = start.duration(to: .now).components
            let text = observations.compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
            trial.readings.append(
                Reading(
                    elapsedMilliseconds: Double(duration.seconds) * 1000 + Double(
                        duration.attoseconds) / 1e15,
                    recognizedText: text, exact: text == sample.text))
        } catch {
            let nsError = error as NSError
            trial.failure = Failure(
                domain: nsError.domain, code: nsError.code, reason: String(describing: error))
            break
        }
    }
    return trial
}

private func run() async throws -> Report {
    var report = Report()
    let samples = [
        Sample(id: "accents", text: "La città è già pronta per la ricerca."),
        Sample(id: "numbers", text: "Riga 27, valore 3,5 su 100."),
    ]
    let images = try samples.map { try makeSample($0.text) }
    for level in [RecognizeTextRequest.RecognitionLevel.fast, .accurate] {
        var request = RecognizeTextRequest(.revision3)
        request.recognitionLevel = level
        request.recognitionLanguages = [Locale.Language(identifier: report.recognitionLanguage)]
        request.usesLanguageCorrection = true
        let devices = request.supportedComputeStageDevices[.main] ?? []
        var mode = ModeReport(
            recognitionLevel: level == .accurate ? "accurate" : "fast",
            supportsItalian: request.supportedRecognitionLanguages.contains {
                $0.languageCode?.identifier == "it"
            },
            supportedMainStageDevices: devices.map(name).sorted())
        if mode.supportsItalian {
            let policies: [MLComputeDevice?] = [nil] + devices.sorted { name($0) < name($1) }
            for device in policies {
                var configured = request
                configured.setComputeDevice(device, for: .main)
                for (sample, image) in zip(samples, images) {
                    let trial = await recognize(
                        configured, sample: sample, image: image,
                        policy: device.map(name) ?? "automatic",
                        repetitions: report.repetitionsAfterFirst)
                    mode.trials.append(trial)
                }
            }
        }
        report.modes.append(mode)
    }
    return report
}

do {
    let report = try await run()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
    if !report.passed { exit(EXIT_FAILURE) }
} catch {
    FileHandle.standardError.write(Data("Could not prepare the OCR probe: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}

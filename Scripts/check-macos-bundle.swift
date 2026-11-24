// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

// Run with: xcrun swift -swift-version 6 Scripts/check-macos-bundle.swift <GlifiStudio.app>
// This checks packaged resources and Foundation lookups, without registering or launching the app.

struct BundleVerificationFailure: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw BundleVerificationFailure(description: message) }
}

func dictionary(at url: URL) throws -> [String: Any] {
    let value = try PropertyListSerialization.propertyList(
        from: Data(contentsOf: url), options: [], format: nil)
    guard let result = value as? [String: Any] else {
        throw BundleVerificationFailure(description: "Expected a property-list dictionary.")
    }
    return result
}

func majorVersion(_ value: String) -> Int? {
    let components = value.split(separator: ".", omittingEmptySubsequences: false)
    guard let first = components.first,
        components.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
    else { return nil }
    return Int(first)
}

func verifyPayload(at bundleURL: URL) throws -> (
    inspectedEntries: Int, forbiddenDirectoryNames: [String], forbiddenExtensions: [String]
) {
    let forbiddenDirectories: Set<String> = [
        ".github", "benchmarks", "config", "design", "distribution", "docs", "fixtures", "packages",
        "scripts", "tests",
    ]
    let forbiddenExtensions: Set<String> = ["xctest", "xcconfig"]
    var pending = [bundleURL]
    var inspectedEntries = 0
    while let directory = pending.popLast() {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        for child in children {
            inspectedEntries += 1
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let relativePath = String(child.path.dropFirst(bundleURL.path.count + 1))
            try require(
                !forbiddenExtensions.contains(child.pathExtension.lowercased()),
                "Development payload found in bundle: \(relativePath)")
            if values.isDirectory == true {
                try require(
                    !forbiddenDirectories.contains(child.lastPathComponent.lowercased()),
                    "Repository directory found in bundle: \(relativePath)")
                // Framework symlinks are allowed; never follow them outside the inspected bundle.
                if values.isSymbolicLink != true { pending.append(child) }
            }
        }
    }
    return (inspectedEntries, forbiddenDirectories.sorted(), forbiddenExtensions.sorted())
}

func verifyBundle(at bundleURL: URL) throws -> [String: Any] {
    try require(bundleURL.pathExtension == "app", "Expected a macOS .app bundle.")
    guard let bundle = Bundle(url: bundleURL), let resources = bundle.resourceURL else {
        throw BundleVerificationFailure(description: "Unable to read the application bundle.")
    }
    let info = try dictionary(at: bundleURL.appendingPathComponent("Contents/Info.plist"))
    try require(
        info["CFBundleIdentifier"] as? String == "studio.glifi.GlifiStudio",
        "Unexpected application bundle identifier.")
    try require(
        info["CFBundlePackageType"] as? String == "APPL", "Expected an application package.")
    guard let minimumSystemVersion = info["LSMinimumSystemVersion"] as? String,
        let minimumSystemMajor = majorVersion(minimumSystemVersion), minimumSystemMajor >= 27,
        let sdkName = info["DTSDKName"] as? String, sdkName.hasPrefix("macosx"),
        let sdkMajor = majorVersion(String(sdkName.dropFirst("macosx".count))), sdkMajor >= 27
    else {
        throw BundleVerificationFailure(
            description:
                "Expected generated minimum macOS and SDK metadata with major version 27 or later.")
    }

    let typeIdentifier = "studio.glifi.project"
    let descriptionKey = "Progetto Glifi Studio"
    let documents = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
    let projectDocuments = documents.filter {
        ($0["LSItemContentTypes"] as? [String] ?? []).contains(typeIdentifier)
    }
    try require(projectDocuments.count == 1, "Expected one Glifi Studio document declaration.")
    try require(
        projectDocuments.first?["CFBundleTypeName"] as? String == descriptionKey,
        "The raw document type name changed.")
    let exportedTypes = info["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []
    let projectTypes = exportedTypes.filter { $0["UTTypeIdentifier"] as? String == typeIdentifier }
    try require(projectTypes.count == 1, "Expected one exported Glifi Studio project type.")
    try require(
        projectTypes.first?["UTTypeDescription"] as? String == descriptionKey,
        "The raw exported UTI description changed.")

    let requiredResources = ["PrivacyInfo.xcprivacy", "Assets.car"]
    for name in requiredResources {
        try require(
            FileManager.default.fileExists(atPath: resources.appendingPathComponent(name).path),
            "Missing packaged resource: \(name)")
    }
    let expectedLocalizations = ["it": descriptionKey, "en": "Glifi Studio Project"]
    var documentLocalizations: [String: String] = [:]
    for language in expectedLocalizations.keys.sorted() {
        let localizationURL = resources.appendingPathComponent("\(language).lproj")
        guard let localizedBundle = Bundle(url: localizationURL),
            let expected = expectedLocalizations[language]
        else {
            throw BundleVerificationFailure(description: "Missing localization: \(language)")
        }
        let table = try dictionary(at: localizationURL.appendingPathComponent("InfoPlist.strings"))
        try require(
            table[descriptionKey] as? String == expected,
            "The InfoPlist table lacks the translated raw description key for \(language).")
        let description = localizedBundle.localizedString(
            forKey: descriptionKey, value: nil, table: "InfoPlist")
        try require(description == expected, "Incorrect InfoPlist lookup for \(language).")
        let applicationName = localizedBundle.localizedString(
            forKey: "app.name", value: nil, table: "Localizable")
        try require(
            applicationName == "Glifi Studio", "Missing application catalog for \(language).")
        documentLocalizations[language] = description
    }
    let payload = try verifyPayload(at: bundleURL)
    return [
        "schema": "studio.glifi.macos-bundle-verification",
        "schemaVersion": 1,
        "bundleName": bundleURL.lastPathComponent,
        "documentTypeIdentifier": typeIdentifier,
        "rawDescriptionKey": descriptionKey,
        "documentLocalizations": documentLocalizations,
        "requiredResources": requiredResources,
        "generatedBuildMetadata": [
            "minimumSystemVersion": minimumSystemVersion,
            "minimumSystemMajorVersion": minimumSystemMajor,
            "sdkName": sdkName,
            "sdkMajorVersion": sdkMajor,
        ],
        "payloadInspection": [
            "inspectedEntries": payload.inspectedEntries,
            "forbiddenDirectoryNames": payload.forbiddenDirectoryNames,
            "forbiddenExtensions": payload.forbiddenExtensions,
            "matchesWithinDeclaredScope": 0,
        ],
        "verifiedScope": [
            "Raw document and exported UTI declarations.",
            "Generated minimum macOS and SDK version metadata.",
            "Required packaged resources and Foundation localized string lookup for it/en.",
            "Bundle entries matching the listed directory names or file extensions.",
        ],
        "finderOrLaunchServicesPresentationVerified": false,
        "secureStateRestorationRuntimeVerified": false,
    ]
}

do {
    try require(
        CommandLine.arguments.count == 2,
        "Usage: xcrun swift -swift-version 6 Scripts/check-macos-bundle.swift <GlifiStudio.app>")
    let bundleURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let report = try verifyBundle(at: bundleURL)
    let data = try JSONSerialization.data(
        withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Bundle verification failed: \(error)\n".utf8))
    exit(1)
}

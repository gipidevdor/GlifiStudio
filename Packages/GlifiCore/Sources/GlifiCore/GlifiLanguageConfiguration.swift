// SPDX-License-Identifier: BSD-3-Clause

/// Identifies the language and locale used when a project has no explicit configuration.
public struct GlifiLanguageConfiguration: Sendable, Equatable {
    /// The initial Italian language configuration.
    public static let italian = GlifiLanguageConfiguration(
        languageCode: "it",
        localeIdentifier: "it_IT"
    )

    /// The BCP 47 language code used by linguistic services.
    public let languageCode: String

    /// The locale identifier used by locale-sensitive operations.
    public let localeIdentifier: String

    /// Creates an explicit language configuration.
    ///
    /// - Parameters:
    ///   - languageCode: A BCP 47 language code.
    ///   - localeIdentifier: A locale identifier for locale-sensitive operations.
    public init(languageCode: String, localeIdentifier: String) {
        self.languageCode = languageCode
        self.localeIdentifier = localeIdentifier
    }
}

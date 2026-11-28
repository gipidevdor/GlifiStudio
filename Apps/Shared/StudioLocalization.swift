// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import SwiftUI

/// Keeps a complete semantic key distinct from a localized interpolation template.
nonisolated enum StudioLocalization {
    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }

    static func value(_ key: String) -> String.LocalizationValue {
        String.LocalizationValue(key)
    }
}

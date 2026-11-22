// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Shared decimal-token grammar; each editor retains its own row and failure contracts.
enum GlifiStudioEditorDecimal {
    static func parse(_ token: String) -> Double? {
        guard
            token.range(
                of: #"^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]+)(?:[eE][+-]?[0-9]+)?$"#,
                options: .regularExpression) != nil,
            !(token.contains(".") && token.contains(",")),
            let value = Double(token.replacingOccurrences(of: ",", with: ".")), value.isFinite
        else { return nil }
        return value
    }
}

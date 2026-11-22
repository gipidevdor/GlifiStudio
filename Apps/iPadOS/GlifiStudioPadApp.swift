// SPDX-License-Identifier: BSD-3-Clause

import SwiftUI

@main
struct GlifiStudioPadApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: GlifiStudioDocument()) {
            (file: FileDocumentConfiguration<GlifiStudioDocument>) in
            StudioHomeView(
                documentURL: file.fileURL,
                needsPackageInitialization: file.document.needsPackageInitialization
            )
        }
    }
}

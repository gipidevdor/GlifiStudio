// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit
import SwiftUI

@main
struct GlifiStudioMacApp: App {
    private let runtimeMonitor: StudioMacRuntimeMonitor

    init() {
        let monitor = StudioMacRuntimeMonitor()
        monitor.start()
        runtimeMonitor = monitor
    }

    var body: some Scene {
        DocumentGroup(newDocument: GlifiStudioDocument()) {
            (file: FileDocumentConfiguration<GlifiStudioDocument>) in
            StudioHomeView(
                documentURL: file.fileURL,
                needsPackageInitialization: file.document.needsPackageInitialization,
                service: GlifiStudioService(runtimeEnvironment: runtimeMonitor.environment)
            )
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            SidebarCommands()
            StudioWorkspaceCommands()
        }
    }
}

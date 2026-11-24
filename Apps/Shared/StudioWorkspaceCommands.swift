// SPDX-License-Identifier: BSD-3-Clause

import SwiftUI

/// Commands resolve against the focused document, including when several projects are open.
struct StudioWorkspaceActions {
    let showOverview: () -> Void
    let showSources: () -> Void
    let showInvestigation: () -> Void
    let showQuery: () -> Void
    let showFindings: () -> Void
    let showCoding: () -> Void
    let showExport: () -> Void
    let findTool: () -> Void
    let importSources: () -> Void
    let canImport: Bool
}

private struct StudioWorkspaceActionsKey: FocusedValueKey {
    typealias Value = StudioWorkspaceActions
}

extension FocusedValues {
    var studioWorkspaceActions: StudioWorkspaceActions? {
        get { self[StudioWorkspaceActionsKey.self] }
        set { self[StudioWorkspaceActionsKey.self] = newValue }
    }
}

struct StudioWorkspaceCommands: Commands {
    @FocusedValue(\.studioWorkspaceActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("action.import") { actions?.importSources() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(actions?.canImport != true)
        }
        CommandGroup(after: .textEditing) {
            Button("workspace.query.find") { actions?.showQuery() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandMenu("workspace.menu") {
            Group {
                Button("workspace.tools.find") { actions?.findTool() }
                    .keyboardShortcut("k", modifiers: .command)
                Divider()
                Button("sidebar.overview") { actions?.showOverview() }
                    .keyboardShortcut("1", modifiers: .command)
                Button("sidebar.sources") { actions?.showSources() }
                    .keyboardShortcut("2", modifiers: .command)
                Button("sidebar.investigation") { actions?.showInvestigation() }
                    .keyboardShortcut("3", modifiers: .command)
                Button("sidebar.query") { actions?.showQuery() }
                    .keyboardShortcut("4", modifiers: .command)
                Button("sidebar.findings") { actions?.showFindings() }
                    .keyboardShortcut("5", modifiers: .command)
                Button("sidebar.coding") { actions?.showCoding() }
                    .keyboardShortcut("6", modifiers: .command)
                Button("sidebar.export") { actions?.showExport() }
                    .keyboardShortcut("7", modifiers: .command)
            }
            .disabled(actions == nil)
        }
    }
}

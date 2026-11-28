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
    let showStudy: () -> Void
    let findTool: () -> Void
    let importSources: () -> Void
    let canImport: Bool
}

private struct StudioWorkspaceActionsKey: FocusedValueKey {
    typealias Value = StudioWorkspaceActions
}

#if os(macOS)
    /// Reading commands and their current availability belong to the focused Study view.
    struct StudioStudyActions {
        let collectPassage: () -> Void
        let newConclusion: () -> Void
        let toggleNotebook: () -> Void
        let toggleComparison: () -> Void
        let canCollectPassage: Bool
        let canCreateConclusion: Bool
        let canToggleNotebook: Bool
        let canToggleComparison: Bool
        let showsNotebook: Bool
        let showsComparison: Bool
    }

    private struct StudioStudyActionsKey: FocusedValueKey {
        typealias Value = StudioStudyActions
    }
#endif

extension FocusedValues {
    var studioWorkspaceActions: StudioWorkspaceActions? {
        get { self[StudioWorkspaceActionsKey.self] }
        set { self[StudioWorkspaceActionsKey.self] = newValue }
    }

    #if os(macOS)
        var studioStudyActions: StudioStudyActions? {
            get { self[StudioStudyActionsKey.self] }
            set { self[StudioStudyActionsKey.self] = newValue }
        }
    #endif
}

struct StudioWorkspaceCommands: Commands {
    @FocusedValue(\.studioWorkspaceActions) private var actions
    #if os(macOS)
        @FocusedValue(\.studioStudyActions) private var studyActions
    #endif

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
                #if os(macOS)
                    Button("study.title") { actions?.showStudy() }
                        .keyboardShortcut("8", modifiers: .command)
                #endif
            }
            .disabled(actions == nil)
        }
        #if os(macOS)
            CommandMenu("study.title") {
                Button("study.collect") { studyActions?.collectPassage() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(studyActions?.canCollectPassage != true)
                Button("study.conclusion.new") { studyActions?.newConclusion() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(studyActions?.canCreateConclusion != true)
                Divider()
                Toggle(
                    "study.notebook",
                    isOn: Binding(
                        get: { studyActions?.showsNotebook ?? false },
                        set: { _ in studyActions?.toggleNotebook() })
                )
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(studyActions?.canToggleNotebook != true)
                Button(
                    LocalizedStringKey(
                        studyActions?.showsComparison == true
                            ? "study.compare.close" : "study.compare.open")
                ) {
                    studyActions?.toggleComparison()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(studyActions?.canToggleComparison != true)
            }
        #endif
    }
}

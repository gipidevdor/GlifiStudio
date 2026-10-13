// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiKit

@main
enum GlifiCLI {
    static func main() async {
        var commandName = "unknown"
        do {
            let request = try CLIRequest(arguments: Array(CommandLine.arguments.dropFirst()))
            commandName = request.command.name
            try await execute(request)
        } catch is CLIUsageError {
            writeStandardError(CLIRequest.usage)
            exit(2)
        } catch let failure as GlifiStudioFailure {
            writeFailure(failure, command: commandName)
            exit(exitCode(for: failure.category))
        } catch {
            let failure = CLIError.internalFailure
            writeFailure(failure, command: commandName)
            exit(70)
        }
    }

    private static func execute(_ request: CLIRequest) async throws {
        let service = GlifiStudioService()
        switch request.command {
        case .status:
            let status = await service.status()
            switch request.format {
            case .text:
                print("GlifiCore pronto")
            case .json:
                try writeJSON(
                    SuccessEnvelope(
                        command: request.command.name, result: StatusResult(status: status))
                )
            }
        case let .projectCreate(projectURL):
            let session = try await service.createProject(at: projectURL)
            let snapshot = try await session.snapshot()
            await session.close()
            try writeProjectResult(snapshot, request: request, action: "creato")
        case let .projectInfo(projectURL):
            let session = try await service.openProject(at: projectURL)
            let snapshot = try await session.snapshot()
            await session.close()
            try writeProjectResult(snapshot, request: request, action: "valido")
        case let .projectValidate(projectURL):
            let session = try await service.openProject(at: projectURL)
            let snapshot = try await session.snapshot()
            await session.close()
            switch request.format {
            case .text:
                print("Progetto valido · generazione \(snapshot.generation)")
            case .json:
                try writeJSON(
                    SuccessEnvelope(
                        command: request.command.name,
                        result: ProjectValidationResult(project: snapshot, status: "valid")
                    )
                )
            }
        case let .importSources(projectURL, sourceURLs):
            let session = try await service.openProject(at: projectURL)
            var lastResult: GlifiStudioProjectImportResult?
            for sourceURL in sourceURLs {
                try Task.checkCancellation()
                lastResult = try await session.importText(
                    at: sourceURL,
                    format: sourceURL.pathExtension.lowercased() == "txt" ? .plainText : .markdown
                )
            }
            await session.close()
            guard let lastResult else {
                throw CLIUsageError.invalidArguments
            }
            switch request.format {
            case .text:
                print(
                    "Importazione completata · generazione \(lastResult.project.generation) · \(lastResult.project.sourceCount) fonti"
                )
            case .json:
                try writeJSON(
                    SuccessEnvelope(
                        command: request.command.name,
                        result: ImportResult(
                            project: lastResult.project,
                            importedSourceCount: sourceURLs.count,
                            lastProfile: lastResult.profile
                        )
                    )
                )
            }
        case let .query(projectURL, input):
            let astData: Data?
            switch input {
            case .text: astData = nil
            case let .ast(url): astData = try readQueryAST(at: url)
            }
            let session = try await service.openProject(at: projectURL)
            let result: GlifiStudioProjectQueryResult
            do {
                switch input {
                case let .text(text): result = try await session.query(text)
                case .ast:
                    guard let astData else { throw CLIError.internalFailure }
                    result = try await session.query(canonicalAST: astData)
                }
                await session.close()
            } catch {
                await session.close()
                throw error
            }
            switch request.format {
            case .text:
                for match in result.matches {
                    print("\(match.leftContext)\t\(match.match)\t\(match.rightContext)")
                }
                if result.isTruncated {
                    writeStandardError("Risultati troncati dal limite dichiarato.\n")
                }
            case .json:
                try writeJSON(
                    SuccessEnvelope(
                        command: request.command.name,
                        result: QueryResult(result)
                    )
                )
            }
        case let .plan(projectURL, requestURL):
            let planRequest = try readPlanRequest(at: requestURL)
            let session = try await service.openProject(at: projectURL)
            let result = try await session.planAnalysis(planRequest)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Piano \(result.plan.status) · generazione \(result.generation) · \(result.plan.steps.count) passi · costo stimato \(result.plan.totalEstimatedWorkUnits)"
                )
                for decision in result.plan.decisions {
                    print(
                        "\(decision.capabilityIdentifier)\t\(decision.applicability)\t\(decision.reasonIdentifiers.joined(separator: ","))"
                    )
                }
            case .json:
                try writeJSON(
                    SuccessEnvelope(command: request.command.name, result: result)
                )
            }
        case let .executePlan(projectURL, requestURL):
            let planRequest = try readPlanRequest(at: requestURL, operation: "executePlan")
            let session = try await service.openProject(at: projectURL)
            do {
                let execution = try await session.executeAnalysisPlan(planRequest)
                var completedResult: GlifiStudioAnalysisExecutionResult?
                for try await event in execution.events {
                    switch event {
                    case let .progress(progress):
                        if request.format == .text, request.showsProgress {
                            writeExecutionProgress(progress)
                        }
                    case let .completed(result):
                        guard completedResult == nil else {
                            throw CLIError.internalFailure
                        }
                        completedResult = result
                    }
                }
                guard let completedResult else {
                    throw CLIError.internalFailure
                }
                await session.close()
                switch request.format {
                case .text:
                    let interpretationSummary =
                        completedResult.interpretation.insufficientEvidence == nil
                        ? "\(completedResult.interpretation.findings.count) Finding"
                        : "evidenza insufficiente"
                    print(
                        "Piano eseguito · \(completedResult.terminalState) · generazione \(completedResult.generation) · \(completedResult.artifacts.count) Artifact analitici · \(interpretationSummary)"
                    )
                case .json:
                    try writeJSON(
                        SuccessEnvelope(
                            command: request.command.name,
                            result: completedResult
                        )
                    )
                }
            } catch {
                await session.close()
                throw error
            }
        case let .visualize(projectURL, requestURL):
            let planRequest = try readPlanRequest(at: requestURL, operation: "executePlan")
            let session = try await service.openProject(at: projectURL)
            do {
                let execution = try await session.executeAnalysisPlan(planRequest)
                var completedResult: GlifiStudioAnalysisExecutionResult?
                for try await event in execution.events {
                    if case let .completed(result) = event {
                        guard completedResult == nil else {
                            throw CLIError.internalFailure
                        }
                        completedResult = result
                    }
                }
                guard let completedResult else {
                    throw CLIError.internalFailure
                }
                let visualizations = try await session.visualizations(for: completedResult)
                await session.close()
                switch request.format {
                case .text:
                    print("Viste · \(visualizations.count)")
                    for visualization in visualizations {
                        print(
                            "\(visualization.specificationIdentifier) · \(visualization.methodIdentifier) · \(visualization.visibleObservationCount)/\(visualization.totalObservationCount) osservazioni"
                        )
                    }
                case .json:
                    try writeJSON(
                        SuccessEnvelope(command: request.command.name, result: visualizations)
                    )
                }
            } catch {
                await session.close()
                throw error
            }
        case let .investigationCreate(projectURL, requestURL):
            let creationRequest: GlifiStudioInvestigationCreationRequest = try readRequest(
                at: requestURL,
                operation: "investigate"
            )
            let session = try await service.openProject(at: projectURL)
            let result = try await session.createInvestigation(creationRequest)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Indagine creata · generazione \(result.generation) · \(result.investigation.selectedFindingIDs.count) finding selezionati"
                )
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .investigationSelect(projectURL, requestURL):
            let selectionRequest: GlifiStudioInvestigationSelectionRequest = try readRequest(
                at: requestURL,
                operation: "investigate"
            )
            let session = try await service.openProject(at: projectURL)
            let result = try await session.reviseInvestigationSelection(selectionRequest)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Selezione aggiornata · generazione \(result.generation) · \(result.investigation.selectedFindingIDs.count) finding"
                )
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .investigationList(projectURL):
            let session = try await service.openProject(at: projectURL)
            let heads = try await session.investigationHeads()
            await session.close()
            switch request.format {
            case .text:
                for head in heads {
                    print("\(head.id)\t\(head.headEventID)\t\(head.question)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: heads))
            }
        case let .exportInvestigation(projectURL, requestURL, outputURL):
            let exportRequest: GlifiStudioScientificExportRequest = try readRequest(
                at: requestURL,
                operation: "export"
            )
            let session = try await service.openProject(at: projectURL)
            do {
                let receipt = try await session.exportInvestigation(
                    exportRequest,
                    to: outputURL
                )
                await session.close()
                switch request.format {
                case .text:
                    print(
                        "Esportazione verificata · \(receipt.fileCount) file · manifest \(receipt.manifestDigest)"
                    )
                case .json:
                    try writeJSON(
                        SuccessEnvelope(command: request.command.name, result: receipt)
                    )
                }
            } catch {
                await session.close()
                throw error
            }
        case let .analyze(projectURL):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeCorpus()
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Corpus analizzato · generazione \(result.generation) · \(result.documentCount) documenti · \(result.sentenceCount) frasi · \(result.lexicalTokenCount) token · \(result.typeCount) type"
                )
                for term in result.terms.prefix(20) {
                    print(
                        "\(term.term)\t\(term.frequency)\tdf=\(term.documentFrequency)\tDP=\(term.griesDP)"
                    )
                }
            case .json:
                try writeJSON(
                    SuccessEnvelope(command: request.command.name, result: result)
                )
            }
        case let .keyness(projectURL, targetSourceRevisionIDs, referenceSourceRevisionIDs):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.compareKeyness(
                targetSourceRevisionIDs: targetSourceRevisionIDs,
                referenceSourceRevisionIDs: referenceSourceRevisionIDs
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Keyness calcolata · generazione \(result.generation) · \(result.targetTokenCount) token target · \(result.referenceTokenCount) token riferimento"
                )
                for term in result.terms.prefix(20) {
                    print(
                        "\(term.term)\tG=\(term.gStatistic)\tp=\(term.pValue)\tq=\(term.qValue)\tlog2=\(term.log2RatioHaldaneAnscombe)\t\(term.direction)"
                    )
                }
            case .json:
                try writeJSON(
                    SuccessEnvelope(command: request.command.name, result: result)
                )
            }
        case let .similarity(projectURL, targetSourceRevisionIDs, referenceSourceRevisionIDs):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.compareSimilarity(
                targetSourceRevisionIDs: targetSourceRevisionIDs,
                referenceSourceRevisionIDs: referenceSourceRevisionIDs
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Similarità calcolata · generazione \(result.generation) · coseno=\(result.cosineSimilarity) jaccard=\(result.jaccardSimilarity) dice=\(result.diceSimilarity)"
                )
            case .json:
                try writeJSON(
                    SuccessEnvelope(command: request.command.name, result: result)
                )
            }
        case let .weighting(projectURL, sourceRevisionIDs, scheme):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeTermWeighting(
                sourceRevisionIDs: sourceRevisionIDs, scheme: scheme)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Ponderazione \(result.combinedIdentifier) · \(scheme.termFrequency) · \(scheme.inverseDocumentFrequency) · \(scheme.normalization) · \(result.cells.count) celle"
                )
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .ngrams(projectURL, sourceRevisionIDs, unit, filter, maximumRows):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeNGramFrequencies(
                sourceRevisionIDs: sourceRevisionIDs, unit: unit, filter: filter,
                maximumRowCount: maximumRows)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "\(result.unitIdentifier) n=\(result.n) · \(result.rows.count) righe · denominatore \(result.denominator)"
                )
                for row in result.rows.prefix(20) {
                    print(
                        "\(row.components.joined(separator: " "))\t\(row.count)\t\(row.documentFrequency)"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .qualitativeState(projectURL):
            let session = try await service.openProject(at: projectURL)
            let state = try await session.qualitativeState()
            await session.close()
            switch request.format {
            case .text:
                let active = state.codings.filter { $0.retractionEventID == nil }.count
                print(
                    "Storia qualitativa · \(state.codebooks.count) codebook · \(active) codifiche attive · \(state.memos.count) memo"
                )
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: state))
            }
        case let .qualitativeAppend(projectURL, requestURL):
            let change: GlifiStudioQualitativeChange = try readRequest(
                at: requestURL, operation: "investigate")
            let session = try await service.openProject(at: projectURL)
            let state = try await session.appendQualitativeChange(change)
            await session.close()
            switch request.format {
            case .text:
                print("Evento qualitativo registrato · testa \(state.headEventID ?? "")")
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: state))
            }
        case let .qualitativeSegments(projectURL, sourceRevisionID):
            let session = try await service.openProject(at: projectURL)
            let segments = try await session.textSegments(sourceRevisionID: sourceRevisionID)
            await session.close()
            switch request.format {
            case .text:
                print("Segmenti selezionabili · \(segments.count) frasi")
                for (index, segment) in segments.enumerated() {
                    print("\(index)\t\(segment.startUTF8)–\(segment.endUTF8)\t\(segment.text)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: segments))
            }
        case let .qualitativePassage(projectURL, sourceRevisionID, selection):
            let session = try await service.openProject(at: projectURL)
            let passage = try await session.passage(
                sourceRevisionID: sourceRevisionID, selection: selection)
            await session.close()
            switch request.format {
            case .text:
                print("Passaggio · byte \(passage.startUTF8)–\(passage.endUTF8)")
                print(passage.text)
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: passage))
            }
        case let .qualitativeAgreement(projectURL, codebookID, revision, coderIDs):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.assessStoredCodingAgreement(
                codebookID: codebookID, codebookRevision: revision, coderIDs: coderIDs)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Accordo dalle codifiche · \(result.agreement.unitCount) unità · \(result.ambiguousUnitCount) ambigue escluse"
                )
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .diversity(projectURL, sourceRevisionIDs, threshold):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeLexicalDiversity(
                sourceRevisionIDs: sourceRevisionIDs, threshold: threshold)
            await session.close()
            switch request.format {
            case .text:
                let pooled = result.pooled.map { "\($0.value.doubleValue)" } ?? "non definito"
                print("MTLD-bidirectional-v1 · τ=\(result.threshold) · complessivo \(pooled)")
                for document in result.documents {
                    let value = document.mtld.map { "\($0.value.doubleValue)" } ?? "non definito"
                    print("\(document.sourceRevisionID)\t\(value)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .bm25(projectURL, sourceRevisionIDs, query, k1, b):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.rankDocumentsBM25(
                sourceRevisionIDs: sourceRevisionIDs, query: query, k1: k1, b: b)
            await session.close()
            switch request.format {
            case .text:
                print("BM25-v1 · k1=\(result.k1) b=\(result.b) · N=\(result.documentCount)")
                for document in result.ranking {
                    print("\(document.sourceRevisionID)\t\(document.score)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .association(projectURL, sourceRevisionIDs):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeAssociation(sourceRevisionIDs: sourceRevisionIDs)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Associazione documento×termine · generazione \(result.lineage.generation) · chi2=\(result.chiSquareStatistic) gdl=\(result.degreesOfFreedom) p=\(result.pValue) V=\(result.cramersV)"
                )
                for residual in result.topResiduals.prefix(10) {
                    print(
                        "\(residual.term)\t\(residual.sourceRevisionID)\tO=\(residual.observed)\tE=\(residual.expected)\tr=\(residual.standardizedResidual)"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .dispersion(projectURL, sourceRevisionIDs, parts):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeDispersion(
                sourceRevisionIDs: sourceRevisionIDs,
                partition: parts
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Dispersione · generazione \(result.lineage.generation) · \(result.terms.count) termini · partizione uguale=\(result.equalSizePartition)"
                )
                for term in result.terms.prefix(20) {
                    print(
                        "\(term.term)\t\(term.frequency)\tdf=\(term.documentFrequency)\tDP=\(term.griesDP)\tDPnorm=\(formattedOptional(term.griesDPNorm))\tD=\(formattedOptional(term.juillandD))"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .groupMetric(projectURL, groups, term, flags):
            let options = try flags.options()
            let session = try await service.openProject(at: projectURL)
            let result = try await session.compareGroupMetric(
                groups: groups,
                metric: term.map { .termRelativeFrequency($0) } ?? .lexicalTokenCount,
                options: options
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Confronto gruppi · generazione \(result.lineage.generation) · metrica \(result.metricIdentifier)"
                )
                for (position, group) in result.groups.enumerated() {
                    print(
                        "gruppo \(position + 1)\tn=\(group.documentCount)\tmedia=\(group.mean)\tvarianza=\(formattedOptional(group.variance))\tIC bootstrap=[\(formattedOptional(group.bootstrapLower)), \(formattedOptional(group.bootstrapUpper))]"
                    )
                }
                if let anova = result.anova {
                    print("ANOVA\tF=\(anova.fStatistic)\tp=\(anova.pValue)")
                } else if let reason = result.anovaUnavailableReason {
                    print("ANOVA non disponibile: \(reason)")
                }
                if let welch = result.welch {
                    print(
                        "Welch\tt=\(welch.statistic)\tgdl=\(welch.degreesOfFreedom)"
                            + "\tp=\(welch.pValue)"
                    )
                } else if let reason = result.welchUnavailableReason {
                    print("Welch non disponibile: \(reason)")
                }
                if let test = result.mannWhitney {
                    print(
                        "Mann-Whitney\tU1=\(test.u1)\tU2=\(test.u2)"
                            + "\tmetodo=\(test.methodIdentifier)\tp=\(test.pValue)"
                    )
                } else if let reason = result.mannWhitneyUnavailableReason {
                    print("Mann-Whitney non disponibile: \(reason)")
                }
                if let test = result.kruskalWallis {
                    print(
                        "Kruskal-Wallis\tH=\(test.correctedHStatistic)\tgdl=\(test.degreesOfFreedom)"
                            + "\tp=\(test.pValue)"
                    )
                } else if let reason = result.kruskalWallisUnavailableReason {
                    print("Kruskal-Wallis non disponibile: \(reason)")
                }
                if let d = result.cohenD {
                    print("Cohen d (pooled)\td=\(d)")
                } else if let reason = result.cohenDUnavailableReason {
                    print("Cohen d non disponibile: \(reason)")
                }
                if let test = result.permutation {
                    print(
                        "Permutazione\tdiff=\(test.observedDifference)\tstrategia=\(test.strategyIdentifier)"
                            + "\tm=\(test.evaluatedCount)\tp=\(test.pValue)\tseed=\(result.resamplingSeed)"
                    )
                } else if let reason = result.permutationUnavailableReason {
                    print("Permutazione non disponibile: \(reason)")
                }
                if let difference = result.standardizedDifference {
                    print(
                        "Hedges g=\(difference.hedgesG)\td=\(difference.cohenD)"
                            + "\tIC d=[\(difference.lower), \(difference.upper)]"
                    )
                }
                if let kruskal = result.kruskalWallis {
                    print("Kruskal-Wallis ε²=\(kruskal.epsilonSquared)")
                }
                for contrast in result.contrasts {
                    print(
                        "Contrasto \(contrast.coefficients)\tstima=\(contrast.estimate)\tt=\(contrast.tStatistic)"
                            + "\tp=\(contrast.pValue)\tBonf=\(contrast.bonferroniPValue)"
                    )
                }
                if let reason = result.contrastsUnavailableReason {
                    print("Contrasti non disponibili: \(reason)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .collocations(projectURL, sourceRevisionIDs, flags):
            let options = try flags.options()
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeCollocations(
                sourceRevisionIDs: sourceRevisionIDs,
                options: options
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Collocazioni · generazione \(result.lineage.generation) · \(result.pairs.count) coppie su \(result.evaluatedPairCount) valutate · universo \(result.universeSize) documenti"
                )
                for pair in result.pairs.prefix(20) {
                    print(
                        "\(pair.firstTerm)\t\(pair.secondTerm)\ta=\(pair.jointCount)\tlogDice=\(formattedOptional(pair.logDice))\tnpmi=\(formattedOptional(pair.npmi))"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .postHoc(projectURL, groups, term):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.postHocGroupMetric(
                groups: groups,
                metric: term.map { .termRelativeFrequency($0) } ?? .lexicalTokenCount
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Post-hoc · generazione \(result.lineage.generation) · \(result.groupCount) gruppi · famiglie Welch m=\(result.welchFamilySize), Mann-Whitney m=\(result.mannWhitneyFamilySize)"
                )
                for pair in result.pairs {
                    let welch = pair.welch.map {
                        "p=\($0.pValue) Bonf=\($0.bonferroniPValue) BH=\($0.benjaminiHochbergPValue)"
                    }
                    let mannWhitney = pair.mannWhitney.map {
                        "p=\($0.pValue) Bonf=\($0.bonferroniPValue) BH=\($0.benjaminiHochbergPValue)"
                    }
                    print(
                        "gruppi \(pair.firstGroupIndex + 1)-\(pair.secondGroupIndex + 1)\tdiff=\(pair.meanDifference)"
                            + "\tWelch \(welch ?? pair.welchUnavailableReason ?? "n/d")"
                            + "\tMann-Whitney \(mannWhitney ?? pair.mannWhitneyUnavailableReason ?? "n/d")"
                    )
                    let tukey = pair.tukey.map { "q=\($0.statistic) p=\($0.pValue)" }
                    let gamesHowell = pair.gamesHowell.map { "q=\($0.statistic) p=\($0.pValue)" }
                    let dunn = pair.dunn.map {
                        "z=\($0.statistic) p=\($0.pValue) Bonf=\(formattedOptional($0.bonferroniPValue))"
                    }
                    print(
                        "\tTukey \(tukey ?? result.tukeyUnavailableReason ?? "n/d")"
                            + "\tGames-Howell \(gamesHowell ?? result.gamesHowellUnavailableReason ?? "n/d")"
                            + "\tDunn \(dunn ?? result.dunnUnavailableReason ?? "n/d")"
                            + "\tg=\(formattedOptional(pair.standardizedDifference?.hedgesG))"
                            + "\trb=\(formattedOptional(pair.rankBiserial))"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .multivariate(projectURL, sourceRevisionIDs, method, maximumTermCount):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeMultivariate(
                sourceRevisionIDs: sourceRevisionIDs,
                method: method,
                maximumTermCount: maximumTermCount
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Multivariata \(result.methodIdentifier) · generazione \(result.lineage.generation) · \(result.sourceRevisionIDs.count) documenti × \(result.terms.count) termini · \(result.representationIdentifier)"
                )
                for (axis, value) in result.axisValues.enumerated() {
                    let share = axis < result.axisShares.count ? result.axisShares[axis] : .nan
                    print("asse \(axis + 1)\tvalore=\(value)\tquota=\(share)")
                }
                if let clusters = result.clusterAssignments {
                    for (document, cluster) in zip(result.sourceRevisionIDs, clusters) {
                        print("\(document)\tcluster=\(cluster)")
                    }
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .paired(projectURL, sourceRevisionIDs, first, second):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.comparePairedMetrics(
                sourceRevisionIDs: sourceRevisionIDs,
                first: first.metric,
                second: second.metric
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Confronto appaiato · generazione \(result.lineage.generation) · \(result.pairCount) documenti · differenza media \(result.meanDifference)"
                )
                if let t = result.tStatistic {
                    print(
                        "t appaiato\tt=\(t)\tp=\(formattedOptional(result.tPValue))"
                            + "\tIC=[\(formattedOptional(result.lower)), \(formattedOptional(result.upper))]"
                    )
                } else if let reason = result.pairedTUnavailableReason {
                    print("t appaiato non disponibile: \(reason)")
                }
                if let p = result.wilcoxonPValue {
                    print(
                        "Wilcoxon\tW+=\(formattedOptional(result.positiveRankSum))\tp=\(p)"
                            + "\tmetodo=\(result.wilcoxonMethodIdentifier ?? "n/d")"
                    )
                } else if let reason = result.wilcoxonUnavailableReason {
                    print("Wilcoxon non disponibile: \(reason)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .correlate(projectURL, sourceRevisionIDs, first, second):
            let session = try await service.openProject(at: projectURL)
            let result = try await session.correlateMetrics(
                sourceRevisionIDs: sourceRevisionIDs,
                first: first.metric,
                second: second.metric
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Correlazione · generazione \(result.lineage.generation) · \(result.pairCount) documenti · \(result.firstMetricIdentifier) × \(result.secondMetricIdentifier)"
                )
                if let pearson = result.pearson {
                    print(
                        "Pearson\tr=\(pearson.coefficient)\tgdl=\(pearson.degreesOfFreedom)\tp=\(pearson.pValue)"
                    )
                } else if let reason = result.pearsonUnavailableReason {
                    print("Pearson non disponibile: \(reason)")
                }
                if let spearman = result.spearman {
                    print(
                        "Spearman\trho=\(spearman.coefficient)\tgdl=\(spearman.degreesOfFreedom)\tp=\(spearman.pValue)"
                    )
                } else if let reason = result.spearmanUnavailableReason {
                    print("Spearman non disponibile: \(reason)")
                }
                if let lower = result.pearsonLower, let upper = result.pearsonUpper {
                    print("Pearson IC Fisher-z=[\(lower), \(upper)]")
                }
                if let exact = result.spearmanExactPValue {
                    print("Spearman p esatto=\(exact)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .windowNetwork(projectURL, sourceRevisionIDs, flags, threshold, weighted):
            let window = try flags.options()
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeWindowNetwork(
                sourceRevisionIDs: sourceRevisionIDs,
                window: window,
                minimumLogDice: threshold,
                usesWeightedJointCount: weighted
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Rete a finestra · generazione \(result.lineage.generation) · \(result.summary.nodeCount) nodi · \(result.summary.edgeCount) archi · componenti \(result.summary.weakComponentCount) · comunità \(result.summary.communityCount.map(String.init) ?? "n/d")"
                )
                for node in result.nodes.prefix(20) {
                    print(
                        "\(node.term)\tPR=\(node.pageRank)\tautovettore=\(node.eigenvector)\tbetweenness pesata=\(node.weightedBetweenness)\tcomunità=\(node.community)"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .windowCollocations(projectURL, sourceRevisionIDs, flags):
            let options = try flags.options()
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeWindowCollocations(
                sourceRevisionIDs: sourceRevisionIDs,
                options: options
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Collocazioni a finestra · generazione \(result.lineage.generation) · \(result.pairs.count) coppie su \(result.distinctPairCount) osservate · universo \(result.universeSize) coppie ordinate · \(result.tokenCount) token"
                )
                for pair in result.pairs.prefix(20) {
                    print(
                        "\(pair.nodeTerm)\t\(pair.collocateTerm)\ta=\(pair.jointCount)\tlogDice=\(formattedOptional(pair.logDice))\tnpmi=\(formattedOptional(pair.npmi))"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .network(projectURL, sourceRevisionIDs, flags):
            let options = try flags.options()
            let session = try await service.openProject(at: projectURL)
            let result = try await session.analyzeLexicalNetwork(
                sourceRevisionIDs: sourceRevisionIDs,
                options: options
            )
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Rete lessicale · generazione \(result.lineage.generation) · \(result.nodes.count) nodi · \(result.edgeCount) archi"
                )
                for node in result.nodes.prefix(20) {
                    print(
                        "\(node.term)\tgrado=\(node.degree)\tPR=\(node.pageRank)\tbetweenness=\(node.betweenness)\tcloseness=\(node.harmonicCloseness)"
                    )
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        case let .agreement(projectURL, requestURL):
            let codingRequest: GlifiStudioCodingAgreementRequest = try readRequest(
                at: requestURL,
                operation: "analyze"
            )
            let session = try await service.openProject(at: projectURL)
            let result = try await session.assessCodingAgreement(codingRequest)
            await session.close()
            switch request.format {
            case .text:
                print(
                    "Accordo codificatori · generazione \(result.lineage.generation) · \(result.unitCount) unità · \(result.coderIdentifiers.count) codificatori"
                )
                if let cohen = result.cohen {
                    print(
                        "Cohen kappa=\(cohen.kappa) po=\(cohen.observedAgreement)"
                            + " pe=\(cohen.expectedAgreement)"
                    )
                } else if let reason = result.cohenUnavailableReason {
                    print("Cohen non disponibile: \(reason)")
                }
                if let alpha = result.krippendorff {
                    print("Krippendorff alpha=\(alpha.alpha)")
                } else if let reason = result.krippendorffUnavailableReason {
                    print("Krippendorff non disponibile: \(reason)")
                }
            case .json:
                try writeJSON(SuccessEnvelope(command: request.command.name, result: result))
            }
        }
    }

    private static func writeProjectResult(
        _ snapshot: GlifiStudioProjectSnapshot,
        request: CLIRequest,
        action: String
    ) throws {
        switch request.format {
        case .text:
            print(
                "Progetto \(action) · generazione \(snapshot.generation) · \(snapshot.sourceCount) fonti"
            )
        case .json:
            try writeJSON(
                SuccessEnvelope(
                    command: request.command.name,
                    result: ProjectResult(project: snapshot)
                )
            )
        }
    }

    private static func readQueryAST(at url: URL) throws -> Data {
        try Task.checkCancellation()
        let maximumByteCount = 65_536
        func failure(_ code: String, category: String = "invalidInput") -> GlifiStudioFailure {
            planRequestFailure(
                code: code,
                category: category,
                retryDisposition: category == "transientIO"
                    ? "transientBackoff"
                    : category == "insufficientResources"
                        ? "afterConditionsChange" : "afterCorrection",
                operation: "query"
            )
        }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            if errno == ELOOP {
                throw failure("query.ast-not-regular-file")
            }
            throw failure("query.ast-unreadable", category: "transientIO")
        }
        defer { close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw failure("query.ast-unreadable", category: "transientIO")
        }
        guard (metadata.st_mode & S_IFMT) == S_IFREG else {
            throw failure("query.ast-not-regular-file")
        }
        guard metadata.st_size >= 0, metadata.st_size <= maximumByteCount else {
            throw failure("query.byte-limit-exceeded", category: "insufficientResources")
        }
        var data = Data(count: maximumByteCount + 1)
        var count = 0
        try data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { throw CLIError.internalFailure }
            while count < buffer.count {
                try Task.checkCancellation()
                let readCount = read(descriptor, base.advanced(by: count), buffer.count - count)
                if readCount < 0 {
                    if errno == EINTR { continue }
                    throw failure("query.ast-unreadable", category: "transientIO")
                }
                if readCount == 0 { break }
                count += readCount
            }
        }
        guard count <= maximumByteCount else {
            throw failure("query.byte-limit-exceeded", category: "insufficientResources")
        }
        data.count = count
        return data
    }

    private static func readPlanRequest(
        at url: URL,
        operation: String = "plan"
    ) throws -> GlifiStudioAnalysisPlanRequest {
        let maximumByteCount = 1_048_576
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else {
                throw planRequestFailure(
                    code: "planner.request-not-regular-file",
                    category: "invalidInput",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
            guard let fileSize = values.fileSize, fileSize <= maximumByteCount else {
                throw planRequestFailure(
                    code: "planner.request-too-large",
                    category: "insufficientResources",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumByteCount else {
                throw planRequestFailure(
                    code: "planner.request-too-large",
                    category: "insufficientResources",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
            do {
                return try JSONDecoder().decode(GlifiStudioAnalysisPlanRequest.self, from: data)
            } catch {
                throw planRequestFailure(
                    code: "planner.request-invalid",
                    category: "invalidInput",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw planRequestFailure(
                code: "planner.request-unreadable",
                category: "transientIO",
                retryDisposition: "transientBackoff",
                operation: operation
            )
        }
    }

    private static func readRequest<Value: Decodable>(
        at url: URL,
        operation: String
    ) throws -> Value {
        let maximumByteCount = 1_048_576
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                let fileSize = values.fileSize,
                fileSize <= maximumByteCount
            else {
                throw planRequestFailure(
                    code: "request.invalid-file",
                    category: "invalidInput",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumByteCount else {
                throw planRequestFailure(
                    code: "request.too-large",
                    category: "insufficientResources",
                    retryDisposition: "afterCorrection",
                    operation: operation
                )
            }
            return try JSONDecoder().decode(Value.self, from: data)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw planRequestFailure(
                code: "request.invalid",
                category: "invalidInput",
                retryDisposition: "afterCorrection",
                operation: operation
            )
        }
    }

    private static func planRequestFailure(
        code: String,
        category: String,
        retryDisposition: String,
        operation: String = "plan"
    ) -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: code,
            category: category,
            operation: operation,
            retryDisposition: retryDisposition,
            retainedState: "lastCommittedGeneration",
            messageKey: "failure.\(code)"
        )
    }

    private static func writeFailure(_ failure: GlifiStudioFailure, command: String) {
        let arguments = Array(failure.arguments).sorted { $0.key < $1.key }.map {
            FailureArgument(key: $0.key, value: $0.value)
        }
        let envelope = FailureEnvelope(
            command: command,
            failure: FailureResult(
                code: failure.code,
                category: failure.category,
                operation: failure.operation,
                retryDisposition: failure.retryDisposition,
                retainedState: failure.retainedState,
                messageKey: failure.messageKey,
                arguments: arguments
            )
        )
        if let data = try? encodedJSON(envelope) {
            FileHandle.standardError.write(data)
        } else {
            writeStandardError("Errore interno non serializzabile\n")
        }
    }

    private static func writeJSON(_ value: some Encodable) throws {
        FileHandle.standardOutput.write(try encodedJSON(value))
    }

    private static func encodedJSON(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    private static func writeStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }

    private static func writeExecutionProgress(_ progress: GlifiStudioOperationProgress) {
        let total = progress.total.map(String.init) ?? "?"
        let step = progress.planStepIdentifier.map { " · \($0)" } ?? ""
        writeStandardError(
            "\(progress.phase) · \(progress.completed)/\(total) \(progress.unit)\(step)\n"
        )
    }

    private static func exitCode(for category: String) -> Int32 {
        switch category {
        case "invalidInput": 3
        case "unsupportedFormat": 4
        case "insufficientData": 5
        case "transientIO", "authorizationDenied": 6
        case "insufficientResources": 7
        case "cancelled": 8
        case "staleArtifact": 9
        case "incompatibleVersion": 10
        case "corruption": 11
        default: 70
        }
    }
}

private struct CLIRequest {
    static let usage = """
        Uso:
          glifi [--format text|json] [--no-progress] status
          glifi [--format text|json] [--no-progress] project create <progetto.glifi>
          glifi [--format text|json] [--no-progress] project info <progetto.glifi>
          glifi [--format text|json] [--no-progress] project validate <progetto.glifi>
          glifi [--format text|json] [--no-progress] import <progetto.glifi> <fonte.txt>...
          glifi [--format text|json] [--no-progress] query <progetto.glifi> (--text <query> | --ast <query.json>)
          glifi [--format text|json] [--no-progress] plan <progetto.glifi> --request <richiesta.json>
          glifi [--format text|json] [--no-progress] execute <progetto.glifi> --request <richiesta.json>
          glifi [--format text|json] [--no-progress] visualize <progetto.glifi> --request <richiesta.json>
          glifi [--format text|json] [--no-progress] investigation create <progetto.glifi> --request <richiesta.json>
          glifi [--format text|json] [--no-progress] investigation select <progetto.glifi> --request <richiesta.json>
          glifi [--format text|json] [--no-progress] investigation list <progetto.glifi>
          glifi [--format text|json] [--no-progress] export <progetto.glifi> --request <richiesta.json> --output <cartella>
          glifi [--format text|json] [--no-progress] analyze <progetto.glifi>
          glifi [--format text|json] [--no-progress] keyness <progetto.glifi> --target <source-revision-id,...> --reference <source-revision-id,...>
          glifi [--format text|json] [--no-progress] similarity <progetto.glifi> --target <source-revision-id,...> --reference <source-revision-id,...>
          glifi [--format text|json] [--no-progress] association <progetto.glifi> --sources <source-revision-id,...>
          glifi [--format text|json] [--no-progress] weighting <progetto.glifi> --sources <source-revision-id,...> [--tf TF-raw-v1|TF-binary-v1|TF-L1-v1|TF-max-v1|TF-augmented-v1|TF-sublinear-v1] [--idf IDF-none-v1|IDF-unsmoothed-v1|IDF-smooth-v1] [--norm RowNorm-none-v1|RowNorm-L1-v1|RowNorm-L2-v1]
          glifi [--format text|json] [--no-progress] ngrams <progetto.glifi> --sources <source-revision-id,...> --unit form|word|character|character-padded [--n <n>] [--stopwords <forma,...>] [--min-length <n>] [--min-count <n>] [--min-df <n>] [--max-df-proportion <x>] [--max-rows <n>]
          glifi [--format text|json] [--no-progress] diversity <progetto.glifi> --sources <source-revision-id,...> [--threshold <τ>]
          glifi [--format text|json] [--no-progress] bm25 <progetto.glifi> --sources <source-revision-id,...> --query <testo> [--k1 <x>] [--b <x>]
          glifi [--format text|json] [--no-progress] dispersion <progetto.glifi> --sources <source-revision-id,...> [--part <source-revision-id,...>]...
          glifi [--format text|json] [--no-progress] group-metric <progetto.glifi> --group <source-revision-id,...> --group <source-revision-id,...>... [--term <termine>] [--confidence <livello>] [--bootstrap <B>] [--permutations <m>] [--seed <n>] [--contrast <c1,c2,...>]...
          glifi [--format text|json] [--no-progress] collocations <progetto.glifi> --sources <source-revision-id,...> [--max-terms <n>] [--min-joint <n>] [--max-pairs <n>]
          glifi [--format text|json] [--no-progress] paired <progetto.glifi> --sources <source-revision-id,...> --x <length|term:parola> --y <length|term:parola>
          glifi [--format text|json] [--no-progress] posthoc <progetto.glifi> --group <source-revision-id,...> --group <source-revision-id,...> --group <source-revision-id,...>... [--term <termine>]
          glifi [--format text|json] [--no-progress] correlate <progetto.glifi> --sources <source-revision-id,...> --x <length|term:parola> --y <length|term:parola>
          glifi [--format text|json] [--no-progress] window-collocations <progetto.glifi> --sources <source-revision-id,...> [--left <n>] [--right <n>] [--cross-sentences true|false] [--self-pairs true|false] [--min-joint <n>] [--max-pairs <n>] [--weighting none|inverse-distance] [--positions <n>]
          glifi [--format text|json] [--no-progress] window-network <progetto.glifi> --sources <source-revision-id,...> [opzioni di window-collocations] [--min-logdice <x>] [--weighted-edges true|false]
          glifi [--format text|json] [--no-progress] network <progetto.glifi> --sources <source-revision-id,...> [--max-terms <n>] [--min-joint <n>] [--max-pairs <n>]
          glifi [--format text|json] [--no-progress] multivariate <progetto.glifi> --sources <source-revision-id,...> --method ca|pca|pca-scaled|lsa|nmf|hac|kmeans [--rank <k>] [--clusters <k>] [--linkage single|complete|average|ward] [--seed <n>] [--restarts <n>] [--max-terms <n>]
          glifi [--format text|json] [--no-progress] agreement <progetto.glifi> --request <codifica.json>
          glifi [--format text|json] [--no-progress] qualitative state <progetto.glifi>
          glifi [--format text|json] [--no-progress] qualitative append <progetto.glifi> --request <cambiamento.json>
          glifi [--format text|json] [--no-progress] qualitative agreement <progetto.glifi> --codebook <id> --revision <n> --coders <c1,c2,...>
          glifi [--format text|json] [--no-progress] qualitative segments <progetto.glifi> --source <source-revision-id>
          glifi [--format text|json] [--no-progress] qualitative passage <progetto.glifi> --source <source-revision-id> --sentences <primo>-<ultimo>|--characters <inizio>-<fine>|--bytes <inizio>-<fine>
        """ + "\n"

    let format: CLIOutputFormat
    let showsProgress: Bool
    let command: CLICommand

    init(arguments: [String]) throws {
        if arguments.isEmpty {
            format = .text
            showsProgress = true
            command = .status
            return
        }

        var remaining = arguments
        var resolvedFormat = CLIOutputFormat.text
        var resolvedShowsProgress = true
        var didResolveFormat = false
        var didResolveProgress = false
        while let option = remaining.first, option.hasPrefix("--") {
            switch option {
            case "--format":
                guard !didResolveFormat, remaining.count >= 2,
                    let candidate = CLIOutputFormat(rawValue: remaining[1])
                else {
                    throw CLIUsageError.invalidArguments
                }
                resolvedFormat = candidate
                didResolveFormat = true
                remaining.removeFirst(2)
            case "--no-progress":
                guard !didResolveProgress else {
                    throw CLIUsageError.invalidArguments
                }
                resolvedShowsProgress = false
                didResolveProgress = true
                remaining.removeFirst()
            default:
                throw CLIUsageError.invalidArguments
            }
        }

        if remaining == ["status"] {
            command = .status
        } else if remaining.count == 3, remaining[0] == "project", remaining[1] == "create" {
            command = .projectCreate(URL(fileURLWithPath: remaining[2]).standardizedFileURL)
        } else if remaining.count == 3, remaining[0] == "project", remaining[1] == "info" {
            command = .projectInfo(URL(fileURLWithPath: remaining[2]).standardizedFileURL)
        } else if remaining.count == 3,
            remaining[0] == "project",
            remaining[1] == "validate"
        {
            command = .projectValidate(URL(fileURLWithPath: remaining[2]).standardizedFileURL)
        } else if remaining.count >= 3, remaining.first == "import" {
            let projectURL = URL(fileURLWithPath: remaining[1]).standardizedFileURL
            let sourceURLs = remaining.dropFirst(2).map {
                URL(fileURLWithPath: $0).standardizedFileURL
            }
            guard
                sourceURLs.allSatisfy({
                    ["txt", "md", "markdown"].contains($0.pathExtension.lowercased())
                })
            else {
                throw CLIUsageError.invalidArguments
            }
            command = .importSources(projectURL, sourceURLs)
        } else if remaining.count == 4,
            remaining[0] == "query",
            ["--text", "--ast"].contains(remaining[2])
        {
            command = .query(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                remaining[2] == "--text"
                    ? .text(remaining[3])
                    : .ast(URL(fileURLWithPath: remaining[3]).standardizedFileURL)
            )
        } else if remaining.count == 2, remaining[0] == "analyze" {
            command = .analyze(URL(fileURLWithPath: remaining[1]).standardizedFileURL)
        } else if remaining.count == 4,
            remaining[0] == "plan",
            remaining[2] == "--request"
        {
            command = .plan(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                URL(fileURLWithPath: remaining[3]).standardizedFileURL
            )
        } else if remaining.count == 4,
            remaining[0] == "execute",
            remaining[2] == "--request"
        {
            command = .executePlan(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                URL(fileURLWithPath: remaining[3]).standardizedFileURL
            )
        } else if remaining.count == 4,
            remaining[0] == "visualize",
            remaining[2] == "--request"
        {
            command = .visualize(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                URL(fileURLWithPath: remaining[3]).standardizedFileURL
            )
        } else if remaining.count == 5,
            remaining[0] == "investigation",
            remaining[1] == "create",
            remaining[3] == "--request"
        {
            command = .investigationCreate(
                URL(fileURLWithPath: remaining[2]).standardizedFileURL,
                URL(fileURLWithPath: remaining[4]).standardizedFileURL
            )
        } else if remaining.count == 5,
            remaining[0] == "investigation",
            remaining[1] == "select",
            remaining[3] == "--request"
        {
            command = .investigationSelect(
                URL(fileURLWithPath: remaining[2]).standardizedFileURL,
                URL(fileURLWithPath: remaining[4]).standardizedFileURL
            )
        } else if remaining.count == 3,
            remaining[0] == "investigation",
            remaining[1] == "list"
        {
            command = .investigationList(
                URL(fileURLWithPath: remaining[2]).standardizedFileURL
            )
        } else if remaining.count == 6, remaining[0] == "export" {
            let values: (request: String, output: String)
            if remaining[2] == "--request", remaining[4] == "--output" {
                values = (remaining[3], remaining[5])
            } else if remaining[2] == "--output", remaining[4] == "--request" {
                values = (remaining[5], remaining[3])
            } else {
                throw CLIUsageError.invalidArguments
            }
            command = .exportInvestigation(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                URL(fileURLWithPath: values.request).standardizedFileURL,
                URL(fileURLWithPath: values.output).standardizedFileURL
            )
        } else if remaining.count == 6, remaining[0] == "keyness" {
            let groups: (target: String, reference: String)
            if remaining[2] == "--target", remaining[4] == "--reference" {
                groups = (remaining[3], remaining[5])
            } else if remaining[2] == "--reference", remaining[4] == "--target" {
                groups = (remaining[5], remaining[3])
            } else {
                throw CLIUsageError.invalidArguments
            }
            command = .keyness(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                try Self.identifiers(groups.target),
                try Self.identifiers(groups.reference)
            )
        } else if remaining.count == 6, remaining[0] == "similarity" {
            let groups: (target: String, reference: String)
            if remaining[2] == "--target", remaining[4] == "--reference" {
                groups = (remaining[3], remaining[5])
            } else if remaining[2] == "--reference", remaining[4] == "--target" {
                groups = (remaining[5], remaining[3])
            } else {
                throw CLIUsageError.invalidArguments
            }
            command = .similarity(
                URL(fileURLWithPath: remaining[1]).standardizedFileURL,
                try Self.identifiers(groups.target),
                try Self.identifiers(groups.reference)
            )
        } else if remaining.count >= 2, remaining[0] == "qualitative" {
            command = try Self.qualitativeCommand(remaining)
        } else if let derived = try Self.derivedCommand(remaining) {
            command = derived
        } else {
            throw CLIUsageError.invalidArguments
        }
        format = resolvedFormat
        showsProgress = resolvedShowsProgress
    }

    private static func qualitativeCommand(_ remaining: [String]) throws -> CLICommand {
        guard remaining.count >= 3 else { throw CLIUsageError.invalidArguments }
        let projectURL = URL(fileURLWithPath: remaining[2]).standardizedFileURL
        let flags = Array(remaining.dropFirst(3))
        switch remaining[1] {
        case "state" where flags.isEmpty:
            return .qualitativeState(projectURL)
        case "append" where flags.count == 2 && flags[0] == "--request":
            return .qualitativeAppend(
                projectURL, URL(fileURLWithPath: flags[1]).standardizedFileURL)
        case "segments" where flags.count == 2 && flags[0] == "--source":
            return .qualitativeSegments(projectURL, flags[1])
        case "passage" where flags.count == 4 && flags[0] == "--source":
            return .qualitativePassage(
                projectURL, flags[1], try Self.passageSelection(flags[2], flags[3]))
        case "agreement" where flags.count == 6:
            var values: [String: String] = [:]
            for index in stride(from: 0, to: 6, by: 2) { values[flags[index]] = flags[index + 1] }
            guard let codebook = values["--codebook"], let revisionText = values["--revision"],
                let revision = Int(revisionText), let coders = values["--coders"]
            else {
                throw CLIUsageError.invalidArguments
            }
            return .qualitativeAgreement(
                projectURL, codebook, revision, coders.split(separator: ",").map(String.init))
        default:
            throw CLIUsageError.invalidArguments
        }
    }

    private static func passageSelection(_ flag: String, _ value: String) throws
        -> GlifiStudioPassageSelection
    {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let first = Int(parts[0]), let second = Int(parts[1]) else {
            throw CLIUsageError.invalidArguments
        }
        switch flag {
        case "--sentences": return .sentences(first: first, last: second)
        case "--characters": return .characters(start: first, end: second)
        case "--bytes": return .bytes(start: first, end: second)
        default: throw CLIUsageError.invalidArguments
        }
    }

    private static func derivedCommand(_ remaining: [String]) throws -> CLICommand? {
        guard remaining.count >= 4,
            [
                "association", "dispersion", "group-metric", "collocations", "window-collocations",
                "window-network",
                "correlate", "paired", "posthoc", "network", "agreement", "multivariate",
                "weighting", "bm25", "diversity", "ngrams",
            ]
            .contains(remaining[0])
        else {
            return nil
        }
        let projectURL = URL(fileURLWithPath: remaining[1]).standardizedFileURL
        var values: [String: [String]] = [:]
        var index = 2
        while index < remaining.count {
            let flag = remaining[index]
            guard flag.hasPrefix("--"), index + 1 < remaining.count else {
                throw CLIUsageError.invalidArguments
            }
            values[flag, default: []].append(remaining[index + 1])
            index += 2
        }
        func single(_ flag: String) throws -> String? {
            guard let entries = values[flag] else { return nil }
            guard entries.count == 1 else { throw CLIUsageError.invalidArguments }
            return entries[0]
        }
        func integer(_ flag: String) throws -> Int? {
            guard let text = try single(flag) else { return nil }
            guard let value = Int(text) else { throw CLIUsageError.invalidArguments }
            return value
        }
        func allowed(_ flags: Set<String>) throws {
            guard Set(values.keys).isSubset(of: flags) else {
                throw CLIUsageError.invalidArguments
            }
        }
        func decimal(_ flag: String) throws -> Double? {
            guard let text = try single(flag) else { return nil }
            guard let value = Double(text) else { throw CLIUsageError.invalidArguments }
            return value
        }
        switch remaining[0] {
        case "weighting":
            try allowed(["--sources", "--tf", "--idf", "--norm"])
            guard let sources = try single("--sources") else {
                throw CLIUsageError.invalidArguments
            }
            return .weighting(
                projectURL,
                try Self.identifiers(sources),
                GlifiStudioTermWeightingScheme(
                    termFrequency: try single("--tf") ?? "TF-raw-v1",
                    inverseDocumentFrequency: try single("--idf") ?? "IDF-smooth-v1",
                    normalization: try single("--norm") ?? "RowNorm-none-v1"
                )
            )
        case "ngrams":
            try allowed([
                "--sources", "--unit", "--n", "--stopwords", "--min-length", "--min-count",
                "--min-df", "--max-df-proportion", "--max-rows",
            ])
            guard let sources = try single("--sources"), let unit = try single("--unit") else {
                throw CLIUsageError.invalidArguments
            }
            let stopwords = try single("--stopwords").map {
                $0.split(separator: ",").map(String.init)
            }
            return .ngrams(
                projectURL,
                try Self.identifiers(sources),
                GlifiStudioNGramUnit(kind: unit, n: try integer("--n") ?? 1),
                GlifiStudioTermFilter(
                    stopwords: stopwords ?? [],
                    minimumLength: try integer("--min-length") ?? 1,
                    minimumCount: try integer("--min-count") ?? 1,
                    minimumDocumentFrequency: try integer("--min-df") ?? 1,
                    maximumDocumentProportion: try decimal("--max-df-proportion") ?? 1
                ),
                try integer("--max-rows") ?? 1_000
            )
        case "diversity":
            try allowed(["--sources", "--threshold"])
            guard let sources = try single("--sources") else {
                throw CLIUsageError.invalidArguments
            }
            return .diversity(
                projectURL, try Self.identifiers(sources), try decimal("--threshold") ?? 0.72)
        case "bm25":
            try allowed(["--sources", "--query", "--k1", "--b"])
            guard let sources = try single("--sources"), let query = try single("--query") else {
                throw CLIUsageError.invalidArguments
            }
            return .bm25(
                projectURL, try Self.identifiers(sources), query,
                try decimal("--k1") ?? 1.2, try decimal("--b") ?? 0.75)
        case "association", "dispersion":
            try allowed(remaining[0] == "association" ? ["--sources"] : ["--sources", "--part"])
            guard let sources = try single("--sources") else {
                throw CLIUsageError.invalidArguments
            }
            let ids = try Self.identifiers(sources)
            if remaining[0] == "association" { return .association(projectURL, ids) }
            let parts = try values["--part"].map { try $0.map { try Self.identifiers($0) } }
            return .dispersion(projectURL, ids, parts)
        case "posthoc":
            try allowed(["--group", "--term"])
            guard let groups = values["--group"], groups.count >= 2 else {
                throw CLIUsageError.invalidArguments
            }
            return .postHoc(
                projectURL,
                try groups.map { try Self.identifiers($0) },
                try single("--term")
            )
        case "group-metric":
            try allowed([
                "--group", "--term", "--confidence", "--bootstrap", "--permutations", "--seed",
                "--contrast",
            ])
            guard let groups = values["--group"], groups.count >= 2 else {
                throw CLIUsageError.invalidArguments
            }
            let confidence = try single("--confidence").map { text -> Double in
                guard let value = Double(text) else { throw CLIUsageError.invalidArguments }
                return value
            }
            let seed = try single("--seed").map { text -> UInt64 in
                guard let value = UInt64(text) else { throw CLIUsageError.invalidArguments }
                return value
            }
            let contrasts = try (values["--contrast"] ?? []).map { text -> [Double] in
                let coefficients = text.split(separator: ",", omittingEmptySubsequences: false)
                    .map { Double($0) }
                guard !coefficients.isEmpty, coefficients.allSatisfy({ $0 != nil }) else {
                    throw CLIUsageError.invalidArguments
                }
                return coefficients.compactMap { $0 }
            }
            return .groupMetric(
                projectURL,
                try groups.map { try Self.identifiers($0) },
                try single("--term"),
                CLIGroupComparisonFlags(
                    confidenceLevel: confidence,
                    bootstrapResampleCount: try integer("--bootstrap"),
                    permutationMonteCarloCount: try integer("--permutations"),
                    resamplingSeed: seed,
                    contrasts: contrasts
                )
            )
        case "multivariate":
            try allowed([
                "--sources", "--method", "--rank", "--clusters", "--linkage", "--seed",
                "--restarts", "--max-terms",
            ])
            guard let sources = try single("--sources"), let name = try single("--method") else {
                throw CLIUsageError.invalidArguments
            }
            let seed =
                try single("--seed").map { text -> UInt64 in
                    guard let value = UInt64(text) else { throw CLIUsageError.invalidArguments }
                    return value
                } ?? 20_260_918
            let restarts = try integer("--restarts") ?? 3
            let method: GlifiStudioMultivariateMethod
            switch name {
            case "ca": method = .correspondence
            case "pca": method = .principalComponents(scaled: false)
            case "pca-scaled": method = .principalComponents(scaled: true)
            case "lsa": method = .latentSemantic(rank: try integer("--rank") ?? 2)
            case "nmf":
                method = .nonNegativeFactorization(
                    rank: try integer("--rank") ?? 2,
                    seed: seed,
                    restarts: restarts
                )
            case "hac":
                method = .hierarchical(
                    linkage: try single("--linkage") ?? "ward",
                    clusterCount: try integer("--clusters") ?? 2
                )
            case "kmeans":
                method = .kMeans(
                    clusterCount: try integer("--clusters") ?? 2,
                    seed: seed,
                    restarts: restarts
                )
            default:
                throw CLIUsageError.invalidArguments
            }
            return .multivariate(
                projectURL,
                try Self.identifiers(sources),
                method,
                try integer("--max-terms") ?? 50
            )
        case "paired":
            try allowed(["--sources", "--x", "--y"])
            guard let sources = try single("--sources"),
                let first = try single("--x"),
                let second = try single("--y")
            else {
                throw CLIUsageError.invalidArguments
            }
            return .paired(
                projectURL,
                try Self.identifiers(sources),
                try CLIMetricSelector(first),
                try CLIMetricSelector(second)
            )
        case "correlate":
            try allowed(["--sources", "--x", "--y"])
            guard let sources = try single("--sources"),
                let first = try single("--x"),
                let second = try single("--y")
            else {
                throw CLIUsageError.invalidArguments
            }
            return .correlate(
                projectURL,
                try Self.identifiers(sources),
                try CLIMetricSelector(first),
                try CLIMetricSelector(second)
            )
        case "window-collocations", "window-network":
            try allowed([
                "--sources", "--left", "--right", "--cross-sentences", "--self-pairs",
                "--min-joint", "--max-pairs", "--weighting", "--positions", "--min-logdice",
                "--weighted-edges",
            ])
            if remaining[0] == "window-collocations" {
                guard values["--min-logdice"] == nil, values["--weighted-edges"] == nil else {
                    throw CLIUsageError.invalidArguments
                }
            }
            guard let sources = try single("--sources") else {
                throw CLIUsageError.invalidArguments
            }
            func boolean(_ flag: String) throws -> Bool? {
                guard let text = try single(flag) else { return nil }
                guard text == "true" || text == "false" else {
                    throw CLIUsageError.invalidArguments
                }
                return text == "true"
            }
            let weighting = try single("--weighting")
            guard weighting == nil || weighting == "none" || weighting == "inverse-distance" else {
                throw CLIUsageError.invalidArguments
            }
            let flags = CLIWindowFlags(
                leftSpan: try integer("--left"),
                rightSpan: try integer("--right"),
                crossesSentences: try boolean("--cross-sentences"),
                includesSelfPairs: try boolean("--self-pairs"),
                minimumJointCount: try integer("--min-joint"),
                maximumPairCount: try integer("--max-pairs"),
                weightsByInverseDistance: weighting.map { $0 == "inverse-distance" },
                maximumPositionsPerPair: try integer("--positions")
            )
            if remaining[0] == "window-collocations" {
                return .windowCollocations(projectURL, try Self.identifiers(sources), flags)
            }
            let threshold = try single("--min-logdice").map { text -> Double in
                guard let value = Double(text), value.isFinite else {
                    throw CLIUsageError.invalidArguments
                }
                return value
            }
            return .windowNetwork(
                projectURL,
                try Self.identifiers(sources),
                flags,
                threshold,
                try boolean("--weighted-edges") ?? false
            )
        case "collocations", "network":
            try allowed(["--sources", "--max-terms", "--min-joint", "--max-pairs"])
            guard let sources = try single("--sources") else {
                throw CLIUsageError.invalidArguments
            }
            let ids = try Self.identifiers(sources)
            let flags = CLICooccurrenceFlags(
                maximumTermCount: try integer("--max-terms"),
                minimumJointCount: try integer("--min-joint"),
                maximumPairCount: try integer("--max-pairs")
            )
            return remaining[0] == "collocations"
                ? .collocations(projectURL, ids, flags) : .network(projectURL, ids, flags)
        default:
            try allowed(["--request"])
            guard let request = try single("--request") else {
                throw CLIUsageError.invalidArguments
            }
            return .agreement(projectURL, URL(fileURLWithPath: request).standardizedFileURL)
        }
    }

    private static func identifiers(_ value: String) throws -> [String] {
        let identifiers = value.split(separator: ",", omittingEmptySubsequences: false).map(
            String.init
        )
        guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else {
            throw CLIUsageError.invalidArguments
        }
        return identifiers
    }
}

private func formattedOptional(_ value: Double?) -> String {
    guard let value else { return "n/d" }
    return "\(value)"
}

private struct CLICooccurrenceFlags {
    let maximumTermCount: Int?
    let minimumJointCount: Int?
    let maximumPairCount: Int?

    func options() throws -> GlifiStudioCooccurrenceOptions {
        let standard = GlifiStudioCooccurrenceOptions.standard
        return try GlifiStudioCooccurrenceOptions(
            maximumTermCount: maximumTermCount ?? standard.maximumTermCount,
            minimumJointCount: minimumJointCount ?? standard.minimumJointCount,
            maximumPairCount: maximumPairCount ?? standard.maximumPairCount
        )
    }
}

private struct CLIGroupComparisonFlags {
    let confidenceLevel: Double?
    let bootstrapResampleCount: Int?
    let permutationMonteCarloCount: Int?
    let resamplingSeed: UInt64?
    let contrasts: [[Double]]

    func options() throws -> GlifiStudioGroupComparisonOptions {
        let standard = GlifiStudioGroupComparisonOptions.standard
        return try GlifiStudioGroupComparisonOptions(
            confidenceLevel: confidenceLevel ?? standard.confidenceLevel,
            bootstrapResampleCount: bootstrapResampleCount ?? standard.bootstrapResampleCount,
            permutationMonteCarloCount: permutationMonteCarloCount
                ?? standard.permutationMonteCarloCount,
            resamplingSeed: resamplingSeed ?? standard.resamplingSeed,
            contrasts: contrasts
        )
    }
}

private struct CLIMetricSelector {
    let metric: GlifiStudioDocumentMetric

    /// Accepts `length` or `term:<parola>`.
    init(_ text: String) throws {
        if text == "length" {
            metric = .lexicalTokenCount
        } else if text.hasPrefix("term:"), text.count > "term:".count {
            metric = .termRelativeFrequency(String(text.dropFirst("term:".count)))
        } else {
            throw CLIUsageError.invalidArguments
        }
    }
}

private struct CLIWindowFlags {
    let leftSpan: Int?
    let rightSpan: Int?
    let crossesSentences: Bool?
    let includesSelfPairs: Bool?
    let minimumJointCount: Int?
    let maximumPairCount: Int?
    let weightsByInverseDistance: Bool?
    let maximumPositionsPerPair: Int?

    func options() throws -> GlifiStudioWindowCooccurrenceOptions {
        let standard = GlifiStudioWindowCooccurrenceOptions.standard
        return try GlifiStudioWindowCooccurrenceOptions(
            leftSpan: leftSpan ?? standard.leftSpan,
            rightSpan: rightSpan ?? standard.rightSpan,
            crossesSentences: crossesSentences ?? standard.crossesSentences,
            includesSelfPairs: includesSelfPairs ?? standard.includesSelfPairs,
            minimumJointCount: minimumJointCount ?? standard.minimumJointCount,
            maximumPairCount: maximumPairCount ?? standard.maximumPairCount,
            weightsByInverseDistance: weightsByInverseDistance
                ?? standard.weightsByInverseDistance,
            maximumPositionsPerPair: maximumPositionsPerPair ?? standard.maximumPositionsPerPair
        )
    }
}

private enum CLIQueryInput {
    case text(String)
    case ast(URL)
}

private enum CLICommand {
    case status
    case projectCreate(URL)
    case projectInfo(URL)
    case projectValidate(URL)
    case importSources(URL, [URL])
    case query(URL, CLIQueryInput)
    case plan(URL, URL)
    case executePlan(URL, URL)
    case visualize(URL, URL)
    case investigationCreate(URL, URL)
    case investigationSelect(URL, URL)
    case investigationList(URL)
    case exportInvestigation(URL, URL, URL)
    case analyze(URL)
    case keyness(URL, [String], [String])
    case similarity(URL, [String], [String])
    case association(URL, [String])
    case weighting(URL, [String], GlifiStudioTermWeightingScheme)
    case bm25(URL, [String], String, Double, Double)
    case diversity(URL, [String], Double)
    case qualitativeState(URL)
    case qualitativeAppend(URL, URL)
    case qualitativeAgreement(URL, String, Int, [String])
    case qualitativeSegments(URL, String)
    case qualitativePassage(URL, String, GlifiStudioPassageSelection)
    case ngrams(URL, [String], GlifiStudioNGramUnit, GlifiStudioTermFilter, Int)
    case dispersion(URL, [String], [[String]]?)
    case groupMetric(URL, [[String]], String?, CLIGroupComparisonFlags)
    case paired(URL, [String], CLIMetricSelector, CLIMetricSelector)
    case multivariate(URL, [String], GlifiStudioMultivariateMethod, Int)
    case collocations(URL, [String], CLICooccurrenceFlags)
    case windowCollocations(URL, [String], CLIWindowFlags)
    case windowNetwork(URL, [String], CLIWindowFlags, Double?, Bool)
    case correlate(URL, [String], CLIMetricSelector, CLIMetricSelector)
    case postHoc(URL, [[String]], String?)
    case network(URL, [String], CLICooccurrenceFlags)
    case agreement(URL, URL)

    var name: String {
        switch self {
        case .status: "status"
        case .projectCreate: "project.create"
        case .projectInfo: "project.info"
        case .projectValidate: "project.validate"
        case .importSources: "import"
        case .query: "query"
        case .plan: "plan"
        case .executePlan: "execute"
        case .visualize: "visualize"
        case .investigationCreate: "investigation.create"
        case .investigationSelect: "investigation.select"
        case .investigationList: "investigation.list"
        case .exportInvestigation: "export"
        case .analyze: "analyze"
        case .keyness: "keyness"
        case .similarity: "similarity"
        case .association: "association"
        case .weighting: "weighting"
        case .bm25: "bm25"
        case .diversity: "diversity"
        case .qualitativeState: "qualitative.state"
        case .qualitativeAppend: "qualitative.append"
        case .qualitativeAgreement: "qualitative.agreement"
        case .qualitativeSegments: "qualitative.segments"
        case .qualitativePassage: "qualitative.passage"
        case .ngrams: "ngrams"
        case .dispersion: "dispersion"
        case .groupMetric: "group-metric"
        case .paired: "paired"
        case .multivariate: "multivariate"
        case .collocations: "collocations"
        case .windowCollocations: "window-collocations"
        case .windowNetwork: "window-network"
        case .correlate: "correlate"
        case .postHoc: "posthoc"
        case .network: "network"
        case .agreement: "agreement"
        }
    }
}

private enum CLIOutputFormat: String {
    case text
    case json
}

private enum CLIUsageError: Error {
    case invalidArguments
}

private enum CLIError {
    static let internalFailure = GlifiStudioFailure(
        code: "internal.unexpected",
        category: "invariantViolation",
        operation: "serviceStatus",
        retryDisposition: "never",
        retainedState: "validityUnknown",
        messageKey: "failure.internal.unexpected",
        arguments: [:]
    )
}

private struct SuccessEnvelope<Result: Encodable>: Encodable {
    let cliProtocolVersion = 1
    let command: String
    let outcome = "succeeded"
    let result: Result
}

private struct FailureEnvelope: Encodable {
    let cliProtocolVersion = 1
    let command: String
    let outcome = "failed"
    let failure: FailureResult
}

private struct FailureResult: Encodable {
    let code: String
    let category: String
    let operation: String
    let retryDisposition: String
    let retainedState: String
    let messageKey: String
    let arguments: [FailureArgument]
}

private struct FailureArgument: Encodable {
    let key: String
    let value: String
}

private struct StatusResult: Encodable {
    let status: String

    init(status: GlifiStudioStatus) {
        self.status = status.rawValue
    }
}

private struct ProjectResult: Encodable {
    let project: ProjectSnapshotResult

    init(project: GlifiStudioProjectSnapshot) {
        self.project = ProjectSnapshotResult(project)
    }
}

private struct ProjectValidationResult: Encodable {
    let project: ProjectSnapshotResult
    let status: String

    init(project: GlifiStudioProjectSnapshot, status: String) {
        self.project = ProjectSnapshotResult(project)
        self.status = status
    }
}

private struct ProjectSnapshotResult: Encodable {
    let projectID: String
    let generation: Int
    let sourceCount: Int
    let artifactCount: Int
    let investigationEventCount: Int
    let sources: [ProjectSourceResult]

    init(_ project: GlifiStudioProjectSnapshot) {
        projectID = project.projectID
        generation = project.generation
        sourceCount = project.sourceCount
        artifactCount = project.artifactCount
        investigationEventCount = project.investigationEventCount
        sources = project.sources.map(ProjectSourceResult.init)
    }
}

private struct ProjectSourceResult: Encodable {
    let sourceID: String
    let sourceRevisionID: String
    let format: String
    let contentDigest: String
    let byteCount: Int

    init(_ source: GlifiStudioProjectSource) {
        sourceID = source.sourceID
        sourceRevisionID = source.sourceRevisionID
        format = source.format.rawValue
        contentDigest = source.contentDigest
        byteCount = source.byteCount
    }
}

private struct ImportResult: Encodable {
    let project: ProjectSnapshotResult
    let importedSourceCount: Int
    let lastProfile: TextProfileResult

    init(
        project: GlifiStudioProjectSnapshot,
        importedSourceCount: Int,
        lastProfile: GlifiStudioTextProfile
    ) {
        self.project = ProjectSnapshotResult(project)
        self.importedSourceCount = importedSourceCount
        self.lastProfile = TextProfileResult(lastProfile)
    }
}

private struct TextProfileResult: Encodable {
    let contentDigest: String
    let characterCount: Int
    let sentenceCount: Int
    let lexicalTokenCount: Int
    let typeCount: Int

    init(_ profile: GlifiStudioTextProfile) {
        contentDigest = profile.contentDigest
        characterCount = profile.characterCount
        sentenceCount = profile.sentenceCount
        lexicalTokenCount = profile.lexicalTokenCount
        typeCount = profile.typeCount
    }
}

private struct QueryResult: Encodable {
    let projectID: String
    let generation: Int
    let queryDigest: String
    let matchedSourceCount: Int
    let matches: [QueryMatchResult]
    let isTruncated: Bool

    init(_ result: GlifiStudioProjectQueryResult) {
        projectID = result.projectID
        generation = result.generation
        queryDigest = result.queryDigest
        matchedSourceCount = result.matchedSourceCount
        matches = result.matches.map(QueryMatchResult.init)
        isTruncated = result.isTruncated
    }
}

private struct QueryMatchResult: Encodable {
    let sourceRevisionID: String
    let coordinateSpace: String
    let startUTF8: Int
    let endUTF8: Int
    let sourceRanges: [GlifiStudioUTF8Range]
    let leftContext: String
    let match: String
    let rightContext: String

    init(_ match: GlifiStudioQueryMatch) {
        sourceRevisionID = match.sourceRevisionID
        coordinateSpace = match.coordinateSpace
        startUTF8 = match.startUTF8
        endUTF8 = match.endUTF8
        sourceRanges = match.sourceRanges
        leftContext = match.leftContext
        self.match = match.match
        rightContext = match.rightContext
    }
}

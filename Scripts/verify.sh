#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
temporary_root="${TMPDIR:-/tmp}"

# Gli artefatti della singola esecuzione (progetti .glifi, export, richieste JSON) sono usa e
# getta e vengono rimossi all'uscita. Le cache di compilazione no: se ogni esecuzione ne creasse
# una nuova, ricompilerebbe tutto da zero e riscriverebbe decine di gigabyte a ogni giro.
temporary_build_directory="$(mktemp -d "${temporary_root%/}/GlifiStudioVerify.XXXXXX")"
source "$script_directory/build-cache.sh"
build_cache_directory="$(glifi_build_cache_directory)"

cleanup() {
    rm -rf "$temporary_build_directory"
    glifi_release_build_cache "$build_cache_directory"
}

trap cleanup EXIT

cd "$project_directory"

glifi_sweep_stale_temporaries "$temporary_root"
glifi_require_free_space "$temporary_root"
glifi_prepare_build_cache "$build_cache_directory"

Scripts/check-repository.py
Scripts/check-secrets.py
Scripts/check-toolchain.sh
Scripts/check-github-config.py
Scripts/check-naming.py
Scripts/check-docs.py
Scripts/check-compliance.py
Scripts/check-oracles.py
Scripts/check-fixtures.py
Scripts/check-architecture.sh
Scripts/check-localization.py
Scripts/check-failure-taxonomy.py
Scripts/check-failure-messages.py
Scripts/check-apple-baseline.py
Scripts/check-app-store-baseline.py
Scripts/check-swift-dialect.py
Scripts/format.sh --check
pdfa_output_directory="$temporary_build_directory/PDFA"
mkdir -p "$pdfa_output_directory"
GLIFI_ORACLE_PDF_DIRECTORY="$pdfa_output_directory" swift test \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM"
Scripts/check-pdfa.py --directory "$pdfa_output_directory"

Scripts/check-recovery-kill.sh "$build_cache_directory/SwiftPM"

cli_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI)"

if [[ "$cli_output" != "GlifiCore pronto" ]]; then
    print -u2 "Headless smoke test non superato: $cli_output"
    exit 1
fi

cli_json_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json status)"

expected_cli_json='{"cliProtocolVersion":1,"command":"status","outcome":"succeeded","result":{"status":"ready"}}'
if [[ "$cli_json_output" != "$expected_cli_json" ]]; then
    print -u2 "Headless JSON contract test non superato: $cli_json_output"
    exit 1
fi

cli_project_path="$temporary_build_directory/CLI-Smoke.glifi"
cli_create_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json project create "$cli_project_path")"
cli_import_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json import "$cli_project_path" \
    Fixtures/Persistence/v1/basic/source.txt)"
cli_markdown_import_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json import "$cli_project_path" \
    Fixtures/Markdown/v1/source.md)"
cli_validate_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json project validate "$cli_project_path")"
cli_query_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json query "$cli_project_path" --text "normalized:due")"
cli_markdown_query_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json query "$cli_project_path" --text "normalized:fonte")"
cli_binary_directory="$(swift build --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --show-bin-path)"
python3 Scripts/check-query-ast.py --executable "$cli_binary_directory/GlifiCLI" \
    --project "$cli_project_path"
cli_analysis_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json analyze "$cli_project_path")"
target_source_revision_id="$(python3 -c \
    'import json, sys; print(json.loads(sys.argv[1])["result"]["project"]["sources"][0]["sourceRevisionID"])' \
    "$cli_import_output")"
reference_source_revision_id="$(python3 -c \
    'import json, sys; sources=json.loads(sys.argv[1])["result"]["project"]["sources"]; print(next(source["sourceRevisionID"] for source in sources if source["sourceRevisionID"] != sys.argv[2]))' \
    "$cli_markdown_import_output" "$target_source_revision_id")"
cli_keyness_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json keyness "$cli_project_path" \
    --target "$target_source_revision_id" \
    --reference "$reference_source_revision_id")"
cli_plan_request_path="$temporary_build_directory/plan-request.json"
print -r -- "{\"intent\":\"compare.objects\",\"targetSourceRevisionIDs\":[\"$target_source_revision_id\"],\"referenceSourceRevisionIDs\":[\"$reference_source_revision_id\"]}" \
    > "$cli_plan_request_path"
cli_plan_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json plan "$cli_project_path" --request "$cli_plan_request_path")"
cli_plan_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json plan "$cli_project_path" --request "$cli_plan_request_path")"
cli_execution_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json --no-progress execute "$cli_project_path" \
    --request "$cli_plan_request_path")"
cli_execution_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --no-progress --format json execute "$cli_project_path" \
    --request "$cli_plan_request_path")"
cli_execution_progress_path="$temporary_build_directory/execution-progress.txt"
cli_execution_text_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI execute "$cli_project_path" \
    --request "$cli_plan_request_path" 2>"$cli_execution_progress_path")"
if [[ "$cli_execution_text_output" != Piano\ eseguito* ]]; then
    print -u2 "Output testuale execute inatteso: $cli_execution_text_output"
    exit 1
fi
if ! grep -Eq '^planning .* nodes$' "$cli_execution_progress_path" \
    || ! grep -Eq '^executing .* workUnits' "$cli_execution_progress_path" \
    || ! grep -Eq '^finalizing .* nodes$' "$cli_execution_progress_path"; then
    print -u2 "Stream di progresso CLI incompleto"
    exit 1
fi
interpretation_artifact_id="$(python3 -c \
    'import json,sys; print(json.loads(sys.argv[1])["result"]["interpretationArtifactID"])' \
    "$cli_execution_output")"
cli_investigation_create_request_path="$temporary_build_directory/investigation-create.json"
print -r -- "{\"schemaIdentifier\":\"studio.glifi.api.investigation-create-request\",\"schemaVersion\":1,\"question\":\"Quali differenze emergono?\",\"languageCode\":\"it\",\"interpretationArtifactID\":\"$interpretation_artifact_id\"}" \
    > "$cli_investigation_create_request_path"
cli_investigation_create_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json investigation create "$cli_project_path" \
    --request "$cli_investigation_create_request_path")"
investigation_id="$(python3 -c \
    'import json,sys; print(json.loads(sys.argv[1])["result"]["investigation"]["id"])' \
    "$cli_investigation_create_output")"
investigation_root_event_id="$(python3 -c \
    'import json,sys; print(json.loads(sys.argv[1])["result"]["investigation"]["headEventID"])' \
    "$cli_investigation_create_output")"
cli_investigation_select_a_request_path="$temporary_build_directory/investigation-select-a.json"
print -r -- "{\"schemaIdentifier\":\"studio.glifi.api.investigation-selection-request\",\"schemaVersion\":1,\"investigationID\":\"$investigation_id\",\"predecessorEventID\":\"$investigation_root_event_id\",\"selectedFindingIDs\":[],\"reasonIdentifier\":\"editorial.omit\"}" \
    > "$cli_investigation_select_a_request_path"
cli_investigation_select_a_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json investigation select "$cli_project_path" \
    --request "$cli_investigation_select_a_request_path")"
cli_investigation_select_b_request_path="$temporary_build_directory/investigation-select-b.json"
print -r -- "{\"schemaIdentifier\":\"studio.glifi.api.investigation-selection-request\",\"schemaVersion\":1,\"investigationID\":\"$investigation_id\",\"predecessorEventID\":\"$investigation_root_event_id\",\"selectedFindingIDs\":[],\"reasonIdentifier\":\"editorial.alternative\"}" \
    > "$cli_investigation_select_b_request_path"
cli_investigation_select_b_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json investigation select "$cli_project_path" \
    --request "$cli_investigation_select_b_request_path")"
investigation_export_head_id="$(python3 -c \
    'import json,sys; print(json.loads(sys.argv[1])["result"]["investigation"]["headEventID"])' \
    "$cli_investigation_select_b_output")"
cli_export_request_path="$temporary_build_directory/export-request.json"
print -r -- "{\"schemaIdentifier\":\"studio.glifi.api.scientific-export-request\",\"schemaVersion\":1,\"investigationHeadEventID\":\"$investigation_export_head_id\",\"formats\":[\"csv\",\"json\",\"markdown\",\"pdf\"],\"presentationLocaleIdentifier\":\"it-IT\",\"presentationTimeZoneIdentifier\":\"Europe/Rome\"}" \
    > "$cli_export_request_path"
cli_export_path="$temporary_build_directory/CLI-Export.glifiexport"
cli_export_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json export "$cli_project_path" \
    --request "$cli_export_request_path" --output "$cli_export_path")"
cli_investigation_list_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json investigation list "$cli_project_path")"
cli_oversized_plan_request_path="$temporary_build_directory/oversized-plan-request.json"
dd if=/dev/zero of="$cli_oversized_plan_request_path" bs=1048577 count=1 2>/dev/null
if cli_oversized_plan_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json plan "$cli_project_path" \
    --request "$cli_oversized_plan_request_path" 2>&1)"; then
    print -u2 "La richiesta planner oltre limite è stata accettata"
    exit 1
else
    cli_oversized_plan_status=$?
fi
if [[ "$cli_oversized_plan_status" -ne 7 ]]; then
    print -u2 "Exit status planner oltre limite inatteso: $cli_oversized_plan_status"
    exit 1
fi
cli_similarity_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json similarity "$cli_project_path" \
    --target "$target_source_revision_id" \
    --reference "$reference_source_revision_id")"
cli_similarity_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json similarity "$cli_project_path" \
    --target "$target_source_revision_id" \
    --reference "$reference_source_revision_id")"
cli_association_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json association "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id")"
cli_association_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json association "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id")"
cli_dispersion_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json dispersion "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id")"
cli_collocations_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json collocations "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id")"
cli_network_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json network "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id")"
cli_window_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json window-collocations "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --left 2 --right 2 --min-joint 1)"
cli_window_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json window-collocations "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --left 2 --right 2 --min-joint 1)"
if cli_correlate_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json correlate "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --x length --y term:casa 2>&1)"; then
    print -u2 "La correlazione su due sole fonti è stata accettata"
    exit 1
else
    cli_correlate_status=$?
fi
if [[ "$cli_correlate_status" -ne 5 ]]; then
    print -u2 "Exit status correlazione con dati insufficienti inatteso: $cli_correlate_status"
    exit 1
fi
if cli_posthoc_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json posthoc "$cli_project_path" \
    --group "$target_source_revision_id" --group "$reference_source_revision_id" 2>&1)"; then
    print -u2 "Il post-hoc su due soli gruppi è stato accettato"
    exit 1
else
    cli_posthoc_status=$?
fi
if [[ "$cli_posthoc_status" -ne 5 ]]; then
    print -u2 "Exit status post-hoc con gruppi insufficienti inatteso: $cli_posthoc_status"
    exit 1
fi
cli_paired_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json paired "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --x length --y length)"
cli_window_network_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json window-network "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --left 2 --right 2 --min-joint 1 --weighting inverse-distance --weighted-edges true)"
cli_multivariate_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json multivariate "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" --method ca)"
cli_hac_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json multivariate "$cli_project_path" \
    --sources "$target_source_revision_id,$reference_source_revision_id" \
    --method hac --linkage average --clusters 2)"
cli_group_metric_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json group-metric "$cli_project_path" \
    --group "$target_source_revision_id" --group "$reference_source_revision_id" \
    --seed 7 --bootstrap 500 --contrast "1,-1")"
cli_agreement_request_path="$temporary_build_directory/agreement-request.json"
print -r -- '{"coderIdentifiers":["c1","c2"],"units":[{"unitIdentifier":"u1","labels":["a","a"]},{"unitIdentifier":"u2","labels":["a","b"]},{"unitIdentifier":"u3","labels":["b","b"]},{"unitIdentifier":"u4","labels":["b","a"]}]}' \
    > "$cli_agreement_request_path"
cli_agreement_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json agreement "$cli_project_path" \
    --request "$cli_agreement_request_path")"
cli_agreement_reused_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json agreement "$cli_project_path" \
    --request "$cli_agreement_request_path")"
cli_final_info_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json project info "$cli_project_path")"

# RF-080: la CLI produce per ogni caso della fixture di query gli stessi intervalli e codici.
cli_query_parity_project="$temporary_build_directory/CLI-Query.glifi"
cli_query_parity_source="$temporary_build_directory/query-source.txt"
python3 -c 'import json,sys; open(sys.argv[2],"w").write(json.load(open(sys.argv[1]))["source"])' \
    Fixtures/Query/v1/cases.json "$cli_query_parity_source"
swift run --package-path Packages/GlifiCore --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json project create "$cli_query_parity_project" >/dev/null
swift run --package-path Packages/GlifiCore --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json import "$cli_query_parity_project" \
    "$cli_query_parity_source" >/dev/null
python3 - "$build_cache_directory/SwiftPM" "$cli_query_parity_project" <<'PY'
import json
import subprocess
import sys

scratch, project = sys.argv[1], sys.argv[2]
fixture = json.load(open("Fixtures/Query/v1/cases.json"))
digests = set()
for case in fixture["cases"]:
    run = subprocess.run(
        ["swift", "run", "--package-path", "Packages/GlifiCore", "--scratch-path", scratch,
         "--skip-build", "GlifiCLI", "--format", "json", "query", project, "--text", case["query"]],
        capture_output=True, text=True,
    )
    if case["outcome"] == "succeeded":
        assert run.returncode == 0, (case["id"], run.stderr)
        result = json.loads(run.stdout)["result"]
        ranges = [[m["startUTF8"], m["endUTF8"]] for m in result["matches"]]
        assert ranges == [[m["start"], m["end"]] for m in case["matches"]], case["id"]
        digests.add(result["queryDigest"])
    else:
        assert run.returncode != 0, case["id"]
        failure = json.loads(run.stderr)["failure"]
        assert failure["code"] == case["failureCode"], (case["id"], failure["code"])
assert len(digests) == sum(1 for c in fixture["cases"] if c["outcome"] == "succeeded")
# RQ-046: l'envelope di errore non riporta la query né il path del progetto.
canary = "ZQXCANARY42"
run = subprocess.run(
    ["swift", "run", "--package-path", "Packages/GlifiCore", "--scratch-path", scratch,
     "--skip-build", "GlifiCLI", "--format", "json", "query", project, "--text", canary + ":casa"],
    capture_output=True, text=True,
)
assert run.returncode != 0
assert canary not in run.stderr and project not in run.stderr, run.stderr
PY

# Contratto di `visualize` su un progetto separato, per non alterare i conteggi del progetto smoke.
cli_visual_project_path="$temporary_build_directory/CLI-Visual.glifi"
swift run --package-path Packages/GlifiCore --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json project create "$cli_visual_project_path" >/dev/null
cli_visual_import_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json import "$cli_visual_project_path" \
    Fixtures/Persistence/v1/basic/source.txt Fixtures/Markdown/v1/source.md)"
cli_visual_sources="$(python3 -c \
    'import json,sys; print(",".join(s["sourceRevisionID"] for s in json.loads(sys.argv[1])["result"]["project"]["sources"]))' \
    "$cli_visual_import_output")"
cli_weighting_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json weighting "$cli_visual_project_path" --sources "$cli_visual_sources" \
    --tf TF-sublinear-v1 --idf IDF-smooth-v1 --norm RowNorm-L2-v1)"
cli_bm25_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json bm25 "$cli_visual_project_path" --sources "$cli_visual_sources" \
    --query "due fonte ignoto")"
cli_diversity_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json diversity "$cli_visual_project_path" --sources "$cli_visual_sources")"
# ADR-0027: storia qualitativa dalla CLI.
cli_codebook_request="$temporary_build_directory/codebook.json"
print -r -- '{"codebookRevised":{"codebookID":"temi","revision":1,"categories":[{"categoryID":"fonte","label":"Fonte","definition":"Riferimenti alla fonte."}]}}' \
    > "$cli_codebook_request"
swift run --package-path Packages/GlifiCore --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json qualitative append "$cli_visual_project_path" \
    --request "$cli_codebook_request" >/dev/null
cli_qualitative_state="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative state "$cli_visual_project_path")"
set +e
cli_qualitative_repeat="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative append "$cli_visual_project_path" \
    --request "$cli_codebook_request" 2>&1 >/dev/null)"
set -e
python3 - "$cli_qualitative_state" "$cli_qualitative_repeat" <<'PY'
import json
import sys

state = json.loads(sys.argv[1])
assert state["command"] == "qualitative.state"
codebooks = state["result"]["codebooks"]
assert [c["codebookID"] for c in codebooks] == ["temi"]
assert len(codebooks[0]["revisions"]) == 1
assert state["result"]["headEventID"].startswith("sha256:")
failure = json.loads(sys.argv[2])["failure"]
assert failure["code"] == "qualitative.revision-not-consecutive", failure
PY
# GS-UX-001-16: selezione strutturata del passaggio dalla CLI.
cli_coding_source="${cli_visual_sources%%,*}"
cli_segments_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative segments "$cli_visual_project_path" \
    --source "$cli_coding_source")"
cli_first_segment_bytes="$(python3 -c \
    'import json,sys; s=json.loads(sys.argv[1])["result"][0]; print("%d-%d" % (s["startUTF8"], s["endUTF8"]))' \
    "$cli_segments_output")"
cli_sentence_passage="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative passage "$cli_visual_project_path" \
    --source "$cli_coding_source" --sentences 0-0)"
cli_bytes_passage="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative passage "$cli_visual_project_path" \
    --source "$cli_coding_source" --bytes "$cli_first_segment_bytes")"
set +e
cli_passage_failure="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json qualitative passage "$cli_visual_project_path" \
    --source "$cli_coding_source" --characters 5-5 2>&1 >/dev/null)"
set -e
python3 - "$cli_segments_output" "$cli_sentence_passage" "$cli_bytes_passage" \
    "$cli_passage_failure" <<'PY'
import json
import sys

segments = json.loads(sys.argv[1])
assert segments["command"] == "qualitative.segments"
rows = segments["result"]
assert rows, rows
assert [row["startUTF8"] for row in rows] == sorted(row["startUTF8"] for row in rows)
assert all(row["text"].strip() for row in rows)
# La selezione per frase e quella per byte descrivono lo stesso passaggio.
sentence = json.loads(sys.argv[2])["result"]
bytes_passage = json.loads(sys.argv[3])["result"]
assert sentence == rows[0], (sentence, rows[0])
assert bytes_passage == rows[0], (bytes_passage, rows[0])
# Un intervallo vuoto è rifiutato senza modificare nulla.
failure = json.loads(sys.argv[4])["failure"]
assert failure["code"] == "qualitative.invalid-selection", failure
assert failure["retainedState"] == "unchanged", failure
PY
# ADR-0028: invalidazione selettiva replicata dalla CLI sulla fixture di persistenza v2.
cli_selective_case="Fixtures/Persistence/v2/selective-invalidation"
cli_selective_project="$temporary_build_directory/CLI-Selective.glifi"
swift run --package-path Packages/GlifiCore --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build GlifiCLI --format json project create "$cli_selective_project" >/dev/null
cli_selective_import="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json import "$cli_selective_project" \
    "$cli_selective_case/alfa.txt" "$cli_selective_case/beta.txt")"
cli_selective_sources="$(python3 -c \
    'import json,sys; print(",".join(s["sourceRevisionID"] for s in json.loads(sys.argv[1])["result"]["project"]["sources"]))' \
    "$cli_selective_import")"
cli_selective_first="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json association "$cli_selective_project" \
    --sources "$cli_selective_sources")"
cli_selective_unrelated="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json import "$cli_selective_project" \
    "$cli_selective_case/estranea.txt")"
cli_selective_reused="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json association "$cli_selective_project" \
    --sources "$cli_selective_sources")"
python3 - "$cli_selective_import" "$cli_selective_first" "$cli_selective_unrelated" \
    "$cli_selective_reused" "$cli_selective_case/case.json" <<'PY'
import json
import sys

expected = json.load(open(sys.argv[5], encoding="utf-8"))["expected"]
imported = json.loads(sys.argv[1])["result"]["project"]
first = json.loads(sys.argv[2])["result"]["lineage"]
unrelated = json.loads(sys.argv[3])["result"]["project"]
reused = json.loads(sys.argv[4])["result"]["lineage"]

assert imported["generation"] == expected["generationAfterImports"], imported["generation"]
assert first["generation"] == expected["generationAfterAnalysis"], first["generation"]
# L'importazione di una fonte estranea non tocca le revisioni dichiarate dall'analisi.
assert unrelated["generation"] == expected["generationAfterUnrelatedImport"], unrelated
assert unrelated["artifactCount"] == expected["artifactCountAfterUnrelatedImport"], unrelated
# Ripetere l'analisi restituisce lo stesso Artifact, senza nuova generazione.
reuse_expected = expected["artifactReusedAfterUnrelatedImport"]
assert (reused["artifactID"] == first["artifactID"]) is reuse_expected, (reused, first)
assert reused["analysisNodeID"] == first["analysisNodeID"], (reused, first)
assert reused["generation"] == unrelated["generation"], (reused, unrelated)
PY

cli_ngrams_output="$(swift run --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" --skip-build \
    GlifiCLI --format json ngrams "$cli_visual_project_path" --sources "$cli_visual_sources" \
    --unit word --n 2 --stopwords UNO)"
python3 - "$cli_ngrams_output" <<'PY'
import json
import sys

ngrams = json.loads(sys.argv[1])
assert ngrams["command"] == "ngrams"
result = ngrams["result"]
assert result["unitIdentifier"] == "WordNGram-v1" and result["n"] == 2
assert result["filter"]["stopwords"] == ["uno"]
assert result["exclusions"]["stopwords"] >= 1
assert all("uno" not in row["components"] for row in result["rows"])
assert all(abs(r["relativeFrequency"] - r["count"] / result["denominator"]) < 1e-15 for r in result["rows"])
PY
python3 - "$cli_diversity_output" <<'PY'
import json
import sys

diversity = json.loads(sys.argv[1])
assert diversity["command"] == "diversity"
result = diversity["result"]
assert result["methodIdentifier"] == "MTLD-bidirectional-v1"
assert result["threshold"] == 0.72
assert len(result["documents"]) == 2
for document in result["documents"]:
    value = document["mtld"]["value"]
    assert value == "+Infinity" or value > 0
PY
python3 - "$cli_weighting_output" "$cli_bm25_output" <<'PY'
import json
import math
import sys

weighting = json.loads(sys.argv[1])
assert weighting["command"] == "weighting"
result = weighting["result"]
assert result["combinedIdentifier"] == "TFIDF-v1"
assert result["scheme"]["normalization"] == "RowNorm-L2-v1"
norms = {}
for cell in result["cells"]:
    norms[cell["rowIndex"]] = norms.get(cell["rowIndex"], 0) + cell["weight"] ** 2
assert all(abs(math.sqrt(value) - 1) < 1e-12 for value in norms.values())
bm25 = json.loads(sys.argv[2])
assert bm25["command"] == "bm25"
ranking = bm25["result"]["ranking"]
assert bm25["result"]["methodIdentifier"] == "BM25-v1"
assert [entry["score"] for entry in ranking] == sorted((e["score"] for e in ranking), reverse=True)
assert any(not term["isInVocabulary"] for term in bm25["result"]["queryTerms"])
assert all(entry["score"] > 0 for entry in ranking)
PY
cli_visual_request_path="$temporary_build_directory/visual-request.json"
print -r -- '{"intent":"explore.relationships"}' > "$cli_visual_request_path"
cli_visualize_output="$(swift run \
    --package-path Packages/GlifiCore \
    --scratch-path "$build_cache_directory/SwiftPM" \
    --skip-build \
    GlifiCLI --format json visualize "$cli_visual_project_path" \
    --request "$cli_visual_request_path")"
python3 - "$cli_visualize_output" <<'PY'
import json
import sys

envelope = json.loads(sys.argv[1])
assert envelope["command"] == "visualize"
assert envelope["outcome"] == "succeeded"
views = envelope["result"]
families = {view["family"] for view in views}
assert {"collocation-table", "network"} <= families, families
for view in views:
    assert view["specificationIdentifier"].startswith("visual-spec.")
    assert view["artifactID"].startswith("artifact:")
    assert view["visibleObservationCount"] <= view["totalObservationCount"]
    assert len(view["table"]["rows"]) == view["visibleObservationCount"] or view["family"] in {
        "factor-plot",
        "dendrogram",
    }
    points = [mark["id"] for mark in view["marks"] if mark["kind"] == "point"]
    if view["family"] in {"factor-plot", "network"}:
        assert points == [row["id"] for row in view["table"]["rows"]]
PY

python3 - "$cli_create_output" "$cli_import_output" "$cli_markdown_import_output" \
    "$cli_validate_output" "$cli_query_output" "$cli_markdown_query_output" \
    "$cli_analysis_output" "$cli_keyness_output" "$cli_plan_output" \
    "$cli_plan_reused_output" "$cli_execution_output" \
    "$cli_execution_reused_output" "$cli_oversized_plan_output" \
    "$cli_investigation_create_output" "$cli_investigation_select_a_output" \
    "$cli_investigation_select_b_output" "$cli_export_output" \
    "$cli_investigation_list_output" "$cli_similarity_output" \
    "$cli_similarity_reused_output" "$cli_association_output" \
    "$cli_association_reused_output" "$cli_dispersion_output" \
    "$cli_collocations_output" "$cli_network_output" \
    "$cli_window_output" "$cli_window_reused_output" \
    "$cli_correlate_output" "$cli_posthoc_output" "$cli_paired_output" "$cli_window_network_output" \
    "$cli_multivariate_output" "$cli_hac_output" \
    "$cli_group_metric_output" "$cli_agreement_output" \
    "$cli_agreement_reused_output" "$cli_final_info_output" \
    "$cli_export_path" "Fixtures/Persistence/v1/basic/case.json" <<'PY'
import hashlib
import json
import pathlib
import sys

(
    created,
    imported,
    markdown_imported,
    validated,
    queried,
    markdown_queried,
    analyzed,
    keyness,
    planned,
    reused_plan,
    executed,
    reused_execution,
    oversized_plan,
    investigation_created,
    investigation_selection_a,
    investigation_selection_b,
    exported,
    investigation_list,
    similarity,
    similarity_reused,
    association,
    association_reused,
    dispersion,
    collocations,
    network,
    window,
    window_reused,
    correlate,
    posthoc,
    paired,
    window_network,
    multivariate,
    hac,
    group_metric,
    agreement,
    agreement_reused,
    final_info,
) = (json.loads(value) for value in sys.argv[1:-2])
export_path = pathlib.Path(sys.argv[-2])
# Le attese della fixture v1 sono lette dal caso, non duplicate qui.
basic_case = json.load(open(sys.argv[-1], encoding="utf-8"))["expected"]
assert created["command"] == "project.create"
assert created["result"]["project"]["generation"] == 0
assert created["result"]["project"]["artifactCount"] == 0
assert imported["command"] == "import"
assert imported["result"]["project"]["generation"] == basic_case["generation"]
assert imported["result"]["project"]["sourceCount"] == basic_case["sourceCount"]
assert imported["result"]["project"]["artifactCount"] == 0
assert len(imported["result"]["project"]["sources"]) == basic_case["sourceCount"]
assert imported["result"]["project"]["sources"][0]["format"] == "plainText"
assert imported["result"]["project"]["sources"][0]["contentDigest"].startswith("sha256:")
assert imported["result"]["lastProfile"]["lexicalTokenCount"] == basic_case["lexicalTokenCount"]
assert imported["result"]["lastProfile"]["typeCount"] == basic_case["typeCount"]
assert markdown_imported["command"] == "import"
assert markdown_imported["result"]["project"]["generation"] == 2
assert markdown_imported["result"]["project"]["sourceCount"] == 2
assert markdown_imported["result"]["project"]["artifactCount"] == 0
assert markdown_imported["result"]["lastProfile"]["lexicalTokenCount"] == 5
assert validated["command"] == "project.validate"
assert validated["result"]["status"] == "valid"
assert validated["result"]["project"] == markdown_imported["result"]["project"]
assert queried["command"] == "query"
assert queried["outcome"] == "succeeded"
assert queried["result"]["generation"] == 2
assert queried["result"]["matchedSourceCount"] == 1
assert queried["result"]["isTruncated"] is False
assert queried["result"]["queryDigest"].startswith("sha256:")
assert [
    (match["startUTF8"], match["endUTF8"], match["match"])
    for match in queried["result"]["matches"]
] == [(4, 7, "due"), (8, 11, "due")]
assert markdown_queried["command"] == "query"
assert markdown_queried["result"]["generation"] == 2
assert markdown_queried["result"]["matchedSourceCount"] == 1
assert len(markdown_queried["result"]["matches"]) == 1
markdown_match = markdown_queried["result"]["matches"][0]
assert markdown_match["coordinateSpace"] == "extractedUTF8"
assert (markdown_match["startUTF8"], markdown_match["endUTF8"]) == (14, 19)
assert markdown_match["sourceRanges"] == [{"start": 64, "end": 69}]
assert analyzed["command"] == "analyze"
assert analyzed["outcome"] == "succeeded"
assert analyzed["result"]["sourceGeneration"] == 2
assert analyzed["result"]["generation"] == 3
assert analyzed["result"]["artifactID"].startswith("artifact:sha256:")
assert analyzed["result"]["analysisNodeID"].startswith("analysis-node:sha256:")
assert analyzed["result"]["analysisIdentifier"] == "corpus-profile-it-v1"
assert analyzed["result"]["corpusDigest"].startswith("sha256:")
assert analyzed["result"]["tokenizationContractIdentifier"] == "it-token-v1"
assert analyzed["result"]["documentCount"] == 2
assert analyzed["result"]["lexicalTokenCount"] == 8
assert analyzed["result"]["typeCount"] == 7
assert analyzed["result"]["terms"][0]["term"] == "due"
assert analyzed["result"]["terms"][0]["frequency"] == 2
assert len(analyzed["result"]["matrix"]["cells"]) == 7
assert analyzed["result"]["matrix"]["tfidfIdentifier"] == "TFIDF-v1"
assert keyness["command"] == "keyness"
assert keyness["outcome"] == "succeeded"
assert keyness["result"]["sourceGeneration"] == 3
assert keyness["result"]["generation"] == 6
assert keyness["result"]["artifactID"].startswith("artifact:sha256:")
assert keyness["result"]["analysisNodeID"].startswith("analysis-node:sha256:")
assert keyness["result"]["comparisonIdentifier"] == "keyness-gtest-fisher-ha-ci-bh-v2"
assert keyness["result"]["testSelectionIdentifier"] == "FisherSelection-min-expected-5-v1"
assert keyness["result"]["confidenceLevel"] == 0.95
for term in keyness["result"]["terms"]:
    expected_test = "FisherExactTwoSided-v1" if term["minimumExpectedCount"] < 5 else "GTest-v1"
    assert term["selectedTestIdentifier"] == expected_test
    assert term["log2RatioLower"] <= term["log2RatioHaldaneAnscombe"] <= term["log2RatioUpper"]
    assert term["oddsRatioLower"] <= term["oddsRatioHaldaneAnscombe"] <= term["oddsRatioUpper"]
assert keyness["result"]["comparisonDigest"].startswith("sha256:")
assert keyness["result"]["testIdentifier"] == "GTest-v1"
assert keyness["result"]["correctionIdentifier"] == "BenjaminiHochberg-v1"
assert keyness["result"]["targetTokenCount"] == 3
assert keyness["result"]["referenceTokenCount"] == 5
assert len(keyness["result"]["terms"]) == 7
assert all(0 <= term["qValue"] <= 1 for term in keyness["result"]["terms"])
assert any(term["hasLowExpectedCount"] for term in keyness["result"]["terms"])
assert planned["command"] == "plan"
assert planned["outcome"] == "succeeded"
assert planned["result"]["sourceGeneration"] == 6
assert planned["result"]["generation"] == 7
assert planned["result"]["artifactID"].startswith("artifact:sha256:")
assert planned["result"]["analysisNodeID"].startswith("analysis-node:sha256:")
assert planned["result"]["plan"]["plannerIdentifier"] == "planner-v2"
assert planned["result"]["plan"]["capabilityCatalogIdentifier"] == "capability-catalog-v2"
assert planned["result"]["plan"]["intent"] == "compare.objects"
assert planned["result"]["plan"]["status"] == "readyWithCaveats"
assert planned["result"]["plan"]["collectionProfile"]["sourceCount"] == 2
# planner-v2 (ADR-0025): tre passi MVP più similarità e confronto di gruppo.
assert [step["role"] for step in planned["result"]["plan"]["steps"]] == [
    "target",
    "reference",
    "comparison",
    "comparison",
    "comparison",
]
assert [step["operation"] for step in planned["result"]["plan"]["steps"]][3:] == [
    "compareSimilarity",
    "compareGroupMetric",
]
assert [decision["isIncluded"] for decision in planned["result"]["plan"]["decisions"]][:2] == [
    True,
    True,
]
assert reused_plan["result"]["sourceGeneration"] == 7
assert reused_plan["result"]["generation"] == 7
assert reused_plan["result"]["artifactID"] == planned["result"]["artifactID"]
assert executed["command"] == "execute"
assert executed["outcome"] == "succeeded"
assert executed["result"]["sourceGeneration"] == 7
assert executed["result"]["generation"] == 10
assert executed["result"]["planArtifactID"] == planned["result"]["artifactID"]
assert executed["result"]["planAnalysisNodeID"] == planned["result"]["analysisNodeID"]
assert executed["result"]["interpretationArtifactID"].startswith("artifact:sha256:")
assert executed["result"]["interpretationAnalysisNodeID"].startswith(
    "analysis-node:sha256:"
)
assert executed["result"]["planStatus"] == "readyWithCaveats"
assert executed["result"]["terminalState"] == "completedWithCaveats"
assert executed["result"]["completedWorkUnits"] == executed["result"]["estimatedWorkUnits"]
assert [artifact["role"] for artifact in executed["result"]["artifacts"]] == [
    "target",
    "reference",
    "comparison",
    "comparison",
    "comparison",
]
assert all(
    artifact["artifactID"].startswith("artifact:sha256:")
    for artifact in executed["result"]["artifacts"]
)
interpretation = executed["result"]["interpretation"]
assert interpretation["ruleCatalogIdentifier"] == "interpretation-rules-mvp-v1"
assert interpretation["rankingIdentifier"] == "editorial-rank-v1"
assert interpretation["planArtifactID"] == planned["result"]["artifactID"]
assert interpretation["planAnalysisNodeID"] == planned["result"]["analysisNodeID"]
assert set(interpretation["sourceArtifactIDs"]) == {
    artifact["artifactID"] for artifact in executed["result"]["artifacts"]
}
# Keyness non ha termini eleggibili; la similarità produce un finding secondo ADR-0026.
assert [finding["familyIdentifier"] for finding in interpretation["findings"]] == [
    "finding-family.similarity.v1"
]
assert interpretation["findings"][0]["assessment"]["policyIdentifier"] == (
    "support-policy.similarity-descriptive-v1"
)
assert len(interpretation["evidence"]) == 1
assert interpretation.get("insufficientEvidence") is None
assert reused_execution["result"]["sourceGeneration"] == 10
assert reused_execution["result"]["generation"] == 10
assert reused_execution["result"]["artifacts"] == executed["result"]["artifacts"]
assert (
    reused_execution["result"]["interpretationArtifactID"]
    == executed["result"]["interpretationArtifactID"]
)
assert reused_execution["result"]["interpretation"] == interpretation
assert investigation_created["command"] == "investigation.create"
assert investigation_created["result"]["generation"] == 11
created_investigation = investigation_created["result"]["investigation"]
assert created_investigation["languageCode"] == "it"
assert created_investigation["question"] == "Quali differenze emergono?"
assert created_investigation["interpretationArtifactID"] == executed["result"]["interpretationArtifactID"]
assert created_investigation["availableFindingIDs"] == [
    finding["id"] for finding in interpretation["findings"]
]
assert set(created_investigation["selectedFindingIDs"]) <= set(
    created_investigation["availableFindingIDs"]
)
assert len(created_investigation["eventIDs"]) == 1
assert investigation_selection_a["command"] == "investigation.select"
assert investigation_selection_a["result"]["generation"] == 12
assert investigation_selection_b["command"] == "investigation.select"
assert investigation_selection_b["result"]["generation"] == 13
assert investigation_selection_a["result"]["investigation"]["id"] == created_investigation["id"]
assert investigation_selection_b["result"]["investigation"]["id"] == created_investigation["id"]
assert investigation_selection_a["result"]["investigation"]["headEventID"] != investigation_selection_b["result"]["investigation"]["headEventID"]
assert exported["command"] == "export"
assert exported["outcome"] == "succeeded"
assert exported["result"]["reportRevisionID"].startswith("report-revision:sha256:")
assert exported["result"]["manifestDigest"].startswith("sha256:")
assert exported["result"]["fileCount"] == 5
manifest_bytes = (export_path / "export-manifest.json").read_bytes()
manifest = json.loads(manifest_bytes)
assert manifest["schema"] == "studio.glifi.export-manifest"
assert manifest["schemaVersion"] == 1
assert manifest["selection"]["investigationHeadEventID"] == investigation_selection_b["result"]["investigation"]["headEventID"]
assert manifest["selection"]["reportRevisionID"] == exported["result"]["reportRevisionID"]
assert [item["path"] for item in manifest["files"]] == [
    "evidence.csv",
    "findings.csv",
    "report.json",
    "report.md",
    "report.pdf",
]
assert str(export_path) not in manifest_bytes.decode("utf-8")
for item in manifest["files"]:
    data = (export_path / item["path"]).read_bytes()
    assert len(data) == item["byteCount"]
    assert "sha256:" + hashlib.sha256(data).hexdigest() == item["sha256"]
assert (export_path / "report.pdf").read_bytes().startswith(b"%PDF-")
assert (export_path / "findings.csv").read_bytes().startswith(
    b'"ordinal","finding_id","message_key"'
)
assert b"\r\n" in (export_path / "evidence.csv").read_bytes()
assert investigation_list["command"] == "investigation.list"
assert len(investigation_list["result"]) == 2
assert {item["headEventID"] for item in investigation_list["result"]} == {
    investigation_selection_a["result"]["investigation"]["headEventID"],
    investigation_selection_b["result"]["investigation"]["headEventID"],
}
assert oversized_plan["command"] == "plan"
assert oversized_plan["outcome"] == "failed"
assert oversized_plan["failure"]["code"] == "planner.request-too-large"
assert oversized_plan["failure"]["category"] == "insufficientResources"
assert similarity["command"] == "similarity"
assert similarity["outcome"] == "succeeded"
assert 0 <= similarity["result"]["weightedJaccardSimilarity"] <= 1
assert 0 <= similarity["result"]["multisetDiceSimilarity"] <= 1
assert similarity["result"]["smoothingIdentifier"] == "Lidstone-v1"
assert similarity["result"]["smoothedKLTargetToReference"] >= 0
assert similarity["result"]["sourceGeneration"] == 13
assert similarity["result"]["generation"] == 13
assert similarity["result"]["artifactID"].startswith("artifact:sha256:")
assert similarity["result"]["analysisNodeID"].startswith("analysis-node:sha256:")
assert similarity["result"]["comparisonIdentifier"] == "corpus-term-similarity-v3"
assert similarity["result"]["comparisonDigest"].startswith("sha256:")
assert similarity["result"]["targetTypeCount"] > 0
assert similarity["result"]["referenceTypeCount"] > 0
assert 0 <= similarity["result"]["jaccardSimilarity"] <= 1
assert 0 <= similarity["result"]["diceSimilarity"] <= 1
assert -1 <= similarity["result"]["cosineSimilarity"] <= 1
assert similarity_reused["command"] == "similarity"
assert similarity_reused["result"]["generation"] == 13
assert similarity_reused["result"]["artifactID"] == similarity["result"]["artifactID"]
assert similarity_reused["result"]["comparisonDigest"] == similarity["result"]["comparisonDigest"]
assert association["command"] == "association"
assert association["result"]["analysisIdentifier"] == "corpus-document-term-association-v2"
assert 0 < association["result"]["monteCarloPValue"] <= 1
assert association["result"]["monteCarloSeed"] == 20260918
assert association["result"]["monteCarloSimulationCount"] == 2000
assert association["result"]["lineage"]["artifactID"].startswith("artifact:sha256:")
assert association["result"]["includedDocumentCount"] == 2
assert 0 <= association["result"]["pValue"] <= 1
assert 0 <= association["result"]["cramersV"] <= 1
assert association_reused["result"]["lineage"]["artifactID"] == association["result"]["lineage"]["artifactID"]
assert association_reused["result"]["lineage"]["generation"] == association["result"]["lineage"]["generation"]
assert dispersion["command"] == "dispersion"
assert dispersion["result"]["analysisIdentifier"] == "corpus-term-dispersion-v2"
assert len(dispersion["result"]["terms"]) > 0
assert dispersion["result"]["partitionIdentifier"] == "document-partition-v1"
assert dispersion["result"]["parts"] == [[pid] for pid in dispersion["result"]["sourceRevisionIDs"]]
assert collocations["command"] == "collocations"
assert collocations["result"]["analysisIdentifier"] == "corpus-document-collocation-v1"
assert collocations["result"]["universeSize"] == 2
assert network["command"] == "network"
assert network["result"]["analysisIdentifier"] == "corpus-document-cooccurrence-network-v2"
assert abs(sum(node["pageRank"] for node in network["result"]["nodes"]) - 1) < 1e-9
assert window["command"] == "window-collocations"
assert window["result"]["analysisIdentifier"] == "corpus-window-collocation-v2"
assert window["result"]["universeIdentifier"] == "ordered-node-collocate-pairs-v1"
assert window["result"]["tokenCount"] > 0
assert window["result"]["universeSize"] > 0
for pair in window["result"]["pairs"]:
    counts = pair["jointCount"] + pair["nodeOnlyCount"] + pair["collocateOnlyCount"] + pair["neitherCount"]
    assert counts == window["result"]["universeSize"]
    assert pair["nodeTerm"] <= pair["collocateTerm"]
assert window_reused["result"]["lineage"]["artifactID"] == window["result"]["lineage"]["artifactID"]
assert window_reused["result"]["lineage"]["generation"] == window["result"]["lineage"]["generation"]
assert correlate["command"] == "correlate"
assert correlate["outcome"] == "failed"
assert correlate["failure"]["code"] == "metric-correlation.insufficient-sources"
assert correlate["failure"]["category"] == "insufficientData"
assert posthoc["command"] == "posthoc"
assert posthoc["outcome"] == "failed"
assert posthoc["failure"]["code"] == "group-posthoc.insufficient-groups"
assert paired["command"] == "paired"
assert paired["result"]["analysisIdentifier"] == "document-metric-paired-comparison-v1"
assert paired["result"]["pairCount"] == 2
# Stessa metrica sui due lati: tutte le differenze sono nulle, i test appaiati non sono definiti.
assert paired["result"]["meanDifference"] == 0
assert paired["result"]["pairedTUnavailableReason"] == "statistics.non-positive-variance"
assert paired["result"]["wilcoxonUnavailableReason"] == "statistics.all-differences-zero"
assert group_metric["result"]["analysisIdentifier"] == "document-metric-group-comparison-v5"
assert group_metric["result"]["resamplingSeed"] == 7
assert group_metric["result"]["bootstrapResampleCount"] == 500
assert len(group_metric["result"]["contrasts"]) == 0
# Un documento per gruppo: N-k=0, il contrasto non è stimabile e il motivo è esplicito.
assert group_metric["result"]["contrastsUnavailableReason"] == "statistics.insufficient-sample-size"
assert window_network["command"] == "window-network"
assert window_network["result"]["analysisIdentifier"] == "corpus-window-cooccurrence-network-v1"
assert window_network["result"]["usesWeightedJointCount"] is True
assert window_network["result"]["summary"]["nodeCount"] == len(window_network["result"]["nodes"])
for edge in window_network["result"]["edges"]:
    assert edge["occurrences"], "ogni arco deve risolvere almeno una posizione sorgente"
    assert edge["weight"] <= edge["jointCount"]
for pair in window["result"]["pairs"]:
    assert pair["occurrences"]
    assert pair["meanDistance"] >= 1
assert network["result"]["summary"]["weakComponentCount"] >= 1
for edge in network["result"]["edges"]:
    assert len(edge["supportingSourceRevisionIDs"]) == edge["jointCount"]
assert multivariate["command"] == "multivariate"
assert multivariate["result"]["methodIdentifier"] == "CA-SVD-v1"
assert multivariate["result"]["backendIdentifier"] == "SVD-Jacobi-v1"
assert abs(sum(multivariate["result"]["axisShares"]) - 1) < 1e-9
assert len(multivariate["result"]["rowCoordinates"]) == 2
assert hac["result"]["methodIdentifier"] == "HAC-v1"
assert hac["result"]["clusterAssignments"] == [0, 1]
assert len(hac["result"]["merges"]) == 1
assert group_metric["command"] == "group-metric"
assert group_metric["result"]["metricIdentifier"] == "document-lexical-token-count-v1"
assert len(group_metric["result"]["groups"]) == 2
assert group_metric["result"]["mannWhitneyIdentifier"] == "MannWhitneyU-v1"
assert group_metric["result"]["kruskalWallisIdentifier"] == "KruskalWallis-v1"
assert group_metric["result"]["cohenDIdentifier"] == "CohenD-pooled-v1"
# Un documento per gruppo: due sole assegnazioni, entrambe estreme (p=1), senza bootstrap.
permutation = group_metric["result"]["permutation"]
assert group_metric["result"]["permutationIdentifier"] == "PermutationMeanDifference-v1"
assert group_metric["result"]["generatorIdentifier"] == "SplitMix64-v1"
assert permutation["strategyIdentifier"] == "exact"
assert permutation["evaluatedCount"] == 2
assert permutation["pValue"] == 1
assert all(group.get("bootstrapLower") is None for group in group_metric["result"]["groups"])
# Un documento per gruppo: s_p non è definita e d resta indisponibile con motivo esplicito.
assert group_metric["result"].get("cohenD") is None
assert group_metric["result"]["cohenDUnavailableReason"] == "statistics.insufficient-sample-size"
mann_whitney = group_metric["result"]["mannWhitney"]
assert mann_whitney["u1"] + mann_whitney["u2"] == 1  # n1·n2 con un documento per gruppo
assert 0 <= mann_whitney["pValue"] <= 1
assert agreement["command"] == "agreement"
assert agreement["result"]["analysisIdentifier"] == "coding-agreement-v2"
assert agreement["result"]["level"] == "nominal"
# Due codificatori, P̄=1/2 e P̄_e=1/2: Fleiss coincide con Cohen (0).
assert abs(agreement["result"]["fleissKappa"]) < 1e-9
assert agreement["result"]["alphaLower"] <= agreement["result"]["alphaUpper"]
assert abs(agreement["result"]["cohen"]["kappa"]) < 1e-9
assert abs(agreement["result"]["krippendorff"]["alpha"] - 0.125) < 1e-9
assert agreement_reused["result"]["lineage"]["artifactID"] == agreement["result"]["lineage"]["artifactID"]
assert agreement_reused["result"]["lineage"]["generation"] == agreement["result"]["lineage"]["generation"]
assert final_info["result"]["project"]["generation"] == 24
assert final_info["result"]["project"]["artifactCount"] == 19
assert final_info["result"]["project"]["investigationEventCount"] == 3
PY

xcodebuild build \
    -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-macOS \
    -configuration Debug \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$build_cache_directory/macOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

xcodebuild build \
    -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-macOS \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$build_cache_directory/macOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

xcodebuild build \
    -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-iPadOS \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$build_cache_directory/iPadOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

xcodebuild build \
    -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-iPadOS \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$build_cache_directory/iPadOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

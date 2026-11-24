#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h:h}"
settings_file="$project_directory/Config/GitHub/repository-settings.json"
labels_file="$project_directory/Config/GitHub/labels.json"
mode="plan"

if [[ "${1:-}" == "--apply" ]]; then
    mode="apply"
    shift
fi

repository="${1:-}"
profile="${2:-solo}"

if [[ ! "$repository" =~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ]]; then
    print -u2 "Uso: $0 [--apply] OWNER/REPOSITORY [solo|team]"
    exit 2
fi

if [[ "$profile" != "solo" && "$profile" != "team" ]]; then
    print -u2 "Profilo non valido: usare solo oppure team"
    exit 2
fi

ruleset_file="$project_directory/Config/GitHub/rulesets/main-${profile}.json"

print "Piano GitHub per $repository"
print -- "- richiede repository già esistente e privato con branch main"
print -- "- applica impostazioni conservative, squash merge e pulizia branch"
print -- "- limita Actions a componenti GitHub, SHA completi e token read-only"
print -- "- abilita Dependabot alerts e aggiornamenti di sicurezza"
print -- "- installa le etichette controllate"
print -- "- applica il ruleset main con profilo $profile"

if [[ "$mode" == "plan" ]]; then
    print "Anteprima soltanto. Per applicare: $0 --apply $repository $profile"
    exit 0
fi

for command_name in gh jq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        print -u2 "Comando obbligatorio non disponibile: $command_name"
        exit 1
    fi
done

gh auth status --hostname github.com >/dev/null

repository_state="$(gh repo view "$repository" --json visibility,defaultBranchRef,isArchived,nameWithOwner)"
visibility="$(print -r -- "$repository_state" | jq -r '.visibility')"
default_branch="$(print -r -- "$repository_state" | jq -r '.defaultBranchRef.name // ""')"
archived="$(print -r -- "$repository_state" | jq -r '.isArchived')"

if [[ "$visibility" != "PRIVATE" ]]; then
    print -u2 "Operazione rifiutata: $repository non risulta privato"
    exit 1
fi
if [[ "$default_branch" != "main" ]]; then
    print -u2 "Operazione rifiutata: il branch predefinito deve essere main"
    exit 1
fi
if [[ "$archived" != "false" ]]; then
    print -u2 "Operazione rifiutata: il repository è archiviato"
    exit 1
fi
if [[ "$profile" == "team" && ! -f "$project_directory/.github/CODEOWNERS" ]]; then
    print -u2 "Il profilo team richiede .github/CODEOWNERS senza segnaposto"
    exit 1
fi

description="$(jq -r '.description' "$settings_file")"
typeset -a topic_arguments
topic_arguments=()
while IFS= read -r topic; do
    topic_arguments+=(--add-topic "$topic")
done < <(jq -r '.topics[]' "$settings_file")

typeset -a ownership_arguments
ownership_arguments=()
repository_owner="${repository%%/*}"
owner_type="$(gh api "users/$repository_owner" --jq '.type')"
if [[ "$owner_type" == "Organization" ]]; then
    ownership_arguments+=(--allow-forking=false)
fi

gh repo edit "$repository" \
    --description "$description" \
    --default-branch main \
    --enable-issues=true \
    --enable-projects=false \
    --enable-wiki=false \
    --enable-discussions=false \
    --template=false \
    --enable-squash-merge=true \
    --enable-merge-commit=false \
    --enable-rebase-merge=false \
    --enable-auto-merge=true \
    --allow-update-branch=true \
    --delete-branch-on-merge=true \
    --squash-merge-commit-message pr-title-description \
    "${ownership_arguments[@]}" \
    "${topic_arguments[@]}"

typeset -a api_headers
api_headers=(
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2026-03-10"
)

gh api "${api_headers[@]}" --method PUT "repos/$repository/actions/permissions" \
    -F enabled=true \
    -f allowed_actions=selected \
    -F sha_pinning_required=true \
    --silent

gh api "${api_headers[@]}" --method PUT \
    "repos/$repository/actions/permissions/selected-actions" \
    -F github_owned_allowed=true \
    -F verified_allowed=false \
    --silent

gh api "${api_headers[@]}" --method PUT "repos/$repository/actions/permissions/workflow" \
    -f default_workflow_permissions=read \
    -F can_approve_pull_request_reviews=false \
    --silent

gh api "${api_headers[@]}" --method PUT "repos/$repository/actions/permissions/access" \
    -f access_level=none \
    --silent

if [[ "$owner_type" == "Organization" ]]; then
    gh api "${api_headers[@]}" --method PUT \
        "repos/$repository/actions/permissions/fork-pr-workflows-private-repos" \
        -F run_workflows_from_fork_pull_requests=false \
        -F send_write_tokens_to_workflows=false \
        -F send_secrets_and_variables=false \
        -F require_approval_for_fork_pr_workflows=true \
        --silent
fi

gh api "${api_headers[@]}" --method PUT "repos/$repository/vulnerability-alerts" --silent
gh api "${api_headers[@]}" --method PUT "repos/$repository/automated-security-fixes" --silent

security_state="$(gh api "${api_headers[@]}" "repos/$repository" \
    --jq '.security_and_analysis.secret_scanning.status // "unavailable"')"
if [[ "$security_state" != "unavailable" ]]; then
    gh repo edit "$repository" \
        --enable-secret-scanning=true \
        --enable-secret-scanning-push-protection=true
else
    print "Secret scanning GitHub non disponibile sul piano o tipo di proprietario corrente."
fi

ruleset_name="$(jq -r '.name' "$ruleset_file")"
ruleset_listing=""
if ruleset_listing="$(gh api "${api_headers[@]}" "repos/$repository/rulesets" 2>&1)"; then
    existing_ruleset_id="$(print -r -- "$ruleset_listing" | jq -r \
        ".[] | select(.name == \"$ruleset_name\") | .id" | head -n 1)"
    if [[ -n "$existing_ruleset_id" ]]; then
        gh api "${api_headers[@]}" --method PUT \
            "repos/$repository/rulesets/$existing_ruleset_id" \
            --input "$ruleset_file" \
            --silent
    else
        gh api "${api_headers[@]}" --method POST "repos/$repository/rulesets" \
            --input "$ruleset_file" \
            --silent
    fi
elif [[ "$ruleset_listing" == *"Upgrade to GitHub Pro"* ]]; then
    print "Ruleset GitHub non disponibile sul piano privato corrente; profilo conservato nel repository."
else
    print -u2 "Impossibile leggere o configurare le ruleset GitHub."
    print -u2 -- "$ruleset_listing"
    exit 1
fi

while IFS=$'\t' read -r label_name label_color label_description; do
    gh label create "$label_name" \
        --repo "$repository" \
        --color "$label_color" \
        --description "$label_description" \
        --force
done < <(jq -r '.[] | [.name, .color, .description] | @tsv' "$labels_file")

while IFS= read -r existing_label; do
    if ! jq -e --arg name "$existing_label" \
        'any(.[]; .name == $name)' "$labels_file" >/dev/null; then
        gh label delete "$existing_label" --repo "$repository" --yes
    fi
done < <(gh label list --repo "$repository" --limit 100 --json name --jq '.[].name')

"$script_directory/audit-repository.py" "$repository" "$profile"

#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

# Share build resources only while holding an exclusive kernel-managed lock.
# The ownership marker prevents cleanup from adopting an arbitrary user directory.
# The lock file lives outside the removable cache and must never be unlinked:
# replacing its inode would let two processes acquire different locks for one cache.
# Entry points use `helper || exit 1`: zsh errexit from a function can bypass EXIT traps.
typeset -g glifi_cache_lock_descriptor=""
typeset -g glifi_cache_owned_directory=""

glifi_validate_gigabytes() {
    local value="$1"
    local variable="$2"
    if [[ "$value" != <-> || ${#value} -gt 6 ]]; then
        print -u2 "${variable}: richiesto un intero non negativo di massimo sei cifre."
        return 1
    fi
}
glifi_verification_scope() {
    if (( $# == 0 )); then
        print -r -- "all"
    elif (( $# == 1 )) && [[ "$1" == "--macos-only" ]]; then
        print -r -- "macos"
    else
        print -u2 "Usage: ${ZSH_ARGZERO:t} [--macos-only]"
        return 2
    fi
}

glifi_build_cache_directory() {
    local requested="${GLIFI_VERIFY_CACHE:-$HOME/Library/Caches/GlifiStudio/verify}"
    print -r -- "${requested:a}"
}

# Fail before building when free space is below the configured floor.
glifi_require_free_space() {
    local target="$1"
    local minimum="${GLIFI_VERIFY_MIN_FREE_GB:-15}"
    local free
    glifi_validate_gigabytes "$minimum" GLIFI_VERIFY_MIN_FREE_GB || return 1
    free=$(df -g "$target" | awk 'NR == 2 { print $4 }') || {
        print -u2 "Impossibile determinare lo spazio libero."
        return 1
    }
    if [[ "$free" != <-> ]]; then
        print -u2 "Impossibile determinare lo spazio libero."
        return 1
    fi
    if (( free < 10#$minimum )); then
        print -u2 "Spazio libero insufficiente: ${free} GiB, ne servono ${minimum}."
        print -u2 "Libera spazio oppure esegui 'make clean-cache' per svuotare la cache di build."
        return 1
    fi
    return 0
}

# Release only a lock acquired by this shell, including failed preparation.
glifi_unlock_build_cache() {
    if [[ -n "$glifi_cache_lock_descriptor" ]]; then
        zsystem flock -u "$glifi_cache_lock_descriptor"
        glifi_cache_lock_descriptor=""
    fi
    glifi_cache_owned_directory=""
}

# Claim an empty cache or reopen a previously owned one before modifying it.
glifi_prepare_build_cache() {
    local requested="$1"
    local maximum="${GLIFI_VERIFY_MAX_CACHE_GB:-12}"
    glifi_validate_gigabytes "$maximum" GLIFI_VERIFY_MAX_CACHE_GB || return 1
    while [[ "$requested" == */ && "$requested" != / ]]; do
        requested="${requested%/}"
    done
    if [[ -z "$requested" || "$requested" == / || -L "$requested" ]]; then
        print -u2 "Percorso cache non ammesso."
        return 1
    fi
    local cache="${requested:A}"
    if [[ -n "$glifi_cache_lock_descriptor" ]]; then
        print -u2 "Questa esecuzione possiede già una cache di build."
        return 1
    fi
    if [[ -e "$cache" && ( ! -d "$cache" || ! -O "$cache" ) ]]; then
        print -u2 "La cache deve essere una directory dell'utente corrente."
        return 1
    fi
    local lock_file="${cache}.glifi-lock"
    if [[ -L "$lock_file" || ( -e "$lock_file" && ( ! -f "$lock_file" || ! -O "$lock_file" ) ) ]]; then
        print -u2 "File di lock della cache non ammesso."
        return 1
    fi
    mkdir -p "${cache:h}" || return 1
    touch "$lock_file" || return 1
    zmodload zsh/system || return 1
    if ! zsystem flock -t 0 -f glifi_cache_lock_descriptor "$lock_file"; then
        print -u2 "Cache di build occupata: attendere l'altra esecuzione o scegliere GLIFI_VERIFY_CACHE."
        return 1
    fi
    local marker="$cache/.glifi-build-cache-owner"
    local active_marker="$cache/.glifi-build-cache-active"
    if [[ -e "$active_marker" || -L "$active_marker" ]]; then
        print -u2 "Cache lasciata da un'esecuzione incompleta: file conservati; scegliere una cache vuota."
        glifi_unlock_build_cache
        return 1
    fi
    if [[ -d "$cache" ]]; then
        local -a contents
        contents=("$cache"/*(DN))
        if (( ${#contents} > 0 )) && [[ -L "$marker" || ! -f "$marker" || ! -O "$marker" || "$(<"$marker")" != studio.glifi.build-cache.v1 ]]; then
            print -u2 "Directory cache non riconosciuta: i file esistenti sono conservati; scegliere una cache vuota."
            glifi_unlock_build_cache
            return 1
        fi
    fi
    mkdir -p "$cache" || { glifi_unlock_build_cache; return 1; }
    print -r -- studio.glifi.build-cache.v1 > "$marker" || {
        glifi_unlock_build_cache
        return 1
    }
    glifi_cache_owned_directory="$cache"
    if [[ -d "$cache" ]]; then
        local kilobytes
        kilobytes="$(du -sk "$cache" | awk '{ print $1 }')" || {
            print -u2 "Impossibile misurare la cache di build."
            return 1
        }
        if [[ "$kilobytes" != <-> ]]; then
            print -u2 "Impossibile misurare la cache di build."
            return 1
        fi
        if (( kilobytes > 10#$maximum * 1048576 )); then
            print "Cache di build oltre il tetto di ${maximum} GiB: viene svuotata."
            rm -rf -- "$cache" || return 1
            mkdir -p "$cache" || return 1
            print -r -- studio.glifi.build-cache.v1 > "$marker" || return 1
        fi
    fi
    # A killed owner can leave compiler children alive after its fcntl lock is
    # released. Do not adopt that cache merely because the lock becomes free.
    print -r -- "$$" > "$active_marker"
}

# A contender's EXIT trap cannot remove the owner's cache.
glifi_release_build_cache() {
    local cache="${1:A}"
    if [[ -z "$glifi_cache_lock_descriptor" || "$cache" != "$glifi_cache_owned_directory" ]]; then
        return 0
    fi
    if [[ -L "$cache" || ! -d "$cache" || ! -O "$cache" || -L "$cache/.glifi-build-cache-owner" || ! -f "$cache/.glifi-build-cache-owner" || "$(<"$cache/.glifi-build-cache-owner")" != studio.glifi.build-cache.v1 ]]; then
        print -u2 "Proprietà della cache modificata: pulizia rifiutata, file conservati."
        glifi_unlock_build_cache
        return 1
    fi
    if [[ "${GLIFI_VERIFY_KEEP_CACHE:-0}" == "1" ]]; then
        print "Cache di build conservata in $cache (GLIFI_VERIFY_KEEP_CACHE=1)."
        rm -f -- "$cache/.glifi-build-cache-active"
    else
        rm -rf -- "$cache"
    fi
    glifi_unlock_build_cache
}

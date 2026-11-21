#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

# Politica comune delle cache di build degli script di qualità.
#
# Una cache di compilazione nuova a ogni esecuzione ricompila tutto da zero e riscrive decine di
# gigabyte: il picco osservato era di circa 37 GiB per il solo target iPadOS. Le cache vivono
# quindi in una directory stabile, riusata fra le esecuzioni e con un tetto dichiarato, mentre gli
# artefatti della singola esecuzione restano temporanei e vengono rimossi all'uscita.
#
# Variabili d'ambiente:
# Al termine la cache viene rimossa: uno strumento non lascia strascichi sul disco di chi lo usa.
# Chi itera molte volte di seguito può conservarla con GLIFI_VERIFY_KEEP_CACHE=1, assumendosi il
# costo in spazio.
#
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
    print -r -- "${GLIFI_VERIFY_CACHE:-$HOME/Library/Caches/GlifiStudio/verify}"
}

# Si ferma subito se il disco non basta, invece di morire a metà build.
glifi_require_free_space() {
    # Attenzione: in zsh `path` è legata a PATH e non va usata come variabile locale.
    local target="$1"
    local minimum="${GLIFI_VERIFY_MIN_FREE_GB:-15}"
    local free
    free=$(df -g "$target" | awk 'NR == 2 { print $4 }')
    if (( free < minimum )); then
        print -u2 "Spazio libero insufficiente: ${free} GiB, ne servono ${minimum}."
        print -u2 "Libera spazio oppure esegui 'make clean-cache' per svuotare la cache di build."
        return 1
    fi
    return 0
}

# Svuota la cache quando supera il tetto, così non cresce senza fine.
glifi_prepare_build_cache() {
    local cache="$1"
    local maximum="${GLIFI_VERIFY_MAX_CACHE_GB:-12}"
    if [[ -d "$cache" ]]; then
        local gigabytes=$(( $(du -sk "$cache" | awk '{ print $1 }') / 1048576 ))
        if (( gigabytes > maximum )); then
            print "Cache di build a ${gigabytes} GiB, oltre il tetto di ${maximum}: viene svuotata."
            rm -rf "$cache"
        fi
    fi
    mkdir -p "$cache"
}

# Rimuove la cache al termine, salvo richiesta esplicita di conservarla.
glifi_release_build_cache() {
    local cache="$1"
    if [[ "${GLIFI_VERIFY_KEEP_CACHE:-0}" == "1" ]]; then
        print "Cache di build conservata in $cache (GLIFI_VERIFY_KEEP_CACHE=1)."
        return 0
    fi
    rm -rf "$cache"
}

# Bonifica i residui di esecuzioni interrotte: se un processo viene ucciso, il trap non gira e la
# directory temporanea resta sul disco per sempre. Vale per gli script di qualità e anche per i
# test, che creano directory `Glifi...` e non possono ripulirle quando vengono uccisi.
#
# Si toccano soltanto directory del namespace `Glifi` nella cartella temporanea dell'utente e più
# vecchie di un'ora, per non disturbare un'esecuzione in corso.
glifi_sweep_stale_temporaries() {
    local root="${1%/}"
    find "$root" -maxdepth 1 -type d -name "Glifi*" -mmin +60 -print0 2>/dev/null |
        xargs -0 rm -rf 2>/dev/null || true
}

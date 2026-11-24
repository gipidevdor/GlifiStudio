<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-112 — Correspondence Analysis e PCA oltre il limite denso

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-112 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task P3 di GS-DOR-002 |

## Ambito

Supera il limite «CA e PCA restano dense» di GS-VER-108:

- `CA-SVD-v1` e `PCA-SVD-v1` usano Jacobi entro il limite denso e `SVD-SubspaceIteration-v1` oltre
  (primi dieci assi o componenti), dichiarando il backend nel risultato e in GlifiKit;
- inerzia totale della CA dalla norma di Frobenius della matrice standardizzata (`χ²/n`) e cos² dalle
  distanze chi-quadrato calcolate direttamente (`d_i² = Σ_j S_ij²/r_i`), quindi corretti anche quando
  la SVD troncata non restituisce tutti gli assi; varianza totale della PCA dalla matrice centrata.

## Procedura e risultato

1. forzando il backend troncato (limite denso 0) sulla matrice di riferimento 5×4: valori singolari,
   coordinate di riga e cos² della CA coincidono con Jacobi (a sua volta verificato contro R,
   GS-VER-102) entro `1e-9`; inerzia totale 0,587755102040816; varianze e quote della PCA entro
   `1e-10`;
2. il contract test CLI verifica il backend dichiarato (`SVD-Jacobi-v1` sulle fixture);
3. suite GlifiCore di 196 test e gate completo `make verify`.

## Esito

**Superato localmente: CA e PCA scalano oltre il limite denso con gli stessi risultati.**

# SPDX-License-Identifier: BSD-3-Clause
# Independent boundary references from R/stats; no R implementation is copied.
# Run: Rscript griglia-kernel.R [output.json]

options(warn = 2)
arguments <- commandArgs(trailingOnly = TRUE)
output <- if (length(arguments)) arguments[[1]] else "griglia-kernel.json"

# Adjacent positive binary64 values, without another package or decimal rounding.
adjacent <- function(value, direction) {
    bytes <- as.integer(writeBin(as.double(value), raw(), size = 8, endian = "little"))
    carry <- direction
    for (index in seq_len(8)) {
        next.byte <- bytes[index] + carry
        if (next.byte >= 0 && next.byte <= 255) {
            bytes[index] <- next.byte
            break
        }
        bytes[index] <- next.byte %% 256
        carry <- if (direction > 0) 1 else -1
    }
    readBin(as.raw(bytes), "double", n = 1, size = 8, endian = "little")
}
neighbors <- function(value) c(adjacent(value, -1), value, adjacent(value, 1))
binary.bits <- function(value) paste(sprintf("%02x", as.integer(
    writeBin(as.double(value), raw(), size = 8, endian = "big"))), collapse = "")
binary.hex <- function(value) {
    # R's parser underflows normalized hex exponents below -1022. The equivalent
    # subnormal C99 spelling keeps that exponent fixed, as Python float.hex does.
    if (value != 0 && abs(value) < .Machine$double.xmin) {
        return(paste0(if (value < 0) "-" else "", "0x0.",
                      substring(binary.bits(abs(value)), 4, 16), "p-1022"))
    }
    sprintf("%a", value)
}
number <- function(value) {
    stopifnot(length(value) == 1, is.finite(value))
    sprintf("%.17g", value)
}
object <- function(values) {
    hexadecimal <- vapply(values, binary.hex, "")
    # Decimal parsing is not assumed correct: attest every C99 input round-trip.
    for (index in seq_along(values)) {
        stopifnot(binary.bits(values[[index]]) == binary.bits(as.numeric(hexadecimal[[index]])))
    }
    bit.fields <- sprintf('"%s":"%s"', names(values), vapply(values, binary.bits, ""))
    hex.fields <- sprintf('"%s":"%s"', names(values), hexadecimal)
    paste0("{", paste(sprintf('"%s":%s', names(values), vapply(values, number, "")), collapse = ","),
           ',"bits":{', paste(bit.fields, collapse = ","), "}",
           ',"hex":{', paste(hex.fields, collapse = ","), "}}")
}
array <- function(values) paste0("[", paste(values, collapse = ",\n"), "]")
strings <- function(values) array(sprintf('"%s"', values))
with.vectors <- function(record, vectors) {
    fields <- character()
    for (name in names(vectors)) {
        values <- vectors[[name]]
        hex <- vapply(values, binary.hex, "")
        bits <- vapply(values, binary.bits, "")
        stopifnot(identical(bits, vapply(as.numeric(hex), binary.bits, "")))
        fields <- c(fields, paste0('"', name, '":', array(vapply(values, number, ""))),
            paste0('"', name, 'Bits":', strings(bits)),
            paste0('"', name, 'Hex":', strings(hex)))
    }
    paste0(substring(record, 1, nchar(record) - 1), ",", paste(fields, collapse = ","), "}")
}

smallest <- .Machine$double.xmin * .Machine$double.eps
powers <- 2^-c(1, 2, 3, 8, 16, 32, 52, 53, 100, 200, 500, 900, 1000, 1022, 1023, 1050, 1073, 1074)
central <- 0.5 + (-32:32) * .Machine$double.eps / 4
cuts <- exp(pnorm(-c(1, 2, 4, 8, 16, 32, 38), log.p = TRUE))
quarter <- 0.25
dense.quarter <- quarter
for (index in seq_len(32)) {
    quarter <- adjacent(quarter, 1)
    dense.quarter <- c(dense.quarter, quarter)
}
quarter <- 0.25
for (index in seq_len(32)) {
    quarter <- adjacent(quarter, -1)
    dense.quarter <- c(dense.quarter, quarter)
}
probabilities <- c(seq_len(16) * smallest, neighbors(.Machine$double.xmin),
                   powers, central, seq(0.01, 0.99, length.out = 29),
                   unlist(lapply(cuts, neighbors)), dense.quarter, neighbors(0.75))
probabilities <- sort(unique(c(probabilities, 1 - probabilities)))
probabilities <- probabilities[probabilities > 0 & probabilities < 1]
normal <- vapply(probabilities, function(p) object(c(probability = p, expected = qnorm(p))), "")

t.rows <- character()
for (degrees in c(1, 2, 7, 40, 1000)) {
    # The beta symmetry branch occurs at t^2 = 3*df/(df+2).
    cut <- sqrt(3 * degrees / (degrees + 2))
    statistics <- sort(unique(c(0, smallest, .Machine$double.xmin, 1e-200, 1e-8,
                                0.2, 1, 3, 10, 1e100, 1e200, 1e300, neighbors(cut))))
    for (statistic in statistics) {
        tail <- exp(log(2) + pt(-abs(statistic), degrees, log.p = TRUE))
        t.rows <- c(t.rows, object(c(statistic = statistic, degrees = degrees,
            twoSided = tail, less = pt(statistic, degrees),
            greater = pt(statistic, degrees, lower.tail = FALSE),
            relativeTolerance = if (degrees <= 40) 1e-12 else 1e-9)))
    }
}

f.rows <- character()
for (pair in list(c(1, 1), c(2, 2), c(1, 40), c(40, 1), c(7, 40),
                  c(40, 7), c(40, 1000), c(1000, 1000), c(0.1, 1000))) {
    first <- pair[[1]]
    second <- pair[[2]]
    cut <- second * (first + 2) / (first * (second + 2))
    statistics <- sort(unique(c(0, smallest, .Machine$double.xmin, 1e-100, 1e-8,
                                0.1, 1, 10, 100, 1e100, 1e200, 1e300, neighbors(cut))))
    for (statistic in statistics) {
        f.rows <- c(f.rows, object(c(statistic = statistic, firstDegrees = first,
            secondDegrees = second, expected = pf(statistic, first, second, lower.tail = FALSE),
            relativeTolerance = if (max(pair) <= 40) 1e-12 else 1e-9)))
    }
}

chi.rows <- character()
for (degrees in c(1, 2, 3, 7, 40, 100, 1000)) {
    # chiSquare/2 = shape+1 is the series/fraction boundary.
    statistics <- sort(unique(c(0, smallest, .Machine$double.xmin, 1e-200, 1e-8,
                                0.1, 1, 10, 50, 100, 1000, 1480, 1484, 1488, 1490,
                                neighbors(degrees + 2))))
    for (statistic in statistics) {
        chi.rows <- c(chi.rows, object(c(statistic = statistic, degrees = degrees,
            expected = pchisq(statistic, degrees, lower.tail = FALSE),
            relativeTolerance = if (degrees <= 100) 1e-12 else 1e-9)))
    }
}

bca.rows <- character()
effect.rows <- character()
levels <- sort(unique(c(1e-8, 1 / 3, neighbors(1 / 3), 0.5, 0.95)))
replicates <- c(-1e150, -8e149, -6e149, -4e149, -2e149, -1e149, -100, -1,
                1, 100, 1e149, 2e149, 4e149, 6e149, 8e149, 1e150)
for (estimate in c(-101, 0, 101)) {
    for (jackknife in list(c(-2, -1, 0, 1, 2), c(0, 1, 2, 4, 10))) {
        deviations <- mean(jackknife) - jackknife
        squares <- sum(deviations^2)
        acceleration <- if (squares > 0) sum(deviations^3) / (6 * squares^1.5) else 0
        bias <- qnorm(sum(replicates < estimate) / length(replicates))
        for (level in levels) {
            tail <- (1 - level) / 2
            probabilities <- vapply(c(tail, 1 - tail), function(p) {
                shifted <- bias + qnorm(p)
                pnorm(bias + shifted / (1 - acceleration * shifted))
            }, 0.0)
            endpoints <- quantile(replicates, probabilities, type = 7, names = FALSE)
            probability.tolerance <- 4e-15
            lower.envelope <- quantile(replicates,
                pmax(0, pmin(1, probabilities[1] + c(-1, 1) * probability.tolerance)),
                type = 7, names = FALSE)
            upper.envelope <- quantile(replicates,
                pmax(0, pmin(1, probabilities[2] + c(-1, 1) * probability.tolerance)),
                type = 7, names = FALSE)
            record <- object(c(estimate = estimate, confidenceLevel = level,
                biasCorrection = bias, acceleration = acceleration,
                lowerProbability = probabilities[1], upperProbability = probabilities[2],
                lower = endpoints[1], upper = endpoints[2],
                probabilityTolerance = probability.tolerance,
                lowerEnvelopeMin = lower.envelope[1], lowerEnvelopeMax = lower.envelope[2],
                upperEnvelopeMin = upper.envelope[1], upperEnvelopeMax = upper.envelope[2]))
            bca.rows <- c(bca.rows, with.vectors(record,
                list(sortedReplicates = replicates, jackknife = jackknife)))
        }
    }
}
for (samples in list(list(c(1, 2, 3, 4, 7), c(-3, -1, 1, 2, 3, 5)),
                     list(c(-7, -4, -3, -2, -1), c(-5, -3, -2, -1, 1, 3)),
                     list(c(1, 2, 3, 4, 7) * 1e140, c(-3, -1, 1, 2, 3, 5) * 1e140))) {
    first <- samples[[1]]
    second <- samples[[2]]
    n1 <- length(first)
    n2 <- length(second)
    degrees <- n1 + n2 - 2
    pooled <- sqrt(((n1 - 1) * var(first) + (n2 - 1) * var(second)) / degrees)
    d <- (mean(first) - mean(second)) / pooled
    correction <- exp(lgamma(degrees / 2) - log(sqrt(degrees / 2)) - lgamma((degrees - 1) / 2))
    se <- sqrt((n1 + n2) / (n1 * n2) + d^2 / (2 * (n1 + n2)))
    for (level in levels) {
        z <- qnorm((1 + level) / 2)
        record <- object(c(confidenceLevel = level, cohenD = d, correctionFactor = correction,
                           hedgesG = correction * d, standardError = se,
                           lower = d - z * se, upper = d + z * se))
        effect.rows <- c(effect.rows, with.vectors(record, list(firstSample = first, secondSample = second)))
    }
}

metadata <- paste0('"schema":"studio.glifi.statistical-optimization-oracle",',
    '"schemaVersion":1,"license":"BSD-3-Clause",',
    '"provenance":"Input sintetici originali; attese da processo separato R stats::qnorm/pt/pf/pchisq. Nessun codice o coefficiente R incorporato.",',
    '"encoding":"Input costruiti in R; ogni campo numerico conserva bit binary64 e C99 hex con round-trip verificato prima della scrittura. I test nativi verificano i bit dopo la decodifica JSON.",',
    '"runtime":"', R.version.string, '",',
    '"normalMaximumULP":8,',
    '"normal":', array(normal), ',',
    '"t":', array(t.rows), ',',
    '"f":', array(f.rows), ',',
    '"chiSquare":', array(chi.rows), ',',
    '"bca":', array(bca.rows), ',',
    '"effectSize":', array(effect.rows))
writeLines(paste0("{", metadata, "}"), output, useBytes = TRUE)
cat(sprintf("Kernel oracle: normal=%d t=%d F=%d chi-square=%d BCa=%d EffectSize=%d\n",
            length(normal), length(t.rows), length(f.rows), length(chi.rows),
            length(bca.rows), length(effect.rows)))

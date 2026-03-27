# core.awk
# Unified log processing engine

BEGIN {
    IGNORECASE = ignore_case ? 1 : 0

    # Dedup mode parsing
    dedup_mode = dedup
    if (dedup_mode == "" || dedup_mode == "none") {
        dedup_enabled = 0
    } else {
        dedup_enabled = 1
    }

    count = 0
    block_active = 0
    block = ""
}

# ------------------------
# Helper: get dedup key
# ------------------------
function get_key(line,   key, idx) {
    if (!dedup_enabled) {
        return line
    }

    # Full line dedup
    if (dedup_mode == "full") {
        return line
    }

    # Field-based dedup
    split(line, fields, FS)

    if (dedup_mode == "last") {
        return fields[length(fields)]
    }

    if (dedup_mode == "second-last") {
        return fields[length(fields)-1]
    }

    # Numeric field index
    if (dedup_mode ~ /^[0-9]+$/) {
        idx = dedup_mode
        return fields[idx]
    }

    # Regex strip mode
    if (dedup_strip != "") {
        key = line
        gsub(dedup_strip, "", key)
        return key
    }

    return line
}

# ------------------------
# MATCH / COUNT MODE
# ------------------------
mode != "block" {
    if ($0 ~ pattern) {

        key = get_key($0)

        if (!dedup_enabled || !seen[key]++) {
            if (mode == "count") {
                count++
            } else {
                print $0
            }
        }
    }
}

# ------------------------
# BLOCK MODE
# ------------------------
mode == "block" {
    # Start of block
    if ($0 ~ start_pattern) {
        block_active = 1
        block = $0 "\n"
        next
    }

    # Inside block
    if (block_active) {
        block = block $0 "\n"

        # End of block
        if ($0 ~ end_pattern) {

            key = get_key(block)

            if (!dedup_enabled || !seen[key]++) {
                if (mode == "count") {
                    count++
                } else {
                    printf "%s", block
                }
            }

            block = ""
            block_active = 0
        }
    }
}

END {
    if (mode == "count") {
        print count
    }
}

# core.awk - minimal, clean log parser

BEGIN {
    IGNORECASE = ignore_case ? 1 : 0

    dedup_enabled = (dedup == "1")

    # auto-enable dedup if strip is set
    if (dedup_strip != "" && !dedup_enabled) {
        dedup_enabled = 1
    }

    count = 0
    block_active = 0
    block = ""
}

# ------------------------
# Normalize text
# ------------------------
function normalize(text,   tmp) {
    tmp = text

    if (dedup_strip != "") {
        gsub(dedup_strip, "", tmp)
    }

    # normalize whitespace
    gsub(/[ \t]+/, " ", tmp)
    gsub(/ *\n/, "\n", tmp)

    # trim leading
    sub(/^[ \t]+/, "", tmp)

    # trim trailing
    sub(/[ \t]+$/, "", tmp)

    return tmp
}

# ------------------------
# Dedup key
# ------------------------
function get_key(text) {
    if (!dedup_enabled) {
        return text
    }
    return normalize(text)
}

# ------------------------
# Process line
# ------------------------
function process_line(line,   key) {
    key = get_key(line)

    if (!dedup_enabled || !seen[key]++) {
        if (mode == "count") {
            count++
        } else {
            print line
        }
    }
}

# ------------------------
# Process block
# ------------------------
function process_block(b,   key) {

    # skip empty blocks
    if (b ~ /^[ \n]*$/) {
        return
    }

    key = get_key(b)

    if (!dedup_enabled || !seen[key]++) {
        if (mode == "count") {
            count++
        } else {
            printf "%s", b
        }
    }
}

# ------------------------
# LINE MODE
# ------------------------
mode != "block" {
    if ($0 ~ pattern) {
        process_line($0)
    }
}

# ------------------------
# BLOCK MODE (supports delimiter)
# ------------------------
mode == "block" {

    # delimiter mode (start == end)
    if ($0 ~ start_pattern && start_pattern == end_pattern) {

        if (block_active) {
            process_block(block)
            block = ""
            block_active = 0
        } else {
            block_active = 1
            block = ""
        }

        next
    }

    # start block
    if ($0 ~ start_pattern) {
        block_active = 1
        block = $0 "\n"
        next
    }

    # inside block
    if (block_active) {
        block = block $0 "\n"

        # end block
        if ($0 ~ end_pattern) {
            process_block(block)
            block = ""
            block_active = 0
        }
    }
}

# ------------------------
# END
# ------------------------
END {

    # flush last block (important!)
    if (mode == "block" && block_active) {
        process_block(block)
    }

    if (mode == "count") {
        print count
    }
}

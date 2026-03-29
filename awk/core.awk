# core.awk - minimal, clean log parser

BEGIN {
    IGNORECASE = ignore_case ? 1 : 0

    dedup_enabled = (dedup == "1")
    dedup_fields_enabled = 0
    dedup_ignore_fields_enabled = 0
    dedup_field_count = 0
    dedup_ignore_field_count = 0

    if ((dedup_strip != "" || dedup_fields != "" || dedup_ignore_fields != "") && !dedup_enabled) {
        dedup_enabled = 1
    }

    if (dedup_fields != "") {
        dedup_field_count = parse_field_list(dedup_fields, dedup_field_index)
        dedup_fields_enabled = (dedup_field_count > 0)
    }

    if (dedup_ignore_fields != "") {
        dedup_ignore_field_count = parse_field_list(dedup_ignore_fields, dedup_ignore_field_index)
        dedup_ignore_fields_enabled = (dedup_ignore_field_count > 0)
    }

    count = 0
    block_active = 0
    block = ""
}

function parse_field_list(spec, target,   n, i, part, count_local, parts) {
    count_local = 0
    n = split(spec, parts, ",")

    for (i = 1; i <= n; i++) {
        part = parts[i]
        gsub(/^[ \t]+|[ \t]+$/, "", part)

        if (part ~ /^[1-9][0-9]*$/) {
            count_local++
            target[count_local] = part + 0
        }
    }

    return count_local
}

function normalize(text,   tmp) {
    tmp = text

    if (dedup_strip != "") {
        gsub(dedup_strip, "", tmp)
    }

    gsub(/[ \t]+/, " ", tmp)
    gsub(/ *\n/, "\n", tmp)
    sub(/^[ \t]+/, "", tmp)
    sub(/[ \t]+$/, "", tmp)

    return tmp
}

function build_field_key(text,   n, i, idx, key, use_field, ignored, fields) {
    text = normalize(text)
    n = split(text, fields, /[ \t]+/)
    key = ""

    for (i = 1; i <= n; i++) {
        use_field = 1

        if (dedup_fields_enabled) {
            use_field = 0
            for (idx = 1; idx <= dedup_field_count; idx++) {
                if (dedup_field_index[idx] == i) {
                    use_field = 1
                    break
                }
            }
        }

        if (use_field && dedup_ignore_fields_enabled) {
            ignored = 0
            for (idx = 1; idx <= dedup_ignore_field_count; idx++) {
                if (dedup_ignore_field_index[idx] == i) {
                    ignored = 1
                    break
                }
            }
            if (ignored) {
                use_field = 0
            }
        }

        if (use_field) {
            key = key SUBSEP fields[i]
        }
    }

    if (key == "") {
        return text
    }

    return key
}

function get_key(text) {
    if (!dedup_enabled) {
        return text
    }

    if (dedup_fields_enabled || dedup_ignore_fields_enabled) {
        return build_field_key(text)
    }

    return normalize(text)
}

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

function process_block(b,   key) {
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

mode != "block" {
    if ($0 ~ pattern) {
        process_line($0)
    }
}

mode == "block" {
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

    if ($0 ~ start_pattern) {
        block_active = 1
        block = $0 "\n"
        next
    }

    if (block_active) {
        block = block $0 "\n"

        if ($0 ~ end_pattern) {
            process_block(block)
            block = ""
            block_active = 0
        }
    }
}

END {
    if (mode == "block" && block_active) {
        process_block(block)
    }

    if (mode == "count") {
        print count
    }
}

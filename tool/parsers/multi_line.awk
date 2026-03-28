#!/usr/bin/awk -f

# Usage: ./multi_line.awk -v start_pattern_1="START_PATTERN" -v end_pattern="END_PATTERN"  input_file
# Also supports optional start_pattern_2 and start_pattern_3 patterns if you need more regex matches.
# To enable case insensitive matching, pass ignore_case="true" as a variable.
#
# Prints everything between lines matching START_PATTERN and END_PATTERN.
# Checking for duplicates based on the second to last field (or last field if only one field exists).
#
#
# Usually multi line errors tend to look something like follows:
#
# ==================================================
# [ERROR] 2024-01-01 12:00:00 Some error occurred
# on trace id 12345
# maybe everything has crashed
# ==================================================
#
# This script ran as: ./multi_line.awk -v start_pattern_1="ERROR" -v end_pattern="===" logfile would print everything between the equal signs.
#
# If you have any other examples not covered by this script, please open an issue on GitHub.

function escape_meta_chars(pattern) {
    gsub(/\\/, "\\\\", pattern);
    gsub(/\./, "\\.", pattern);
    gsub(/\*/, "\\*", pattern);
    gsub(/\+/, "\\+", pattern);
    gsub(/\?/, "\\?", pattern);
    gsub(/\^/, "\\^", pattern);
    gsub(/\$/, "\\$", pattern);
    gsub(/\|/, "\\|", pattern);
    gsub(/\(\)/, "\\(\\)", pattern);
    gsub(/\[\]/, "\\[\\]", pattern);
    gsub(/\{\}/, "\\{\\}", pattern);
    return pattern;
}

BEGIN {
    flag = 0

    if ((!start_pattern_1) || (!end_pattern)) {
        exit 1
    }

    start_pattern_1 = escape_meta_chars(start_pattern_1)
    end_pattern = escape_meta_chars(end_pattern)

    if (!start_pattern_2 || start_pattern_2 == "") {
        start_pattern_2 = "^$";
    } else {
        start_pattern_2 = escape_meta_chars(start_pattern_2)
    }

    if (!start_pattern_3 || start_pattern_3 == "") {
        start_pattern_3 = "^$";
    } else {
        start_pattern_3 = escape_meta_chars(start_pattern_3)
    }
    if (ignore_case == "true") {
      IGNORECASE = 1;
    }
}

$0 ~ start_pattern_1 {
    flag = 1
}
$0 ~ start_pattern_2 {
    flag = 1
}
$0 ~ start_pattern_3 {
    flag = 1
}
$0 ~ end_pattern {
    flag = 0
}

flag && !line_count[$(NF ? NF-(control_character ? control_character : 1) : NF)]++ {
    sorter[++count] = $0
}

END {
    for (i = 1; i <= count; i++) {
        if (length(sorter[i]) > 0) {
            print sorter[i]
        }
    }
}


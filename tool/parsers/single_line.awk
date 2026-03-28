#!/usr/bin/awk -f

# Usage ./single_line.awk -v error_pattern_1="your_regex_here" -v error_pattern_2="other_regex_here" input_file
# Support up to 4 error_patterns
# To enable case insensitive matching, pass ignore_case="true" as a variable.
#
# Matches each line of $error_pattern_[NUM] and prints only if it has not already been printed once.
# Uses the last or second to last field as unique identifier to check if the line has already been printed.

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
    if (!error_pattern_1 || error_pattern_1 == "") {
        error_pattern_1 = "^$";
    } else {
        error_pattern_1 = escape_meta_chars(error_pattern_1);
    }

    if (!error_pattern_2 || error_pattern_2 == "") {
        error_pattern_2 = "^$";
    } else {
        error_pattern_2 = escape_meta_chars(error_pattern_2);
    }

    if (!error_pattern_3 || error_pattern_3 == "") {
        error_pattern_3 = "^$";
    } else {
        error_pattern_3 = escape_meta_chars(error_pattern_3);
    }

    if (!error_pattern_4 || error_pattern_4 == "") {
        error_pattern_4 = "^$";
    } else {
        error_pattern_4 = escape_meta_chars(error_pattern_4);
    }

    if (ignore_case == "true") {
      IGNORECASE = 1;
    }
}

{
    if ($0 ~ error_pattern_1 || $0 ~ error_pattern_2 || $0 ~ error_pattern_3 || $0 ~ error_pattern_4) {
        id = $0
        if (!line_check[$(NF ? NF-(control_character ? control_character : 1) : NF)]++) {
            line_check[id] = $0
            sorter[sort++] = id
        }
    }
}

END {
    for (i = 0; i < sort; i++) {
        if (length(line_check[sorter[i]]) > 0) {
            print line_check[sorter[i]]
        }
    }
}

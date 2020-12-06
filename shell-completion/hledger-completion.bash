# Completion script for hledger.
# Created using a Makefile and real hledger.

# This script is sourced by an interactive shell, so do NOT do things like
# 'set -o pipefail' or mangle the global environment in any other way!
# That said, we *do* remove colon (:) from COMP_WORDBREAKS which impacts
# the rest of the session and completion for other programs.

_hledger_completion_function() {
    # Current treatment for special characters:
    # - exclude colon (:) from COMP_WORDBREAKS
    # - use comptop -o filenames to escape the rest
    COMP_WORDBREAKS=${COMP_WORDBREAKS//:}
    compopt -o filenames

    local wordToComplete=$2
    local subcommand
    local subcommandOptions
    local i

    for (( i=1; i<${#COMP_WORDS[@]}; i++ )); do
        subcommand=${COMP_WORDS[i]}
        if ! grep -Fxqe "$subcommand" <<< "$_hledger_complist_commands"; then
            subcommand=
            continue
        fi
        # There could be other commands begining with $subcommand, e.g.:
        # $subcommand == reg --> register, register-match,
        # $subcommand == bal --> balance, balancesheet, balancesheetequity, etc.
        # Do not ignore them!
        if [[ $subcommand == "$wordToComplete" ]] && ((i == COMP_CWORD)); then
            local subcommandMatches
            subcommandMatches=$(grep -c "^$wordToComplete" <<< "$_hledger_complist_commands")
            if ((subcommandMatches > 1)); then
                subcommand=
                break
            else
                _hledger_compreply "$subcommand"
                return 0
            fi
        fi
        # Replace dashes with underscores and use indirect expansion
        subcommandOptions=_hledger_complist_options_${subcommand//-/_}
        _hledger_compreply "$(_hledger_compgen "${!subcommandOptions}")"
        break
    done

    if [[ -z $subcommand ]]; then
        _hledger_compreply_optarg && return

        # Completion lists are already sorted at build-time
        # This keeps commands and options grouped separately
        compopt -o nosort
        _hledger_compreply "$(_hledger_compgen "$_hledger_complist_commands")"
        _hledger_compreply_append "$(_hledger_compgen "$_hledger_complist_generic_options")"

        return 0
    fi

    # Option argument completion after subcommand too
    _hledger_compreply_optarg && return

    # Avoid setting compopt bellow if completing an option
    [[ $wordToComplete == -* ]] && return

    # Almost all subcommands accept [QUERY]
    # -> always add accounts to completion list
    # Except for those few that will complain
    local noQuery=(files help test)
    [[ " ${noQuery[*]} " =~ " $subcommand " ]] && return
    # Add any other subcommand special treatment here, or if it becomes unwieldy
    # move it out in say _hledger_compreply_subcommand() and return on success.

    # Query specific completions
    _hledger_compreply_query && return

    # Do not sort, keep accounts and query filters grouped separately
    compopt -o nosort -o nospace
    _hledger_compreply_append "$(_hledger_compgen "$_hledger_complist_query_filters")"
    if [[ -z $wordToComplete ]]; then
        _hledger_compreply_append "$(_hledger_compgen "$(_hledger accounts --flat --depth 1)")"
    else
        _hledger_compreply_append "$(_hledger_compgen "$(_hledger accounts --flat)")"
    fi

    return 0
}

_hledger_extension_completion_function() {
    local cmd=$1
    shift

    # Change parameters and arguments and call the
    # normal hledger completion function.
    local extensionName=${cmd#*-}
    COMP_WORDS=( "hledger" "$extensionName" "${COMP_WORDS[@]:1}" )
    _hledger_completion_function "hledger" "$@"
}

# Register completion function for hledger:
complete -F _hledger_completion_function hledger

# Register completion functions for hledger extensions:
complete -F _hledger_extension_completion_function hledger-ui
complete -F _hledger_extension_completion_function hledger-web

# Helpers

# Comment out when done
_hledger_debug() {
    ((HLEDGER_DEBUG)) || return 0
    local var=${1:-COMP_WORDS}
    printf '\ndebug: %s\n' "$(declare -p "$var")" >&2
}

# Stolen from bash-completion
# This function quotes the argument in a way so that readline dequoting
# results in the original argument.  This is necessary for at least
# `compgen' which requires its arguments quoted/escaped:
_hledger_quote_by_ref()
{
    printf -v $2 %q "$1"

    # If result becomes quoted like this: $'string', re-evaluate in order to
    # drop the additional quoting.  See also: http://www.mail-archive.com/
    # bash-completion-devel@lists.alioth.debian.org/msg01942.html
    [[ ${!2} == \$* ]] && eval $2=${!2}
}

_hledger_quote()
{
    local quoted
    _hledger_quote_by_ref "$1" quoted
    printf %s "$quoted"
}

# Set the value of COMPREPLY from newline delimited completion candidates
_hledger_compreply() {
    local IFS=$'\n'
    COMPREPLY=($1)
}

# Append the value of COMPREPLY from newline delimited completion candidates
_hledger_compreply_append() {
    local IFS=$'\n'
    COMPREPLY+=($1)
}

# Generate input suitable for _hledger_compreply() from newline delimited
# completion candidates. It doesn't seem there is a way to feed a literal
# wordlist to compgen -- it will eat your quotes, drink your booze and...
# Completion candidates are quoted accordingly first and then we leave it to
# compgen to deal with readline.
_hledger_compgen() {
    local wordlist=$1
    local quoted=()
    local word
    local i=0

    while IFS= read -r word; do
        _hledger_quote_by_ref "$word" word
        quoted[i++]=$word
    done <<< "$wordlist"

    local IFS=$'\n'
    compgen -W "${quoted[*]}" -- "$wordToComplete"
}

# Try required option argument completion. Set COMPREPLY and return 0 on
# success, 1 if option doesn't require an argument or out of context
_hledger_compreply_optarg() {
    local optionIndex=${1:-$((COMP_CWORD - 1))}
    local recursionLevel=${2:-0}
    local wordlist
    local error=0

    case ${COMP_WORDS[optionIndex]} in
        --alias)
            compopt -o nospace
            _hledger_compreply "$(_hledger_compgen "$(_hledger accounts --flat)")"
            ;;
        -f|--file|--rules-file|-o|--output-file)
            _hledger_compreply "$(compgen -f -- "$wordToComplete")"
            ;;
        --pivot)
            compopt -o nosort
            wordlist="code description note payee"
            _hledger_compreply "$(compgen -W "$wordlist" -- "$wordToComplete")"
            _hledger_compreply_append "$(_hledger_compgen "$(_hledger tags)")"
            ;;
        --value)
            wordlist="cost then end now"
            _hledger_compreply "$(compgen -W "$wordlist" -- "$wordToComplete")"
            ;;
        -X|--exchange)
            _hledger_compreply "$(_hledger_compgen "$(_hledger commodities)")"
            ;;
        --color|--colour)
            compopt -o nosort
            wordlist="auto always yes never no"
            _hledger_compreply "$(compgen -W "$wordlist" -- "$wordToComplete")"
            ;;
        # Argument required, but no handler (yet)
        -b|--begin|-e|--end|-p|--period|--depth)
            _hledger_compreply ""
            ;;
        =)
            # Recurse only once!
            ((recursionLevel > 1)) && return 1
            if [[ ${COMP_WORDS[optionIndex - 1]} == -* ]]; then
                _hledger_compreply_optarg $((optionIndex - 1)) $((recursionLevel + 1))
                error=$?
            fi
            ;;
        *)
            error=1
            ;;
    esac

    return $error
}

# Query filter completion through introspection
_hledger_compreply_query() {
    [[ $wordToComplete =~ .: ]] || return
    local query=${wordToComplete%%:*}:
    grep -Fxqe "$query" <<< "$_hledger_complist_query_filters" || return

    local hledgerArgs=()
    case $query in
        acct:)
            hledgerArgs=(accounts --flat)
            ;;
        code:)
            hledgerArgs=(codes)
            ;;
        cur:)
            hledgerArgs=(commodities)
            ;;
        desc:)
            hledgerArgs=(descriptions)
            ;;
        note:)
            hledgerArgs=(notes)
            ;;
        payee:)
            hledgerArgs=(payees)
            ;;
        tag:)
            hledgerArgs=(tags)
            ;;
        *)
            return 1
            ;;
    esac

    _hledger_compreply "$(
        _hledger_compgen "$(
            _hledger "${hledgerArgs[@]}" | sed "s/^/$query/g"
        )"
    )"

    return 0
}

# Get ledger file from -f --file arguments from COMP_WORDS and pass it to the
# 'hledger' call. Note that --rules-file - if present - must also be passed!
_hledger() {
    local hledgerArgs=("$@")
    local hledgerFile
    local hledgerRulesFile
    local i

    # hledger balance --file ~/ledger _
    # 0       1       2      3        4
    for (( i=1; i < ${#COMP_WORDS[@]} - 2; i++ )); do
        case ${COMP_WORDS[i]} in
            -f|--file)
                if [[ ${COMP_WORDS[i+1]} == '=' ]]; then
                    hledgerFile=${COMP_WORDS[i+2]}
                else
                    hledgerFile=${COMP_WORDS[i+1]}
                fi
                ;;
            --rules-file)
                if [[ ${COMP_WORDS[i+1]} == '=' ]]; then
                    hledgerRulesFile=${COMP_WORDS[i+2]}
                else
                    hledgerRulesFile=${COMP_WORDS[i+1]}
                fi
                ;;
        esac
    done

    [[ -f $hledgerFile ]] && hledgerArgs+=(--file "$hledgerFile")
    [[ -f $hledgerRulesFile ]] && hledgerArgs+=(--rules-file "$hledgerRulesFile")

    # Discard errors. Is there a way to validate files before using them?
    hledger "${hledgerArgs[@]}" 2>/dev/null
}

# Include lists of commands and options generated by the Makefile using the
# m4 macro processor.
# Included files must have exactly one newline at EOF to prevent weired errors.

read -r -d "" _hledger_complist_commands <<TEXT
accounts
activity
add
areg
aregister
bal
balance
balancesheet
balancesheetequity
bs
bse
cashflow
cf
check-dates
check-dupes
close
codes
commodities
descriptions
diff
equity
files
help
import
incomestatement
is
notes
payees
prices
print
print-unique
reg
register
register-match
rewrite
roi
stats
tags
test
txns
ui
web
api
TEXT

read -r -d "" _hledger_complist_query_filters <<TEXT
acct:
amt:
code:
cur:
date:
date2:
depth:
desc:
inacct:
not:
note:
payee:
real:
status:
tag:
TEXT

read -r -d "" _hledger_complist_generic_options <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

# Dashes are replaced by m4 with underscores to form valid identifiers
# Referenced by indirect expansion of $subcommandOptions

read -r -d "" _hledger_complist_options_accounts <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--declared
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--help
--ignore-assertions
--infer-value
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--tree
--unmarked
--used
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_activity <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_add <<TEXT
--alias
--anon
--debug
--file
--help
--ignore-assertions
--no-new-accounts
--pivot
--rules-file
--version
TEXT

read -r -d "" _hledger_complist_options_areg <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--rules-file
--txn-dates
--unmarked
--value
--version
--weekly
--width
--yearly
TEXT

read -r -d "" _hledger_complist_options_aregister <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--rules-file
--txn-dates
--unmarked
--value
--version
--weekly
--width
--yearly
TEXT

read -r -d "" _hledger_complist_options_bal <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--budget
--change
--cleared
--color
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-value
--invert
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--transpose
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_balance <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--budget
--change
--cleared
--color
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-value
--invert
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--transpose
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_balancesheet <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_balancesheetequity <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_bs <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_bse <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_cashflow <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_cf <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_check_dates <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-value
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--strict
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_check_dupes <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_close <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--close
--close-acct
--close-desc
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--explicit
--file
--forecast
--help
--ignore-assertions
--infer-value
--interleaved
--market
--monthly
--open
--open-acct
--open-desc
--pending
--period
--pivot
--quarterly
--real
--rules-file
--show-costs
--unmarked
--value
--version
--weekly
--x
--yearly
TEXT

read -r -d "" _hledger_complist_options_codes <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-value
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_commodities <<TEXT
--alias
--anon
--debug
--file
--help
--ignore-assertions
--pivot
--rules-file
--version
TEXT

read -r -d "" _hledger_complist_options_descriptions <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_diff <<TEXT
--alias
--anon
--debug
--file
--help
--ignore-assertions
--pivot
--rules-file
--version
TEXT

read -r -d "" _hledger_complist_options_equity <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--close
--close-acct
--close-desc
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--explicit
--file
--forecast
--help
--ignore-assertions
--infer-value
--interleaved
--market
--monthly
--open
--open-acct
--open-desc
--pending
--period
--pivot
--quarterly
--real
--rules-file
--show-costs
--unmarked
--value
--version
--weekly
--x
--yearly
TEXT

read -r -d "" _hledger_complist_options_files <<TEXT
--alias
--anon
--debug
--file
--help
--ignore-assertions
--pivot
--rules-file
--version
TEXT

read -r -d "" _hledger_complist_options_help <<TEXT
--cat
--help
--info
--man
--pager
TEXT

read -r -d "" _hledger_complist_options_import <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--catchup
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--dry-run
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--new
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_incomestatement <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-market-price
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_is <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--change
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--drop
--empty
--end
--exchange
--file
--flat
--forecast
--format
--help
--historical
--ignore-assertions
--infer-value
--market
--monthly
--no-elide
--no-total
--output-file
--output-format
--pending
--percent
--period
--pivot
--pretty-tables
--quarterly
--real
--row-total
--rules-file
--sort-amount
--tree
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_notes <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_payees <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_prices <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--costs
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-value
--inverted-costs
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_print <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--explicit
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--match
--monthly
--new
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_print_unique <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_reg <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--historical
--ignore-assertions
--infer-value
--invert
--market
--monthly
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--related
--rules-file
--unmarked
--value
--version
--weekly
--width
--yearly
TEXT

read -r -d "" _hledger_complist_options_register <<TEXT
--alias
--anon
--auto
--aux-date
--average
--begin
--cleared
--colour
--cost
--cumulative
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--historical
--ignore-assertions
--infer-value
--invert
--market
--monthly
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--related
--rules-file
--unmarked
--value
--version
--weekly
--width
--yearly
TEXT

read -r -d "" _hledger_complist_options_register_match <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_rewrite <<TEXT
--add-posting
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--diff
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_roi <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cashflow
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-value
--inv
--investment
--market
--monthly
--pending
--period
--pivot
--pnl
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_stats <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--output-file
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_tags <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--parsed
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--values
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_test <<TEXT
--color
--debug
--help
--version
TEXT

read -r -d "" _hledger_complist_options_txns <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--explicit
--file
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--match
--monthly
--new
--output-file
--output-format
--pending
--period
--pivot
--quarterly
--real
--rules-file
--unmarked
--value
--version
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_ui <<TEXT
--alias
--anon
--auto
--aux-date
--begin
--change
--cleared
--colour
--cost
--daily
--date2
--debug
--depth
--empty
--end
--exchange
--file
--flat
--forecast
--help
--ignore-assertions
--infer-market-price
--market
--monthly
--pending
--period
--pivot
--quarterly
--real
--register
--rules-file
--theme
--tree
--unmarked
--value
--version
--watch
--weekly
--yearly
TEXT

read -r -d "" _hledger_complist_options_web <<TEXT
TEXT

read -r -d "" _hledger_complist_options_api <<TEXT
TEXT

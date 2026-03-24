---
name: shell-programmer
description: >
  Best practices for writing readable, maintainable shell scripts based on the Google Shell
  Style Guide and community standards. Provides a 7-dimension readability scoring framework,
  idiomatic bash patterns, and a structured review workflow. Use this skill whenever Claude is
  writing, reviewing, refactoring, or debugging shell scripts (.sh files, bash, zsh) — even if
  the user doesn't mention "style" or "readability." Trigger for any shell script task: writing
  new scripts, editing existing ones, reviewing PRs that touch shell code, fixing bugs in shell
  scripts, or converting one-liners into proper scripts. Also trigger when the user pastes shell
  code and asks for help, or when generating shell scripts as part of a larger task (Makefiles,
  CI pipelines, git hooks, deployment scripts). Do NOT trigger for one-off shell commands typed
  directly into a terminal, or for non-shell languages.
---

# Shell Programmer

This skill encodes shell scripting best practices drawn from the
[Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html),
the GitLab Shell Scripting Standards, and community conventions validated by ShellCheck.

The goal is not to dogmatically enforce rules but to produce shell scripts that a person can
read top-to-bottom and understand without re-reading any line. Readability is the primary
value — correctness is a close second. Cleverness is not a value at all.

Shell is the right tool for glue scripts under ~100 lines. Beyond that, consider Python or
another structured language. Within that range, these principles help keep scripts clear.


## Readability Scoring Framework

When reviewing or refactoring a shell script, assess it on these 7 dimensions (1–5 each,
35 max). This framework is useful both for identifying what to fix and for communicating
the impact of changes to the user.

| # | Dimension | What a 5 looks like |
|---|-----------|---------------------|
| 1 | **Naming** | Every variable and function name is self-documenting. Locals use `lowercase_snake`, constants use `UPPER_SNAKE` with `readonly`. No abbreviations that require context to decode. |
| 2 | **Structure** | File follows: shebang → header comment → constants → functions → main logic. Each section has a clear marker. Reader never encounters a function call before its definition. |
| 3 | **Comments** | File header states purpose and input/output. Each function has a one-line doc comment above it. Section markers orient the reader. Comments explain *why*, not *what*. No over-commenting of obvious code. |
| 4 | **Quoting & Safety** | All variable expansions use `"${var}"`. Traps use single quotes. No backticks. Error messages go to stderr. No unquoted `$@` or `$*`. |
| 5 | **Formatting** | 2-space indentation, no tabs. Lines ≤ 80 characters. `[[ ]]` for conditionals (in bash), `(( ))` for arithmetic. `; then` and `; do` on the same line as their keyword. |
| 6 | **DRY / No Dead Code** | No unused variables or extracted-but-never-read fields. No redundant assignments (`x="$y"; z="$x"` when `z="$y"` suffices). No parallel shadow variables. |
| 7 | **Correctness** | No semantic anti-patterns. Logic handles empty/missing values where the data source is external. No subshell round-trips that could be avoided. |

### Using the framework

When *reviewing*: score each dimension, identify the 2–3 lowest, focus changes there.
Present before/after scores so the user can see the impact.

When *writing*: aim for 4+ on every dimension from the start. It's easier to write clean
than to clean up later.


## File Structure

A well-structured shell script reads like a short document: context at the top, building
blocks in the middle, narrative at the bottom.

```bash
#!/bin/bash
#
# Brief description of what this script does.
# What it reads (stdin, files, args) and what it produces (stdout, files, exit codes).

readonly SOME_CONSTANT="value"
readonly ANOTHER_CONSTANT=42

# One-line description of what this function does.
my_function() {
  local arg="${1}"
  # ...
}

# --- Main logic ---

# ... uses the functions and constants above ...
```

Why this order matters: a reader scanning from the top sees *what* the script is (header),
*what knobs it has* (constants), *what verbs it defines* (functions), and then *what it
actually does* (main logic). Every forward reference is resolved by the time it's reached.

### File extensions

Executables should have a `.sh` extension or no extension. Libraries (sourced files) must
have a `.sh` extension and should not be executable. This distinction tells the reader
whether a file is meant to be run or sourced.


## Naming

Names are the single highest-leverage readability tool. A good name eliminates the need for
a comment; a bad name creates the need for several.

- **Local variables**: `lowercase_snake_case`. Prefer full words (`used_percentage`, not
  `used_pct`; `context_size`, not `ctx_sz`). Single-letter names are acceptable only in
  trivial arithmetic loops (`for i in ...`).
- **Constants**: `UPPER_SNAKE_CASE`, declared with `readonly`. This signals "don't touch"
  and the shell enforces it.
- **Functions**: `lowercase_snake_case`. Verb-first when possible (`format_number`,
  `check_cache`, `build_output`). Avoid abbreviations (`fmt_k` tells the reader nothing;
  `format_number` tells them everything).

```bash
# Bad
fmt_k() { ... }
ctx_sz=200000
used=45

# Good
format_number() { ... }
readonly CONTEXT_SIZE=200000
used_percentage=45
```


## Comments

The scoring framework covers the basics (file headers, function docs, section markers).
Two additional conventions:

### TODO format

Mark temporary or imperfect code with a TODO that includes who has context:

```bash
# TODO(jdoe): Handle the edge case where input is empty (bug #1234)
```

The name/identifier makes TODOs searchable and answerable — someone can find the right
person to ask rather than guessing at the intent.

### When not to comment

Don't comment obvious code. A comment like `# increment counter` above `(( count++ ))`
adds noise without information. Save comments for *why* something is done a non-obvious
way, not *what* the code does.


## Quoting and Safety

Unquoted variables are the #1 source of subtle shell bugs (word splitting, glob expansion).
The rule is simple: always quote, no exceptions worth memorizing.

- **Use `"${var}"`** everywhere, not `$var`. The braces make the boundary unambiguous
  (is it `$var_name` or `${var}_name`?) and the quotes prevent word splitting.
- **Command substitution**: `$(command)`, never backticks. Backticks can't nest, are hard
  to distinguish from single quotes in many fonts, and are deprecated in every modern guide.
- **Traps**: use single quotes so variables expand at trap-execution time, not
  trap-definition time: `trap 'rm -f "$tmpfile"' EXIT`
- **Error messages**: send to stderr so they don't pollute stdout pipelines:
  `echo "error: file not found" >&2`
- **`"$@"`** to pass argument lists, never `$*` or unquoted `$@`.


## Formatting

Consistent formatting lets the eye parse structure without conscious effort.

- **Indentation**: 2 spaces. No tabs. (Tabs are only acceptable inside heredoc bodies
  when using `<<-`.)
- **Line length**: 80 characters maximum. Break long lines with `\` at logical points:

  ```bash
  file_mtime=$(stat -f %m "${CACHE_FILE}" 2>/dev/null \
    || stat -c %Y "${CACHE_FILE}" 2>/dev/null \
    || echo 0)
  ```

- **Conditionals on one line**: `if ...; then` and `while ...; do` — the `then`/`do` goes
  on the same line. `else`, `elif`, `fi`, and `done` get their own lines.

- **Long one-liners**: if a line has 3+ nested `$()` or multiple chained `||`/`&&`, break
  it into intermediate variables. The variable names serve as documentation:

  ```bash
  # Bad — dense, requires careful parsing
  [ $(($(date +%s) - $(stat -f %m "$f" 2>/dev/null || echo 0))) -gt 5 ]

  # Good — each step is named and obvious
  local file_mtime
  file_mtime=$(stat -f %m "${f}" 2>/dev/null || echo 0)
  local age=$(( $(date +%s) - file_mtime ))
  (( age > 5 ))
  ```

- **Case statements**: indent alternatives by 2 spaces. One-line alternatives get a space
  after `)` and before `;;`. Multi-command alternatives split across lines:

  ```bash
  case "${flag}" in
    a) aflag='true' ;;
    b) bflag='true' ;;
    verbose)
      verbose='true'
      log_level='debug'
      ;;
    *)
      echo "Unexpected: ${flag}" >&2
      exit 1
      ;;
  esac
  ```

- **Pipelines**: if a pipeline doesn't fit on one line, split it with the pipe on the new
  line, indented:

  ```bash
  command1 \
    | command2 \
    | command3 \
    | command4
  ```


## Conditionals and Arithmetic

Bash provides two distinct conditional syntaxes. Use the right one for the job:

- **`[[ ... ]]`** for string/file tests. It supports pattern matching (`[[ $x == *.txt ]]`),
  regex (`[[ $x =~ ^[0-9]+$ ]]`), and doesn't require quoting inside to prevent word
  splitting (though you should still quote for consistency). Prefer `[[ ]]` over `[ ]` in
  bash scripts — `[ ]` is POSIX but lacks these features and has sharper edges.

- **`(( ... ))`** for arithmetic. It reads like math (`(( n >= 1000 ))`) instead of
  requiring operators that look like flags (`[ "$n" -ge 1000 ]`). Variables inside don't
  need `$` prefixes. The return value is 0 (true) when the expression is non-zero.

### The `&&`/`||` trap

```bash
# Dangerous — if command_a succeeds but command_b fails, command_c also runs
command_a && command_b || command_c

# Safe — explicit flow control
if command_a; then
  command_b
else
  command_c
fi
```

The `&&`/`||` pattern looks like an if/else but isn't one. The `||` branch runs whenever
the *entire left side* (`command_a && command_b`) fails — including when `command_a`
succeeds but `command_b` fails. Use `if/else` for conditional logic. Reserve `&&`/`||` for
simple guard-and-return patterns: `[[ -f "$f" ]] || return 1`.


## Functions

- **Declare local variables** with `local`. Without it, variables leak into the caller's
  scope — a source of painful debugging in any non-trivial script.
- **Document with a one-liner** above the function. If the function's purpose isn't obvious
  from its name, the comment fills the gap. If it *is* obvious, the comment confirms the
  reader's assumption (which is still valuable).
- **Use `printf`** for output, not `echo`. `echo` behaves differently across platforms
  (does `-n` suppress the newline? does `-e` enable escapes? depends on the shell). `printf`
  is consistent everywhere.
- **Keep functions short**. If a function doesn't fit on a screen (~25 lines), it's
  probably doing too much.
- **Never use aliases in scripts** — they require careful quoting, and variables like
  `$RANDOM` expand at definition time, not call time. Functions do everything aliases do
  without the surprises.

```bash
# Format a number with k/M suffix (e.g., 200000 -> "200k").
format_number() {
  local n="${1}"
  if (( n >= 1000000 )); then
    printf "%s.%sM" "$(( n / 1000000 ))" "$(( (n % 1000000) / 100000 ))"
  elif (( n >= 1000 )); then
    printf "%sk" "$(( n / 1000 ))"
  else
    printf "%s" "${n}"
  fi
}
```

### The `local` + command substitution pitfall

When you need the exit status of a command substitution, separate `local` from the
assignment. `local` always returns 0, silently masking failures:

```bash
# Bug — $? is always 0 (local's return status, not my_func's)
local my_var="$(my_func)"
(( $? == 0 )) || return

# Correct — split declaration and assignment
local my_var
my_var="$(my_func)"
(( $? == 0 )) || return
```

This only matters when you check `$?`. If you don't need the exit status,
`local my_var="$(cmd)"` is fine.


## Arrays

Arrays are the safe way to store and pass lists in bash. Without them, you end up fighting
quoting or reaching for `eval`.

```bash
# Build a flag list safely
declare -a flags
flags=(--foo --bar='baz')
flags+=(--greeting="Hello ${name}")
mybinary "${flags[@]}"
```

Always expand with `"${array[@]}"` (quoted, `@`). Unquoted expansion splits on whitespace —
the exact problem arrays exist to solve.

Avoid building lists as space-separated strings:

```bash
# Broken — spaces in values cause misparse
flags='--foo --greeting="Hello world"'
mybinary ${flags}  # "Hello" and "world" become separate args

# Correct
declare -a flags=(--foo --greeting="Hello world")
mybinary "${flags[@]}"
```


## Error Handling

- **Check return values** explicitly. Use `if` directly or check `$?`, and send informative
  messages to stderr:

  ```bash
  if ! mv "${files[@]}" "${dest}/"; then
    echo "Failed to move files to ${dest}" >&2
    exit 1
  fi
  ```

- **Use `PIPESTATUS`** to check individual pipe segments. `$?` only reflects the last
  command in a pipeline:

  ```bash
  tar -cf - ./* | ( cd "${dir}" && tar -xf - )
  if (( PIPESTATUS[0] != 0 || PIPESTATUS[1] != 0 )); then
    echo "tar pipeline failed" >&2
  fi
  ```

  `PIPESTATUS` is overwritten by the next command, so save it immediately if you need
  per-segment handling:

  ```bash
  tar -cf - ./* | ( cd "${dir}" && tar -xf - )
  local -a rc=("${PIPESTATUS[@]}")
  ```

- **Prefer builtins over external commands**. Parameter expansion, `=~`, and arithmetic
  are faster and more portable than shelling out to `sed`, `expr`, or `awk` for simple
  operations:

  ```bash
  # Prefer — no subprocess
  substitution="${string/#foo/bar}"

  # Avoid — spawns sed
  substitution="$(echo "${string}" | sed 's/^foo/bar/')"
  ```

- **SUID/SGID is forbidden** on shell scripts. Security vulnerabilities in shell make
  sufficient hardening impractical. Use `sudo` for elevated access.


## Anti-Patterns to Flag

These patterns should be called out during review because they hurt readability or
correctness in ways that aren't always obvious:

| Anti-pattern | Why it's bad | Fix |
|-------------|-------------|-----|
| `echo "$(printf ...)"` | Spawns a subshell just to capture printf, then echoes it. Two processes where one suffices. | Use `printf "...\n"` directly. |
| Unused extracted fields | Variables pulled from JSON/CSV/etc. but never referenced. Dead weight that misleads the reader about what data matters. | Remove from both extraction and assignment. |
| Parallel shadow variables | Maintaining `var` and `var_plain` (e.g., one with ANSI codes, one without) where only one is ever read. | Delete the unused variant. |
| `eval "$cmd"` | Arbitrary code execution. Almost always avoidable with arrays or `"$@"`. | Use arrays: `cmd=(git commit -m "$msg"); "${cmd[@]}"` |
| Pipes to `while` | `cat file \| while read ...` runs the loop in a subshell — variables set inside don't survive. | Use redirection: `while read ...; do ... done < file` or process substitution: `while read ...; do ... done < <(cmd)` |
| `set -e` without thought | Causes silent exits on any non-zero return, including intentional ones (`grep` returning 1 for no match). Hard to debug. | Use explicit error checking at each point that can fail. |
| Unquoted variables | `$var` without quotes is subject to word splitting and glob expansion. Works until a filename has a space. | Always `"${var}"`. |
| `[ ] && X \|\| Y` for branching | `Y` runs when `X` fails, not when the test is false. | Use `if/else`. |
| `rm *` / bare `*` globs | Filenames starting with `-` are interpreted as flags. `rm *` in a dir containing `-rf` deletes everything recursively. | Use `./*` to anchor the glob: `rm ./*` |
| Aliases in scripts | Expand at definition time, not call time. `$RANDOM` in an alias is frozen; quoting is fragile; failures are silent. | Use functions. They handle arguments, expand at call time, and compose naturally. |


## String Concatenation

Prefer `+=` over re-wrapping:

```bash
# Verbose — repeats the variable name and nests quotes
result="${result}$(printf " extra")"

# Cleaner — appends in place
result+=$(printf " extra")
```

This is a bash-ism (not POSIX), but if the shebang says `#!/bin/bash`, use bash idioms.
Writing POSIX-compatible code inside a bash script satisfies no real constraint and
sacrifices readability.


## Review Workflow

When asked to review or refactor a shell script:

1. **Read the entire script** before making any changes.
2. **Score it** against the 7 dimensions. Note the 2–3 weakest areas.
3. **Run ShellCheck** (if available) to catch bugs and non-standard patterns that a
   human review might miss. ShellCheck is recommended for all scripts, large or small.
4. **Identify dead code** — variables assigned but never read, functions defined but never
   called, fields extracted but never used.
5. **Make changes**, prioritizing the lowest-scoring dimensions. Keep each change
   atomic and explainable.
6. **Present before/after scores** with a short explanation of what moved each dimension.
7. **List the specific changes** so the user can verify nothing broke.

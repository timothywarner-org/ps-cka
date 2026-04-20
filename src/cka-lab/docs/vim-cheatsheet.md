# Vim cheatsheet for the CKA exam

Vim is the default editor in every CKA exam pod. You won't need vim wizardry
— you'll need fast, muscle-memory edits to YAML manifests. This cheatsheet
covers the subset that actually matters when the exam timer is running.

## The only two things you must set

Put these in `~/.vimrc` **before** the exam starts. The allowed-docs page lets
you open a terminal to check, and the exam proctor allows a `~/.vimrc`.

```vim
set expandtab      " use spaces, never tabs (YAML dies on tabs)
set tabstop=2      " tab width = 2 spaces
set shiftwidth=2   " indent width = 2 spaces
set number         " show line numbers
```

If you forget the `.vimrc`, you can set them live:

```vim
:set expandtab tabstop=2 shiftwidth=2
```

## Modes — the source of all confusion

| Mode | How to enter | What it does |
| ---- | ------------ | ------------ |
| Normal | `Esc` (from anywhere) | Move, delete, yank, paste |
| Insert | `i`, `a`, `o`, `O` | Type text |
| Visual | `v` | Select by character |
| Visual line | `V` | Select whole lines |
| Visual block | `Ctrl-v` | Select a rectangle (the CKA lifesaver) |
| Command | `:` | Run ex commands (save, quit, search/replace) |

Rule: if a keystroke does something weird, you were in the wrong mode. Hit
`Esc` twice and start over.

## Save, quit, bail out

| Keys | What it does |
| ---- | ------------ |
| `:w` | Write (save) |
| `:w!` | Write even if readonly — forces the save |
| `:q` | Quit |
| `:q!` | Quit without saving — **your panic button** |
| `:wq` or `:x` or `ZZ` | Save and quit |
| `:e!` | Reload file from disk, discard edits |

**Exam panic pattern:** you edited the wrong file, or you broke the YAML
irreversibly. Hit `Esc`, type `:q!`, re-run `kubectl edit` or reopen the
original manifest.

## Navigation — faster than arrow keys

| Keys | Where you go |
| ---- | ------------ |
| `h j k l` | Left, down, up, right |
| `w` / `b` | Next / previous word |
| `0` / `$` | Start / end of line |
| `gg` | Start of file (line 1, column 1) |
| `G` | End of file (last line) |
| `<N>G` or `:<N>` | Jump to line N (e.g. `42G` or `:42`) |
| `Ctrl-d` / `Ctrl-u` | Down / up half a screen |
| `%` | Jump to matching `{`, `[`, `(` |

## Editing — the YAML-surgery moves

| Keys | Effect |
| ---- | ------ |
| `i` | Insert before cursor |
| `a` | Insert after cursor |
| `o` | New line below, enter insert mode |
| `O` | New line above, enter insert mode |
| `x` | Delete character under cursor |
| `dd` | Delete (cut) current line |
| `<N>dd` | Delete N lines (e.g. `5dd`) |
| `yy` | Yank (copy) current line |
| `<N>yy` | Yank N lines |
| `p` / `P` | Paste below / above |
| `u` | Undo |
| `Ctrl-r` | Redo |
| `.` | Repeat last edit — use it more than you think |

## Visual mode — the manifest-editor's best friend

| Keys | Effect |
| ---- | ------ |
| `v` | Character-wise selection |
| `V` | Line-wise selection |
| `Ctrl-v` | Block (column) selection |
| `y` | **Copy** (yank) selection |
| `d` | **Cut** (delete) selection — goes into the same register as yank |
| `x` | Cut selection (same as `d` in visual mode) |
| `c` | Cut selection **and** enter insert mode |
| `p` | **Paste** after cursor (line-wise paste goes below current line) |
| `P` | Paste before cursor (line-wise paste goes above current line) |
| `>` / `<` | Indent / dedent selection |
| `=` | Auto-indent selection (limited help with YAML) |

### Copy / cut / paste workflow

The three-step rhythm every exam edit boils down to:

1. **Select** — enter visual mode (`v`, `V`, or `Ctrl-v`), move to grow the
   selection.
2. **Grab** — `y` to copy, `d` to cut. Both land in vim's unnamed register.
3. **Drop** — move the cursor to the destination, then `p` (after) or `P`
   (before).

Quick patterns:

- **Copy a line:** `yy` then `p` — no visual mode needed.
- **Copy 5 lines:** `5yy` then `p`.
- **Cut a line to move it:** `dd`, navigate, `p`.
- **Copy a block of YAML:** `V` to start line-wise select, `j` to extend
  down, `y` to copy, navigate, `p` to drop.
- **Duplicate current line:** `yy` then `p` — instant copy-pasta.

If something goes sideways after a paste, `u` undoes it. If you overwrote
your yank register with a delete and need the last *yank* specifically,
paste from the yank register with `"0p` (quote-zero-p).

### The CKA block-edit trick

You need to add a `namespace: dev` line (with two leading spaces) to 10 pods'
YAML. In normal mode:

1. Move to column 1 of the first line.
2. `Ctrl-v` to start block selection.
3. `j` 9 times to extend down 10 lines.
4. `I` (capital i) to insert before the block.
5. Type two spaces, then `namespace: dev`.
6. `Esc` — the text appears on every selected line.

## Search and replace

| Keys | Effect |
| ---- | ------ |
| `/pattern` | Search forward |
| `?pattern` | Search backward |
| `n` / `N` | Next / previous match |
| `*` | Search for word under cursor |
| `:%s/old/new/g` | Replace all `old` with `new` in the file |
| `:%s/old/new/gc` | Same, but confirm each change |
| `:.,+10s/old/new/g` | Replace on current line + next 10 |

## Indentation — YAML's #1 killer

| Keys | Effect |
| ---- | ------ |
| `>>` | Indent current line one shift-width |
| `<<` | Dedent current line |
| `<N>>>` | Indent N lines |
| `=G` | Auto-indent from cursor to end of file |
| `gg=G` | Auto-indent the whole file |

**If a manifest won't apply, 9/10 it's whitespace.** Run `cat -A file.yaml`
in a pseudo-terminal to spot tabs (`^I`) vs. spaces.

## Reading files and piping in

These are exam-relevant because `kubectl explain` output and docs open in
a pager that shares vim bindings:

| Keys | Effect |
| ---- | ------ |
| `:r /path/to/file` | Read file into buffer at cursor |
| `:r !kubectl get pod foo -o yaml` | Read command output into buffer |
| `:!<command>` | Run shell command, show output (doesn't modify buffer) |

The second one is gold: when `kubectl edit` isn't quite right, `:r ! ...`
pulls resource YAML into a file you're already editing.

## Working inside `kubectl edit`

`kubectl edit <resource>` drops you into vim on a temp file. Same bindings,
same `:wq` to save and apply. Gotchas:

- If you `:q!`, kubectl reports "edit cancelled, no changes made" — safe.
- If kubectl rejects your edit (validation error), it keeps the temp file
  and tells you where. Reopen it with `vim <path-from-error>`, fix, save.
- `:wq` triggers the API call. Watch the terminal — a 201 is a win.

## The 10 commands you'll use in 90% of exam moments

1. `i` — enter insert mode
2. `Esc` — leave insert mode
3. `:wq` — save and quit
4. `:q!` — bail out without saving
5. `dd` — delete a line
6. `yy` `p` — copy and paste a line
7. `u` — undo
8. `/foo` — search
9. `:%s/foo/bar/g` — replace all
10. `gg=G` — auto-indent the whole file

Drill these in a throwaway YAML until they're reflex. Everything else is a
bonus.

## One-page practice drill

Open any pod manifest. In under 60 seconds:

1. Jump to line 1 (`gg`).
2. Find `image:` (`/image:`).
3. Change `nginx` to `nginx:1.25` on that line (`cw` or `:s/nginx/nginx:1.25/`).
4. Add a new env var block under `env:` (navigate, `o`, type it).
5. Save with `:w`, verify with `kubectl apply --dry-run=client -f file.yaml`.
6. If the dry-run errors, read the line number, jump (`:<N>`), fix.
7. Reapply, save, quit.

If you can do this in a minute on every manifest in this repo's
`exercise-files/`, you're ready for the vim portion of the CKA.

## See also

- [TUTORIAL-KIND.md](../TUTORIAL-KIND.md) — the lab walkthrough that gives
  you YAML to practice on.
- `kubectl explain <resource> --recursive` — for when you forget a field
  name mid-edit.

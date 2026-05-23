"""Convert a CKA Course 2 markdown demo-runbook into a JupyterLab notebook.

Usage:
    uv run python tools/runbook_to_ipynb.py <path-to-runbook.md> [--out <ipynb>]

Pedagogy:
    The runbook is authoritative. The notebook is a derived, executable mirror
    aimed at on-camera recording. One numbered Step = one executable cell when
    the Step body contains a fenced code block; otherwise the Step becomes a
    markdown cell. Demo headers, exam tips, money shots, and camera checklists
    all become markdown cells.

Cell type mapping:
    ```powershell ...```  ->  code cell, raw body, kernel = .net-powershell
    ```bash ...```        ->  code cell, wrapped as: ssh <host> @'...'@
    ```yaml ...```        ->  code cell: here-string -> Out-File; scp to control1
                              if the next step references the file
    ```text ...```        ->  markdown cell rendered as expected-output block

Host routing for bash blocks:
    Default host = control1. Overridden when the enclosing H2 or H3 mentions
    "worker1", "worker2", "all nodes", or "all three nodes". For "all nodes"
    we emit a pwsh foreach loop. The detection is intentionally conservative;
    when in doubt, default to control1 — the recorder can edit on the fly.

Destructive-cell tagging:
    Any cell whose code body matches DESTRUCTIVE_RE earns the `destructive`
    metadata tag. assets/recording.css styles those cells with a red border
    so Tim sees the warning mid-recording.

Idempotency:
    Running this script twice on the same input produces byte-identical .ipynb
    output. We freeze nbformat metadata, sort tags, and never emit cell-level
    execution counts or outputs.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

import nbformat
from markdown_it import MarkdownIt
from markdown_it.token import Token


# ---------------------------------------------------------------------------
# Constants — kernel metadata, language regexes, etc.
# ---------------------------------------------------------------------------

KERNEL_NAME = ".net-powershell"
KERNEL_DISPLAY = ".NET (PowerShell)"
KERNEL_LANGUAGE = "powershell"

DESTRUCTIVE_RE = re.compile(
    r"\b("
    r"kubeadm\s+init"
    r"|kubeadm\s+join"
    r"|kubeadm\s+reset"
    r"|vagrant\s+destroy"
    r"|vagrant\s+halt"
    r"|cka-restore"
    r"|cka-down"
    r"|cka-destroy"
    r"|etcdctl\s+snapshot\s+restore"
    r"|kubectl\s+delete\s+(node|namespace|ns|all)"
    r"|rm\s+-rf"
    r")\b",
    re.IGNORECASE,
)

# Commands that block the kernel waiting for keyboard input. Tagging these
# lets recording.css gray them out and the talk track says "switch to terminal."
INTERACTIVE_RE = re.compile(
    r"(?:^|[\s;|&])("
    r"vim?|nvim|nano|emacs"
    r"|less|more"
    r"|top|htop|watch"
    r"|vagrant\s+ssh\b"
    r"|crictl\s+(exec|attach)"
    r"|kubectl\s+(exec|attach|port-forward|edit|proxy)"
    r")\b",
    re.IGNORECASE,
)

WORKER1_RE = re.compile(r"\bworker1\b", re.IGNORECASE)
WORKER2_RE = re.compile(r"\bworker2\b", re.IGNORECASE)
ALL_NODES_RE = re.compile(r"\ball (three )?(nodes|VMs)\b|\beach (node|VM)\b", re.IGNORECASE)

# Heading-text -> tag mapping. Lowercase substring match.
SECTION_TAG_RULES = [
    ("pre-flight", "pre-flight"),
    ("preflight", "pre-flight"),
    ("camera checklist", "pre-flight"),
    ("click path", "reference"),
    ("money shot", "narration"),
    ("exam tip", "exam-tip"),
    ("pro tip", "exam-tip"),
    ("narrate", "narration"),
]


# ---------------------------------------------------------------------------
# AST: a Section is one H2/H3 heading + the tokens that follow it until the
# next heading at the same or higher level. The walker flattens the runbook
# into a list of Sections, then each Section becomes one or more notebook
# cells based on what's inside it.
# ---------------------------------------------------------------------------

@dataclass
class Section:
    level: int                  # 1, 2, or 3
    title: str                  # the heading text, plain string
    title_inline: list[Token] = field(default_factory=list)  # for rich rendering
    body_tokens: list[Token] = field(default_factory=list)   # everything between this heading and the next
    parent_h2_title: str = ""   # nearest H2 ancestor title (for host routing)


def parse_runbook(md_text: str) -> tuple[str, list[Section]]:
    """Parse markdown into (notebook_title, sections).

    The notebook_title is the H1 text. Everything before the first H2 (the
    H1 + any intro prose) becomes Section(level=1).
    """
    md = MarkdownIt("commonmark", {"html": False}).enable("table")
    tokens = md.parse(md_text)

    sections: list[Section] = []
    current: Section | None = None
    parent_h2_title = ""

    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t.type == "heading_open" and t.tag in ("h1", "h2", "h3"):
            # Flush previous section
            if current is not None:
                sections.append(current)
            level = int(t.tag[1])
            # The inline tokens follow at index i+1; closing tag at i+2.
            inline = tokens[i + 1]
            # Render with inline formatter so backticked code (`cd`), bold, etc.
            # all survive into the heading text.
            title_text = render_inline_to_markdown(inline.children or [])
            # Track H2 ancestor so H3 sections can know their parent.
            if level == 2:
                parent_h2_title = title_text
            current = Section(
                level=level,
                title=title_text,
                title_inline=inline.children or [],
                parent_h2_title=parent_h2_title if level == 3 else "",
            )
            i += 3  # skip heading_open, inline, heading_close
            continue
        if current is not None:
            current.body_tokens.append(t)
        i += 1
    if current is not None:
        sections.append(current)

    if not sections or sections[0].level != 1:
        raise ValueError("Runbook must start with an H1 heading.")
    notebook_title = sections[0].title
    return notebook_title, sections


# ---------------------------------------------------------------------------
# Section -> cells conversion
# ---------------------------------------------------------------------------

def render_inline_to_markdown(tokens: Iterable[Token]) -> str:
    """Render a list of inline-block tokens back to CommonMark markdown.

    markdown-it-py's renderer does the full job for us; we only need to wrap
    the tokens in a pseudo-block context. We do this by emitting markdown for
    the original block tokens directly. Simpler: just slice the original text.

    But we don't have the original text here. So we reconstruct from tokens.
    For our runbooks (which avoid nested constructs), this works.
    """
    parts: list[str] = []
    for t in tokens:
        if t.type == "text":
            parts.append(t.content)
        elif t.type == "code_inline":
            parts.append(f"`{t.content}`")
        elif t.type == "strong_open":
            parts.append("**")
        elif t.type == "strong_close":
            parts.append("**")
        elif t.type == "em_open":
            parts.append("*")
        elif t.type == "em_close":
            parts.append("*")
        elif t.type == "softbreak":
            parts.append("\n")
        elif t.type == "hardbreak":
            parts.append("  \n")
        elif t.type == "link_open":
            href = next((a[1] for a in t.attrs if a[0] == "href"), "") if isinstance(t.attrs, list) else (t.attrs or {}).get("href", "")
            parts.append(f"[")
            t._link_href = href  # type: ignore[attr-defined]
        elif t.type == "link_close":
            parts.append(f"]")
        else:
            # Fall back to raw content if present
            if t.content:
                parts.append(t.content)
    return "".join(parts)


def tokens_to_markdown(body_tokens: list[Token]) -> str:
    """Reconstruct markdown body text from a Section's body tokens.

    Handles: paragraphs, fenced code blocks, lists, blockquotes, tables.
    Used for markdown cells. We skip fenced code blocks since those are
    pulled out separately into code cells.
    """
    out: list[str] = []
    i = 0
    while i < len(body_tokens):
        t = body_tokens[i]

        if t.type == "paragraph_open":
            # Inline content is the next token; closing tag follows.
            inline = body_tokens[i + 1]
            text = render_inline_to_markdown(inline.children or [])
            out.append(text + "\n")
            i += 3
            continue

        if t.type == "fence":
            # Code blocks are emitted as separate cells, so skip here.
            # We DO include the rendered code block in expected-output text cells.
            if (t.info or "").strip().lower() == "text":
                # Expected-output rendered inline as a quoted block.
                content = (t.content or "").rstrip()
                quoted = "\n".join(f"> {line}" if line else ">" for line in content.split("\n"))
                out.append(f"**Expected output:**\n\n{quoted}\n")
            i += 1
            continue

        if t.type == "bullet_list_open":
            # Find matching close
            depth = 1
            j = i + 1
            lines: list[str] = []
            while j < len(body_tokens) and depth > 0:
                tt = body_tokens[j]
                if tt.type == "bullet_list_open":
                    depth += 1
                elif tt.type == "bullet_list_close":
                    depth -= 1
                elif tt.type == "list_item_open":
                    # Find the inline content inside this list item
                    k = j + 1
                    item_text_parts: list[str] = []
                    item_depth = 1
                    while k < len(body_tokens) and item_depth > 0:
                        kt = body_tokens[k]
                        if kt.type == "list_item_open":
                            item_depth += 1
                        elif kt.type == "list_item_close":
                            item_depth -= 1
                            if item_depth == 0:
                                break
                        elif kt.type == "paragraph_open":
                            inline_k = body_tokens[k + 1]
                            item_text_parts.append(render_inline_to_markdown(inline_k.children or []))
                            k += 2
                        k += 1
                    if item_text_parts:
                        lines.append(f"- {' '.join(item_text_parts)}")
                j += 1
            if lines:
                out.append("\n".join(lines) + "\n")
            i = j + 1
            continue

        if t.type == "ordered_list_open":
            # Similar to bullet list but with numbers
            depth = 1
            j = i + 1
            lines: list[str] = []
            n = 1
            while j < len(body_tokens) and depth > 0:
                tt = body_tokens[j]
                if tt.type == "ordered_list_open":
                    depth += 1
                elif tt.type == "ordered_list_close":
                    depth -= 1
                elif tt.type == "list_item_open" and depth == 1:
                    k = j + 1
                    item_parts: list[str] = []
                    item_depth = 1
                    while k < len(body_tokens) and item_depth > 0:
                        kt = body_tokens[k]
                        if kt.type == "list_item_open":
                            item_depth += 1
                        elif kt.type == "list_item_close":
                            item_depth -= 1
                            if item_depth == 0:
                                break
                        elif kt.type == "paragraph_open":
                            inline_k = body_tokens[k + 1]
                            item_parts.append(render_inline_to_markdown(inline_k.children or []))
                            k += 2
                        k += 1
                    if item_parts:
                        lines.append(f"{n}. {' '.join(item_parts)}")
                        n += 1
                j += 1
            if lines:
                out.append("\n".join(lines) + "\n")
            i = j + 1
            continue

        if t.type == "blockquote_open":
            depth = 1
            j = i + 1
            qlines: list[str] = []
            while j < len(body_tokens) and depth > 0:
                tt = body_tokens[j]
                if tt.type == "blockquote_open":
                    depth += 1
                elif tt.type == "blockquote_close":
                    depth -= 1
                elif tt.type == "paragraph_open":
                    inline_j = body_tokens[j + 1]
                    qlines.append(render_inline_to_markdown(inline_j.children or []))
                    j += 2
                j += 1
            if qlines:
                quoted = "\n".join(f"> {line}" for line in "\n".join(qlines).split("\n"))
                out.append(quoted + "\n")
            i = j + 1
            continue

        if t.type == "hr":
            out.append("\n---\n")

        if t.type == "table_open":
            depth = 1
            j = i + 1
            rows: list[list[str]] = []
            current_row: list[str] = []
            is_header = False
            while j < len(body_tokens) and depth > 0:
                tt = body_tokens[j]
                if tt.type == "table_open":
                    depth += 1
                elif tt.type == "table_close":
                    depth -= 1
                elif tt.type == "thead_open":
                    is_header = True
                elif tt.type == "thead_close":
                    is_header = False
                elif tt.type == "tr_open":
                    current_row = []
                elif tt.type == "tr_close":
                    rows.append(current_row)
                    if is_header:
                        rows.append(["---"] * len(current_row))
                elif tt.type == "inline":
                    current_row.append(render_inline_to_markdown(tt.children or []).strip())
                j += 1
            if rows:
                out.append("\n".join("| " + " | ".join(r) + " |" for r in rows) + "\n")
            i = j + 1
            continue

        i += 1
    return "\n".join(out).strip()


def detect_host_for_bash(parent_h2: str, section_title: str) -> str:
    """Pick the SSH target host based on enclosing heading text.

    Heuristic order (first match wins):
      1) "all nodes" / "each node"  -> "ALL"  (caller emits a foreach loop)
      2) "worker2"                    -> worker2
      3) "worker1"                    -> worker1
      4) default                      -> control1
    """
    context = f"{parent_h2} {section_title}"
    if ALL_NODES_RE.search(context):
        return "ALL"
    if WORKER2_RE.search(context):
        return "worker2"
    if WORKER1_RE.search(context):
        return "worker1"
    return "control1"


def wrap_bash_for_pwsh(bash_body: str, host: str) -> str:
    """Wrap a bash code block so it runs under the PowerShell kernel via ssh.

    For a single host: ssh <host> @'<body>'@
    For ALL: foreach loop over control1/worker1/worker2.

    We use the pwsh single-quoted here-string @'...'@ because:
      - $ is literal (no PowerShell variable expansion ambushes our bash)
      - " is literal (no escape needed inside the bash body)
      - Only ' would need doubling, which is exceedingly rare in our runbooks
    """
    # Defensive: if the bash body itself contains @' or '@, fall back to
    # base64 transit. Runbooks today don't do this, but the safety net is cheap.
    if "@'" in bash_body or "'@" in bash_body:
        import base64
        b64 = base64.b64encode(bash_body.encode("utf-8")).decode("ascii")
        decode = f'$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("{b64}")))'
        if host == "ALL":
            return (
                f"foreach ($h in 'control1','worker1','worker2') {{\n"
                f"    Write-Host \"--- $h ---\" -ForegroundColor Cyan\n"
                f"    ssh $h {decode}\n"
                f"}}"
            )
        return f"ssh {host} {decode}"

    if host == "ALL":
        return (
            "foreach ($h in 'control1','worker1','worker2') {\n"
            "    Write-Host \"--- $h ---\" -ForegroundColor Cyan\n"
            "    ssh $h @'\n"
            f"{bash_body.rstrip()}\n"
            "'@\n"
            "}"
        )
    return f"ssh {host} @'\n{bash_body.rstrip()}\n'@"


def wrap_yaml_for_pwsh(yaml_body: str, section_title: str) -> str:
    """A YAML block becomes a here-string written to a local file, then scp'd.

    File name comes from the section title (e.g., "Edit init.yaml" -> init.yaml),
    or falls back to a generic name.
    """
    # Try to extract a filename from the section title
    m = re.search(r"([a-zA-Z0-9_\-]+\.ya?ml)", section_title)
    fname = m.group(1) if m else "config.yaml"
    return (
        f"@'\n{yaml_body.rstrip()}\n'@ | "
        f"Out-File -FilePath \"$env:TEMP\\{fname}\" -Encoding utf8\n"
        f"scp \"$env:TEMP\\{fname}\" control1:/tmp/{fname}"
    )


def extract_code_blocks(body_tokens: list[Token]) -> list[tuple[str, str]]:
    """Return [(language, body), ...] for every fence in body_tokens."""
    out: list[tuple[str, str]] = []
    for t in body_tokens:
        if t.type == "fence":
            lang = (t.info or "").strip().lower()
            out.append((lang, t.content))
    return out


def derive_section_tags(parent_h2: str, section_title: str) -> list[str]:
    """Apply SECTION_TAG_RULES to figure out which static tags this cell earns."""
    tags: set[str] = set()
    context = f"{parent_h2} {section_title}".lower()
    for substring, tag in SECTION_TAG_RULES:
        if substring in context:
            tags.add(tag)
    # Demo-N tag from H2 like "Demo 3 — Verify..."
    m = re.search(r"\bdemo\s+(\d+)\b", parent_h2 or section_title, re.IGNORECASE)
    if m:
        tags.add(f"demo-{m.group(1)}")
    return sorted(tags)


def section_to_cells(section: Section) -> list[dict]:
    """Convert one Section into a list of notebook cell dicts.

    Layout: optional markdown header cell (heading + narration), then one code
    cell per fenced code block in the section. Code-free sections collapse to
    a single markdown cell.
    """
    cells: list[dict] = []

    # Header markdown cell — always emitted so the H2/H3 heading is visible
    # and any prose before the first code block is captured.
    heading_md = f"{'#' * section.level} {section.title}".strip()
    narration_md = tokens_to_markdown(section.body_tokens)
    header_text = heading_md + (("\n\n" + narration_md) if narration_md else "")
    base_tags = derive_section_tags(section.parent_h2_title, section.title)

    cells.append(make_markdown_cell(header_text, tags=base_tags))

    # One code cell per fence
    for lang, body in extract_code_blocks(section.body_tokens):
        cell = code_block_to_cell(lang, body, section, base_tags)
        if cell is not None:
            cells.append(cell)

    return cells


def code_block_to_cell(
    lang: str, body: str, section: Section, base_tags: list[str]
) -> dict | None:
    """Turn one fenced code block into a notebook cell (code or markdown).

    Returns None for languages we deliberately skip (`text` is consumed into
    the header markdown cell).
    """
    tags = list(base_tags)
    body = body.rstrip()

    if lang == "powershell" or lang == "pwsh":
        cell_body = body
    elif lang == "bash" or lang == "shell" or lang == "sh":
        host = detect_host_for_bash(section.parent_h2_title, section.title)
        cell_body = wrap_bash_for_pwsh(body, host)
        tags.append(f"host-{host.lower()}" if host != "ALL" else "host-all")
    elif lang == "yaml":
        cell_body = wrap_yaml_for_pwsh(body, section.title)
        tags.append("writes-file")
    elif lang == "text" or lang == "":
        # Already rendered into the markdown header by tokens_to_markdown.
        return None
    else:
        # Unknown language — emit as a raw markdown code block so it's still visible
        return make_markdown_cell(f"```{lang}\n{body}\n```", tags=base_tags)

    if DESTRUCTIVE_RE.search(body) or DESTRUCTIVE_RE.search(cell_body):
        tags.append("destructive")
    if INTERACTIVE_RE.search(body):
        tags.append("interactive")

    return make_code_cell(cell_body, tags=sorted(set(tags)))


# ---------------------------------------------------------------------------
# nbformat helpers — keep cell output empty/deterministic for byte stability
# ---------------------------------------------------------------------------

def _stable_cell_id(source: str, kind: str, index_seed: list[int]) -> str:
    """Deterministic, byte-stable cell ID.

    nbformat 5+ requires an `id` field. We make it a hash of (kind, ordinal,
    source) so re-running the parser on identical input produces identical IDs.
    The ordinal prevents collisions when two cells happen to share source text.
    """
    import hashlib
    index_seed[0] += 1
    h = hashlib.sha256(f"{kind}:{index_seed[0]}:{source}".encode("utf-8")).hexdigest()[:12]
    return f"{kind[0]}-{h}"


# Cell-counter shared across calls so IDs are unique even for duplicate cell text.
_CELL_COUNTER: list[int] = [0]


def make_markdown_cell(source: str, tags: list[str] | None = None) -> dict:
    cell = nbformat.v4.new_markdown_cell(source=source)
    cell["id"] = _stable_cell_id(source, "markdown", _CELL_COUNTER)
    if tags:
        cell["metadata"]["tags"] = sorted(set(tags))
    return cell


def make_code_cell(source: str, tags: list[str] | None = None) -> dict:
    cell = nbformat.v4.new_code_cell(source=source)
    cell["id"] = _stable_cell_id(source, "code", _CELL_COUNTER)
    cell["execution_count"] = None
    cell["outputs"] = []
    if tags:
        cell["metadata"]["tags"] = sorted(set(tags))
    return cell


def build_notebook(title: str, sections: list[Section]) -> nbformat.NotebookNode:
    # Reset cell counter so two notebooks in one Python session start at 1.
    _CELL_COUNTER[0] = 0
    nb = nbformat.v4.new_notebook()
    nb.metadata["kernelspec"] = {
        "name": KERNEL_NAME,
        "display_name": KERNEL_DISPLAY,
        "language": KERNEL_LANGUAGE,
    }
    nb.metadata["language_info"] = {
        "name": KERNEL_LANGUAGE,
        "file_extension": ".ps1",
        "mimetype": "text/x-powershell",
        "pygments_lexer": "powershell",
    }
    # Generator stamp helps anyone reading the .ipynb know it's derived.
    nb.metadata["cka_runbook"] = {
        "generator": "tools/runbook_to_ipynb.py",
        "source_format": "markdown runbook",
    }

    cells: list[dict] = []

    # H1 section becomes the title + intro markdown
    h1 = sections[0]
    title_cell_text = f"# {title}\n\n" + tokens_to_markdown(h1.body_tokens)
    cells.append(make_markdown_cell(title_cell_text.strip(), tags=["title"]))

    # Walk H2 / H3 sections
    for s in sections[1:]:
        cells.extend(section_to_cells(s))

    nb["cells"] = cells
    return nb


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def derive_output_path(runbook_path: Path, notebooks_dir: Path) -> Path:
    """c02-m01-demo-runbook.md -> c02-m01-<topic-slug>.ipynb

    Topic slug comes from the runbook's parent directory name with the leading
    "mXX-" stripped (e.g. m01-linux-host-prep -> linux-host-prep, but we keep
    the original course/module prefix from the filename).
    """
    stem = runbook_path.stem  # e.g. c02-m01-demo-runbook
    m = re.match(r"^(c\d{2}-m\d{2})", stem)
    prefix = m.group(1) if m else stem
    parent_dir_name = runbook_path.parent.name  # e.g. m01-linux-host-prep
    topic = re.sub(r"^m\d+-", "", parent_dir_name)
    return notebooks_dir / f"{prefix}-{topic}.ipynb"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("runbook", type=Path, help="Path to the markdown runbook")
    p.add_argument("--out", type=Path, default=None, help="Output .ipynb path")
    args = p.parse_args(argv)

    if not args.runbook.exists():
        print(f"ERROR: runbook not found: {args.runbook}", file=sys.stderr)
        return 1

    md_text = args.runbook.read_text(encoding="utf-8")
    title, sections = parse_runbook(md_text)
    nb = build_notebook(title, sections)

    notebooks_dir = Path(__file__).resolve().parent.parent
    out_path = args.out or derive_output_path(args.runbook, notebooks_dir)
    nbformat.write(nb, out_path)

    n_cells = len(nb["cells"])
    n_code = sum(1 for c in nb["cells"] if c["cell_type"] == "code")
    n_destructive = sum(
        1 for c in nb["cells"]
        if c["cell_type"] == "code" and "destructive" in c.get("metadata", {}).get("tags", [])
    )
    print(f"Wrote {out_path.name}: {n_cells} cells ({n_code} code, {n_destructive} destructive)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

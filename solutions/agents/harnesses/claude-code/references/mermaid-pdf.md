# PDF Generation from Markdown with Mermaid Diagrams

## Pipeline: mmdc → fix captions → pandoc

1. **Render mermaid as PDF** (not SVG/PNG): `mmdc -i input.md -o rendered.md -e pdf --outputFormat pdf --pdfFit`
   - Uses Puppeteer (headless Chrome) — only reliable way to render mermaid's `foreignObject` HTML text
   - Produces true vector output, sharp at any zoom
2. **Fix captions**: mmdc outputs generic `![diagram](./file.pdf)` — sed/replace with descriptive alt-text before pandoc
3. **pandoc to PDF**: use xelatex engine with desired fonts/styling
4. **Clean up**: remove intermediate `rendered-*.pdf` and `rendered.md` files

## Mermaid SVG text rendering — key gotcha

Mermaid uses HTML `<foreignObject>` inside SVG for all text. Most SVG converters **cannot render this**:
- `cairosvg` — shapes only, no text
- `inkscape` — shapes only, no text, floods stderr with `foreignObject` warnings
- `mmdc -e pdf` (Puppeteer) — works perfectly, full text rendering

## pandoc options (known-good)

```
--pdf-engine=xelatex
-V geometry:margin=1in
-V colorlinks=true -V linkcolor=NavyBlue -V urlcolor=NavyBlue
-V 'monofont=Source Code Pro' -V 'mainfont=Roboto'
-V fontsize=11pt -V linestretch=1.25
--table-of-contents --toc-depth=3
--highlight-style=tango          # light mode
-H header.tex                    # for code block line wrapping
```

## Code block line wrapping (header.tex)

```latex
\usepackage{fvextra}
\DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,commandchars=\\\{\}}
```

Wraps long lines with `↪` marker. Still better to manually break long source lines in markdown to avoid it.

## Font notes
- Roboto lacks `→` (U+2192) — use "to" in captions instead of arrows
- Source Code Pro works well for monospace
- highlight styles: `tango` (light), `breezedark` (dark), `pygments`, `kate`, `monochrome`

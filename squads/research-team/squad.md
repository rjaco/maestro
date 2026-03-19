---
name: "research-team"
description: "Research and analysis team for competitive analysis, market research, and technical evaluation. Researcher gathers raw data, analyst synthesizes insights, writer produces the final report."
version: "1.0.0"
author: "Maestro"
agents:
  - role: researcher
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Raw data collection from primary and secondary sources. Search the web for facts, statistics, competitor information, technical documentation, and primary sources. Do not analyze or draw conclusions — collect and organize. Produce a structured research dossier: sources cited, data points extracted, gaps flagged. The analyst works from this dossier, not from independent searches."
    tools: [Read, Write, Grep, Glob, WebSearch, WebFetch]
  - role: analyst
    agent: "maestro:maestro-implementer"
    model: opus
    focus: "Deep synthesis and insight generation from the research dossier. Identify patterns, contradictions, and gaps. Draw conclusions grounded in the data — no speculation without evidence. Produce a structured analysis: key findings, supporting evidence, confidence levels, and open questions. The writer shapes this analysis into a report, but does not add new conclusions."
    tools: [Read, Write, Grep, Glob]
  - role: writer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Transform the analyst's findings into a clear, well-structured report. Organize by audience and purpose. Use plain language, concrete examples, and logical flow. Do not introduce new analysis or conclusions — faithfully represent the analyst's output. Add structure, narrative, and readability. Cite sources from the research dossier throughout."
    tools: [Read, Edit, Write, Grep, Glob]
orchestration_mode: sequential
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Researcher produces a structured dossier with cited sources before analysis begins"
  - "Every conclusion in the analyst's output is traceable to a specific data point in the dossier"
  - "No unsourced statistics or unattributed claims in the final report"
  - "Writer does not introduce new analysis — all conclusions originate from the analyst"
  - "Final report has a clear structure: executive summary, key findings, evidence, and recommendations"
---

# Squad: Research Team

## Purpose

Structured research and analysis that produces defensible, evidence-based reports. This squad enforces a separation between data collection, synthesis, and communication: a researcher gathers raw material, an analyst draws conclusions from the evidence, and a writer shapes those conclusions into a readable report.

Use this squad when the output is a knowledge artifact rather than code: competitive landscape analysis, technology evaluation reports, market research, vendor comparisons, architectural decision records backed by external research, or any work where rigor and traceability matter.

Do not use this squad for exploratory spikes or quick lookups. Use it when the research output will inform significant decisions and must withstand scrutiny.

## Agents

### researcher (sonnet)

The data collector. Searches widely, organizes carefully, draws no conclusions.

Responsibilities:
- Execute web searches for primary sources, competitor information, technical documentation, and data
- Fetch and extract relevant content from identified URLs
- Organize findings into a structured dossier: source URL, date accessed, key data points extracted, relevance to the research question
- Flag gaps: what was looked for but not found, what sources are paywalled or inaccessible
- Note contradictions between sources without resolving them — that is the analyst's job
- Do not editorialize or interpret. Collect and cite.

Dossier format:
```
## Research Dossier: [Topic]

### Sources
1. [Title] — [URL] (accessed [date])
   Key data points: [bullet list of extracted facts/statistics]

2. ...

### Data Summary
[Organized tabular or structured view of collected data points by theme]

### Gaps
- [What was searched for but not found]
- [Sources that require access not available]

### Contradictions
- [Conflicting data points between sources, both preserved without resolution]
```

### analyst (opus)

The insight engine. Synthesizes the dossier into conclusions the decision-maker can act on.

Responsibilities:
- Read the full research dossier before drawing any conclusions
- Identify patterns across data points: trends, outliers, convergences
- Surface contradictions and assess their implications — which source is more credible, and why
- Draw conclusions with explicit confidence levels: high (multiple concordant sources), medium (single strong source), low (inferred from indirect evidence)
- Identify what the data does not say — critical gaps that affect the reliability of conclusions
- Produce a structured analysis with: key findings (prioritized), supporting evidence per finding, confidence level, and open questions that remain unanswered
- Every conclusion must cite a specific data point from the dossier. No unsourced conclusions.

Analysis format:
```
## Analysis: [Topic]

### Key Findings
1. [Finding — stated as a specific, falsifiable claim]
   Evidence: [data points from dossier]
   Confidence: high | medium | low
   Why: [reasoning that connects evidence to finding]

2. ...

### Open Questions
- [What remains unanswered and why it matters]

### Caveats
- [Limitations of the data that affect reliability of findings]
```

### writer (sonnet)

The communicator. Transforms analysis into a report that a non-analyst can read and act on.

Responsibilities:
- Open with an executive summary: the 3-5 most important findings in plain language, no jargon
- Structure the body by decision relevance: what matters most comes first
- Use concrete language: specific numbers, named competitors, dates, not vague generalizations
- Cite the original sources from the dossier throughout the report — not just in a bibliography
- Preserve all confidence levels from the analyst's output — do not upgrade "medium confidence" claims to certainties
- End with a recommendations section if the brief asked for one
- Do not introduce new analysis. If a conclusion is not in the analyst's output, it does not appear in the report.

## Workflow

```
researcher → analyst → writer
```

1. **researcher** receives the research question and produces a structured dossier: organized sources, extracted data points, gaps, and contradictions.

2. **analyst** receives the full dossier and produces a structured analysis: key findings with evidence, confidence levels, and open questions.

3. **writer** receives both the dossier and the analysis and produces the final report: executive summary, structured body, cited sources, and recommendations.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: context about the project the research serves
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **analyst** receives the researcher's full dossier as injected context
- **writer** receives both the dossier and the analyst's full analysis as injected context

## Quality Gates

1. **Dossier completeness** — Analyst must not run until the researcher has produced a dossier with at least 3 cited sources and an explicit gaps section.
2. **Evidence traceability** — Every conclusion in the analysis must cite a specific data point from the dossier. Unsourced conclusions are a gate failure.
3. **Confidence labeling** — All findings in the analysis and report must carry explicit confidence levels. No confidence label = rejected.
4. **Writer fidelity** — The writer must not introduce new conclusions. If a claim appears in the report but not in the analysis, it is a gate failure.
5. **Report structure** — Final report must include: executive summary, findings body with citations, and (if requested) recommendations.

## When to Use

- Competitive landscape analysis: who are the key players, what are their strengths and gaps
- Technology evaluation: comparing frameworks, databases, vendors, or architectural approaches
- Market research: sizing, trends, customer segments, pricing benchmarks
- Technical due diligence: evaluating a codebase, team, or vendor before a significant commitment
- Architecture decision records that require external evidence (e.g., "why we chose X over Y")
- Any research output that will be shared with stakeholders or used to justify significant decisions

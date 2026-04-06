---
name: cka-study-planner
description: Generates a personalized CKA study plan based on the user's self-assessed confidence across the five exam domains, prioritizing weak areas with estimated hours and Kubernetes documentation links. Use when the user asks for a study plan, is unsure what to study, or wants exam prep guidance.
---

# Skill: cka.study_planner.personalized

**Description:** Generates a personalized CKA study plan based on the user's self-assessed confidence across the five CKA exam domains, prioritizing weak areas with estimated hours and official documentation links.

## Grounding

**Required sources:**

- `references/cka-objectives.md` (CKA v1.35 curriculum, five domains with weights)
- Kubernetes official documentation (for current documentation links)

**Allowed reference domains:**

- kubernetes.io/docs
- kubernetes.io/blog
- helm.sh/docs
- gateway-api.sigs.k8s.io

## Workflow

1. **Present domains with weights.** Show the five CKA exam domains and their weight percentages:

   | Domain | Exam Weight |
   | --- | --- |
   | Cluster Architecture, Installation and Configuration | 25% |
   | Workloads and Scheduling | 15% |
   | Services and Networking | 20% |
   | Storage | 10% |
   | Troubleshooting | 30% |

2. **Ask for confidence ratings.** Ask the user to rate their confidence in each domain using one of these levels:
   - **Strong** -- comfortable with most objectives; needs only light review.
   - **Moderate** -- familiar with the concepts but needs targeted practice.
   - **Weak** -- limited experience; needs focused study.
   - **Unknown** -- not sure; treat as weak.

3. **Generate a prioritized study plan.** Based on the user's ratings:
   - Order domains from weakest to strongest.
   - Within equal confidence levels, prioritize domains with higher exam weight.
   - For each domain, provide:
     - Estimated study hours (see table below).
     - Two to three specific kubernetes.io/docs links for key topics.
     - Key objectives to focus on (from `references/cka-objectives.md`).
     - Recommended practice scenario types.
   - Include a total estimated hours range at the bottom.

4. **Highlight February 2025 additions.** Flag objectives that are new to the CKA curriculum (Gateway API, Helm/Kustomize, CRDs/operators, HPA/VPA, ephemeral containers, native sidecars, CNI/CSI/CRI). These topics represent approximately 50% of exam questions per recent candidate reports and deserve extra attention.

5. **Offer to start practicing.** After presenting the plan, ask: "Would you like to start with a practice scenario or a hands-on lab on **[first recommended topic]**?"

## Study hour estimates

| Confidence | Estimated Hours |
| --- | --- |
| Weak / Unknown | 10-15 hours |
| Moderate | 5-8 hours |
| Strong | 2-3 hours |

Scale proportionally by domain weight. Troubleshooting (30%) at Weak warrants 12-15 hours. Storage (10%) at Weak warrants 4-6 hours.

| Domain | Exam Weight | Weak Hours | Moderate Hours | Strong Hours |
| --- | --- | --- | --- | --- |
| Troubleshooting | 30% | 12-15 | 6-8 | 3-4 |
| Cluster Architecture, Installation and Configuration | 25% | 10-12 | 5-7 | 2-3 |
| Services and Networking | 20% | 8-10 | 4-6 | 2-3 |
| Workloads and Scheduling | 15% | 6-8 | 3-5 | 1-2 |
| Storage | 10% | 4-6 | 2-3 | 1-2 |

## Output format

```markdown
## Your Personalized CKA Study Plan

### Priority 1: [Domain Name] (exam weight: XX%)

**Your confidence:** [rating]
**Estimated study time:** X-X hours

**Focus objectives:**
- [Objective 1]
- [Objective 2]
- [Objective 3]

**New in February 2025:** [Flag any new curriculum additions in this domain]

**Recommended documentation:**
- [Topic title](kubernetes.io/docs URL)
- [Topic title](kubernetes.io/docs URL)

**Recommended practice:** [Scenario types to request from cka-scenario-creator]

---

### Priority 2: [Domain Name] (exam weight: XX%)

... (repeat for each domain)

---

**Total estimated study time:** XX-XX hours

### Exam day reminders

- You have 120 minutes for approximately 17 tasks. Budget about 7 minutes per task.
- Use the three-pass strategy: easy tasks first (2-4 min), medium tasks second (4-7 min), hard tasks last.
- Every task starts with a context-switch command. Forgetting to switch context is the most common silent error.
- The `k` alias for kubectl and bash autocompletion are pre-configured.
- Bookmark key documentation pages before the exam.

Ready to start? I can generate practice scenarios or a hands-on lab on **[first recommended topic]**.
```

## Guardrails

- Do not skip any of the five domains. Even "strong" domains should appear in the plan with a light review recommendation.
- Do not invent documentation URLs. Provide real kubernetes.io/docs paths.
- Treat "unknown" confidence the same as "weak."
- Always use current Kubernetes terminology. See `.github/copilot-instructions.md`.
- No contractions.

## Delivery rules

Deliver the full study plan in a single message after the user provides their confidence ratings. Do not split the plan across multiple messages.

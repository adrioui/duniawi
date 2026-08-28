### Authoring or modifying a skill

**You own the skill's voice.** Agent-facing prose has a higher bar than human prose; unhelpful sentences become instructions.

1. **Follow the Agent Skills standard.** Every skill lives in `skills/<kebab-case-name>/SKILL.md`. YAML frontmatter requires `name` (kebab-case, matches directory) and `description`. Optional: `whenToUse`. Strip Cursor-only frontmatter (`mode`, `icon`, `color`, `disable-model-invocation`) unless its semantics matter in DSH.
2. **Keep it short.** SKILL.md under ~180 lines. Playbooks 10–30 lines. Terse imperative voice — say what to do, skip the reason. Explain only when the rule is confusing without one.
3. **Validate the skill.** Frontmatter has `name` and `description`, referenced files exist, cross-skill links resolve. `name` must be kebab-case and match the directory name exactly.
4. **Test if structural; skip if subjective.** Structural skills get at least one smoke test. Subjective prose skills get a review pass.
5. **Bundle one level deep.** A skill directory contains `SKILL.md` and at most one level of sub-files (playbooks/, references/). No deeper nesting.
6. **Delegate to other skills by path.** Don't restate their content. Reference `principle-encode-lessons-in-structure` by name, not by copy.
7. **Run Opening a PR.** When the skill is ready, open a PR per `playbooks/opening-a-pr.md`.

When in doubt, delete; prose earns its keep by changing a decision. A workflow you keep hitting but isn't captured → propose a new skill.

**Reply:** summary of the skill, key design decisions, validation notes.
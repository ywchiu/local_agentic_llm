# Experiment: Group 1 Python Fundamentals — Initial Run

**Date:** 2026-03-19
**Group:** group1_python_fundamentals
**OpenCode:** v1.2.20
**Provider:** OpenRouter
**Timeout:** 300s per test

## Summary

12 models tested successfully. 5 models (Qwen 3.5 sub-variants, Gemma 3-27B, Qwen3-Coder-Next) were not available in OpenCode's model registry.

| Rank | Model | Score | Cost | Time | Tokens | Cost/Pt |
|------|-------|-------|------|------|--------|---------|
| 1 | z-ai/glm-4.7 | **19/30** | $0.18 | 12m | 357K | $0.009 |
| 2 | z-ai/glm-5 | 18/30 | $0.39 | 17m | 610K | $0.022 |
| 2 | minimax/minimax-m2.5 | 18/30 | $0.17 | 25m | 1.46M | $0.009 |
| 2 | minimax/minimax-m2.1 | 18/30 | $0.06 | 11m | 555K | $0.003 |
| 5 | moonshotai/kimi-k2.5 | 17/30 | $0.26 | 11m | 868K | $0.015 |
| 5 | qwen/qwen3-coder-30b-a3b | 17/30 | $0.15 | 32m | 2.1M | $0.009 |
| 7 | anthropic/claude-haiku-4.5 | 16/30 | $0.35 | 13m | 1.03M | $0.022 |
| 8 | google/gemini-3-flash | 15/30 | $0.14 | 5m | 287K | $0.009 |
| 9 | qwen/qwen3-coder-flash | 13/30 | $0.23 | 14m | 2.2M | $0.018 |
| 9 | openai/gpt-oss-20b | 13/30 | $0.05 | 13m | 838K | $0.004 |
| 11 | qwen/qwen3-coder | 10/30 | $0.24 | 32m | 7.0M | $0.024 |
| 12 | openai/gpt-oss-120b | 4/30 | $0.03 | 2m | 388K | $0.008 |

## Per-Test Results

| Test | GLM-4.7 | GLM-5 | M2.5 | M2.1 | Kimi | Q3-30B | Haiku | Gemini | Q3-Fl | GPT-20 | Q3-C | GPT-120 |
|------|:-------:|:-----:|:----:|:----:|:----:|:------:|:-----:|:------:|:-----:|:------:|:----:|:-------:|
| 01 CSV→JSON | 3 | 3 | 2 | 3 | 1 | 2 | 3 | 3 | 0 | 0 | 1 | 0 |
| 02 Sysinfo | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| 03 Calculator | 3 | 3 | 3 | 3 | 3 | 3 | 0 | 0 | 0 | 3 | 0 | 0 |
| 04 Bugfix | 3 | 3 | 3 | 2 | 3 | 3 | 3 | 3 | 3 | 1 | 1 | 1 |
| 05 TDD | 3 | 3 | 3 | 3 | 3 | 1 | 3 | 3 | 3 | 3 | 1 | 0 |
| 06 Expense API | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 07 URL Short | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| 08 Dashboard | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 0 |
| 09 Kanban | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 10 Chat | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | 0 | 1 | 0 |

## Cost Detail

| Model | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 | Total |
|-------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-------|
| GLM-4.7 | .000 | .029 | .021 | .008 | .028 | .011 | .018 | .028 | .025 | .015 | $0.18 |
| GLM-5 | .052 | .029 | .036 | .040 | .035 | .048 | .031 | .062 | .039 | .019 | $0.39 |
| M-M2.5 | .010 | .013 | .015 | .014 | .018 | .016 | .024 | .021 | .021 | .024 | $0.17 |
| M-M2.1 | .006 | .006 | .007 | .005 | .009 | .005 | .005 | .006 | .009 | .005 | $0.06 |
| Kimi K2.5 | .023 | .026 | .019 | .022 | .029 | .036 | .014 | .024 | .023 | .041 | $0.26 |
| Q3-30B | .016 | .008 | .007 | .012 | .030 | .017 | .017 | .007 | .013 | .028 | $0.15 |
| Haiku 4.5 | .000 | .038 | .009 | .012 | .040 | .061 | .140 | .028 | .009 | .015 | $0.35 |
| Gemini 3F | .053 | .000 | .010 | .018 | .012 | .010 | .010 | .010 | .010 | .011 | $0.14 |
| Q3-Flash | .010 | .021 | .011 | .025 | .027 | .023 | .034 | .031 | .013 | .035 | $0.23 |
| GPT-20B | .001 | .014 | .005 | .004 | .008 | .003 | .004 | .004 | .006 | .001 | $0.05 |
| Q3-Coder | .044 | .019 | .000 | .009 | .056 | .043 | .004 | .042 | .000 | .026 | $0.24 |
| GPT-120B | .001 | .021 | .001 | .001 | .001 | .001 | .001 | .002 | .001 | .001 | $0.03 |

## Notes

- Tests 06 (Expense API) and 09 (Kanban) scored 0 across all 12 models
- GLM-4.7 is the overall winner at best score + reasonable cost
- MiniMax M2.1 is the best value at $0.003/point
- Qwen3-Coder (full) consumed 7M tokens — 37x more per point than GLM-4.7
- Claude Haiku 4.5 and Gemini 3 Flash both scored lower than top open-source models

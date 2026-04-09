#!/usr/bin/env python3
"""Generate quadrant scatter plots for README (English + Chinese)."""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.offsetbox import AnnotationBbox, TextArea
import numpy as np

# Data: (label, arch, params, score, cost_estimate)
# cost_estimate is relative (0=expensive, 1=cheap) matching the mermaid chart
DATA = [
    ("Sonnet-4.6†", "?", "?B", 29, 0.03),
    ("Gemma4-31B†", "Dense", "31B", 27, 0.99),
    ("Gemma4-26B‡ (H200)", "MoE", "26B/4B", 25, 1.00),
    ("Q3-Coder-Flash", "MoE", "?B", 30, 0.47),
    ("Kimi-K2.5", "MoE", "1T/32B", 27, 0.48),
    ("Haiku-4.5", "?", "?B", 27, 0.05),
    ("GLM-5", "MoE", "745B/44B", 26, 0.38),
    ("Q3-Coder-30B", "MoE", "30.5B/3.3B", 26, 0.56),
    ("Gemini-3F", "?", "?B", 25, 0.59),
    ("Q3.5-27B", "Dense", "27B", 25, 0.58),
    ("DS-v3.2", "MoE", "685B/37B", 25, 0.45),
    ("M-M2.1", "MoE", "230B/10B", 24, 0.54),
    ("Q3-Coder", "MoE", "480B/35B", 24, 0.53),
    ("GLM-4.7", "MoE", "355B/32B", 23, 0.40),
    ("Q3.5-122B", "MoE", "122B/10B", 23, 0.43),
    ("GPT-120B", "MoE", "117B/5.1B", 22, 0.95),
    ("Q3.5-35B", "MoE", "35B/3B", 22, 0.58),
    ("Q3-Coder-Next", "MoE", "80B/3B", 20, 0.63),
    ("Q3.5-397B", "MoE", "397B/17B", 20, 0.39),
    ("M-M2.5", "MoE", "230B/10B", 19, 0.56),
    ("GPT-20B", "MoE", "21B/3.6B", 14, 0.95),
    ("Kimi-K2", "MoE", "1T/32B", 14, 0.29),
]


def generate_chart(lang='en'):
    zh = lang == 'zh'
    font_family = 'Heiti TC' if zh else 'DejaVu Sans'

    plt.rcParams['font.family'] = font_family
    plt.rcParams['font.size'] = 10

    fig, ax = plt.subplots(figsize=(14, 9))

    # Quadrant background colors
    ax.axhspan(22, 31, xmin=0.5, xmax=1.0, alpha=0.08, color='green')   # top-right: champions
    ax.axhspan(22, 31, xmin=0.0, xmax=0.5, alpha=0.08, color='blue')    # top-left: strong but pricey
    ax.axhspan(12, 22, xmin=0.0, xmax=0.5, alpha=0.08, color='red')     # bottom-left: expensive & weak
    ax.axhspan(12, 22, xmin=0.5, xmax=1.0, alpha=0.08, color='orange')  # bottom-right: budget picks

    # Quadrant labels
    if zh:
        labels = ['冠軍區', '高分但貴', '又貴又弱', '預算之選']
    else:
        labels = ['Champions', 'Strong but pricey', 'Expensive & weak', 'Budget picks']

    ax.text(0.75, 30, labels[0], ha='center', va='top', fontsize=13, alpha=0.3, fontweight='bold')
    ax.text(0.25, 30, labels[1], ha='center', va='top', fontsize=13, alpha=0.3, fontweight='bold')
    ax.text(0.25, 13, labels[2], ha='center', va='bottom', fontsize=13, alpha=0.3, fontweight='bold')
    ax.text(0.75, 13, labels[3], ha='center', va='bottom', fontsize=13, alpha=0.3, fontweight='bold')

    # Midlines
    ax.axhline(y=22, color='gray', linestyle='--', alpha=0.3)
    ax.axvline(x=0.5, color='gray', linestyle='--', alpha=0.3)

    # Plot points
    xs = [d[4] for d in DATA]
    ys = [d[3] for d in DATA]

    # Color by architecture
    colors = []
    for d in DATA:
        if d[1] == 'Dense':
            colors.append('#2196F3')  # blue
        elif d[1] == 'MoE':
            colors.append('#FF9800')  # orange
        else:
            colors.append('#9E9E9E')  # gray for unknown

    ax.scatter(xs, ys, c=colors, s=80, zorder=5, edgecolors='white', linewidth=0.8)

    # Manual label offsets (x_pt, y_pt) to avoid overlaps
    # Positive x = right, positive y = up
    OFFSETS = {
        "Sonnet-4.6†": (8, 4),
        "Q3-Coder-Flash": (8, 4),
        "Kimi-K2.5": (8, 4),
        "Haiku-4.5": (8, 4),
        "GLM-5": (8, 4),
        "Q3-Coder-30B": (8, 4),
        "Gemini-3F": (8, 12),        # nudge up well clear
        "Q3.5-27B": (8, -14),       # nudge down
        "DS-v3.2": (8, -14),         # nudge down to avoid Gemini/Q3.5-27B
        "M-M2.1": (-110, 10),       # place left of point
        "Q3-Coder": (8, -14),       # nudge down
        "GLM-4.7": (-100, 10),      # place left of point
        "Q3.5-122B": (8, -14),      # nudge down
        "GPT-120B": (8, 4),
        "Q3.5-35B": (8, 4),
        "Q3-Coder-Next": (8, 4),
        "Q3.5-397B": (8, 4),
        "M-M2.5": (8, 4),
        "GPT-20B": (8, 4),
        "Kimi-K2": (8, 4),
        "Gemma4-26B‡ (H200)": (-150, 4),
    }

    # Annotate each point with name + arch + params on the right side
    for i, d in enumerate(DATA):
        name, arch, params, score, cost = d
        main_text = f"{name} {score}/30"
        sub_text = f"{arch} {params}"

        xo, yo = OFFSETS.get(name, (8, 4))

        ax.annotate(
            main_text,
            xy=(cost, score),
            xytext=(xo, yo),
            textcoords='offset points',
            fontsize=8,
            fontweight='bold',
            va='bottom',
            ha='left',
            zorder=6,
        )
        ax.annotate(
            sub_text,
            xy=(cost, score),
            xytext=(xo, yo - 10),
            textcoords='offset points',
            fontsize=6.5,
            va='top',
            ha='left',
            color='#666666',
            zorder=6,
        )

    # Axis labels
    if zh:
        ax.set_xlabel('← 昂貴                                                              便宜 →', fontsize=12)
        ax.set_ylabel('分數', fontsize=12)
        ax.set_title('分數 vs 費用 — 第一組寫程式（右上角最佳）', fontsize=14, fontweight='bold')
    else:
        ax.set_xlabel('← Expensive                                                              Cheap →', fontsize=12)
        ax.set_ylabel('Score', fontsize=12)
        ax.set_title('Score vs Cost — Group 1 Coding (top-right is best)', fontsize=14, fontweight='bold')

    ax.set_xlim(-0.02, 1.05)
    ax.set_ylim(12, 31)
    ax.set_yticks(range(14, 32, 2))

    # Legend for arch types
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#FF9800', markersize=8, label='MoE'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#2196F3', markersize=8, label='Dense'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#9E9E9E', markersize=8, label='Unknown'),
    ]
    ax.legend(handles=legend_elements, loc='lower left', fontsize=9)

    ax.grid(True, alpha=0.15)
    ax.set_axisbelow(True)

    plt.tight_layout()

    suffix = 'zh' if zh else 'en'
    out_path = f'docs/quadrant_{suffix}.png'
    fig.savefig(out_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f"Saved: {out_path}")


if __name__ == '__main__':
    generate_chart('en')
    generate_chart('zh')

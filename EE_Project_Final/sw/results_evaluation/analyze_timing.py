"""
WNS (Worst Negative Slack) analysis for et4351 synthesis results.
Cases: original@12MHz, original_cg@12MHz, original_cg@45MHz,
       ver1@12MHz, ver1@45MHz, ver1_cg@12MHz
Source: et4351_qor.rpt – Critical Path Slack column per cost group.
"""

import matplotlib.pyplot as plt
import numpy as np

# ──────────────────────────────────────────────
# Raw data extracted from et4351_qor.rpt
# ──────────────────────────────────────────────

cases = [
    "Original\n12 MHz",
    "Original CG\n12 MHz",
    "Original CG\n45 MHz",
    "Ver1\n12 MHz",
    "Ver1\n45 MHz",
    "Ver1 CG\n12 MHz",
]

# Clock period [ps] per case (from QOR Timing section)
periods = np.array([83330.0, 83330.0, 22000.0, 83330.0, 22000.0, 83330.0])

# Critical Path Slack [ps] per clock group – NaN where group absent
NaN = np.nan
slack = {
    "clk":             np.array([31851.1, 33127.9,  2514.2, 31688.8,  1365.8, 33219.9]),
    "flash_clk":       np.array([35449.3, 35320.0,  4655.2, 35449.3,  4733.0, 35320.0]),
    "cg_enable_group": np.array([    NaN, 32215.2,  2911.2,     NaN,     NaN,  32299.3]),
}

# WNS = minimum slack across all groups (ignoring NaN)
wns = np.nanmin(np.column_stack(list(slack.values())), axis=1)

# WNS margin as % of clock period
wns_pct = wns / periods * 100.0

# Colours per case (consistent with analyze_power.py)
COLORS = ["#4C72B0", "#9BBFDD", "#DD8452", "#55A868", "#C44E52", "#8FBC8F"]
# Colours per clock group
GROUP_COLORS = {
    "clk":             "#4C72B0",
    "flash_clk":       "#DD8452",
    "cg_enable_group": "#55A868",
}

# ──────────────────────────────────────────────
# Figure: WNS Overview
# ──────────────────────────────────────────────

fig, axes = plt.subplots(1, 2, figsize=(13, 5))
fig.suptitle("Timing Overview (WNS) – et4351", fontsize=14, fontweight="bold", y=1.01)

x = np.arange(len(cases))
bar_w = 0.6

# ── Panel 1: WNS per case ──
ax = axes[0]
bars = ax.bar(x, wns / 1e3, width=bar_w, color=COLORS, edgecolor="white", linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels(cases, fontsize=7.5)
ax.set_ylabel("Timing Slack (ns)", fontsize=10)
ax.set_title("Critical Path Timing Slack", fontsize=11)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
for bar, val, pct in zip(bars, wns / 1e3, wns_pct):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.3,
            f"{val:.1f} ns\n({pct:.1f}%)", ha="center", va="bottom", fontsize=6.5)

# ── Panel 2: Per-clock-group slack breakdown ──
ax = axes[1]
n_groups = len(slack)
group_names = list(slack.keys())
sub_w = bar_w / n_groups
offsets = np.linspace(-(bar_w - sub_w) / 2, (bar_w - sub_w) / 2, n_groups)

for offset, gname in zip(offsets, group_names):
    vals = slack[gname] / 1e3
    valid = ~np.isnan(vals)
    ax.bar(x[valid] + offset, vals[valid], width=sub_w,
           color=GROUP_COLORS[gname], edgecolor="white", linewidth=0.5,
           label=gname.replace("_", " "))

ax.set_xticks(x)
ax.set_xticklabels(cases, fontsize=7.5)
ax.set_ylabel("Critical Path Slack (ns)", fontsize=10)
ax.set_title("Slack per Clock Group", fontsize=11)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
ax.legend(fontsize=8, loc="upper right")

fig.tight_layout()
fig.savefig("wns_overview.png", dpi=150, bbox_inches="tight")
print("Saved: wns_overview.png")

plt.show()
print("\nAll done.")

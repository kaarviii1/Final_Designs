"""
Power, Area, and Energy analysis for et4351 synthesis results.
Cases: standard@12MHz, standard@45MHz, cg@12MHz, cg@45MHz
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# ──────────────────────────────────────────────
# Raw data extracted from reports
# ──────────────────────────────────────────────

cases = [
    "Original\n12 MHz",
    "Original CG\n12 MHz",
    "Original CG\n45 MHz",
    "Ver1\n12 MHz",
    "Ver1\n45 MHz",
    "Ver1 CG\n12 MHz",
]
labels_short = ["Orig@12", "Orig CG@12", "Orig CG@45", "Ver1@12", "Ver1@45", "Ver1 CG@12"]

# Power [W] – from et4351_power.rpt (Subtotal row)
power = {
    "leakage":   np.array([2.58854e-06, 3.03863e-06, 3.00283e-06, 2.54333e-06, 2.54638e-06, 3.06300e-06]),
    "internal":  np.array([1.58217e-04, 4.63843e-05, 3.44248e-04, 1.50931e-04, 5.65075e-04, 4.58157e-05]),
    "switching": np.array([1.32938e-04, 1.16808e-05, 4.98931e-05, 8.21567e-06, 2.45382e-05, 1.17858e-05]),
}
power_total = power["leakage"] + power["internal"] + power["switching"]  # W

# Area [µm²] – Total Area from et4351_area.rpt (top-level row)
area_total = np.array([194967.841, 201140.952, 200581.904, 193556.602, 193151.190, 203599.303])

# Runtime [s] per case
runtimes = np.array([61e-6, 61e-6, 16.104e-6, 33.91e-6, 8.954e-6, 33.91e-6])

# Energy [J] = Power × Time
energy_total = power_total * runtimes

# Colours per case
COLORS = ["#4C72B0", "#9BBFDD", "#DD8452", "#55A868", "#C44E52", "#8FBC8F"]
# Colours for power breakdown stacks
STACK_COLORS = ["#aec6e8", "#1f77b4", "#ffbb78"]

# ──────────────────────────────────────────────
# Figure 1: Overview – Power | Area | Energy
# ──────────────────────────────────────────────

fig1, axes = plt.subplots(1, 3, figsize=(16, 5))
fig1.suptitle("Synthesis Results Overview – et4351", fontsize=14, fontweight="bold", y=1.01)

x = np.arange(len(cases))
bar_w = 0.6

# ── Panel 1: Total Power ──
ax = axes[0]
bars = ax.bar(x, power_total * 1e6, width=bar_w, color=COLORS, edgecolor="white", linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels(cases, fontsize=7.5)
ax.set_ylabel("Total Power (µW)", fontsize=10)
ax.set_title("Total Power", fontsize=11)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
for bar, val in zip(bars, power_total * 1e6):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 2,
            f"{val:.1f}", ha="center", va="bottom", fontsize=7)

# ── Panel 2: Total Area ──
ax = axes[1]
bars = ax.bar(x, area_total / 1e3, width=bar_w, color=COLORS, edgecolor="white", linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels(cases, fontsize=7.5)
ax.set_ylabel("Total Area (×10³ µm²)", fontsize=10)
ax.set_title("Total Area", fontsize=11)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
for bar, val in zip(bars, area_total / 1e3):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.2,
            f"{val:.1f}k", ha="center", va="bottom", fontsize=7)

# ── Panel 3: Total Energy ──
ax = axes[2]
bars = ax.bar(x, energy_total * 1e9, width=bar_w, color=COLORS, edgecolor="white", linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels(cases, fontsize=7.5)
ax.set_ylabel("Energy (nJ)", fontsize=10)
ax.set_title("Energy  (Power × Runtime)", fontsize=11)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
for bar, val in zip(bars, energy_total * 1e9):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.03,
            f"{val:.2f}", ha="center", va="bottom", fontsize=7)

fig1.tight_layout()
fig1.savefig("overview.png", dpi=150, bbox_inches="tight")
print("Saved: overview.png")

plt.show()
print("\nAll done.")

# Genus Low Power — Optimization Recommendations
### Based on Genus Low Power Guide, Product Version 21.1

---

## 1. Enable Power Optimization

The attribute `design_power_effort` is the **master control** for all power optimization in Genus. Without it, power optimization is fully disabled.

| Value  | Behavior |
|--------|----------|
| `none` | Power optimization disabled (default) |
| `low`  | Minimizes area cost during optimization |
| `high` | Aggressive power reduction — accepts area/frequency trade-off |

> **Recommendation:** Set to `high` when the primary goal is minimum power consumption.

```tcl
set_attribute design_power_effort high /
```

---

## 2. Balance Leakage vs. Dynamic Power

Use `opt_leakage_to_dynamic_ratio` to control the weighting between leakage and dynamic power during optimization. Value ranges from **0.0** (dynamic only) to **1.0** (leakage only).

> **Recommendation:** Start at `0.5` for balanced optimization. Lean toward `0.2–0.3` if internal/switching power dominates.

```tcl
set_attribute opt_leakage_to_dynamic_ratio 0.3 /
```

---

## 3. Add the `syn_opt` Step

The Genus recommended flow is:

```
syn_generic  →  syn_map  →  syn_opt
```

`syn_opt` performs:
- **Power-Aware Incremental Optimization (IOPT)**
- **Power-Aware Logic Restructuring**

Without this step, the mapped netlist is never incrementally optimized for power.

---

## 4. Clock Gating Tuning

Clock gating is already enabled in the CG flow. Additional knobs available:

| Attribute | Purpose |
|-----------|---------|
| `lp_clock_gating_min_flops` | Minimum FF count before inserting a gate — avoid gating tiny groups |
| `lp_clock_gating_max_flops` | Maximum fanout of a single clock gate |
| `lp_clock_gating_style` | `latch` (already set) is the recommended style |
| `lp_clock_gating_control_point` | `precontrol` (already set) or `postcontrol` |

---

## Summary Table

| Recommendation | Impact | Effort |
|---|---|---|
| Enable `design_power_effort high` | **High** — currently disabled | Low |
| Add `syn_opt` step | **High** — optimization pass missing | Low |
| Set `opt_leakage_to_dynamic_ratio` | **Medium** — guides trade-off | Low |
| Tune clock gating thresholds | **Low–Medium** | Low |

---

*Reference: Genus Low Power Guide, Cadence Design Systems, Product Version 21.1, August 2021*

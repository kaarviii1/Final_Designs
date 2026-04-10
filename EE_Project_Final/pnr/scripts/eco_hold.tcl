
##########################################################################
###
### ECO script - Manual hold violation fix.
###
### Inserts one buffer on the single violating hold path:
###   soc/spimemio/din_data_reg_3_/Q
###     -> soc/spimemio/xfer/dummy_count_reg_3_/D
### Violation: -0.007 ns (7 ps). A BUFX2HVT adds ~20 ps.
###
### Run from EE09/pnr/ directory:
###   innovus -files ./scripts/eco_hold.tcl
###
##########################################################################

set DESIGN "et4351"

# ---------------------------------------------------------------------------
# Restore post-route checkpoint (includes all routing + hold optimisation)
# ---------------------------------------------------------------------------
restoreDesign checkpoints/${DESIGN}_route.enc.dat ${DESIGN}

# ---------------------------------------------------------------------------
# Insert one BUFX2HVT on the violating net, driven toward the endpoint pin
# ---------------------------------------------------------------------------
ecoAddRepeater \
    -cell      {BUFX2HVT} \
    -term      {soc/spimemio/xfer/dummy_count_reg_3_/D}

# ---------------------------------------------------------------------------
# Re-route only the affected nets
# ---------------------------------------------------------------------------
ecoRoute

# ---------------------------------------------------------------------------
# Verify hold is now clean
# ---------------------------------------------------------------------------
timeDesign -postRoute -hold \
    -pathReports -slackReports -numPaths 10 \
    -outDir timingReports/eco_hold

# ---------------------------------------------------------------------------
# Save updated design
# ---------------------------------------------------------------------------
saveDesign checkpoints/${DESIGN}_route_eco.enc

Puts "\n\n ECO hold fix complete. Check timingReports/eco_hold/ for results.\n\n"

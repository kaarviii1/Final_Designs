set DESIGN "et4351"

# ---------------------------------------------------------------------------
# Insert BUFX2LVT on all violating data paths
# All endpoints are /D or data input pins — LVT buffer appropriate
# ---------------------------------------------------------------------------

# accel paths
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/iomem_conf_rdata_reg_9_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/u_re_reg_9_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/v_im_reg_15_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/v_re_reg_25_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/v_im_reg_26_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/u_im_reg_15_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/half_reg_4_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_11__21_/D}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_10__21_/D}

# soc/cpu path
ecoAddRepeater -cell {BUFX2LVT} \
    -term {soc/cpu/cpuregs_reg_27__30_/D}

# SRAM input — check orientation before running
ecoAddRepeater -cell {BUFX2LVT} \
    -term {soc/memory/sram_0/I[1]}

# SN pin — async set/reset — verify this is safe before inserting
# Comment out if path is genuinely asynchronous
ecoAddRepeater -cell {BUFX2LVT} \
    -term {soc/simpleuart/send_pattern_reg_0_/SN}

ecoAddRepeater -cell {BUFX2LVT} \
    -term {soc/cpu/reg_op2_reg_24_/D}
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/fft/w_im_reg_4_/D}
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_15__21_/D }
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_14__21_/D}
ecoAddRepeater -cell {BUFX2LVT} \
    -term {soc/spimemio/rd_addr_reg_21_/D}
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_1__27_/D}
ecoAddRepeater -cell {BUFX2LVT} \
    -term {accel/mem/mem_b1_reg_0__27_/D}


# ---------------------------------------------------------------------------
# Re-route only affected nets
# ---------------------------------------------------------------------------
ecoRoute

# ---------------------------------------------------------------------------
# Verify hold and setup after ECO
# ---------------------------------------------------------------------------
timeDesign -postRoute -hold \
    -pathReports -slackReports \
    -numPaths 50 \
    -outDir ECO_HOLD/report_timing_hold

timeDesign -postRoute \
    -pathReports -slackReports \
    -numPaths 50 \
    -outDir ECO_HOLD/report_timing


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
saveDesign checkpoints/${DESIGN}_route_eco.enc
puts "\n\n ECO hold fix complete. Check finalReports \n\n"


##########################################################################
###
### Place-and-route scripts - clock tree synthesis (CTS).
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


Puts ""
Puts ""
Puts ""
Puts " ##############################################################    "
Puts " ##                                                                "
Puts " ##                        CLOCK TREE                              "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


# ####################
# CTS
# ####################

setOptMode -usefulSkew true
setOptMode -usefulSkewCCOpt extreme
set_ccopt_property buffer_cells       {         CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX6 CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20}
set_ccopt_property inverter_cells     {CLKINVX1 CLKINVX2 CLKINVX3 CLKINVX4 CLKINVX6 CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20}
set_ccopt_property delay_cells        {DLY1X1 DLY1X4 DLY2X1 DLY2X4 DLY3X1 DLY3X4 DLY4X1 DLY4X4}

ccopt_design


# ####################
# Post-CTS Hold Fixing and reporting
# ####################

setOptMode -fixCap true -fixTran true -fixFanoutLoad true

setOptMode -holdTargetSlack 0.08 \
           -holdFixingCells {DLY1X1 DLY1X4 DLY2X1 DLY2X4 DLY3X1 DLY3X4 CLKBUFX2 CLKBUFX3 CLKBUFX4}
           
optDesign  -postCTS -hold -outDir timingReports/postCTSHold_hold
timeDesign -postCTS -outDir timingReports/postCTSHold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -outfile powerReports/postCTSHold.rpt

check_timing -verbose > verifyReports/cts_check_timing.rpt
report_ccopt_clock_trees -file clockReports/CT.rpt
report_ccopt_skew_groups -file clockReports/skew_groups.rpt
report_ccopt_pin_insertion_delays -file clockReports/pin_insertion.rpt
report_ccopt_worst_chain -file clockReports/worst_chain.rpt

# Keep second tree report call because your original script needed it
report_ccopt_clock_trees -file clockReports/CT.rpt


# #############
# # Save 	 ##
# #############

Puts " \n\n save Design \n\n"
saveDesign checkpoints/${DESIGN}_cts.enc

fit


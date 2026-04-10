
##########################################################################
###
### Place-and-route scripts - routing.
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
Puts " ##                        ROUTE                                   "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


# ####################
# Filler configuration and inclusion
# ####################

setFillerMode -core {FILL1HVT FILL2HVT FILL4HVT FILL8HVT FILL16HVT FILL32HVT FILL64HVT} -corePrefix FILLER_ -doDRC true -ecoMode true

addFiller
checkFiller

# ####################
# Nano route parameters
# ####################

setNanoRouteMode -quiet -routeTdrEffort 9
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration 60
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeSiEffort high
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeFixTopLayerAntenna false
setNanoRouteMode -routeInsertAntennaDiode true
setNanoRouteMode -routeAntennaCellName "ANTENNAHVT"
setOptMode       -postRouteDrvRecovery true -fixSISlew true -fixGlitch true

#Reduce effort level as there are only captables
setExtractRCMode -engine postRoute -effortLevel high

routeDesign -globalDetail

# ####################
# Post-route pre-opt reports
# ####################

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/route
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/route_hold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/route.rpt


# ####################
# Post-route optimization
# ####################

# Setup timing + DRV optimization
setOptMode -fixCap true -fixTran true -fixFanoutLoad true \
           -postRouteHoldRecovery auto 

optDesign -postRoute -drv

# Power optimization
optPower -postRoute

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/postRoute
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/postRoute_hold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/postRoute.rpt

# ####################
# Hold optimization (last — preserves setup and power gains)
# ####################

optDesign -postRoute -hold

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/postRouteHold
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/postRouteHold_hold
report_noise -bumpy_waveform -output_file timingReports/bumpyWaves_postRouteHold.rpt 

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/postRouteHold.rpt

# ####################
# # Verify and Save
# ####################

checkRoute
reportRoute

deleteRouteBlk -all

Puts " \n\n save Design \n\n"

saveDesign checkpoints/${DESIGN}_route.enc

fit






#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Tue Apr  7 15:13:08 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v21.11-s130_1 (64bit) 08/19/2021 16:59 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: NanoRoute 21.11-s130_1 NR210811-1832/21_11-UB (database version 18.20.554) {superthreading v2.14}
#@(#)CDS: AAE 21.11-s059 (64bit) 08/19/2021 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: CTE 21.11-s010_1 () Aug 12 2021 04:17:41 ( )
#@(#)CDS: SYNTECH 21.11-s003_1 () Aug  4 2021 01:23:26 ( )
#@(#)CDS: CPE v21.11-s010
#@(#)CDS: IQuantus/TQuantus 20.1.2-s578 (64bit) Fri Jul 9 11:48:16 PDT 2021 (Linux 2.6.32-431.11.2.el6.x86_64)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
setMessageLimit 1 ENCLF 45
setMessageLimit 1 ENCLF 119
setMessageLimit 1 ENCLF 200
setMessageLimit 1 ENCLF 201
setMessageLimit 10 IMPDB 2078
setMessageLimit 10 IMPDC 348
setMultiCpuUsage -localCpu 4 -cpuPerRemoteHost 4 -remoteHost 1 -keepLicense true
set init_pwr_net VDD
set init_gnd_net VSS
set init_design_settop 1
set init_verilog ../synth/outputs/et4351.struct.v
set init_top_cell et4351
set init_lef_file {  /data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045_tech/lef/gsclib045_tech.lef  /data/Cadence/gpdk045_v60/gsclib045_all_v4.7/gsclib045_lvt/lef/gsclib045_lvt_macro.lef  /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.lef }
set init_mmmc_file ./scripts/2.1.set_library_n_sdc.tcl
setDesignMode -process 45
setDelayCalMode -SIAware true
setAnalysisMode -analysisType onChipVariation -cppr both
init_design
report_design > initialReports/report_design.rpt
report_constraint > initialReports/report_constraint.rpt
report_clocks > initialReports/report_clocks.rpt
report_ports > initialReports/report_ports.rpt
report_path_exceptions > initialReports/report_path_exceptions.rpt
report_annotated_check > initialReports/report_annotated_check.rpt
setDrawView fplan
setFPlanRowSpacingAndType 0.0 1
floorPlan -site CoreSite -s 596.4 596.4 34.2 34.2 34.2 34.2 -noSnapToGrid
loadIoFile ./scripts/3.1.ET4351_chip.io
placeInstance soc/memory/sram_3 34.2 396.21 R0
placeInstance soc/memory/sram_2 73.035 396.21 R0
placeInstance soc/memory/sram_1 111.87 396.21 R0
placeInstance soc/memory/sram_0 150.705 396.21 R0
addHaloToBlock 0 2.000 2.000 0 -fromInstBox soc/memory/sram_3
addHaloToBlock 0 2.000 2.000 0 -fromInstBox soc/memory/sram_2
addHaloToBlock 0 2.000 2.000 0 -fromInstBox soc/memory/sram_1
addHaloToBlock 0 2.000 22.000 0 -fromInstBox soc/memory/sram_0
checkFPlan -outFile verifyReports/checkFPlan.rpt
saveDesign checkpoints/et4351_fplan.enc
saveFPlan checkpoints/et4351.fp
fit
addRing -around default_power_domain -nets {VSS VDD} -layer {bottom M1 top M1 right M2 left M2} -width 12 -spacing 5 -offset 2
addRing -around default_power_domain -nets {VSS VDD} -layer {bottom M3 top M3 right M4 left M4} -width 12 -spacing 5 -offset 2
addStripe -number_of_sets 1 -start_from left -start 190.54 -spacing 2.0 -direction vertical -layer 6 -width 8 -nets {VSS VDD}
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi
globalNetConnect VSS -type tielo
sroute -nets { VDD VSS } -connect { blockPin }
addStripe -number_of_sets 8 -start_from bottom -start 70 -stop 596 -spacing 2.5 -direction horizontal -layer 7 -width 8 -nets {VSS VDD}
addStripe -number_of_sets 2 -start_from left -start 70 -stop 155 -spacing 2.5 -direction vertical -layer 8 -width 8 -nets {VSS VDD}
addStripe -number_of_sets 5 -start_from left -start 240 -stop 596 -spacing 2.5 -direction vertical -layer 8 -width 8 -nets {VSS VDD}
sroute -nets { VDD VSS } -connect { corePin }
saveDesign checkpoints/et4351_pplan.enc
fit
set_power_analysis_mode -report_missing_nets true -corner delay_typ -analysis_view analysis_view_power
read_activity_file ../sim_struct/vcd/et4351.struct.vcd -reset -format VCD -scope testbench/dut
win

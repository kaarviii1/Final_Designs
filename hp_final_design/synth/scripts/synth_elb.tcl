
##########################################################################
###
### Synthesis scripts - elaboration.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


puts ""
puts ""
puts " ##################################"
puts " #                                #"
puts " #    ELABORATION                 #"
puts " #                                #"
puts " ##################################"
puts ""
puts ""


####################################################################
## Load Design
####################################################################

# Source design HDL
read_hdl -v2001 "${INPUT_PATH}/design/${DESIGN}.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator.v"
read_hdl -sv    "${INPUT_PATH}/design/accelerator_fft.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator_mem.v"
read_hdl -v2001 "${INPUT_PATH}/design/picosoc.v"
read_hdl -v2001 "${INPUT_PATH}/design/spimemio.v"
read_hdl -v2001 "${INPUT_PATH}/design/simpleuart.v"
read_hdl -v2001 "${INPUT_PATH}/design/picorv32.v"

# Issue an error on latch inference
set_attribute hdl_error_on_latch true /

# No automatically ungroup of any hierarchy during the synthesis process (Good for debug but turn it off for better results)
set_attribute auto_ungroup none /

#elaborate design
elaborate $DESIGN
timestat Elaboration

# set_attr preserve true [get_nets soc/*]
# set_attr preserve true [get_nets soc/cpu/*]
# set_attr preserve true [get_nets soc/simpleuart/*]
# set_attr preserve true [get_nets soc/spimemio/*]
# set_attr preserve true [get_nets soc/memory/*]
# set_attr preserve true [get_nets soc/cpu/mem_done]

####################################################################
## Constraints and implementation parameters setup
####################################################################

read_sdc "${INPUT_PATH}/sdc/${DESIGN}.sdc"

change_names -restricted "\[ \]" -replace_str "_"

# Number of routing layers
set_attribute number_of_routing_layers 8 /designs/*


create_floorplan \
    -die_size {664.8 664.8 34.2 34.2 34.2 34.2}
#              w      h     left bottom right top
    #
    #
# Place SRAMs using exact coordinates from your floorplan script
placeInstance -fixed soc/memory/sram_3  "34.200  396.21"    
placeInstance -fixed soc/memory/sram_2 "73.035  396.21"    
placeInstance -fixed soc/memory/sram_1 "111.870  396.21"    
placeInstance -fixed soc/memory/sram_0 "150.705  396.21"    

# Add halos matching your floorplan script exactly
#addHaloToBlock 0  2.0   2.0   0  -fromInstBox soc/memory/sram_3
#addHaloToBlock 0  2.0   2.0   0  -fromInstBox soc/memory/sram_2
#addHaloToBlock 0  2.0   2.0   0  -fromInstBox soc/memory/sram_1
#addHaloToBlock 0  2.0  22.0   0  -fromInstBox soc/memory/sram_0



####################################################################
## Generic synthesis
####################################################################
set_attribute syn_generic_effort low
syn_generic
timestat GENERIC


####################################################################
## Generate reports
####################################################################

set IMPL_STAGE "elb"

if {![file exists ${REPORTS_PATH}/${IMPL_STAGE}]} {
  file mkdir ${REPORTS_PATH}/${IMPL_STAGE}
  puts "Creating directory ${REPORTS_PATH}/${IMPL_STAGE}"
}

report timing -lint -verbose       > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_lint.rpt
report clocks                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_clocks.rpt
report clocks -generated           > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_clocksg.rpt
report port *                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_port.rpt
find / -instance cdn_loop_breaker*
report cdn_loop_breaker            > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_loopbreaks.rpt
check_design -all                  > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_precheck.rpt

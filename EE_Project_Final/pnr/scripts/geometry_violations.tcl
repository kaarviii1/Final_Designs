source scripts/1.set_variable.tcl
restoreDesign checkpoints/et4351_done.enc.dat et4351

ecoRoute
ecoRoute -fix_drc
ecoRoute -fix_drc
ecoRoute

routeDesign -wireOpt -viaOpt
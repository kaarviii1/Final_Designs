#!/bin/bash
################################################################################
## Run all the steps in the project flow
##
## Author:
##     Ang Li <Ang.Li@tudelft.nl>
##     Yizhuo Wu <Yizhuo.Wu@tudelft.nl>
## Edited 22/01/2026:
##     Guilherme Guedes <g.guedes@tudelft.nl>
##
## Usage:
##   ./run_all.sh [--from STEP]
##
## Steps (in order):
##   firmware    - Generate firmware hex files
##   sim_behav   - Behavioural RTL simulation
##   synth       - Logic synthesis (Genus)
##   sim_struct  - Post-synthesis structural simulation
##   pnr         - Place and route (Innovus)
##   sim_phys    - Post-PnR physical simulation
##
## Example:
##   ./run_all.sh --from synth   # skip firmware and sim_behav, start at synthesis
################################################################################

# Project directory variable
PROJECT_DIR="$(pwd)"

# Use system Python3
PYTHON="python"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
declare -A STEP_NUM=([firmware]=1 [sim_behav]=2 [synth]=3 [sim_struct]=4 [pnr]=5 [sim_phys]=6)
START_NUM=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            if [[ -z "$2" || ! -v STEP_NUM[$2] ]]; then
                echo "ERROR: --from requires a valid step name."
                echo "Valid steps: firmware sim_behav synth sim_struct pnr sim_phys"
                exit 1
            fi
            START_NUM=${STEP_NUM[$2]}
            echo ":::: INFO :::: Starting from step: $2 (step ${START_NUM})"
            shift 2
            ;;
        -h|--help)
            sed -n '2,25p' "$0" | sed 's/^## \?//'
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Usage: ./run_all.sh [--from STEP]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# 0. Setup Environment (always runs)
# ---------------------------------------------------------------------------
echo ":::: INFO :::: Setting up environment..."
source setup.sh

# Exit on error from here on
set -e

# ---------------------------------------------------------------------------
# 1. Generate Firmware
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 1 ]]; then
    echo ":::: INFO :::: [1/6] Generating firmware for full audio signal..."
    cd "${PROJECT_DIR}/firmware"
    make clean && make
    cd "${PROJECT_DIR}"
else
    echo ":::: INFO :::: [1/6] Skipping firmware generation."
fi

# ---------------------------------------------------------------------------
# 2. Behavioural Simulation
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 2 ]]; then
    echo ":::: INFO :::: [2/6] Running behavioral simulation..."
    cd "${PROJECT_DIR}/sim_behav"
    source run_behav_sim.sh

    echo ":::: INFO :::: Verifying behavioral simulation..."
    ${PYTHON} ../sw/verify.py sim_behav

    echo ":::: INFO :::: Generating firmware for single chunk of audio..."
    cd "${PROJECT_DIR}/firmware"
    make clean && N_CHUNKS=1 make
    cd "${PROJECT_DIR}"
else
    echo ":::: INFO :::: [2/6] Skipping behavioral simulation."
fi

# ---------------------------------------------------------------------------
# 3. Synthesis
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 3 ]]; then
    echo ":::: INFO :::: [3/6] Running synthesis..."
    cd "${PROJECT_DIR}/synth"
    source run_synth.sh
    cd "${PROJECT_DIR}"
else
    echo ":::: INFO :::: [3/6] Skipping synthesis."
fi

# ---------------------------------------------------------------------------
# 4. Structural Simulation
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 4 ]]; then
    echo ":::: INFO :::: [4/6] Running structural simulation..."
    cd "${PROJECT_DIR}/sim_struct"
    source run_struct_sim_vcd.sh

    echo ":::: INFO :::: Verifying structural simulation..."
    ${PYTHON} ../sw/verify.py sim_struct
else
    echo ":::: INFO :::: [4/6] Skipping structural simulation."
fi

# ---------------------------------------------------------------------------
# 5. Place and Route
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 5 ]]; then
    echo ":::: INFO :::: [5/6] Running place and route..."
    cd "${PROJECT_DIR}/pnr"
    source run_pnr.sh
    cd "${PROJECT_DIR}"
else
    echo ":::: INFO :::: [5/6] Skipping place and route."
fi

# ---------------------------------------------------------------------------
# 6. Physical Simulation
# ---------------------------------------------------------------------------
if [[ ${START_NUM} -le 6 ]]; then
    echo ":::: INFO :::: [6/6] Running physical simulation..."
    cd "${PROJECT_DIR}/sim_phys"
    source run_pnr_sim_setup_max.sh
    source run_pnr_sim_hold_min.sh

    echo ":::: INFO :::: Verifying physical simulation..."
    ${PYTHON} ../sw/verify.py sim_phys
else
    echo ":::: INFO :::: [6/6] Skipping physical simulation."
fi

echo ":::: INFO :::: Full project flow completed successfully!"

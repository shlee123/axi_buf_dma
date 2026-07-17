#!/usr/bin/env bash
set -uo pipefail

BUILD_DIR=${BUILD_DIR:-build/regression}
SUMMARY=${SUMMARY:-${BUILD_DIR}/summary.txt}
SUMMARY_JSON=${SUMMARY_JSON:-${BUILD_DIR}/summary.json}
MANIFEST=${MANIFEST:-regression.tests}
MAKE_CMD=${MAKE_CMD:-make}
SEED=${SEED:-1}

[[ -r "${MANIFEST}" ]] || { echo "[ERROR] regression manifest not found: ${MANIFEST}"; exit 2; }
mkdir -p "${BUILD_DIR}"
: > "${SUMMARY}"
results_file=$(mktemp)
trap 'rm -f "${results_file}"' EXIT

pass=0
fail=0
start_all=$(date +%s)
printf '%s\n' '========================================' 'AXI Buffer DMA Regression Summary' '========================================' | tee -a "${SUMMARY}"

while read -r test_name test_kind extra; do
  [[ -z "${test_name:-}" || "${test_name}" == \#* ]] && continue
  [[ -n "${extra:-}" ]] && { echo "[ERROR] invalid manifest line for ${test_name}"; exit 2; }
  case_name=${test_name}
  [[ "${test_kind}" != "-" ]] && case_name="${test_name}_kind${test_kind}"
  case_dir="${BUILD_DIR}/${case_name}"
  case_log="${case_dir}/run.log"
  mkdir -p "${case_dir}"
  start_case=$(date +%s)
  cmd=("${MAKE_CMD}" --no-print-directory sim SIM=iverilog TEST="${test_name}" SEED="${SEED}")
  [[ "${test_kind}" != "-" ]] && cmd+=(TEST_KIND="${test_kind}")
  if "${cmd[@]}" >"${case_log}" 2>&1; then status=PASS; pass=$((pass+1)); else status=FAIL; fail=$((fail+1)); fi
  elapsed=$(( $(date +%s) - start_case ))
  printf '%-5s %-28s %4ss\n' "${status}" "${case_name}" "${elapsed}" | tee -a "${SUMMARY}"
  printf '%s\t%s\t%d\t%s\n' "${case_name}" "${status}" "${elapsed}" "${case_log}" >> "${results_file}"
done < "${MANIFEST}"

total=$((pass+fail))
elapsed_all=$(( $(date +%s) - start_all ))
printf '%s\n' '----------------------------------------' | tee -a "${SUMMARY}"
printf 'Total   : %d\nPASS    : %d\nFAIL    : %d\nElapsed : %ds\n' "${total}" "${pass}" "${fail}" "${elapsed_all}" | tee -a "${SUMMARY}"
printf '%s\n' '========================================' | tee -a "${SUMMARY}"

{
  printf '{\n  "total": %d,\n  "pass": %d,\n  "fail": %d,\n  "elapsed_seconds": %d,\n  "tests": [\n' "${total}" "${pass}" "${fail}" "${elapsed_all}"
  first=1
  while IFS=$'\t' read -r name status elapsed log; do
    (( first )) || printf ',\n'
    first=0
    printf '    {"name":"%s","status":"%s","elapsed_seconds":%d,"log":"%s"}' "${name}" "${status}" "${elapsed}" "${log}"
  done < "${results_file}"
  printf '\n  ]\n}\n'
} > "${SUMMARY_JSON}"

(( fail == 0 ))

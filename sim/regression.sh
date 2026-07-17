#!/usr/bin/env bash
set -uo pipefail
BUILD_DIR=${BUILD_DIR:-build/regression}
SUMMARY=${SUMMARY:-${BUILD_DIR}/summary.txt}
MAKE_CMD=${MAKE_CMD:-make}
SEED=${SEED:-1}
mkdir -p "${BUILD_DIR}"
: > "${SUMMARY}"
TESTS=(byte_addressing byte_backpressure byte_boundary byte_random byte_error:1 byte_error:2 byte_error:3 byte_error:4 byte_error:5 byte_error:6)
pass=0; fail=0; start_all=$(date +%s)
printf '%s\n' '========================================' 'AXI Buffer DMA Regression Summary' '========================================' | tee -a "${SUMMARY}"
for entry in "${TESTS[@]}"; do
  test_name=${entry%%:*}; test_kind=''; case_name=${test_name}
  if [[ "${entry}" == *:* ]]; then test_kind=${entry##*:}; case_name="${test_name}_kind${test_kind}"; fi
  case_dir="${BUILD_DIR}/${case_name}"; case_log="${case_dir}/run.log"; mkdir -p "${case_dir}"
  start_case=$(date +%s)
  cmd=("${MAKE_CMD}" --no-print-directory sim SIM=iverilog TEST="${test_name}" SEED="${SEED}")
  [[ -n "${test_kind}" ]] && cmd+=(TEST_KIND="${test_kind}")
  if "${cmd[@]}" >"${case_log}" 2>&1; then status=PASS; pass=$((pass+1)); else status=FAIL; fail=$((fail+1)); fi
  elapsed=$(( $(date +%s) - start_case ))
  printf '%-5s %-28s %4ss\n' "${status}" "${case_name}" "${elapsed}" | tee -a "${SUMMARY}"
done
total=$((pass+fail)); elapsed_all=$(( $(date +%s) - start_all ))
printf '%s\n' '----------------------------------------' | tee -a "${SUMMARY}"
printf 'Total   : %d\nPASS    : %d\nFAIL    : %d\nElapsed : %ds\n' "${total}" "${pass}" "${fail}" "${elapsed_all}" | tee -a "${SUMMARY}"
printf '%s\n' '========================================' | tee -a "${SUMMARY}"
(( fail == 0 ))

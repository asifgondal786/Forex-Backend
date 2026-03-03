#!/usr/bin/env bash
set -euo pipefail

echo "Business Ops Check - Forex Backend"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

required_files=(
  "docs/PHASE_9_STRATEGIC_GROWTH.md"
  "docs/PHASE_10_REVENUE_SCALING.md"
  "docs/PHASE_11_MARKET_DOMINANCE.md"
  "docs/PHASE_12_EXIT_OR_EMPIRE.md"
  "docs/BUSINESS_IMPACT.md"
  "docs/REVENUE_MODEL.md"
  "docs/WEEKLY_BUSINESS_REVIEW_TEMPLATE.md"
  "docs/BUSINESS_SCORECARD_TEMPLATE.md"
  "docs/MONTHLY_BUSINESS_METRICS.csv"
  "docs/THOUGHT_LEADERSHIP_STRATEGY.md"
  "docs/CATEGORY_LEADERSHIP_SCORECARD.md"
  "docs/MARKET_DOMINANCE_12_MONTH_PLAN.md"
  "docs/PARTNERSHIP_PIPELINE.csv"
  "docs/MONTHLY_CATEGORY_METRICS.csv"
  "docs/PHASE_12_DECISION_SCORECARD.md"
  "docs/PHASE_12_WEEK1_ACTIONS.md"
  "docs/STATE_OF_COMPANY_TEMPLATE.md"
  "docs/BOARD_PATH_DECISION_MEMO_TEMPLATE.md"
  "docs/PATH_A_EXIT_90_DAY_PLAN.md"
  "docs/PATH_B_EMPIRE_90_DAY_PLAN.md"
  "docs/PATH_C_HYBRID_90_DAY_PLAN.md"
  "docs/PHASE_12_DECISION_LOG.csv"
  "docs/PHASE_12_90_DAY_TRACKER.csv"
)

echo
echo "1) Required artifact check"
missing=0
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi
echo "All required business artifacts are present."

echo
echo "2) Monthly metrics freshness check"
period="$(date -u +"%Y-%m")"
if grep -q "^${period}," "docs/MONTHLY_BUSINESS_METRICS.csv"; then
  echo "Found metrics row for current period: $period"
else
  echo "Warning: no metrics row found for $period in docs/MONTHLY_BUSINESS_METRICS.csv"
fi

echo
echo "3) Category metrics freshness check"
if grep -q "^${period}," "docs/MONTHLY_CATEGORY_METRICS.csv"; then
  echo "Found category metrics row for current period: $period"
else
  echo "Warning: no metrics row found for $period in docs/MONTHLY_CATEGORY_METRICS.csv"
fi

echo
echo "4) Phase 12 tracker freshness check"
if grep -q "^${period}," "docs/PHASE_12_90_DAY_TRACKER.csv"; then
  echo "Found Phase 12 tracker row for current period: $period"
else
  echo "Warning: no metrics row found for $period in docs/PHASE_12_90_DAY_TRACKER.csv"
fi

echo
echo "Business ops check complete."

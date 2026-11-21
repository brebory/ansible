#!/usr/bin/env bash
# One-shot script to create Wayfinder/triage labels and wire native GitHub
# sub-issues + blocked_by dependency edges on snackpackgames/ansible.
set -euo pipefail
REPO="snackpackgames/ansible"

echo "==> Creating canonical Wayfinder & triage labels..."
gh label create "wayfinder:map"       -R "$REPO" --color "5319E7" --description "Wayfinder exploration map" --force
gh label create "wayfinder:grilling"  -R "$REPO" --color "D93F0B" --description "HITL design/domain grilling ticket" --force
gh label create "wayfinder:research"  -R "$REPO" --color "0E8A16" --description "AFK research ticket" --force
gh label create "wayfinder:prototype" -R "$REPO" --color "FBCA04" --description "HITL prototype ticket" --force
gh label create "wayfinder:task"      -R "$REPO" --color "1D76DB" --description "Prerequisite task unblocking a decision" --force
gh label create "needs-triage"        -R "$REPO" --color "EDEDED" --description "Maintainer needs to evaluate this issue" --force
gh label create "needs-info"          -R "$REPO" --color "D876E3" --description "Waiting on reporter for more information" --force
gh label create "ready-for-agent"     -R "$REPO" --color "006B75" --description "Fully specified, ready for an AFK agent" --force
gh label create "ready-for-human"     -R "$REPO" --color "B60205" --description "Requires human implementation" --force

echo "==> Applying wayfinder:map labels..."
gh api -X POST "repos/$REPO/issues/1/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/6/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/11/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/16/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/21/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/26/labels" -f "labels[]=wayfinder:map" >/dev/null
gh api -X POST "repos/$REPO/issues/30/labels" -f "labels[]=wayfinder:map" >/dev/null

echo "==> Applying ticket labels and linking native sub-issues..."
gh api -X POST "repos/$REPO/issues/2/labels" -f "labels[]=wayfinder:research" >/dev/null
gh api -X POST "repos/$REPO/issues/1/sub_issues" -F sub_issue_id=6533882351 >/dev/null || true
gh api -X POST "repos/$REPO/issues/3/labels" -f "labels[]=wayfinder:research" >/dev/null
gh api -X POST "repos/$REPO/issues/1/sub_issues" -F sub_issue_id=6533897007 >/dev/null || true
gh api -X POST "repos/$REPO/issues/4/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/1/sub_issues" -F sub_issue_id=6533897111 >/dev/null || true
gh api -X POST "repos/$REPO/issues/5/labels" -f "labels[]=wayfinder:task" >/dev/null
gh api -X POST "repos/$REPO/issues/1/sub_issues" -F sub_issue_id=6533897214 >/dev/null || true
gh api -X POST "repos/$REPO/issues/7/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/6/sub_issues" -F sub_issue_id=6533897400 >/dev/null || true
gh api -X POST "repos/$REPO/issues/8/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/6/sub_issues" -F sub_issue_id=6533897505 >/dev/null || true
gh api -X POST "repos/$REPO/issues/9/labels" -f "labels[]=wayfinder:prototype" >/dev/null
gh api -X POST "repos/$REPO/issues/6/sub_issues" -F sub_issue_id=6533897641 >/dev/null || true
gh api -X POST "repos/$REPO/issues/10/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/6/sub_issues" -F sub_issue_id=6533897767 >/dev/null || true
gh api -X POST "repos/$REPO/issues/12/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/11/sub_issues" -F sub_issue_id=6533898007 >/dev/null || true
gh api -X POST "repos/$REPO/issues/13/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/11/sub_issues" -F sub_issue_id=6533898127 >/dev/null || true
gh api -X POST "repos/$REPO/issues/14/labels" -f "labels[]=wayfinder:prototype" >/dev/null
gh api -X POST "repos/$REPO/issues/11/sub_issues" -F sub_issue_id=6533898229 >/dev/null || true
gh api -X POST "repos/$REPO/issues/15/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/11/sub_issues" -F sub_issue_id=6533898329 >/dev/null || true
gh api -X POST "repos/$REPO/issues/17/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/16/sub_issues" -F sub_issue_id=6533898519 >/dev/null || true
gh api -X POST "repos/$REPO/issues/18/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/16/sub_issues" -F sub_issue_id=6533898608 >/dev/null || true
gh api -X POST "repos/$REPO/issues/19/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/16/sub_issues" -F sub_issue_id=6533898718 >/dev/null || true
gh api -X POST "repos/$REPO/issues/20/labels" -f "labels[]=wayfinder:prototype" >/dev/null
gh api -X POST "repos/$REPO/issues/16/sub_issues" -F sub_issue_id=6533898816 >/dev/null || true
gh api -X POST "repos/$REPO/issues/22/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/21/sub_issues" -F sub_issue_id=6533899001 >/dev/null || true
gh api -X POST "repos/$REPO/issues/23/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/21/sub_issues" -F sub_issue_id=6533899072 >/dev/null || true
gh api -X POST "repos/$REPO/issues/24/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/21/sub_issues" -F sub_issue_id=6533899160 >/dev/null || true
gh api -X POST "repos/$REPO/issues/25/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/21/sub_issues" -F sub_issue_id=6533899256 >/dev/null || true
gh api -X POST "repos/$REPO/issues/27/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/26/sub_issues" -F sub_issue_id=6533899461 >/dev/null || true
gh api -X POST "repos/$REPO/issues/28/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/26/sub_issues" -F sub_issue_id=6533899554 >/dev/null || true
gh api -X POST "repos/$REPO/issues/29/labels" -f "labels[]=wayfinder:research" >/dev/null
gh api -X POST "repos/$REPO/issues/26/sub_issues" -F sub_issue_id=6533899642 >/dev/null || true
gh api -X POST "repos/$REPO/issues/31/labels" -f "labels[]=wayfinder:prototype" >/dev/null
gh api -X POST "repos/$REPO/issues/30/sub_issues" -F sub_issue_id=6533899838 >/dev/null || true
gh api -X POST "repos/$REPO/issues/32/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/30/sub_issues" -F sub_issue_id=6533899928 >/dev/null || true
gh api -X POST "repos/$REPO/issues/33/labels" -f "labels[]=wayfinder:grilling" >/dev/null
gh api -X POST "repos/$REPO/issues/30/sub_issues" -F sub_issue_id=6533900017 >/dev/null || true

echo "==> Wiring native blocked_by dependency edges..."
gh api -X POST "repos/$REPO/issues/4/dependencies/blocked_by" -F issue_id=6533882351 >/dev/null || true  # #4 blocked by #2
gh api -X POST "repos/$REPO/issues/4/dependencies/blocked_by" -F issue_id=6533897007 >/dev/null || true  # #4 blocked by #3
gh api -X POST "repos/$REPO/issues/8/dependencies/blocked_by" -F issue_id=6533897400 >/dev/null || true  # #8 blocked by #7
gh api -X POST "repos/$REPO/issues/9/dependencies/blocked_by" -F issue_id=6533897400 >/dev/null || true  # #9 blocked by #7
gh api -X POST "repos/$REPO/issues/10/dependencies/blocked_by" -F issue_id=6533897505 >/dev/null || true  # #10 blocked by #8
gh api -X POST "repos/$REPO/issues/13/dependencies/blocked_by" -F issue_id=6533898007 >/dev/null || true  # #13 blocked by #12
gh api -X POST "repos/$REPO/issues/15/dependencies/blocked_by" -F issue_id=6533898229 >/dev/null || true  # #15 blocked by #14
gh api -X POST "repos/$REPO/issues/18/dependencies/blocked_by" -F issue_id=6533898519 >/dev/null || true  # #18 blocked by #17
gh api -X POST "repos/$REPO/issues/19/dependencies/blocked_by" -F issue_id=6533898519 >/dev/null || true  # #19 blocked by #17
gh api -X POST "repos/$REPO/issues/20/dependencies/blocked_by" -F issue_id=6533898608 >/dev/null || true  # #20 blocked by #18
gh api -X POST "repos/$REPO/issues/23/dependencies/blocked_by" -F issue_id=6533899001 >/dev/null || true  # #23 blocked by #22
gh api -X POST "repos/$REPO/issues/24/dependencies/blocked_by" -F issue_id=6533899072 >/dev/null || true  # #24 blocked by #23
gh api -X POST "repos/$REPO/issues/25/dependencies/blocked_by" -F issue_id=6533899001 >/dev/null || true  # #25 blocked by #22
gh api -X POST "repos/$REPO/issues/25/dependencies/blocked_by" -F issue_id=6533899072 >/dev/null || true  # #25 blocked by #23
gh api -X POST "repos/$REPO/issues/28/dependencies/blocked_by" -F issue_id=6533899461 >/dev/null || true  # #28 blocked by #27
gh api -X POST "repos/$REPO/issues/29/dependencies/blocked_by" -F issue_id=6533899554 >/dev/null || true  # #29 blocked by #28
gh api -X POST "repos/$REPO/issues/32/dependencies/blocked_by" -F issue_id=6533899838 >/dev/null || true  # #32 blocked by #31

echo "Done! All 7 Wayfinder maps and 26 child tickets are labeled and wired."

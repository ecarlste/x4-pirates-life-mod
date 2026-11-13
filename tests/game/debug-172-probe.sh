#!/usr/bin/env bash
# [DEBUG-172] Throwaway probe loop for #172 (capture_wing_holds_fire overshoot). Delete before the PR.
#
# Runs capture_wing_holds_fire N times in one game session, keeps the debuglog, and prints:
#   - fail rate at the loop's 3-point margin (lowest hull < 72) and at the real 20-point margin (< 55)
#   - mean hull drop after the wingman's first hold, by distance at that hold
#   - fail rate by wingman and target piloting skill (needs the [DEBUG-172] skills line in the test)
#   - every run that went under 60%
#
# Usage: tests/game/debug-172-probe.sh <label> [repeats=50]     run, save, analyse
#        tests/game/debug-172-probe.sh --analyze <debuglog.txt>  analyse a saved log only
# Logs are saved to $PROBE_LOGS (default: ~/x4-debug-172-logs/<label>-debuglog.txt).

set -euo pipefail

analyze() {
    awk '
    function num(re, off) { if (match($0, re)) return substr($0, RSTART + off, RLENGTH - off) + 0; return -1 }
    /DEBUG-172\] skills/ { w = num("wingman piloting [0-9]+", 17); t = num("target piloting [0-9]+", 16) }
    / holds on event_object/ { holds++; if (hold == "") hold = num("hull [0-9.]+", 5) }
    / holds on / && !/ holds on event_object/ { if (dist == "") dist = num("distance [0-9.]+", 9) }
    /(PASS|FAIL) capture_wing_holds_fire/ {
        runs++
        low = num("lowest hull [0-9.]+", 12)
        if (low < 0) { other++; print "  other result: " substr($0, index($0, "capture_wing")); reset(); next }
        if (low < 72) f3++
        if (low < 55) f20++
        if (dist != "") {
            b = (dist < 700) ? "a <700m" : (dist < 1200) ? "b 700-1200m" : (dist < 1600) ? "c 1200-1600m" : "d >=1600m"
            dn[b]++; ds[b] += hold - low; if (low < 72) df[b]++
        }
        if (w >= 0) { wb = (w <= 5) ? "a 0-5" : (w <= 8) ? "b 6-8" : (w <= 12) ? "c 9-12" : "d 13-15"; wn[wb]++; if (low < 72) wf[wb]++ }
        if (t >= 0) { tb = (t <= 5) ? "a 0-5" : (t <= 8) ? "b 6-8" : (t <= 12) ? "c 9-12" : "d 13-15"; tn[tb]++; if (low < 72) tf[tb]++ }
        lows[low]++
        if (low < 60) deep = deep sprintf("  lowest %s%%: hold at %s%%, %sm, %s holds, wingman skill %s, target skill %s\n", low, hold, dist, holds, w, t)
        reset()
    }
    function reset() { hold = ""; dist = ""; holds = 0; w = -1; t = -1 }
    BEGIN { reset() }
    END {
        printf "runs %d: fail at 3 pts (<72%%) %d (%d%%), at 20 pts (<55%%) %d, other results %d\n", runs, f3, runs ? 100 * f3 / runs : 0, f20, other
        print "drop after first hold, by distance at the hold:"
        n = asorti(dn, k); for (i = 1; i <= n; i++) printf "  %-14s %3d runs, fail %3d, mean drop %.1f pts\n", substr(k[i], 3), dn[k[i]], df[k[i]], ds[k[i]] / dn[k[i]]
        print "fail at 3 pts by wingman piloting:"
        n = asorti(wn, k); for (i = 1; i <= n; i++) printf "  %-6s %d of %d\n", substr(k[i], 3), wf[k[i]], wn[k[i]]
        print "fail at 3 pts by target piloting:"
        n = asorti(tn, k); for (i = 1; i <= n; i++) printf "  %-6s %d of %d\n", substr(k[i], 3), tf[k[i]], tn[k[i]]
        printf "lowest hull values:"; n = asorti(lows, k, "@ind_num_asc"); for (i = 1; i <= n; i++) printf " %s(x%d)", k[i], lows[k[i]]; print ""
        if (deep != "") { print "runs under 60%:"; printf "%s", deep }
    }' "$1"
    # Wingman distance to the target from the test's 1 s trace: above the gate, and holding (35-75%)
    awk '
    function get(re, a, b) { if (match($0, re)) return substr($0, RSTART + a, RLENGTH - a - b) + 0; return -1 }
    /trace: hull/ { h = get("hull [0-9.]+%", 5, 1); d = get("wingman [0-9.]+m away", 8, 6); s = get("at [0-9.]+ m/s", 3, 4)
        p = (h < 75 && h >= 35) ? "holding" : (h >= 75) ? "above 75%" : ""
        if (p == "") next
        n[p]++; v[p, n[p]] = d; if (d < 100) near[p]++
        if (d < 100 && s < 10) { st++; if (st > mst) mst = st } else st = 0
        if (!(p in rmin) || d < rmin[p]) rmin[p] = d }
    /(PASS|FAIL) capture_wing_holds_fire/ { runs++
        if (("holding" in rmin) && rmin["holding"] < 100) close_runs = close_runs " " runs
        if (mst >= 3) parked_runs = parked_runs sprintf(" %d(%ds)", runs, mst)
        delete rmin; st = 0; mst = 0 }
    END {
        print "wingman distance to the target (1 s trace):"
        for (k = 1; k <= 2; k++) { p = (k == 1) ? "above 75%" : "holding"; if (!n[p]) continue
            delete D; for (i = 1; i <= n[p]; i++) D[i] = v[p, i]; m = asort(D)
            printf "  %-9s %5d s, p10 %4.0f m, median %4.0f m, p90 %4.0f m, %d s within 100 m\n", p, m, D[int(m / 10) + 1], D[int((m + 1) / 2)], D[int(m * 9 / 10)], near[p] }
        print "  runs that came within 100 m while holding:" (close_runs == "" ? " none" : close_runs)
        print "  runs parked (under 100 m and under 10 m/s) 3 s or more:" (parked_runs == "" ? " none" : parked_runs)
    }' "$1"
}

if [ "${1:-}" = --analyze ]; then analyze "$2"; exit 0; fi

label=${1:?usage: $0 <label> [repeats]}
repeats=${2:-50}
logs=${PROBE_LOGS:-$HOME/x4-debug-172-logs}
mkdir -p "$logs"
root=$(git rev-parse --show-toplevel)
cd "$root"
set +e
make game-test RUNNER_ARGS="-Test capture_wing_holds_fire -Repeat $repeats" > "$logs/$label-runner.txt" 2>&1
set -e
grep -E 'Repeated:|clean_log|load_order|GAME TESTS|never started|didn.t finish' "$logs/$label-runner.txt" || true
# The test profile's log, as the runner reports it (Windows path -> WSL)
win=$(grep -oE 'results go to .*debuglog\.txt' "$logs/$label-runner.txt" | sed 's/^results go to //')
cp "$(wslpath -u "$win")" "$logs/$label-debuglog.txt"
echo "log: $logs/$label-debuglog.txt"
analyze "$logs/$label-debuglog.txt"

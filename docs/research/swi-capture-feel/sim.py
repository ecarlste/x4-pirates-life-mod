"""Monte Carlo model of bail checks in the 9.x build and under SWI's Enhanced Bailing.

Run: python3 -I docs/research/swi-capture-feel/sim.py
Models only the bail phase: from the moment the target is inside the gates
(shields < 20%, hull < 75%) until its pilot bails. The time to get there (break
phase) is not modelled. See docs/research/swi-capture-feel.md.
"""
import random
import statistics as st

N = 4000            # fights per cell
LIMIT = 900.0       # give up after 15 min in the gates
PLAYER_GAP = 2.0    # mean seconds between qualifying player hits [inferred]
WING_CYCLE = (20.0, 40.0)  # wing-only: seconds between shield knock-downs [inferred]

# Targets: (label, crew capacity, combat type for SWI's halving)
VANILLA = [("S fighter (cap 2)", 2, True), ("M corvette (cap 6)", 6, True),
           ("M miner (cap 8)", 8, False), ("M transport (cap 17)", 17, False)]
SWI = [("S fighter (TIE/X-wing, cap 1)", 1, True), ("M corvette (CR90, cap 36)", 36, True),
       ("M miner (Action IV, cap 7)", 7, False), ("M transport (Gozanti, cap 17)", 17, False),
       ("M transport (YT-1300, cap 5)", 5, False)]


LOGGED = False  # True: draw 9.x chances from Erik's logged plays (32-88%) instead [inferred]


def vanilla_chance(rng, wing):
    if LOGGED:
        return rng.uniform(32, 88)
    cs = rng.uniform(20, 60)                 # ship combined skill [inferred from metrics logs]
    c = int(46 - cs / 5)                     # hull and damage ratios = 1 (S attacker, healthy)
    if wing:
        c = c // 4                           # vanilla /4 ...
        c = c * 4                            # ... undone by the hook's capture-wing x4
    return min(100, int(c * 2))              # hook's x2, capped


def vanilla_batch(cap, count, morale):
    return min(max(min(int(cap * (15 - morale) / 15), count), 1), 3)


def swi_raw(rng, cap, count, morale, combat):
    crew = 10 - ((count + 1) / cap * 10) if cap else 0
    crew = min(max(crew, 0), 10)
    att = rng.uniform(150, 200)              # attacker shield% + hull%
    tgt = rng.uniform(0, 19) + rng.uniform(40, 74)
    hs = min(att / tgt, 10)
    size = 0                                 # S attacker vs S or M target
    c = 11 + crew + hs + size - morale * 1.75
    if c <= 0:
        c = 1
    if combat:
        c /= 2
    return c


def swi_batch(rng, cap, count):
    lo = max(int(cap * 0.2), 1)
    hi = int(count * 1.2)
    n = rng.randint(lo, hi) if lo < hi else count
    return min(n, count)


def next_check(rng, t_ready, wing, phase, cycle, tick):
    """Time of the first check at or after t_ready."""
    if wing:
        k = max(0, -(-(t_ready - phase) // cycle))
        t_hit = phase + k * cycle
    else:
        t_hit = t_ready + rng.expovariate(1 / PLAYER_GAP)
    if tick:
        t_tick = -(-t_ready // tick) * tick   # tick fires 'shouldwebail' every `tick` s
        t_hit = min(t_hit, t_tick)
    return t_hit


def fight(rng, model, cap, combat, wing, morale, adjust=None, cooldown=None, tick=None):
    swi = model == "swi"
    fill = rng.uniform(0.6, 0.95) if swi else rng.uniform(0.2, 0.75)
    count = int(round(cap * fill))
    cd = cooldown if cooldown else (5.0 if swi else 30.0)
    cycle = rng.uniform(*WING_CYCLE)
    phase = rng.uniform(0, cycle)
    t, checks, succ = next_check(rng, 0.0, wing, phase, cycle, tick), 0, 0
    while t < LIMIT:
        checks += 1
        if swi:
            raw = swi_raw(rng, cap, count, morale, combat)
            p = adjust(raw, rng, wing, t) if adjust else raw
        else:
            p = vanilla_chance(rng, wing)
        if rng.random() * 100 < p:
            succ += 1
            n = swi_batch(rng, cap, count) if swi else vanilla_batch(cap, count, morale)
            if n >= count:
                return t, checks, succ, checks == 1
            count -= n
        t = next_check(rng, t + cd, wing, phase, cycle, tick)
    return LIMIT, checks, succ, False


def pressure(step=8.0, every=10.0, cap=80.0):
    """The agreed bail pressure: plain chance + step per `every` s inside the gates, capped."""
    return lambda raw, rng, w, t: max(raw, min(raw + step * (t // every), cap))


def cell(model, cap, combat, wing, morales, **kw):
    rng = random.Random(1)
    ts, cs, ss, fs = [], [], [], 0
    for i in range(N):
        m = rng.choice(morales)
        a, b, c, f = fight(rng, model, cap, combat, wing, m, **kw)
        ts.append(a); cs.append(b); ss.append(c); fs += f
    ts.sort()
    return dict(mean=st.mean(ts), med=ts[N // 2], p60=sum(x <= 60 for x in ts) / N,
                gaveup=sum(x >= LIMIT for x in ts) / N, first=fs / N, checks=st.mean(cs), succ=st.mean(ss))


def fmt(r):
    return "%5.0f s | %4.0f s | %3.0f%% | %3.0f%% | %4.1f | %3.1f | %3.0f%%" % (
        r["mean"], r["med"], 100 * r["p60"], 100 * r["first"], r["checks"], r["succ"], 100 * r["gaveup"])


ALL = list(range(13))   # NPC pilot morale 0-12 (characters.xml) [read]

if __name__ == "__main__":
    import sys
    hdr = "| Target | Attacker | Mean | Median | <=60 s | 1st-check bail | Checks | Successes | >15 min |"
    sep = "|---|---|---|---|---|---|---|---|---|"

    def table(title, model, targets, **kw):
        print("\n" + title + "\n\n" + hdr + "\n" + sep)
        for lab, cap, combat in targets:
            for wing in (False, True):
                r = cell(model, cap, combat, wing, ALL, **kw)
                print("| %s | %s | %s |" % (lab, "wing only" if wing else "player", fmt(r).replace(" | ", " | ")))

    table("(a) 9.x build as is", "vanilla", VANILLA)
    table("(b) plain SWI", "swi", SWI)
    table("(b2) SWI + the 9.x hook's x2 ported as is (x4 dropped, int truncation)", "swi", SWI,
          adjust=lambda raw, rng, w, t: min(100, int(raw * 2)))
    for k in (4, 8, 16):
        table("(c) SWI, multiplier x%d" % k, "swi", SWI, adjust=lambda raw, rng, w, t, k=k: min(100, raw * k))
    for a in (10, 15, 20, 25):
        table("(c) SWI, flat +%d" % a, "swi", SWI, adjust=lambda raw, rng, w, t, a=a: min(100, raw + a))
    table("(c) SWI, floor 20", "swi", SWI, adjust=lambda raw, rng, w, t: max(raw, 20))
    table("(c) SWI, 9.x chance (vanilla formula x2) at SWI's 5 s", "swi", SWI,
          adjust=lambda raw, rng, w, t: vanilla_chance(rng, False))
    table("(c) SWI, 9.x chance with a 30 s cooldown", "swi", SWI,
          adjust=lambda raw, rng, w, t: vanilla_chance(rng, False), cooldown=30.0)
    table("(c) SWI, plain, 30 s cooldown", "swi", SWI, cooldown=30.0)
    table("(c) SWI, flat +15 with a 10 s 'shouldwebail' tick", "swi", SWI,
          adjust=lambda raw, rng, w, t: min(100, raw + 15), tick=10.0)
    table("(c) SWI, agreed bail pressure (+8 per 10 s in the gates, cap 80) with its 10 s tick", "swi", SWI,
          adjust=pressure(), tick=10.0)
    table("(c) SWI, bail pressure without the tick", "swi", SWI, adjust=pressure())
    table("(c) SWI, bail pressure +12 per 10 s with the tick", "swi", SWI, adjust=pressure(step=12), tick=10.0)
    LOGGED = True
    table("(a') 9.x build, chances drawn from Erik's logged plays (32-88%)", "vanilla", VANILLA)
    LOGGED = False
    table("(c) SWI, flat +15 with a 15 s cooldown", "swi", SWI,
          adjust=lambda raw, rng, w, t: min(100, raw + 15), cooldown=15.0)

    print("\nPer-check chance by morale (S attacker, target at hull 60%, shields 10%, attacker 200%):\n")
    print("| Morale | 9.x player | 9.x wing | SWI fighter | SWI fighter x2 hook | SWI miner/transport, crew 70% (cap 17) |")
    print("|---|---|---|---|---|---|")
    for m in (0, 3, 6, 7, 9, 12):
        def raw(cap, count, combat):
            crew = min(max(10 - ((count + 1) / cap * 10), 0), 10)
            c = 11 + crew + 200 / 70 - m * 1.75
            c = 1 if c <= 0 else c
            return c / 2 if combat else c
        f = raw(1, 1, True)
        t = raw(17, 12, False)
        print("| %d | 76 | 72 | %.1f | %d | %.1f |" % (m, f, min(100, int(f * 2)), t))

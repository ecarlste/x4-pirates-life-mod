# X4 AI script gotchas

Status: Done; add to it as more turn up.

How X4's AI scripts (`aiscripts/`) behave where the docs and `aiscripts.xsd` don't say. Each was found on the SWI build (X4 8.00) while fixing the capture wing's stall ([#205](https://github.com/ecarlste/x4-pirates-life-mod/issues/205), [PR #207](https://github.com/ecarlste/x4-pirates-life-mod/pull/207)).

## Interrupt handlers

**Only the first matching interrupt handler runs.** When an event matches more than one handler in a script's `<interrupts>`, X4 runs the first one in order and skips the rest. So handler order matters: a later handler whose conditions overlap an earlier one's never fires. In #205 a handler placed after the miss-window reset, which matches every hit, never ran ([round 2](https://github.com/ecarlste/x4-pirates-life-mod/issues/205#issuecomment-6883653152)).

**How to apply:** put narrow handlers before broad ones, or fold them into one handler with `do_if` branches.

## Attention levels

**`shoot_at` only works in `attention min="visible"`.** Out of visible attention the ship doesn't fire. An order whose fighting runs in other attention levels (`order.apirateslife.capture.xml` runs in `attention min="unknown"`) needs its own script, with a visible block, for the firing. That's why the finisher's pass is `aiscripts/apirateslife.capture.pass.xml`, a script the order calls with `run_script` ([round 3](https://github.com/ecarlste/x4-pirates-life-mod/issues/205#issuecomment-6883901809), [PR #207](https://github.com/ecarlste/x4-pirates-life-mod/pull/207)).

## Cutting a called script short

**`abort_called_scripts resume="<label>"`** ends the running `run_script` (and anything it called) and resumes the caller at that label. The capture order uses it from its interrupt handlers to go back to `decide` mid-pass. A pass cut short like this and started again carries on from where the ship is, still on its run-in, with no lost fire: the trace in #205 showed the trim to two guns and the restore aborting a pass, and the next pass starting from about 150 m ([round 7](https://github.com/ecarlste/x4-pirates-life-mod/issues/205#issuecomment-6902093469); [capture-operation.md](../specs/capture-operation.md#design), the finisher's pass).

## Shields

**S/M shields recharge only after about 6 s without hits.** A ship that's being hit regrows no shields at all, however fast its shields recharge once they start (Erik, on [#172](https://github.com/ecarlste/x4-pirates-life-mod/issues/172)). So slow, steady fire keeps them down, while a gap of more than about 6 s lets them regrow. A finisher whose passes are more than about 6 s apart loses ground between them. That's #205's cause 2, and why some runs against a still TIE/LN still time out: the turn between passes lasts 6 to 10 s ([round 7](https://github.com/ecarlste/x4-pirates-life-mod/issues/205#issuecomment-6902093469); the measured rate is in [capture-operation.md](../specs/capture-operation.md#design), the finisher's pass).

## How the probe rounds worked

#205 took seven rounds of probes: debug lines once a second (distance, speed, shots, the target's bearing off the nose), one change at a time, each run 10 or 20 times with `make game-test RUNNER_ARGS="-Test <Name> -Repeat 10"`. **Posting each round's findings on the issue**, with its numbers, its WIP commit and what was ruled out, is what let the investigation survive two compactions of the session's context. Do the same for any investigation that takes more than one round.

Two lessons from the numbers:

- **10 runs is noisy.** 2 of 10 against 4 of 10 was within noise; compare on the probe's own measures (seconds with a shot, damage per pass) and use the red rate as the final gate, over 20 runs or more.
- **Check where a slow behaviour starts before blaming it.** Round 4 blamed the order's close-in for slow passes; round 5's bearing probe showed they were turnarounds.

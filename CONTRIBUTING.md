# Contributing

Thanks for helping make *Sword Tale: Lost Excalibur* playable for everyone.

## House rules

1. **No game files.** Never commit anything from the game installation (binaries,
   `.pak`, assets, extracted content). The repo ships only original work.
2. **No DRM talk.** No instruction that helps bypass ownership checks or Steam
   DRM. The game is free; own it legally and run it under Steam/Proton.
3. **Evidence-based.** If you open an issue about a crash, run
   `tools/collect-crash-info.sh` and paste the output. Reproducible > anecdotal.
4. **Kind to the developer.** The game is a student-team project
   (University of the Thai Chamber of Commerce). Frame reports constructively.
5. **One feature per PR**, shellcheck-clean, and covered by the CI checks.

## Issue template (short form)

```
### Title: one sentence
### Game: Sword Tale: Lost Excalibur (App 3305630), game build/date
### Platform: distro, Proton version, GPU/driver, RAM
### Steps to reproduce:
### Observed:
### Expected:
### Evidence: (attach collect-crash-info.sh output)
```

## Development loop

```bash
# after editing config templates:
tools/verify-launch.sh          # boots the game once, checks the engine log appears

# after editing shell scripts:
bash -n script.sh
shellcheck script.sh

# run the CI suite locally (same checks as .github/workflows/ci.yml):
bash -n script.sh && shellcheck script.sh
python3 - <<'PY'
# replicate the workflow's inline ini validator (see ci.yml) here
PY
```

Merge happens on green CI and at least one maintainer review.
# Job Snapshots

This folder holds resumable job-state snapshots for substantial coding tasks.

## Active Jobs

- Use exactly one canonical in-progress file per active job: `docs/jobs/YYYY-MM-DD-<job-slug>-ongoing.md`.
- Update that file in place as the job evolves.
- Read it first when resuming the same job after interruption or compaction.
- Create one only when the task is long-running, non-linear, multi-stage, or likely to be resumed.
- Skip it for simple one-pass tasks that do not need a durable resume point.
- Use the job start date in ISO format as the filename prefix and keep that same date if the job resumes later.

## Completed Jobs

- Move the final job record to `docs/jobs/archive/YYYY-MM-DD-<job-slug>.md`.
- When the task is done, remove the `-ongoing` suffix but keep the same date prefix and slug.
- Do not keep multiple competing in-progress files for the same job.

## Relationship To Other State

- `MEMORY.md` is the compact current-state summary.
- `memory/YYYY-MM-DD.md` is the chronological project history.
- `docs/jobs/` is for active per-job working state.
- `docs/jobs/archive/` is for completed job records.
- `tmp/` is only for disposable artifacts such as build outputs, DerivedData, and scratch files.

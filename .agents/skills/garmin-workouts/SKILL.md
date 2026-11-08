---
name: garmin-workouts
description: Convert training sessions from Google Calendar, training-plan PDFs, or pasted text into Garmin Connect workouts. Use when preparing, uploading, or scheduling workouts, including lap-button steps, distance or timed reps, recoveries, and VMA-based pace targets.
---

# Garmin workouts

## Confirmed preferences

- Use Lap-ended warmups. Preserve the prescribed duration as a step description,
  not as an automatic end condition. Do not promise a timed alert from that text.
- Work reps advance automatically at their prescribed time or distance.
- Categorize running drills as Other. They end on Lap, with the prescribed
  duration in the step notes.
- Use a timed cooldown when the source gives a duration. An unspecified cooldown
  ends on Lap.
- Distinguish active recovery from standing rest. Ask when the source is ambiguous.
  Timed recovery or rest advances automatically and keeps the activity timer running.
- After the last work rep of the whole session, omit the usual final recovery
  and insert standing rest ending on Lap before the cooldown. Do not apply this
  rule after intermediate repeat blocks. Apply it as the general preference
  unless Pedro explicitly requests a different finish. Do not add both a timed
  final recovery and this Lap-ended rest.
- A Lap-ended step, standing rest, activity pause, Auto Pause, and Auto Lap are
  different behaviors. Do not claim a workout configures device-level settings.
- For the Corrida training plan, use the `Coureurs réguliers II` column unless
  Pedro selects another group.
- VMA is provisionally 15 km/h, stated in November 2026. Confirm its relevance
  when using it for a later plan. Do not update Garmin profile settings from this estimate.
- VMA alone does not determine the intensity of a session. Use source percentages
  or ask Pedro to approve proposed percentages. The `soutenu` fallback below is
  already approved. Other qualitative effort labels need approval before being
  converted into numerical alerts.
- Pedro's fallback interpretation of `soutenu` is 75-88% VMA when the source gives
  no numerical target. An explicit coach target overrides this fallback. Do not
  apply it to unlabeled sessions or assume it means the same as `rapide`.
- Do not treat a week-specific recovery duration or approved pace range as a
  permanent default.

## Prepare the preview

1. Confirm the inclusive date range and source. Do not assume that "next week"
   means the next seven days. Confirm the calendar timezone when calendar events
   determine the workout date.
1. Discover the available integration before accessing Google Calendar. If none
   is available, ask for an approved browser session, an export, or event text.
   When Pedro supplies a PDF instead, identify it as the source. Do not claim
   to have read or synchronized Google Calendar.
1. Read the complete event descriptions or relevant PDF table, including the
   selected training group. Use `pdftotext -layout` for PDFs. If extraction is
   empty, render pages and use image reading or OCR, checking uncertain values.
1. Extract warmup, drills, every work rep, recovery, block transition, and cooldown.
   Confirm ambiguous pyramids or repeat counts instead of inventing a sequence.
   Check whether recovery follows the final rep. Avoid adding both a final repeat
   recovery and a block-transition recovery unless prescribed.
1. Read Garmin's scheduled workouts for the range. Inspect library candidates
   before reusing one. Compare actual steps and targets, not just names.
   Leave Coach workouts and other existing entries untouched unless Pedro
   explicitly authorizes a change. Flag overlapping dates in the preview.
1. Present a step-by-step Garmin Connect-style preview for each date. Show every
   step in order, with its category, duration or end condition, target, and notes,
   including the final rest and cooldown. Separate prescribed facts from approved
   suggestions. Ask only about unresolved choices.
1. Preserve the full original session description in the workout notes, in its
   source language. For a multi-group plan, retain the selected group's text.
   Preserve the relevant original wording in each step's notes as well. Map
   these notes to Garmin's `description` fields. Keep source text distinct from
   added cues, translations, and approved interpretations. Do not silently
   replace the original with a summary or translation. Label added steps that
   have no source wording as user preferences.
1. Maintain one canonical workout definition. Generate both the preview and the
   upload payload from it. Apply approved edits there and regenerate both outputs.
   Do not rebuild the upload independently from memory or from the preview prose.
1. Respect preview-only requests. Save private, dated workout drafts outside the
   public dotfiles repository and report their paths. Never put calendar links,
   event identifiers, profile details, or a dated training schedule in this skill.

## Build Garmin workout data

Discover the Garmin MCP tools with `list_commands`, then `describe_commands`
before invoking them. Follow the live tool schema. Use `get_workout_by_id` with
`raw: true` to check existing Garmin DTO conventions when needed. Do not carry
owner, workout, segment, or step IDs into a new workout.

- Running sport: `sportTypeId: 1`, `sportTypeKey: "running"`.
- Regular steps: `type: "ExecutableStepDTO"`.
- Step types: warmup `1`, cooldown `2`, interval `3`, recovery `4`, rest `5`,
  other `7`. Running drills use `stepTypeId: 7`, `stepTypeKey: "other"`.
- End conditions: Lap `1 / lap.button`, time `2 / time` in seconds, distance
  `3 / distance` in meters. A Lap-ended step has no timed end condition.
- No target: `workoutTargetTypeId: 1`, `workoutTargetTypeKey: "no.target"`.
- Pace target: `workoutTargetTypeId: 6`, `workoutTargetTypeKey: "pace.zone"`.
  Store `targetValueOne` and `targetValueTwo` on the step, not inside `targetType`.
  Follow Garmin's raw convention: faster speed in `targetValueOne`, slower speed
  in `targetValueTwo`.
- Convert VMA percentages to m/s: `speed = VMA_kmh * percentage / 100 / 3.6`.
  For pace in seconds/km: `speed = 1000 / pace_seconds`. Do not store min/km in
  Garmin's speed fields. Round only the displayed pace, not the conversion input.
- Repeat groups: `type: "RepeatGroupDTO"`, `numberOfIterations`, and
  `endCondition: {"conditionTypeId": 7, "conditionTypeKey": "iterations"}`.
  Use one depth-first `stepOrder` counter across groups and children. Explicit
  steps are also valid and can make final-recovery handling easier to audit.
- Named HR zones use target type `4 / heart.rate.zone` with `zoneNumber`.
  Custom bpm ranges use the same target type with `targetValueOne` and
  `targetValueTwo`, without `zoneNumber`. Never infer bpm from VMA.
- Do not add targets to recovery, rest, drills, or easy running unless prescribed
  or approved. Keep source instructions and provisional-target notes in descriptions.

## Upload and verify

1. Obtain approval for the prepared definitions before writing to Garmin. An
   explicit preview-only request overrides an earlier request to upload.
1. Upload the payload generated from the exact approved canonical definition.
   Check that step categories, original-language notes, final rests, and targets
   match the latest preview. Do not make unreviewed structural changes at upload.
1. Recheck the target dates for duplicates or changed entries. A schedule call
   can be idempotent for an existing workout ID and date, but uploading inline
   workout data can still create another library workout.
1. Upload once and retain returned workout IDs. Schedule those IDs on the
   confirmed dates. If a call partially fails, inspect the result and Garmin
   state before retrying only the failed items.
1. Read back the uploaded workouts and schedule. Verify every rep, target,
   recovery, repeat count, and date. Report partial failures accurately.
1. Provide Garmin links and distinguish creation, scheduling, and device sync.
   Do not claim the watch received a workout without evidence of device sync.
   Never delete or unschedule existing workouts without explicit authorization.

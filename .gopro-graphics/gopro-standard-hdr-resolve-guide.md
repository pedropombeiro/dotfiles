# GoPro Hero 13 Standard Profile → HDR Grade in Free DaVinci Resolve

A repeatable workflow for grading 10-bit 4K **standard color profile (fixed white balance)**
footage into an **HDR10 / PQ** deliverable for YouTube, using the **free** version of DaVinci
Resolve 21 on macOS — including telemetry overlay and preserved recording timestamps.

## Assumptions

- Footage: GoPro Hero 13, **standard color profile**, 10-bit, 4K, **fixed white balance**
- DaVinci Resolve **21 (free)** on macOS
- Target: **HDR10 / PQ**, destination **YouTube**
- `ffmpeg` installed (Homebrew)

> **Difference from GP-Log workflow:** standard profile footage is already display-referred
> Rec.709 — no log curve, no IDT required. The camera's tone-mapper has already rolled off
> highlights, so the HDR output won't recover blown skies, but 10-bit bit depth keeps the
> SDR→HDR map clean with minimal banding.

## Free-version constraints to keep in mind

- **No 10-bit H.264/H.265 export** (8-bit only) → deliver via ProRes / DNxHR instead
- No HDR scopes, HDR Wheels palette, Dolby Vision, HDR10+, or static HDR10 metadata (MaxCLL/MaxFALL)
- Without an HDR reference monitor you're grading semi-blind → trust the waveform, check on
  an HDR screen before publishing

---

## 1. Project color management (RCM)

**Project Settings → Color Management:**

- **Color science:** `DaVinci YRGB Color Managed`
- **Input color space:** `Rec.709 Gamma 2.4`
- **Timeline color space:** `DaVinci Wide Gamut Intermediate`
- **Output color space:** `Rec.2100 ST2084 (1000 nits)`

> RCM automatically handles the SDR→HDR inverse tone map for every clip tagged Rec.709 — no
> per-clip input transform to assign (unlike the ACES/IDT approach in the GP-Log workflow).

## 2. Assign input color space (per clip, if needed)

Resolve picks up the `bt709` color tags from the GoPro's HEVC stream automatically. Verify
on the **Color** page that each clip's **Input Color Space** (right-click clip → Clip
Attributes → Color Space) shows `Rec.709 Gamma 2.4`. Correct any outliers manually.

## 3. Grade (in DaVinci Wide Gamut Intermediate)

Suggested node order:

1. **Exposure** — **Lift/Gamma/Gain** wheels, or Primaries Bars for fine control
2. **Contrast / tone** — curves; go gently (the image is already tone-mapped — aggressive
   contrast risks banding in the stretched PQ range)
3. **Secondaries** — saturation, qualifiers, power windows
4. _(optional)_ **Sharpen** — Blur palette, drag **Radius below 0.50**; use **Coring** to
   protect noise; keep subtle; put on its own node near the end

Notes:

- **White balance is already baked** (fixed WB in camera) — no neutralization step needed.
  Record the Kelvin value you locked for consistency across a shoot.
- The RCM output transform applies an HDR tone-map on the way out; check the waveform in
  **nits** (right-click scope → nits) — legitimate peaks will sit around **1000 nits**.
- In-camera highlight roll-off means the skies won't open up like GP-Log; compensate with
  **power windows** or **qualifiers** rather than global lifts.
- **Log wheels** (`Color Wheels palette → Log mode`) are less useful here since the working
  space is not log-encoded; stick to Custom curves for targeted tonal work.

## 4. Deliver

> **Do NOT pick H.264 or H.265** — free Resolve silently renders them 8-bit, destroying HDR.

**Deliver page → Custom Export:**

- **Format:** QuickTime
- **Codec:** Apple ProRes
- **Type:** 422 HQ _(10-bit, native to macOS, opens in QuickTime. DNxHR HQX is the
  cross-platform alternative but won't open in QuickTime Player.)_
- **Resolution:** 3840×2160 (UHD), matching timeline frame rate
- **Render range:** **Entire Timeline**

> If the output comes out ~0.02 s / one frame, the render range is set to **In/Out** —
> switch it to **Entire Timeline**, or clear stray in/out marks with **Option+X**.

**Advanced Settings:**

- **Data Levels:** Video
- **Color Space Tag:** Rec2020
- **Gamma Tag:** ST2084 1000 nit
- **Tone Mapping:** None

## 5. Verify the export

```
ffprobe -hide_banner Rossens.mov
```

Confirm:

- Codec `prores (HQ)`, pixel format `yuv422p10le`
- Color tags `bt2020nc/bt2020/smpte2084`
- **Duration** = your real clip length (not `0.02 s`)

## 6. Copy the recording timestamp (stream copy — no re-encode)

```
TS=$(ffprobe -v quiet -show_entries format_tags=creation_time \
  -of default=nw=1:nk=1 original.MP4)

ffmpeg -i Rossens.mov -map 0 -c copy \
  -metadata creation_time="$TS" Rossens_stamped.mov
```

_(If the `tmcd` timecode track trips ffmpeg up, use `-map 0:v -map 0:a` instead of `-map 0`.)_

Re-run `ffprobe` to confirm `creation_time` updated **and** the `bt2020/smpte2084` tags survived.

> **Rotation:** some clips carry a `displaymatrix` rotation (e.g. −180° for an inverted
> mount). The stream copy preserves it; confirm Resolve and your player honour it.

## 7. Telemetry overlay

The graded file has **no telemetry** — GPMF data lives only in the original GoPro file.
Use the transparent-overlay method so the gauges sit pristine above the HDR grade:

1. In a telemetry tool (e.g. **Telemetry Overlay**, supports Hero 13), load the **original**
   GoPro `.MP4` to read GPS / speed / elevation.
2. _(Optional)_ import external data (Garmin `.fit` / `.gpx` for power, HR, cadence) and sync
   — the original's `creation_time` timestamp anchors the alignment.
3. Export a **transparent MOV** (gauges only, with alpha).
4. In Resolve: graded clip on **V1**, transparent overlay on **V2**, aligned at the same
   start frame. Render the final composite.

> Keep clips untrimmed for frame-accurate sync, or account for the offset explicitly.

## 8. Upload to YouTube

- Upload the ProRes master (or the final composited render).
- YouTube detects HDR from the **Rec.2020 + PQ + bt2020nc** tags and fills in the missing
  static metadata itself (assumes a Sony BVM-X300 mastering display).
- The **HDR** label may appear only after the 4K/HDR transcode finishes — which lands _after_
  the lower-resolution versions. Give it time.

---

## Appendix — optional HEVC transcode (smaller upload)

Free Resolve can't make 10-bit HEVC, but you can transcode the ProRes master yourself:

```
ffmpeg -i Rossens_stamped.mov -c:v libx265 -pix_fmt yuv420p10le \
  -crf 20 \
  -x265-params "colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10=1:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400" \
  -tag:v hvc1 Rossens_hdr10.mp4
```

- `master-display` above = P3-D65 primaries inside a Rec.2020 container, 1000-nit peak.
- Adjust `max-cll=1000,400` (MaxCLL, MaxFALL) to your content. `max-cll` is the x265
  parameter name; `max-call` is invalid and x265 silently omits the content-light metadata.
- For a plain YouTube upload you can drop the whole `master-display`/`max-cll` block and keep
  just `colorprim` / `transfer` / `colormatrix`.
- `-crf 20` is a sensible starting point for 4K60 upload masters. Higher CRF values make a
  much smaller file, but discard detail before YouTube performs its own transcode.

Verify the HEVC upload copy as well as the ProRes master:

```
ffprobe -v error -show_frames -select_streams v:0 -read_intervals "%+#1" \
  -of json Rossens_hdr10.mp4 | jq '.frames[0].side_data_list'
```

Confirm that it lists both `Mastering display metadata` and `Content light level metadata`, in
addition to `bt2020nc` / `bt2020` / `smpte2084` in the normal `ffprobe` stream output.

---

### Quick reference

| Step                 | Setting                          |
| -------------------- | -------------------------------- |
| Color science        | DaVinci YRGB Color Managed (RCM) |
| Input color space    | Rec.709 Gamma 2.4                |
| Timeline color space | DaVinci Wide Gamut Intermediate  |
| Output color space   | Rec.2100 ST2084 (1000 nits)      |
| Codec                | Apple ProRes 422 HQ (QuickTime)  |
| Render range         | Entire Timeline                  |
| Color Space Tag      | Rec2020                          |
| Gamma Tag            | ST2084 1000 nit                  |
| Data Levels          | Video                            |
| Tone Mapping         | None                             |

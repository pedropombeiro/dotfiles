# GoPro Hero 12 GP-Log → HDR Grade in Free DaVinci Resolve

A repeatable workflow for grading 10-bit 4K **GP-Log (Native WB)** footage into an
**HDR10 / PQ** deliverable for YouTube, using the **free** version of DaVinci Resolve 21
on macOS — including telemetry overlay and preserved recording timestamps.

## Assumptions

- Footage: GoPro Hero 12, **GP-Log**, 10-bit, 4K, **Native** white balance
- DaVinci Resolve **21 (free)** on macOS
- Target: **HDR10 / PQ**, destination **YouTube**
- `ffmpeg` installed (Homebrew)

## Free-version constraints to keep in mind

- **No 10-bit H.264/H.265 export** (8-bit only) → deliver via ProRes / DNxHR instead
- No HDR scopes, HDR Wheels palette, Dolby Vision, HDR10+, or static HDR10 metadata (MaxCLL/MaxFALL)
- GP-Log is **not** a native input color space → needs an IDT
- Without an HDR reference monitor you're grading semi-blind → trust the waveform, check on an HDR screen before publishing

---

## 1. Install the GP-Log ACES IDT (one-time)

GP-Log isn't recognized natively, and applying a GP-Log DCTL as an **OFX node watermarks**
the free version. The watermark-free route is to use it as an **ACES Input Transform (IDT)**.

1. Download the **GP-Log → ACES IDT (Native)** — the _IDT-flavored_ file, **not** the
   parameterized OFX `.dctl` — from a GoPro transform pack
   (`protune-transforms` on GitHub, or the GP-Tune Transform pack).
2. Copy it into the **user** ACES Transforms folder (not the system `/Library`):
   ```
   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/ACES Transforms/IDT/
   ```
   Create the `ACES Transforms/IDT` folders if they don't exist.
3. **Fully quit and relaunch** Resolve (IDTs load only at startup).

> If it doesn't appear: confirm the project is in ACES (step 2), that you installed the
> IDT file (not the OFX one), that it's in the **user** Library, and that you restarted.

## 2. Project color management (ACES)

**Project Settings → Color Management:**

- **Color science:** `ACEScct`
- **Output (ODT):** `Rec.2100 ST2084 (1000 nits)`

> Rec.2100 = Rec.2020 primaries + PQ. There is no separate "Rec.2020 ST.2084" to look for —
> Rec.2100 ST2084 **is** your HDR10/PQ output.

## 3. Assign the input transform (per clip)

On the **Color** page, set each clip's **ACES Input Transform** to the
**GoPro GP-Log (Native)** IDT.

## 4. Grade (in ACEScct)

Suggested node order:

1. **Exposure** — use the **Offset** wheel (clean log-space exposure shift)
2. **White balance** — correct the Native green cast (Temp/Tint); neutralize off a gray reference
3. **Contrast / tone** — curves, or **Log wheels**
   (_Color Wheels palette → top-left mode toggle → **Log** → Shadow / Midtone / Highlight / Offset_)
4. **Secondaries** — saturation, qualifiers, power windows
5. _(optional)_ **Sharpen** — Blur palette, drag **Radius below 0.50**; use **Coring** to
   protect noise; keep it subtle; put it on its own node near the end

Notes:

- The ACES tone-map already bakes in an S-curve + highlight roll-off → go **easy** on contrast and saturation.
- The waveform topping out near **768** (10-bit) is **correct** — that's 1000 nits on the PQ
  curve, not clipping. You can switch the waveform to read in **nits** if that's clearer.

## 5. Deliver

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

## 6. Verify the export

```
ffprobe -hide_banner Rossens.mov
```

Confirm:

- Codec `prores (HQ)`, pixel format `yuv422p10le`
- Color tags `bt2020nc/bt2020/smpte2084`
- **Duration** = your real clip length (not `0.02 s`)

## 7. Copy the recording timestamp (stream copy — no re-encode)

```
TS=$(ffprobe -v quiet -show_entries format_tags=creation_time \
  -of default=nw=1:nk=1 original.MP4)

ffmpeg -i Rossens.mov -map 0 -c copy \
  -metadata creation_time="$TS" Rossens_stamped.mov
```

_(If the `tmcd` timecode track trips ffmpeg up, use `-map 0:v -map 0:a` instead of `-map 0`.)_

Re-run `ffprobe` to confirm `creation_time` updated **and** the `bt2020/smpte2084` tags survived.

## 8. Telemetry overlay

The graded file has **no telemetry** — GPMF data lives only in the original GoPro file.

1. In a telemetry tool (e.g. **Telemetry Overlay**, supports Hero 12), load the **original**
   GoPro `.MP4` to read GPS / speed / elevation.
2. _(Optional)_ import external data (Garmin `.fit` / `.gpx` for power, HR, cadence) and sync —
   the original's timestamp anchors the alignment.
3. Export a **transparent MOV** (gauges only, with alpha).
4. In Resolve: graded clip on **V1**, transparent overlay on **V2**, aligned at the same
   start frame. Render the final.

> Keep clips untrimmed for frame-accurate sync, or account for the offset.

## 9. Upload to YouTube

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
  -x265-params "colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10=1:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-call=1000,400" \
  -tag:v hvc1 Rossens_hdr10.mp4
```

- `master-display` above = P3-D65 primaries inside a Rec.2020 container, 1000-nit peak.
- Adjust `max-call=1000,400` (MaxCALL, MaxFALL) to your content.
- For a plain YouTube upload you can drop the whole `master-display`/`max-call` block and keep
  just `colorprim` / `transfer` / `colormatrix`.

---

### Quick reference

| Step             | Setting                         |
| ---------------- | ------------------------------- |
| Color science    | ACEScct                         |
| Input transform  | GoPro GP-Log (Native) IDT       |
| Output transform | Rec.2100 ST2084 (1000 nits)     |
| Codec            | Apple ProRes 422 HQ (QuickTime) |
| Render range     | Entire Timeline                 |
| Color Space Tag  | Rec2020                         |
| Gamma Tag        | ST2084 1000 nit                 |
| Data Levels      | Video                           |
| Tone Mapping     | None                            |

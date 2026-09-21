# trace

The other thing the film opens on.

```bash
trace                      # resolves to this machine's address
trace --target 312-555-0690
```

Not the rain. The rain falls, in katakana, and never stops. This sits still, in
digits, and ends: a field of cells cycling in place until the trace closes and
they lock onto an address.

## Where the numbers come from

Every parameter in the rain is traceable to
[Rezmason/matrix](https://github.com/Rezmason/matrix), the reconstruction that
worked the films out frame by frame. **That project does not cover this
sequence**, and neither does anything else published: the writing about "the
Matrix code" — Simon Whiteley, the Japanese cookbook, the mirrored kana — is all
about the rain. So these were measured off a frame instead.

| | |
|---|---|
| Layout | 5 blocks of 9 columns, gap ≈ 1.7 column widths |
| Cell | 38 × 40 px — very nearly square, unlike the rain's tall cells |
| Rows | ~20 visible |
| Glyphs | the ten digits, nothing else |
| Motion | cycles in place; nothing falls |
| Luminance | p10 35, median 61, p90 119, max 196 |
| Bright cells | ~9% of the field |

The one process detail that exists comes from the VFX team's description of the
title shader: it "would hold some in place sometimes making it look glitchy or
overlap two characters on the same cell with different levels of brightness."
Holding and the brightness spread are reproduced. Overlap is not — a terminal
cell takes one glyph.

## The colour, which is not the rain's

Measured across 389 digits, the trace sits at **hue 159–161**, a green with blue
in it, at 38% saturation. The rain is at **hue 108**. Fifty degrees apart, which
is twice the error in the `#00ff41` the internet reaches for.

Stated with its caveat: that is one frame of one transfer, and a grade can move
a hue. It has not been checked against a second source. `--green` renders in the
rain's hue instead, which is what you want when the two share a screen.

## Options

| | |
|---|---|
| `--target N` | the address it resolves to; defaults to this machine's |
| `--green` | the rain's hue instead of the trace's own |
| `--once` | one pass, then hold, instead of looping |
| `--fps N` | default 20 |

Any key quits.

The default target is found the way a machine finds its own address: a UDP
socket is pointed at TEST-NET-1, which is routed nowhere and receives nothing,
and the kernel's choice of source address is read back. No packet is sent. With
no network at all it falls back to the number from the film.

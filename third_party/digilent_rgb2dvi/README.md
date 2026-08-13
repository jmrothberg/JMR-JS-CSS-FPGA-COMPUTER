# Digilent rgb2dvi — HDMI/DVI Source IP (vendor, not hand-rolled)

**Do not rewrite TMDS.** This tree is Digilent’s `rgb2dvi` IP from
[Digilent/vivado-library](https://github.com/Digilent/vivado-library)
(`ip/rgb2dvi`).

## Why

Nexys Video (XC7A200T) has onboard HDMI Source (J8) with a TMDS141 buffer.
Digilent already ships encode + serialize for 7-series. We feed it:

```text
8-bit FB → palette → 24-bit RGB + HSync/VSync/DE + PixelClk(~25.175 MHz)
        → rgb2dvi → TMDS → HDMI connector
```

## Files

VHDL sources under `src/` (rgb2dvi.vhd, TMDS_Encoder.vhd, OutputSERDES.vhd, …).

## Integration in this repo

- Board top (Vivado): instantiate Digilent `rgb2dvi` with 640×480@60 timing.
  Feed `vid_pData` / `vid_pHSync` / `vid_pVSync` / `vid_pVDE` + `PixelClk`
  from `rtl/video/jmr_hdmi_scanout.sv`; map TMDS outs to
  `constraints/nexys_video.xdc` (Digilent HDMI Source pins).
- Our RTL: scanout + palette only — **never** rewrite TMDS_Encoder.
- FPGA-SIM: does **not** need TMDS; host twin / FB? protocol mirrors glass.
- Pattern cite: Digilent Nexys Video HDMI demo project (method only).

## License

Follow Digilent’s license in the upstream vivado-library repository. Keep this
directory as a vendor snapshot; update by re-copying from upstream when needed.

Pattern cite: Digilent Nexys Video HDMI demos use the same IP — method only.

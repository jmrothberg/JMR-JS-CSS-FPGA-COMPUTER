# releases/

`current/jmr_js_mac.bit` is the bitstream for the root source: build 96 (Finder-only Mac-like system),
timing met (setup +0.005 ns, hold +0.022 ns), 0 routing and DRC errors. Its timing,
utilization and route reports are beside it. Make the card from `storage/` with
`python3 tools/make_sd_image.py create card.img` (see the top-level README).

Load: `openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit`

The rollback that works on the board is `build/run78_clean_architecture/` (not in git).

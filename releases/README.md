# releases/

`current/jmr_js_mac.bit` is the bitstream for this source: build 99, timing met
(setup +0.089 ns, hold +0.041 ns), 0 routing and DRC errors. Its timing,
utilization and route reports are beside it. Make the card from `storage/` with
`python3 tools/make_sd_image.py create card.img`; Finder's About then shows
"Build 99".

Load: `openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit`

Earlier bits are in git history: build 98 at cdb489d, build 97 at d6dbe8e.
Check one out with its own `card.img`.

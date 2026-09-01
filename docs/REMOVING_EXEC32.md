# exec32 is gone — do not resurrect it

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**exec32** was the tagged-Q16 opcode decoder. **exec64** is the only
decoder (**Value64**). `jmr_js_vm_exec32.sv` is deleted. Non-Value64
images fault **code 9**. Do not add a second decoder.

**The `e32_` prefix lies.** Many `e32_*` names are **parent-owned**
Port-A buses still used by Value64. Deleting by prefix breaks exec64.
Keep anything that appears on the left-hand side of an assignment in
`rtl/engines/jmr_js_vm.sv` (optional rename to `p_*`). Discriminator:

```bash
grep -oE '^[^=<]*\be32_[A-Za-z0-9_]+ *(<=|=[^=])' rtl/engines/jmr_js_vm.sv \
  | grep -o 'e32_[A-Za-z0-9_]*' | sort -u
```

**Do not trust a constant fold to remove a large array.** `v64_on` did
not sweep the tagged twin; hand-delete did. Do not Port-A the dead twin.

Cut A blow-by-blow and the dead-vs-live table are git history
(`git log -- docs/REMOVING_EXEC32.md`). Optional future: Cut B console
`.JS` / `.JSB` tidy — not a fit lever.

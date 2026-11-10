# resources/toolbox/

Source of the resident Toolbox library and its optional client modules.

| File | Part |
|---|---|
| `toolbox.js` | Memory and graphics helpers over the native `toolbox()` call |
| `ui.js` | Menus, dialogs, text, ports, damage, window and control geometry |
| `session.js` | Application session: roles, menus, input, frames |
| `documents.js` | File dialogs, SOURCE documents, program switching |
| `*_client.js` | Optional modules copied inline into the HTML programs that use them |

The first four are linked, in that order, into `storage/TOOLBOX.ROM`.

```sh
python3 -m tools.toolbox_linker              # rebuild ROM, LNK and factory hex
python3 tools/sync_toolbox_clients.py        # check the inline copies (--write to refresh)
```

- Calls: [docs/TOOLBOX_API.md](../../docs/TOOLBOX_API.md) and
  [docs/SYSTEM_APPLICATIONS.md](../../docs/SYSTEM_APPLICATIONS.md).
- Linking, limits and the update steps:
  [docs/RESIDENT_TOOLBOX.md](../../docs/RESIDENT_TOOLBOX.md).

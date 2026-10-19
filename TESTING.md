# Validation record

Checked 2026-10-19 on Omarchy 4.0.5-1, Qt 6.12.0.

- Manifest validation and Qt 6 qmllint: passed for all QML files.
- Nine Python DSP tests: passed.
- Real PipeWire output-monitor capture: five valid frames, silent output.
- Running shell: enabled; shell summon/hide calls succeeded.

## Standalone service regression check (2026-10-19)

After removing clone metadata, the bar must use `serviceFor(moduleName)`, not
`firstPartyServiceFor("omarchy.media")`. The latter returned no service while
the built-in plugin was disabled; successful summon calls alone did not catch
this because `open()` does nothing without media.

After the fix and a shell restart, `omarchy-shell konochi.konobeat status` reported
`hasMedia: true`, `playing: true`, nonzero widget width, `sampling: true`, live
spectrum data, and an empty `sampleError` with the built-in media plugin disabled.
All nine DSP unit tests still passed. Qt 6 qmllint emitted type-resolution and
unqualified-access warnings; these are not a clean warning-free lint result.

Full manual playback/seek, click/Escape, multi-monitor behavior, restart, and
destructive uninstall testing remain to be performed before requesting
marketplace approval. The shell log contained duplicate IPC-handler warnings
for this plugin (also seen for built-in panels); tested shell routes still worked.

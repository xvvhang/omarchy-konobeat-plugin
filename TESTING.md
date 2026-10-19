# Validation record

Checked 2026-10-19 on Omarchy 4.0.5-1, Qt 6.12.0.

- Manifest validation and Qt 6 qmllint: passed for all QML files.
- Nine Python DSP tests: passed.
- Real PipeWire output-monitor capture: five valid frames, silent output.
- Running shell: enabled; shell summon/hide calls succeeded.

Full manual playback/seek, click/Escape, multi-monitor behavior, restart, and
destructive uninstall testing remain to be performed before requesting
marketplace approval. The shell log contained duplicate IPC-handler warnings
for this plugin (also seen for built-in panels); tested shell routes still worked.

# Security

The kit installs hooks that run PowerShell in every Claude Code session of a project built from it, and Cerbero's optional hooks run Python.
The hook commands call `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`: the bypass applies to that one process and that one script, and it is there so the hooks run on a machine whose policy blocks unsigned scripts. Read `system/scripts/` before you enable them.
To report a vulnerability, use GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability").
Please do not open a public issue for a security problem.
There is no promise of a response time.

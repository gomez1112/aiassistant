"""Export only this app's Debug marketing-cache files through its own debugger.

In LLDB: command script import /absolute/path/read_mac_captures.py
Then: export-ari /absolute/path/to/output
"""
import pathlib
import shlex

import lldb


def export(debugger, command, result, internal_dict):
    arguments = shlex.split(command)
    if len(arguments) != 1:
        result.SetError("Usage: export-ari /absolute/path/to/output")
        return
    root = pathlib.Path(arguments[0]).expanduser()
    if not root.is_absolute():
        result.SetError("The output directory must be an absolute path.")
        return
    root.mkdir(parents=True, exist_ok=True)
    (root / "frames").mkdir(exist_ok=True)
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    files = ["writing.png", "planning.png", "outputs.png", "library.png", "study.png"]
    files += [f"frames/frame-{index:04}.png" for index in range(200)]
    exported = 0
    for file in files:
        # These paths are fixed fixture outputs, never persistence-store files.
        expression = (
            '(id)[NSData dataWithContentsOfFile:(id)[NSHomeDirectory() '
            'stringByAppendingPathComponent:@"Library/Caches/AriMarketingCapture/mac/'
            + file + '"]]'
        )
        value = target.EvaluateExpression(expression)
        pointer = value.GetValueAsUnsigned()
        if not pointer:
            continue
        length = target.EvaluateExpression(
            f"(unsigned long long)[(id){hex(pointer)} length]"
        ).GetValueAsUnsigned()
        address = target.EvaluateExpression(
            f"(unsigned long long)[(id){hex(pointer)} bytes]"
        ).GetValueAsUnsigned()
        error = lldb.SBError()
        data = process.ReadMemory(address, length, error)
        if not error.Success():
            result.SetError(f"Could not export {file}: {error.GetCString()}")
            return
        if data:
            (root / file).write_bytes(data)
            exported += 1
    result.AppendMessage(f"Exported {exported} fixture files to {root}")


def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand("command script add -f read_mac_captures.export export-ari")

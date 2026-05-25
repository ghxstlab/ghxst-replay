Set WshShell = CreateObject("WScript.Shell")
AppPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
PythonScript = AppPath & "\_app\ui\ghx_replay_toolkit.py"

' Try pythonw first, which launches GUI apps without a console window.
Command = "pythonw.exe """ & PythonScript & """"
ReturnCode = WshShell.Run(Command, 0, False)

If ReturnCode <> 0 Then
    ' Fallback to normal python if pythonw is not available.
    Command = "python.exe """ & PythonScript & """"
    WshShell.Run Command, 0, False
End If
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\uniOPOS_PuenteWeb"
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""Get-Process node -EA SilentlyContinue | Where-Object { $_.Path -like '*uniOPOS*' } | Stop-Process -Force -EA SilentlyContinue""", 0, True
WshShell.Run """C:\uniOPOS_PuenteWeb\bin\node\node.exe"" ""C:\uniOPOS_PuenteWeb\server.js""", 0, False
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\uniOPOS_PuenteWeb\tray_monitor.ps1""", 0, False

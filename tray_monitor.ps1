Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$mutex = New-Object System.Threading.Mutex($false, 'Global\uniOPOS_Tray_v2')
if (-not $mutex.WaitOne(0, $false)) { exit }
function New-DotIcon([System.Drawing.Color]$c) { $b = New-Object System.Drawing.Bitmap 16,16; $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent); $br = New-Object System.Drawing.SolidBrush $c; $g.FillEllipse($br, 2, 2, 12, 12); $g.Dispose(); return [System.Drawing.Icon]::FromHandle($b.GetHicon()) }
$icoOk = New-DotIcon([System.Drawing.Color]::LimeGreen); $icoErr = New-DotIcon([System.Drawing.Color]::Crimson)
$ni = New-Object System.Windows.Forms.NotifyIcon; $ni.Icon = $icoErr; $ni.Text = 'uniOPOS PuenteWeb v2.0 (Iniciando...)'; $ni.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$mMesas = $menu.Items.Add('Abrir Mesas (Celular)'); $mMesas.Add_Click({ Start-Process 'http://localhost:5000' })
$mCocina = $menu.Items.Add('Abrir Cocina / Comandas'); $mCocina.Add_Click({ Start-Process 'http://localhost:5000/comandas.html' })
$menu.Items.Add('-') | Out-Null
$mRestart = $menu.Items.Add('Reiniciar Puente'); $mRestart.Add_Click({ Get-Process node -EA SilentlyContinue | Where-Object { $_.Path -like '*uniOPOS*' } | Stop-Process -Force -EA SilentlyContinue; Start-Process 'wscript.exe' -ArgumentList '"C:\uniOPOS_PuenteWeb\iniciar_puente.vbs"' })
$mExit = $menu.Items.Add('Detener y Salir'); $mExit.Add_Click({ Get-Process node -EA SilentlyContinue | Where-Object { $_.Path -like '*uniOPOS*' } | Stop-Process -Force -EA SilentlyContinue; $ni.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$ni.ContextMenuStrip = $menu
$ni.Add_DoubleClick({ Start-Process 'http://localhost:5000' })
$timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 3000
$timer.Add_Tick({ try { $tcp = New-Object System.Net.Sockets.TcpClient; $ar = $tcp.BeginConnect('127.0.0.1', 5000, $null, $null); if ($ar.AsyncWaitHandle.WaitOne(400, $false) -and $tcp.Connected) { $ni.Icon = $icoOk; $ni.Text = 'uniOPOS PuenteWeb v2.0 - ACTIVO (Puerto 5000)' } else { $ni.Icon = $icoErr; $ni.Text = 'uniOPOS PuenteWeb v2.0 - DETENIDO' }; $tcp.Close() } catch { $ni.Icon = $icoErr; $ni.Text = 'uniOPOS PuenteWeb v2.0 - DETENIDO' } })
$timer.Start(); [System.Windows.Forms.Application]::Run()
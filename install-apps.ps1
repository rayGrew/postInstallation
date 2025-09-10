<#
.SYNOPSIS
  Instalador con menú (General / Dev W11), escaneo profundo (winget + registro + Get-Package + rutas),
  selección interactiva de pendientes, progreso en tiempo real por app y salidas claras (OK/ERROR).
#>

# ===== Config =====
$SilentMode = $false

# ===== Salidas claras =====
function Exit-Ok    { param([string]$Message="OK")    Write-Host $Message -ForegroundColor Green; exit 0 }
function Exit-Error { param([string]$Message="ERROR") Write-Host $Message -ForegroundColor Red;  exit 1 }

# ===== Logging =====
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath   = Join-Path $env:TEMP "winget_menu_install_$TimeStamp.log"
function Write-Log { param([string]$Message,[string]$Level="INFO")
  $line = "[{0}] {1} - {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
  $line | Tee-Object -FilePath $LogPath -Append | Out-Null
}
Write-Log "=== Inicio ==="; Write-Log "Log: $LogPath"

# ===== Comprobaciones =====
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Log "winget no disponible" "ERROR"; Exit-Error "ERROR: winget no encontrado. Instala 'App Installer' (Microsoft Store)."
}
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $IsAdmin) { Write-Log "No Admin" "ERROR"; Exit-Error "ERROR: Ejecuta PowerShell como Administrador." }

# ===== Utilidad: ejecutar proceso con salida en vivo =====
function Invoke-LiveProcess {
  param(
    [Parameter(Mandatory)] [string] $FilePath,
    [Parameter(Mandatory)] [string[]] $Arguments,
    [string] $Heading = ""
  )
  if ($Heading) {
    Write-Host ""
    Write-Host ("=== {0} ===" -f $Heading) -ForegroundColor Cyan
    Write-Log  ("=== {0} ===" -f $Heading)
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.Arguments = ($Arguments -join " ")
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  while (-not $p.HasExited) {
    while (!$p.StandardOutput.EndOfStream) {
      $line = $p.StandardOutput.ReadLine()
      if ($null -ne $line) { Write-Host $line; Write-Log $line }
    }
    Start-Sleep -Milliseconds 100
  }
  while (!$p.StandardOutput.EndOfStream) { $line = $p.StandardOutput.ReadLine(); if ($null -ne $line) { Write-Host $line; Write-Log $line } }
  while (!$p.StandardError.EndOfStream)  { $eline = $p.StandardError.ReadLine();  if ($null -ne $eline){ Write-Host $eline -ForegroundColor DarkRed; Write-Log $eline "ERROR" } }

  return $p.ExitCode
}

# ===== Catálogo =====
$Catalog = @{
  # General
  "Microsoft 365 Apps" = @{
    MatchNames  = @("Microsoft 365 Apps","Microsoft 365","Microsoft Office","Office 365")
    InstallPlan = @(@{ Source="winget"; Id="Microsoft.Office"; Name="Microsoft 365 Apps" })
    KnownPaths  = @()
  }
  "Zoom" = @{
    MatchNames  = @("Zoom","Zoom Workplace","Zoom Meetings")
    InstallPlan = @(
      @{ Source="winget";  Id="Zoom.Zoom";    Name="Zoom" },
      @{ Source="msstore"; Id="9WZDNCRFJ4QD"; Name="Zoom" }  # puede variar por región
    )
    KnownPaths  = @()
  }
  
  "Adobe Acrobat Reader" = @{
    MatchNames  = @("Adobe Acrobat Reader","Acrobat Reader","Adobe Reader")
    InstallPlan = @(@{ Source="winget"; Id="Adobe.Acrobat.Reader.64-bit"; Name="Adobe Acrobat Reader" })
    KnownPaths  = @(
      "$env:ProgramFiles\Adobe\Acrobat Reader\Reader\AcroRd32.exe",
      "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
      "$env:ProgramFiles(x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    )
  }
  "Google Chrome" = @{
    MatchNames  = @("Google Chrome","Chrome")
    InstallPlan = @(@{ Source="winget"; Id="Google.Chrome"; Name="Google Chrome" })
    KnownPaths  = @(
      "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
      "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
  }

  "AnyDesk" = @{
    MatchNames  = @("AnyDesk")
    InstallPlan = @(@{ Source="winget"; Id="AnyDeskSoftwareGmbH.AnyDesk"; Name="AnyDesk" })
    KnownPaths  = @(
      "$env:ProgramFiles (x86)\AnyDesk\AnyDesk.exe",
      "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    )
  }

  # Dev
  "Visual Studio Code" = @{
    MatchNames  = @("Microsoft Visual Studio Code","Visual Studio Code","VS Code")
    InstallPlan = @(@{ Source="winget"; Id="Microsoft.VisualStudioCode"; Name="Visual Studio Code" })
    KnownPaths  = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe")
  }
  "Cursor" = @{
    MatchNames  = @("Cursor")
    InstallPlan = @(@{ Source="winget"; Id="Cursor.Cursor"; Name="Cursor" })
    KnownPaths  = @("$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe")
  }
  "Zen Browser" = @{
    MatchNames  = @("Zen Browser","Zen")
    InstallPlan = @(@{ Source="winget"; Id="Zen-Team.Zen"; Name="Zen" })
    KnownPaths  = @("$env:LOCALAPPDATA\Programs\Zen\zen.exe","$env:ProgramFiles\Zen\zen.exe")
  }
  "Thunderbird" = @{
    MatchNames  = @("Mozilla Thunderbird","Thunderbird")
    InstallPlan = @(@{ Source="winget"; Id="Mozilla.Thunderbird"; Name="Thunderbird" })
    KnownPaths  = @("$env:ProgramFiles\Mozilla Thunderbird\thunderbird.exe","$env:ProgramFiles(x86)\Mozilla Thunderbird\thunderbird.exe")
  }
  "SSMS" = @{
    MatchNames  = @("SQL Server Management Studio","SSMS")
    InstallPlan = @(@{ Source="winget"; Id="Microsoft.SQLServerManagementStudio"; Name="SQL Server Management Studio" })
    KnownPaths  = @("$env:ProgramFiles (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe","$env:ProgramFiles\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe")
  }

  # ✅ Termius (corrección)
  "Termius" = @{
    MatchNames  = @("Termius","Termius (x64)","Termius x64","Termius (64-bit)")
    InstallPlan = @(@{ Source="winget"; Id="Termius.Termius"; Name="Termius" })  # winget id verificado
    KnownPaths  = @("$env:LOCALAPPDATA\Programs\Termius\Termius.exe")
  }

  "Postman" = @{
    MatchNames  = @("Postman")
    InstallPlan = @(@{ Source="winget"; Id="Postman.Postman"; Name="Postman" })
    KnownPaths  = @("$env:LOCALAPPDATA\Postman\Postman.exe","$env:LOCALAPPDATA\Programs\Postman\Postman.exe")
  }
  "Insomnia" = @{
    MatchNames  = @("Insomnia","Kong Insomnia")
    InstallPlan = @(
      @{ Source="winget";  Id="Kong.Insomnia"; Name="Insomnia" },
      @{ Source="winget";  Id=$null;           Name="Insomnia" },
      @{ Source="direct";  Url="https://updates.insomnia.rest/downloads/windows/latest"; SilentArgs="/S"; Name="Insomnia" }
    )
    KnownPaths  = @("$env:LOCALAPPDATA\Programs\Insomnia\Insomnia.exe")
  }
  "Docker Desktop" = @{
    MatchNames  = @("Docker Desktop")
    InstallPlan = @(@{ Source="winget"; Id="Docker.DockerDesktop"; Name="Docker Desktop" })
    KnownPaths  = @("$env:ProgramFiles\Docker\Docker\Docker Desktop.exe")
  }
  
  # Portafolio
  "IBKR Desktop" = @{
    MatchNames  = @("IBKR Desktop","Interactive Brokers Desktop","Trader Workstation","TWS")
    InstallPlan = @(
      # IBKR Desktop / TWS (enlace oficial para Windows de IBKR)
      @{ Source="direct"; Url="https://download2.interactivebrokers.com/installers/ntws/latest-standalone/ntws-latest-standalone-windows-x64.exe"; SilentArgs=""; Name="IBKR Desktop" }
    )
    KnownPaths  = @(
      "C:\Jts\tws.exe",                      # TWS típico
      "C:\Program Files\IBKR Desktop\IBKR Desktop.exe" # ruta probable si cambia el nombre del ejecutable
    )
  }

  "XTB xStation 5" = @{
    MatchNames  = @("XTB","xStation","xStation 5","XTB xStation")
    InstallPlan = @(
      # Instalador oficial de XTB para Windows
      @{ Source="direct"; Url="https://xstation.xtb.com/desktop/XTB%20xStation.exe"; SilentArgs="/S"; Name="XTB xStation 5" }
    )
    KnownPaths  = @(
      "$env:ProgramFiles\XTB xStation\xStation.exe",
      "$env:ProgramFiles\XTB\xStation 5\xStation.exe",
      "$env:LOCALAPPDATA\Programs\XTB xStation\xStation.exe"
    )
  }
}

# ===== Detección helpers =====
function Test-Winget {
  param([string]$Id,[string]$Name,[string]$Source)
  try {
    if ($Id) {
      $r = winget list --id $Id -e --source $Source 2>$null
      if ($r -and ($r -match [Regex]::Escape($Id))) { return @{Found=$true; How="winget($Source):Id"} }
    }
    if ($Name) {
      $r2 = winget list --name $Name -e --source $Source 2>$null
      if ($r2 -and ($r2 -match [Regex]::Escape($Name))) { return @{Found=$true; How="winget($Source):Name"} }
    }
    foreach ($src in @("winget","msstore")) {
      if ($Id) {
        $r3 = winget list --id $Id -e --source $src 2>$null
        if ($r3 -and ($r3 -match [Regex]::Escape($Id))) { return @{Found=$true; How="winget($src):Id"} }
      }
    }
    return @{Found=$false; How=$null}
  } catch { return @{Found=$false; How=$null} }
}
function Test-Registry {
  param([string[]]$Patterns)
  $paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($p in $paths) {
    try {
      Get-ItemProperty $p -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.DisplayName
        if ([string]::IsNullOrWhiteSpace($name)) { return }
        foreach ($pat in $Patterns) {
          if ($name -like "*$pat*") {
            $ver = $null
            if ($_.PSObject.Properties.Name -contains "DisplayVersion") { $ver = $_.DisplayVersion }
            return @{Found=$true; How="registry: $name $ver"}
          }
        }
      }
    } catch {}
  }
  return @{Found=$false; How=$null}
}
function Test-GetPackage {
  param([string[]]$Patterns)
  try {
    $pkgs = Get-Package -ProviderName Programs -ErrorAction SilentlyContinue
    foreach ($pkg in $pkgs) {
      foreach ($pat in $Patterns) {
        if ($pkg.Name -like "*$pat*") { return @{Found=$true; How="Get-Package: $($pkg.Name) $($pkg.Version)"} }
      }
    }
  } catch {}
  return @{Found=$false; How=$null}
}
function Test-Paths {
  param([string[]]$Paths)
  foreach ($path in $Paths) {
    $expanded = [Environment]::ExpandEnvironmentVariables($path)
    if (Test-Path -LiteralPath $expanded) { return @{Found=$true; How="path: $expanded"} }
  }
  return @{Found=$false; How=$null}
}
function Test-AppInstalledDeep {
  param([string]$DisplayName)
  if (-not $Catalog.ContainsKey($DisplayName)) { return @{Found=$false; How=$null} }
  $meta = $Catalog[$DisplayName]
  foreach ($plan in $meta.InstallPlan) {
    if ($plan.Source -in @("winget","msstore")) {
      $r = Test-Winget -Id $plan.Id -Name $plan.Name -Source $plan.Source
      if ($r.Found) { return @{Found=$true; How=$r.How} }
    }
  }
  $r2 = Test-Registry -Patterns $meta.MatchNames; if ($r2.Found) { return @{Found=$true; How=$r2.How} }
  $r3 = Test-GetPackage -Patterns $meta.MatchNames; if ($r3.Found) { return @{Found=$true; How=$r3.How} }
  if ($meta.ContainsKey("KnownPaths") -and $meta.KnownPaths.Count -gt 0) {
    $r4 = Test-Paths -Paths $meta.KnownPaths; if ($r4.Found) { return @{Found=$true; How=$r4.How} }
  }
  return @{Found=$false; How=$null}
}

# ===== Instalación (con progreso) =====
function Get-WingetArgs {
  param([string]$Id,[string]$Name,[string]$Source)
  $args = @("install","-e","--accept-package-agreements","--accept-source-agreements","--disable-interactivity","--source",$Source)
  if ($SilentMode) { $args += @("--silent","--force") }
  if ($Id) { $args += @("--id",$Id) } else { $args += @("--name",$Name) }
  return $args
}
function Install-FromWinget {
  param([string]$Id,[string]$Name,[string]$Source,[string]$App)
  if ($Id) {
    $args = Get-WingetArgs -Id $Id -Name $null -Source $Source
    $code = Invoke-LiveProcess -FilePath "winget" -Arguments $args -Heading "$App vía winget ($Source, Id)"
    if ($code -eq 0) { return @{Ok=$true; Where="winget:$Source:Id"} }
    Write-Log "winget por Id falló (ExitCode=$code). Reintentando por Name si aplica." "WARN"
  }
  if ($Name) {
    $args2 = Get-WingetArgs -Id $null -Name $Name -Source $Source
    $code2 = Invoke-LiveProcess -FilePath "winget" -Arguments $args2 -Heading "$App vía winget ($Source, Name)"
    if ($code2 -eq 0) { return @{Ok=$true; Where="winget:$Source:Name"} }
    Write-Log "winget por Name falló (ExitCode=$code2)." "WARN"
  }
  return @{Ok=$false}
}
function Install-FromDirect {
  param([string]$Url,[string]$SilentArgs,[string]$Name)
  try {
    $tmp = Join-Path $env:TEMP ("{0}_{1}.exe" -f ($Name -replace '\s',''), (Get-Date -Format "yyyyMMddHHmmss"))
    Write-Log "Descargando $Name desde $Url -> $tmp"
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -ErrorAction Stop

    $heading = "$Name - Instalación directa"
    $args = @()
    if ($SilentMode -and $SilentArgs) { $args = $SilentArgs.Split(" ") }

    Write-Log "Ejecutando instalador: $tmp $($args -join ' ')"
    $code = Invoke-LiveProcess -FilePath $tmp -Arguments $args -Heading $heading
    if ($code -eq 0) { return @{Ok=$true; Where="direct"} }

    Write-Log "Instalador directo devolvió ExitCode=$code" "ERROR"
    return @{Ok=$false}
  } catch {
    Write-Log "Fallo descarga/instalación directa: $($_.Exception.Message)" "ERROR"
    return @{Ok=$false}
  }
}
function Install-App {
  param([string]$DisplayName)
  $meta = $Catalog[$DisplayName]
  foreach ($plan in $meta.InstallPlan) {
    if ($plan.Source -in @("winget","msstore")) {
      $r = Install-FromWinget -Id $plan.Id -Name $plan.Name -Source $plan.Source -App $DisplayName
      if ($r.Ok) { Write-Log "✅ Instalado '$DisplayName' vía $($r.Where)"; return $true }
    } elseif ($plan.Source -eq "direct") {
      $r2 = Install-FromDirect -Url $plan.Url -SilentArgs $plan.SilentArgs -Name $plan.Name
      if ($r2.Ok) { Write-Log "✅ Instalado '$DisplayName' vía descarga directa"; return $true }
    }
  }
  Write-Log "❌ No se pudo instalar '$DisplayName' con los planes disponibles." "ERROR"
  return $false
}

# ===== Estado / selección =====
function Get-InstallStatusDeep {
  param([string[]]$Items)
  $already = @(); $pending = @(); $details = @()
  foreach ($i in $Items) {
    $r = Test-AppInstalledDeep -DisplayName $i
    if ($r.Found) { $already += $i; $details += [pscustomobject]@{ App=$i; Estado="Instalado"; Detectado=$r.How } }
    else { $pending += $i; $details += [pscustomobject]@{ App=$i; Estado="Pendiente"; Detectado="" } }
  }
  [pscustomobject]@{ Already=$already; Pending=$pending; Details=$details }
}
function Prompt-SelectPending {
  param([string[]]$Pending)
  if ($Pending.Count -eq 0) { return @() }
  Write-Host "`nSeleccione qué pendientes instalar:" -ForegroundColor Cyan
  for ($i=0; $i -lt $Pending.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i+1), $Pending[$i]) }
  Write-Host "   all   -> todos"
  Write-Host "   none  -> ninguno / cancelar"
  $inp = Read-Host "Ingrese 'all', 'none', números (1,3,5) o nombres"
  $inpTrim = $inp.Trim().ToLower()
  if ($inpTrim -eq "none" -or $inpTrim -eq "") { return @() }
  if ($inpTrim -eq "all") { return $Pending }
  $selected = New-Object System.Collections.Generic.List[string]
  $parts = $inp.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  foreach ($p in $parts) {
    if ($p -match '^\d+$') {
      $idx = [int]$p - 1; if ($idx -ge 0 -and $idx -lt $Pending.Count) { $selected.Add($Pending[$idx]) }
    } else {
      $match = $Pending | Where-Object { $_.ToLower() -eq $p.ToLower() -or $_.ToLower().StartsWith($p.ToLower()) }
      if ($match) { $selected.AddRange($match) }
    }
  }
  $selected | Select-Object -Unique
}

# ===== Menú =====
Write-Host ""
Write-Host "Seleccione el tipo de instalación:" -ForegroundColor Cyan
Write-Host "  1) General  (Microsoft 365 Apps + Zoom)"
Write-Host "  2) Dev W11  (General + VSCode, Cursor, Zen, Thunderbird, SSMS, Termius, API client, Docker)"
Write-Host "  3) Portafolio  (General + IBKR Desktop + XTB xStation 5)"
$choice = Read-Host "Ingrese 1, 2 o 3"

switch ($choice) {
  "1" {
    $selection = @(
      "Microsoft 365 Apps",
      "Zoom",
      "Adobe Acrobat Reader",
      "Google Chrome",
      "AnyDesk"
    )
    Write-Host "`n→ Opción 'General' seleccionada." -ForegroundColor Green
  }
  "2" {
    Write-Host "`nCliente API:" -ForegroundColor Cyan
    Write-Host "  1) Postman"; Write-Host "  2) Insomnia"
    $apiChoice = Read-Host "Ingrese 1 o 2"
    $apiTool = if ($apiChoice -eq "2") { "Insomnia" } else { "Postman" }
    $selection = @(
      "Microsoft 365 Apps","Zoom","Adobe Acrobat Reader","Google Chrome","AnyDesk",
      "Visual Studio Code","Cursor","Zen Browser","Thunderbird","SSMS","Termius",$apiTool,"Docker Desktop"
    )
    Write-Host "`n→ Opción 'Dev W11' seleccionada (API: $apiTool)." -ForegroundColor Green
  }
  "3" {
    # Portafolio = todo lo de General + IBKR + XTB
    $selection = @(
      "Microsoft 365 Apps","Zoom","Adobe Acrobat Reader","Google Chrome","AnyDesk",
      "IBKR Desktop","XTB xStation 5"
    )
    Write-Host "`n→ Opción 'Portafolio' seleccionada." -ForegroundColor Green
  }
  Default {
    Write-Log "Entrada inválida" "WARN"
    Exit-Ok "OK: Entrada inválida, operación cancelada por el usuario."
  }
}

# ===== Escaneo previo =====
Write-Host "`nEscaneando estado actual..." -ForegroundColor Yellow
$status = Get-InstallStatusDeep -Items $selection

Write-Host "`n=== RESUMEN PREVIO (detección profunda) ===" -ForegroundColor Cyan
foreach ($row in $status.Details) {
  $tag = if ($row.Estado -eq "Instalado") { "[✔]" } else { "[ ]" }
  Write-Host ("{0} {1}  {2}" -f $tag, $row.App, $row.Detectado)
}

if ($status.Pending.Count -eq 0) {
  Write-Log "No había pendientes."
  Write-Host ("`nSe instalarán: ninguno`nLog: $LogPath")
  Exit-Ok "OK: No hay nada para instalar."
}

$toInstall = Prompt-SelectPending -Pending $status.Pending
if ($toInstall.Count -eq 0) {
  Write-Log "Usuario no seleccionó pendientes."
  Write-Host ("`nNo se seleccionó nada para instalar.`nLog: $LogPath")
  Exit-Ok "OK: Operación cancelada por el usuario."
}

Write-Host "`nInstalará:" -ForegroundColor Yellow
$toInstall | ForEach-Object { Write-Host " - $_" }
$confirm = Read-Host "`n¿Desea continuar? (S/N)"
if ($confirm.ToUpper() -ne "S") { Write-Log "Cancelado tras selección"; Write-Host ("Log: $LogPath"); Exit-Ok "OK: Operación cancelada por el usuario." }

# ===== Instalación =====
$ok=@(); $fail=@()
foreach ($app in $toInstall) {
  $probe = Test-AppInstalledDeep -DisplayName $app
  if ($probe.Found) { Write-Log "↩️ Ya instalado ($($probe.How)): $app. Omitiendo."; $ok += $app; continue }
  if (Install-App -DisplayName $app) { $ok += $app } else { $fail += $app }
}

Write-Host "`n==== RESUMEN FINAL ===="
$already = $status.Details | Where-Object {$_.Estado -eq "Instalado"} | Select-Object -ExpandProperty App
if ($already.Count -gt 0) { Write-Host ("Omitidos (ya estaban): {0}" -f ($already -join ", ")) }
Write-Host ("Instaladas ahora / confirmadas: {0}" -f ($(if ($ok.Count) { $ok -join ", " } else { "ninguna" })))
if ($fail.Count -gt 0) {
  Write-Host ("Con errores: {0}" -f ($fail -join ", ")) -ForegroundColor Red
  Write-Host ("Log: $LogPath"); Exit-Error "ERROR: Una o más instalaciones fallaron."
} else {
  Write-Host ("Log: $LogPath"); Exit-Ok "OK: Proceso completado."
}

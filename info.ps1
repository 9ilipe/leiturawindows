# ==============================================================================
# DIAGNÓSTICO COMPLETO DO SISTEMA (Hardware, GPU, RAM, Discos, Rede, PCI e USB)
# ==============================================================================

function Print-Item ($rotulo, $valor) {
    Write-Host ("  {0,-25}: " -f $rotulo) -NoNewline -ForegroundColor Gray
    Write-Host $valor -ForegroundColor White
}

function Print-Header ($titulo) {
    Write-Host ""
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host ("  {0}" -f $titulo.ToUpper()) -ForegroundColor Cyan
    Write-Host "==================================================================================" -ForegroundColor Cyan
}

Clear-Host
Write-Host "==================================================================================" -ForegroundColor Green
Write-Host "             RELATÓRIO DE DIAGNÓSTICO COMPLETO DO SISTEMA                         " -ForegroundColor Green
Write-Host "==================================================================================" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 1. RESUMO DO SISTEMA E PROCESSADOR
# ------------------------------------------------------------------------------
Print-Header "1. Resumo do Sistema e Processador"

$cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue

$biosDate = "N/A"
if ($bios.ReleaseDate) {
    if ($bios.ReleaseDate -is [datetime]) {
        $biosDate = $bios.ReleaseDate.ToString('dd/MM/yyyy')
    } else {
        $biosDate = $bios.ReleaseDate.ToString().Split(' ')[0]
    }
}

$uptimeStr = "N/A"
if ($os.LastBootUpTime) {
    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeStr = "{0} dias, {1} horas e {2} minutos" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
}

Print-Item "Nome do Computador" $cs.Name
Print-Item "Sistema Operacional" "$($os.Caption) ($($os.OSArchitecture))"
Print-Item "Versão / Build" "$($os.Version) (Build $($os.BuildNumber))"
Print-Item "Tempo Ligado (Uptime)" $uptimeStr
Print-Item "Fabricante / Modelo" "$($cs.Manufacturer) - $($cs.Model)"
Print-Item "Processador (CPU)" $cpu.Name
Print-Item "Arquitetura e Soquete" "$($cpu.AddressWidth)-bits | Soquete $($cpu.SocketDesignation)"
Print-Item "Núcleos / Threads" "$($cpu.NumberOfCores) Cores Físicos / $($cpu.NumberOfLogicalProcessors) Threads"
Print-Item "Frequência Base / Máx" "$($cpu.CurrentClockSpeed) MHz / $($cpu.MaxClockSpeed) MHz"
Print-Item "Cache L2 / L3" "$([math]::Round($cpu.L2CacheSize / 1KB, 2)) MB / $([math]::Round($cpu.L3CacheSize / 1KB, 2)) MB"
Print-Item "Versão da BIOS" "$($bios.SMBIOSBIOSVersion) ($biosDate)"

# ------------------------------------------------------------------------------
# 2. RESUMO SINTÉTICO DO HARDWARE
# ------------------------------------------------------------------------------
Print-Header "2. Resumo Sintético do Hardware"

$shortTree = [System.Collections.Generic.List[PSObject]]::new()

# Sistema / Placa-Mãe
$board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
$shortTree.Add([PSCustomObject]@{ HWPath = "/0"; Class = "system"; Description = "$($cs.Manufacturer) $($cs.Model)".Trim() })
$shortTree.Add([PSCustomObject]@{ HWPath = "/0/bus"; Class = "bus"; Description = "Placa-Mãe: $($board.Manufacturer) $($board.Product)".Trim() })

# Processador
$cpus = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)
$cIdx = 0
foreach ($c in $cpus) {
    $shortTree.Add([PSCustomObject]@{ HWPath = "/0/cpu/$cIdx"; Class = "processor"; Description = $c.Name.Trim() })
    $cIdx++
}

# Memórias
$mems = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
$mIdx = 0
foreach ($m in $mems) {
    $mGB = if ($m.Capacity) { [math]::Round($m.Capacity / 1GB, 2) } else { 0 }
    $mBrand = if ($m.Manufacturer -and $m.Manufacturer -notlike "*(Standard*)*") { $m.Manufacturer.Trim() } else { "RAM" }
    $shortTree.Add([PSCustomObject]@{ HWPath = "/0/mem/$mIdx"; Class = "memory"; Description = "$mGB GB $mBrand".Trim() })
    $mIdx++
}

# Vídeo / GPU
$gpusShort = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -and $_.Name -notlike "*Microsoft Remote Display*" -and $_.Name -notlike "*Indirect Display*" })
$gIdx = 0
if ($gpusShort.Count -eq 0) {
    $shortTree.Add([PSCustomObject]@{ HWPath = "/0/gpu/0"; Class = "display"; Description = "Sem Placa de Vídeo (GPU)" })
} else {
    foreach ($g in $gpusShort) {
        $shortTree.Add([PSCustomObject]@{ HWPath = "/0/gpu/$gIdx"; Class = "display"; Description = $g.Name.Trim() })
        $gIdx++
    }
}

# Armazenamento / Discos
$drives = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
foreach ($d in $drives) {
    $dGB = if ($d.Size) { [math]::Round($d.Size / 1GB, 2) } else { 0 }
    $shortTree.Add([PSCustomObject]@{ HWPath = "/0/disk/$($d.Index)"; Class = "storage"; Description = "$($d.Model) ($dGB GB)".Trim() })
}

# Placas de Rede
$netsShort = @(Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.PhysicalAdapter -eq $true -and $_.PNPClass -eq "Net" })
$nIdx = 0
foreach ($n in $netsShort) {
    $shortTree.Add([PSCustomObject]@{ HWPath = "/0/net/$nIdx"; Class = "network"; Description = $n.Name.Trim() })
    $nIdx++
}

Write-Host ""
Write-Host ("{0,-16} {1,-12} {2}" -f "H/W PATH", "CLASS", "DESCRIPTION") -ForegroundColor Yellow
Write-Host ("{0,-16} {1,-12} {2}" -f "--------", "-----", "-----------") -ForegroundColor Gray

foreach ($item in $shortTree) {
    Write-Host ("{0,-16} " -f $item.HWPath) -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-12} " -f $item.Class) -NoNewline -ForegroundColor Magenta
    Write-Host $item.Description -ForegroundColor White
}

# ------------------------------------------------------------------------------
# 3. PLACA DE VÍDEO (GPU) E EXIBIÇÃO
# ------------------------------------------------------------------------------
Print-Header "3. Placa de Vídeo (GPU) e Exibição"

$gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -and $_.Name -notlike "*Microsoft Remote Display*" -and $_.Name -notlike "*Indirect Display*" })

if ($gpus.Count -eq 0) {
    Write-Host "`n  [!] O hardware não possui placa de vídeo (GPU) detectada." -ForegroundColor Red
} else {
    $gpuIndex = 1
    foreach ($gpu in $gpus) {
        Write-Host "`nGPU ${gpuIndex}: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($gpu.Name)" -ForegroundColor Green

        $vramStr = "N/A"
        if ($gpu.AdapterRAM -gt 0) {
            $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            if ($vramGB -ge 1) {
                $vramStr = "$vramGB GB"
            } else {
                $vramMB = [math]::Round($gpu.AdapterRAM / 1MB, 2)
                $vramStr = "$vramMB MB"
            }
        }

        $driverDateStr = "N/A"
        if ($gpu.DriverDate) {
            if ($gpu.DriverDate -is [datetime]) {
                $driverDateStr = $gpu.DriverDate.ToString('dd/MM/yyyy')
            } else {
                $driverDateStr = $gpu.DriverDate.ToString().Split(' ')[0]
            }
        }

        $resStr = "N/A"
        if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {
            $resStr = "$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
            if ($gpu.CurrentRefreshRate) {
                $resStr += " @ $($gpu.CurrentRefreshRate) Hz"
            }
        }

        Print-Item "Fabricante / Provedor" $gpu.AdapterCompatibility
        Print-Item "Memória de Vídeo (VRAM)" $vramStr
        Print-Item "Versão do Driver" $gpu.DriverVersion
        Print-Item "Data do Driver" $driverDateStr
        Print-Item "Resolução Atual" $resStr
        Print-Item "Status do Dispositivo" $gpu.Status

        $gpuIndex++
    }
}

# ------------------------------------------------------------------------------
# 4. DETALHAMENTO DE MEMÓRIA RAM
# ------------------------------------------------------------------------------
Print-Header "4. Memória RAM Detalhada"

$ramSlots = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)

$totalBytes    = ($ramSlots | Measure-Object -Property Capacity -Sum).Sum
$physicalRamGB = if ($totalBytes) { [math]::Round($totalBytes / 1GB, 2) } else { 0 }
$usableRamGB   = if ($os.TotalVisibleMemorySize) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 2) } else { 0 }
$freeRamGB     = if ($os.FreePhysicalMemory) { [math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { 0 }
$usedRamGB     = [math]::Round($usableRamGB - $freeRamGB, 2)
$hardwareResGB = [math]::Max(0, [math]::Round($physicalRamGB - $usableRamGB, 2))

Write-Host "`n[ RESUMO DE MEMÓRIA ]" -ForegroundColor Yellow
Print-Item "Memória Física Instalada" "$physicalRamGB GB"
Print-Item "Memória Usável p/ Windows" "$usableRamGB GB"
Print-Item "Memória Em Uso" "$usedRamGB GB"
Print-Item "Memória Livre" "$freeRamGB GB"
Print-Item "Reservada para Hardware" "$hardwareResGB GB"
Print-Item "Módulos Detectados" "$($ramSlots.Count) pente(s) físico(s) instalado(s)"

Write-Host "`n[ MÓDULOS INSTALADOS ]" -ForegroundColor Yellow
$ramIndex = 1
foreach ($slot in $ramSlots) {
    $sizeGB  = if ($slot.Capacity) { [math]::Round($slot.Capacity / 1GB, 2) } else { 0 }
    $partNum = if ($slot.PartNumber) { $slot.PartNumber.Trim() } else { "" }
    $smbios  = $slot.SMBIOSMemoryType
    $typeNum = $slot.MemoryType

    # Identificação da Tecnologia da Memória
    $typeStr = "DDR3"
    if ($smbios -eq 26 -or $typeNum -eq 26) { $typeStr = "DDR4" }
    elseif ($smbios -eq 34 -or $typeNum -eq 34) { $typeStr = "DDR5" }
    elseif ($partNum -match "PC3L|DDR3L|16KTF|8KTF|KVR16L|M471B|HMT4") { $typeStr = "DDR3L" }

    $formFactor   = if ($slot.FormFactor -eq 12) { "SO-DIMM (Notebook)" } else { "DIMM (Desktop)" }
    $manufacturer = if ($slot.Manufacturer -and $slot.Manufacturer -notlike "*(Standard*)*") { $slot.Manufacturer.Trim() } else { "Genérico" }
    $serialNumber = if ($slot.SerialNumber -and $slot.SerialNumber.Trim() -ne "") { $slot.SerialNumber.Trim() } else { "N/A" }
    $clockSpeed   = if ($slot.ConfiguredClockSpeed) { $slot.ConfiguredClockSpeed } else { $slot.Speed }

    $slotLocation = if ($slot.DeviceLocator) { $slot.DeviceLocator } else { "Slot $ramIndex" }

    Write-Host "Módulo em ${slotLocation}: " -NoNewline -ForegroundColor Yellow
    Write-Host "$sizeGB GB $typeStr @ $clockSpeed MHz" -ForegroundColor Green
    
    Print-Item "Capacidade Em Bytes" "$($slot.Capacity) Bytes"
    Print-Item "Fabricante / Marca" $manufacturer
    Print-Item "Número de Série" $serialNumber
    Print-Item "Velocidade em Uso" "$clockSpeed MT/s (Máx. Módulo: $($slot.Speed) MT/s)"
    Print-Item "Formato (Form Factor)" $formFactor
    Print-Item "Largura do Barramento" "$($slot.DataWidth) bits"
    Write-Host ""
    $ramIndex++
}

# ------------------------------------------------------------------------------
# 5. DISCOS E ARMAZENAMENTO FÍSICO
# ------------------------------------------------------------------------------
Print-Header "5. Discos e Armazenamento Físico"

$pDisks   = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
$wmiDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)

foreach ($disk in $pDisks) {
    $sizeGB    = if ($disk.Size) { [math]::Round($disk.Size / 1GB, 2) } else { 0 }
    $mediaType = if ($disk.MediaType) { $disk.MediaType } else { "Unidade Externa / Outro" }
    $busType   = if ($disk.BusType) { $disk.BusType } else { "N/A" }
    $serialNum = if ($disk.SerialNumber) { $disk.SerialNumber.Trim() } else { "N/A" }
    
    $wmiMatch = $wmiDisks | Where-Object { $_.SerialNumber -and $_.SerialNumber.Trim() -eq $serialNum }
    $modelRaw = if ($wmiMatch -and $wmiMatch.Model) { $wmiMatch.Model.Trim() } elseif ($disk.FriendlyName) { $disk.FriendlyName.Trim() } else { "Desconhecido" }

    $brand = "Desconhecido / OEM"
    switch -Regex ($modelRaw) {
        "WDC|WD|Western Digital" { $brand = "Western Digital (WD)" }
        "ST|Seagate"             { $brand = "Seagate" }
        "SAMSUNG|SEC"            { $brand = "Samsung" }
        "KINGSTON|SA400|SNV"     { $brand = "Kingston" }
        "CRUCIAL|CT[0-9]"        { $brand = "Crucial (Micron)" }
        "SANDISK"                { $brand = "SanDisk" }
        "TOSHIBA|THNSN"          { $brand = "Toshiba" }
        "INTEL|SSDPE"            { $brand = "Intel" }
        "ADATA|SU630|SU800"      { $brand = "ADATA" }
        "LEXAR"                  { $brand = "Lexar" }
        "XPG"                    { $brand = "XPG" }
        "Hynix|SK"               { $brand = "SK Hynix" }
        default { 
            if ($disk.Manufacturer -and $disk.Manufacturer -notlike "*(Standard*)*") {
                $brand = $disk.Manufacturer
            } else {
                $brand = ($modelRaw.Split(" ")[0])
            }
        }
    }

    Write-Host "`nDisco $($disk.DeviceId): " -NoNewline -ForegroundColor Yellow
    Write-Host "$modelRaw ($sizeGB GB)" -ForegroundColor Green

    Print-Item "  ├─ Marca / Fabricante" $brand
    Print-Item "  ├─ Tipo de Mídia" "$mediaType ($busType)"
    Print-Item "  ├─ Capacidade" "$sizeGB GB"
    Print-Item "  └─ Número de Série" $serialNum

    if ($wmiMatch) {
        $partitions = @(Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($wmiMatch.DeviceID)'} WHERE ResultClass=Win32_DiskPartition" -ErrorAction SilentlyContinue)
        foreach ($part in $partitions) {
            $volumes = @(Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($part.DeviceID)'} WHERE ResultClass=Win32_LogicalDisk" -ErrorAction SilentlyContinue)
            foreach ($vol in $volumes) {
                $volTotalGB  = if ($vol.Size) { [math]::Round($vol.Size / 1GB, 2) } else { 0 }
                $volFreeGB   = if ($vol.FreeSpace) { [math]::Round($vol.FreeSpace / 1GB, 2) } else { 0 }
                $volUsedGB   = [math]::Round($volTotalGB - $volFreeGB, 2)
                $percentUsed = if ($volTotalGB -gt 0) { [math]::Round(($volUsedGB / $volTotalGB) * 100, 1) } else { 0 }

                Print-Item "     Volume ($($vol.Name))" "$volUsedGB GB usados de $volTotalGB GB ($volFreeGB GB livres | $percentUsed% ocupado - $($vol.FileSystem))"
            }
        }
    }
    Write-Host ""
}

# ------------------------------------------------------------------------------
# 6. USO DO ESPAÇO EM DISCO / SISTEMA DE ARQUIVOS
# ------------------------------------------------------------------------------
Print-Header "6. Uso do Espaço em Disco / Sistema de Arquivos"

$logicalDisks = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 2 or DriveType = 3 or DriveType = 4" -ErrorAction SilentlyContinue)

Write-Host ""
Write-Host ("{0,-12} {1,-10} {2,-10} {3,-10} {4,-10} {5,-8} {6}" -f "FILESYSTEM", "TYPE", "SIZE", "USED", "AVAIL", "USE%", "MOUNTED ON / LABEL") -ForegroundColor Yellow
Write-Host ("{0,-12} {1,-10} {2,-10} {3,-10} {4,-10} {5,-8} {6}" -f "----------", "----", "----", "----", "-----", "----", "------------------") -ForegroundColor Gray

foreach ($v in $logicalDisks) {
    $driveLetter = $v.DeviceID
    $fsType      = if ($v.FileSystem) { $v.FileSystem } else { "N/A" }
    $totalGB     = if ($v.Size) { [math]::Round($v.Size / 1GB, 1) } else { 0 }
    $freeGB      = if ($v.FreeSpace) { [math]::Round($v.FreeSpace / 1GB, 1) } else { 0 }
    $usedGB      = [math]::Round($totalGB - $freeGB, 1)
    $usePercent  = if ($totalGB -gt 0) { [math]::Round(($usedGB / $totalGB) * 100) } else { 0 }
    $volLabel    = if ($v.VolumeName) { $v.VolumeName } else { "Sem Rótulo" }

    $sizeStr  = "$totalGB G"
    $usedStr  = "$usedGB G"
    $availStr = "$freeGB G"
    $percStr  = "$usePercent%"
    $mountStr = "$driveLetter\ ($volLabel)"

    Write-Host ("{0,-12} " -f $driveLetter) -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-10} " -f $fsType) -NoNewline -ForegroundColor Magenta
    Write-Host ("{0,-10} " -f $sizeStr) -NoNewline -ForegroundColor White
    Write-Host ("{0,-10} " -f $usedStr) -NoNewline -ForegroundColor Red
    Write-Host ("{0,-10} " -f $availStr) -NoNewline -ForegroundColor Green
    Write-Host ("{0,-8} " -f $percStr) -NoNewline -ForegroundColor Yellow
    Write-Host $mountStr -ForegroundColor White
}

Write-Host ""

# ------------------------------------------------------------------------------
# 7. REDE E CONECTIVIDADE
# ------------------------------------------------------------------------------
Print-Header "7. Rede e Conectividade"

$netConfigs = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" -ErrorAction SilentlyContinue)

if ($netConfigs.Count -eq 0) {
    Write-Host "`n  [!] Nenhuma conexão de rede ativa com IP configurado." -ForegroundColor Red
} else {
    $netIndex = 1
    foreach ($net in $netConfigs) {
        Write-Host "`nAdaptador de Rede ${netIndex}: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($net.Description)" -ForegroundColor Green

        $ipv4 = ($net.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }) -join ", "
        $ipv6 = ($net.IPAddress | Where-Object { $_ -match ':' }) -join ", "
        $subnet = ($net.IPSubnet | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }) -join ", "
        $gateways = ($net.DefaultIPGateway) -join ", "
        $dnsServers = ($net.DNSServerSearchOrder) -join ", "

        $dhcpStatus = if ($net.DHCPEnabled) { "Habilitado (Dinâmico)" } else { "Desabilitado (Estático)" }

        Print-Item "Endereço MAC" $net.MACAddress
        Print-Item "Endereço IPv4" $(if ($ipv4) { $ipv4 } else { "N/A" })
        Print-Item "Máscara de Rede" $(if ($subnet) { $subnet } else { "N/A" })
        Print-Item "Endereço IPv6" $(if ($ipv6) { $ipv6 } else { "N/A" })
        Print-Item "Gateway Padrão" $(if ($gateways) { $gateways } else { "N/A" })
        Print-Item "Servidores DNS" $(if ($dnsServers) { $dnsServers } else { "N/A" })
        Print-Item "Configuração DHCP" $dhcpStatus

        $netIndex++
    }
}

# ------------------------------------------------------------------------------
# 8. DISPOSITIVOS E PLACAS PCI / PCIE
# ------------------------------------------------------------------------------
Print-Header "8. Dispositivos e Placas PCI / PCIe"

$pciDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
    Where-Object { 
        $_.DeviceID -like "PCI\VEN_*" -and 
        $_.Present -ne $false
    })

$knownPciVendors = @{
    "10DE" = "NVIDIA Corporation"
    "1002" = "Advanced Micro Devices, Inc. (AMD/ATI)"
    "8086" = "Intel Corporation"
    "10EC" = "Realtek Semiconductor Corp."
    "14E4" = "Broadcom Inc."
    "168C" = "Qualcomm Atheros"
    "1B21" = "ASMedia Technology Inc."
    "1987" = "Phison Electronics Corp. (NVMe)"
    "1D0F" = "Amazon.com, Inc. (NVMe/Virtual)"
    "1106" = "VIA Technologies"
}

$pciIndex = 1
foreach ($dev in $pciDevices) {
    $pciVen = "0000"
    $pciDev = "0000"
    
    if ($dev.DeviceID -match "VEN_([0-9A-Fa-f]{4})") { $pciVen = $Matches[1].ToUpper() }
    if ($dev.DeviceID -match "DEV_([0-9A-Fa-f]{4})") { $pciDev = $Matches[1].ToUpper() }

    $vendorName = "Desconhecido"
    if ($knownPciVendors.ContainsKey($pciVen)) {
        $vendorName = $knownPciVendors[$pciVen]
    } elseif ($dev.Manufacturer -and $dev.Manufacturer -notlike "*(Standard*)*" -and $dev.Manufacturer -notlike "*Padrão*") { 
        $vendorName = $dev.Manufacturer.Trim() 
    } else {
        $vendorName = "Dispositivo PCI OEM"
    }

    Write-Host ("PCI Slot/Dev {0:D2}: " -f $pciIndex) -NoNewline -ForegroundColor Yellow
    Write-Host "ID ${pciVen}:${pciDev} " -NoNewline -ForegroundColor Cyan
    Write-Host "$($dev.Name)" -ForegroundColor Green
    
    Print-Item "ID Hardware (VEN:DEV)" "${pciVen}:${pciDev}"
    Print-Item "Fabricante / Vendor" $vendorName
    Print-Item "Classe / Categoria" $($dev.PNPClass)
    Print-Item "Caminho PnP / DeviceID" $dev.DeviceID
    Write-Host ""
    $pciIndex++
}

Write-Host "Total de Dispositivos PCI Ativos: $($pciIndex - 1)" -ForegroundColor Gray

# ------------------------------------------------------------------------------
# 9. DISPOSITIVOS USB ATIVOS
# ------------------------------------------------------------------------------
Print-Header "9. Dispositivos USB Ativos"

$usbDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
    Where-Object { 
        $_.DeviceID -like "USB\VID_*" -and 
        $_.DeviceID -notlike "*&MI_*" -and 
        $_.PNPClass -ne "System" -and 
        $_.Present -ne $false
    })

$knownUsbVendors = @{
    "046D" = "Logitech, Inc."; "045E" = "Microsoft Corp."; "0BDA" = "Realtek Semiconductor";
    "1B1C" = "Corsair"; "1532" = "Razer USA"; "0781" = "SanDisk Corp."; "05AC" = "Apple, Inc.";
    "8087" = "Intel Corp. (Hub Integrado)"; "5986" = "Bison Electronics / Acer WebCam"; "1EA7" = "SHENZHEN JESHEN (Dongle Sem Fio)"
}

$usbIndex = 1
foreach ($dev in $usbDevices) {
    $usbVid = "0000"
    $usbPid = "0000"
    
    if ($dev.DeviceID -match "VID_([0-9A-Fa-f]{4})") { $usbVid = $Matches[1].ToUpper() }
    if ($dev.DeviceID -match "PID_([0-9A-Fa-f]{4})") { $usbPid = $Matches[1].ToUpper() }

    $manufacturer = "Desconhecido"
    if ($dev.Manufacturer -and $dev.Manufacturer -notlike "*(Standard*)*" -and $dev.Manufacturer -notlike "*Padrão*") { 
        $manufacturer = $dev.Manufacturer.Trim() 
    } elseif ($knownUsbVendors.ContainsKey($usbVid)) {
        $manufacturer = $knownUsbVendors[$usbVid]
    } else {
        $manufacturer = "Dispositivo Padrão / OEM"
    }

    Write-Host ("Bus 001 Device {0:D3}: " -f $usbIndex) -NoNewline -ForegroundColor Yellow
    Write-Host "ID ${usbVid}:${usbPid} " -NoNewline -ForegroundColor Cyan
    Write-Host "$($dev.Name)" -ForegroundColor Green
    
    Print-Item "ID Hardware (VID:PID)" "${usbVid}:${usbPid}"
    Print-Item "Fabricante / Marca" $manufacturer
    Print-Item "Classe / Categoria" $($dev.PNPClass)
    Print-Item "Caminho do Dispositivo" $dev.DeviceID
    Write-Host ""
    $usbIndex++
}

Write-Host "Total de Dispositivos USB Ativos: $($usbIndex - 1)" -ForegroundColor Gray
Write-Host ""
Write-Host "==================================================================================" -ForegroundColor Green

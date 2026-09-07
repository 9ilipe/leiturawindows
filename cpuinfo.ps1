# Função para formatar tamanhos em KB / MB
function Format-MemorySize ($sizeKB) {
    if (-not $sizeKB -or $sizeKB -eq 0) { return "N/A / Não informado pelo firmware" }
    if ($sizeKB -ge 1024) {
        return "$([math]::Round($sizeKB / 1024, 2)) MiB ($sizeKB KiB)"
    }
    return "$sizeKB KiB"
}

# Coleta de dados via CIM/WMI
$cpu = Get-CimInstance Win32_Processor
$caches = Get-CimInstance Win32_CacheMemory -ErrorAction SilentlyContinue

# Extração de Cache L1/L2/L3 com fallback (garante exibição mesmo se a classe de Cache falhar)
$l1Cache = $caches | Where-Object { $_.Purpose -like "*L1*" -or $_.Level -eq 3 }
$l2CacheSize = if ($cpu.L2CacheSize) { $cpu.L2CacheSize } else { ($caches | Where-Object { $_.Purpose -like "*L2*" -or $_.Level -eq 4 }).MaxCacheSize }
$l3CacheSize = if ($cpu.L3CacheSize) { $cpu.L3CacheSize } else { ($caches | Where-Object { $_.Purpose -like "*L3*" -or $_.Level -eq 5 }).MaxCacheSize }

# Detalhando L1 se disponível
$l1d = $caches | Where-Object { $_.Purpose -like "*L1*Data*" -or $_.Purpose -like "*L1-Data*" }
$l1i = $caches | Where-Object { $_.Purpose -like "*L1*Instruction*" -or $_.Purpose -like "*L1-Instruction*" }

# Montagem das seções
$secoes = [ordered]@{
    "GERAL & ARQUITETURA" = [ordered]@{
        "Nome do Modelo"         = $cpu.Name.Trim()
        "Fabricante / Vendor"    = $cpu.Manufacturer
        "Arquitetura"            = $env:PROCESSOR_ARCHITECTURE
        "Modo de Operacao"       = "$($cpu.AddressWidth)-bits"
        "Largura de Endereco"    = "$($cpu.AddressWidth) bits physical / $($cpu.DataWidth) bits data"
        "Ordem dos Bytes"        = "Little Endian"
        "Frequencia Base"        = "$($cpu.MaxClockSpeed) MHz"
        "Frequencia Atual"       = "$($cpu.CurrentClockSpeed) MHz"
    }
    "TOPOLOGIA & NÚCLEOS" = [ordered]@{
        "Soquetes Ocupados"      = $cpu.SocketDesignation
        "Nucleos Fisicos"        = $cpu.NumberOfCores
        "Processadores Logicos"  = $cpu.NumberOfLogicalProcessors
        "Threads por Nucleo"     = [math]::Round($cpu.NumberOfLogicalProcessors / $cpu.NumberOfCores)
        "CPUs Logicas Online"    = "0-$($cpu.NumberOfLogicalProcessors - 1)"
        "Estado da CPU"          = if ($cpu.CpuStatus -eq 1) { "Ativo / OK" } else { "Alerta ($($cpu.CpuStatus))" }
    }
    "MEMÓRIA CACHE DO PROCESSADOR" = [ordered]@{
        "L1 Cache (Instrução)"  = if ($l1i) { Format-MemorySize $l1i.MaxCacheSize } else { "Integrado ao Núcleo" }
        "L1 Cache (Dados)"       = if ($l1d) { Format-MemorySize $l1d.MaxCacheSize } else { "Integrado ao Núcleo" }
        "L2 Cache Total"         = Format-MemorySize $l2CacheSize
        "L3 Cache Total"         = Format-MemorySize $l3CacheSize
    }
    "RECURSOS & VIRTUALIZAÇÃO" = [ordered]@{
        "Virtualizacao (SLAT)"   = if ($cpu.SecondLevelAddressTranslationSupported) { "Suportado" } else { "Nao suportado" }
        "Virtualizacao na BIOS"  = if ($cpu.VirtualizationFirmwareEnabled) { "Ativada (VT-x / AMD-V)" } else { "Desativada" }
        "Suporte a Hypervisor"   = if ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent) { "Presente / Ativo" } else { "Inativo" }
    }
}

# Exibição Formatada no Terminal
Clear-Host
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "             INFORMAÇÕES DETALHADAS DA CPU (lscpu)                " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

foreach ($titulo in $secoes.Keys) {
    Write-Host "`n[ $titulo ]" -ForegroundColor Yellow
    foreach ($chave in $secoes[$titulo].Keys) {
        $valor = $secoes[$titulo][$chave]
        Write-Host ("{0,-28}: " -f $chave) -NoNewline -ForegroundColor White
        Write-Host $valor -ForegroundColor Green
    }
}
Write-Host "`n==================================================================" -ForegroundColor Cyan

# GHDL Compile and Simulate Script (PowerShell)
# Run from: D:\VHDL Software\configurable_fsm

# Navigate to project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
Push-Location $projectRoot

# 1. Create work directory
Write-Host "Creating work directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path work | Out-Null

# 2. Compile all source files
Write-Host "Compiling source files..." -ForegroundColor Cyan
ghdl -a --std=08 -fsynopsys src/generic_fsm.vhd
ghdl -a --std=08 -fsynopsys src/config_rom.vhd
ghdl -a --std=08 -fsynopsys src/traffic_light_wrapper.vhd
ghdl -a --std=08 -fsynopsys src/elevator_wrapper.vhd
ghdl -a --std=08 -fsynopsys src/serial_wrapper.vhd
ghdl -a --std=08 -fsynopsys src/vending_wrapper.vhd

# 3. Compile testbenches
Write-Host "Compiling testbenches..." -ForegroundColor Cyan
ghdl -a --std=08 -fsynopsys tb/tb_generic_fsm.vhd
ghdl -a --std=08 -fsynopsys tb/tb_traffic_light.vhd
ghdl -a --std=08 -fsynopsys tb/tb_elevator.vhd
ghdl -a --std=08 -fsynopsys tb/tb_serial.vhd
ghdl -a --std=08 -fsynopsys tb/tb_vending.vhd

# 4. Elaborate testbench
Write-Host "Elaborating tb_traffic_light..." -ForegroundColor Cyan
ghdl -e --std=08 -fsynopsys tb_traffic_light

# 5. Run simulation with waveform output
Write-Host "Running simulation..." -ForegroundColor Cyan
ghdl -r --std=08 -fsynopsys tb_traffic_light --wave=wave.ghw --stop-time=1us

# 6. View waveforms (if GTKWave is available)
Write-Host "Checking for GTKWave..." -ForegroundColor Cyan
$gtkwave = Get-Command gtkwave -ErrorAction SilentlyContinue
if ($gtkwave) {
    Write-Host "Opening waveforms in GTKWave..." -ForegroundColor Green
    gtkwave wave.ghw
} else {
    Write-Host "GTKWave not found. Waveform saved to wave.ghw" -ForegroundColor Yellow
}

Write-Host "Done!" -ForegroundColor Green
Pop-Location

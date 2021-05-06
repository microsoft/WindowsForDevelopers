# Things to note
# Single script, will survive reboot
# Script needs to be run under admin (will auto correct if not)
# Script needs internet access to download files
# Script assumes WinGet is installed
# 
# Why aren't we using wsl --install -d Ubuntu
# Well, we want to WSL.exe install a bunch of stuff
# Ubuntu2004 install --root can't be done above so it requires user interaction
# if you don't need to install items on linux without setting root, this script becomes much simplier 
# as we don't need to recreate wsl --install

$mypath = $MyInvocation.MyCommand.Path
Write-Output "Path of the script : $mypath"
Write-Output "IsReboot: $Args"
$isReboot = $Args[0]
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Restarting as Admin
if (!$isAdmin) {
	Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$mypath' $Args;`"";
	exit;
}

if(!$isReboot)
{
	Write-Output "First time run"
	
	# Enabling hyper-v
	Write-Output "Enabling Hyper-V"
	dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

	# Enabling WSL
	Write-Output "Enabling WSL"
	dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
}
else
{
	# Copy JSON fragments to Terminal folder
	$termFragPath = $env:LOCALAPPDATA + "\Microsoft\Windows Terminal\Fragments\build-extension"
	mkdir $termFragPath

	move-item -Path .\build-extension -Destination $termFragPath

	# Rebooted
	Write-Output "Rebooted"

	# Updating kernel
	Write-Output "Updating kernel"
	Invoke-WebRequest -Uri https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -OutFile ~/wsl_update_x64.msi -UseBasicParsing
	Start-Process ~\wsl_update_x64.msi -ArgumentList '/quiet' -Wait

	# WSL2 as default
	Write-Output "WSL2 as default"
	wsl.exe --set-default-version 2

	# Installing distro
	Write-Output "Installing Ubuntu"
	Invoke-WebRequest -Uri https://aka.ms/wslubuntu2004 -OutFile ~/Ubuntu.appx -UseBasicParsing
	Add-AppxPackage -Path ~/Ubuntu.appx

	# run the distro once and have it install locally with root user, unset password
	Ubuntu2004 install --root

	# Installing apps Craig needs for demo
	# Install Linux GUI apps
	wsl.exe -u root apt update
	wsl.exe -u root apt install nautilus vim-gtk gedit -y

	# Install NodeJS
	wsl.exe -u root curl -fsSL https://deb.nodesource.com/setup_15.x `| -E bash -
	wsl.exe -u root apt-get install -y nodejs

	# Install TestCafe
	# TODO CRAIG: flip to https://playwright.dev/
	wsl.exe -u root npm install -g testcafe

	# Install Microsoft Edge
	wsl.exe -u root apt update
	wsl.exe -u root apt install software-properties-common apt-transport-https wget
	wsl.exe -u root wget -q https://packages.microsoft.com/keys/microsoft.asc -O- `| apt-key add -
	wsl.exe -u root add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main"
	wsl.exe -u root apt install microsoft-edge-dev -y
	
	# Installing stuff on Windows
	Write-Output "Winget install stuff"
	winget import WSL_WinGet.json
}

if(!$isReboot)
{
	# RESTART COMPUTER
	$RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
	set-itemproperty $RunOnceKey "NextRun" ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + $mypath + ' -reboot')
	
	Write-Output "Need to restart"
	$Input = Read-Host -Prompt "Press to restart"
	Restart-Computer
}
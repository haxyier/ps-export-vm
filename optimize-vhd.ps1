################################
# Optimize specified VHD(x). 
################################

# Configure parameters.
Param(
    [Parameter(HelpMessage="VM attached target VHD.")]
    [String]
    $TargetVM
)

# In case encounters any errors, always throw exception.
$ErrorActionPreference = "Stop"


function OptimizeVHD($vm_name) {
    try {
        $vm = Get-VM -VMName $vm_name

        Write-Host "`r`nStart optimize VHD of" $vm.Name

        $restart_required = $false
        if ($vm.State -ne "Off") {
            $input = Read-Host $vm.Name "is not powered off. Turn it off ? (y|N)"
            if ($input -eq "y") {
                Stop-VM -Name $vm.Name
                $restart_required = $true
                Write-Host $VM.Name "is stopped."
            } else {
                Write-Host "Optimization is skipped.`r`n"
                return
            }
        }

        $disks = Get-VMHardDiskDrive -VMName $vm.Name
        Write-Host "Found" $disks.Count "disk(s) attached."

        foreach ($disk in $disks) {
            Write-Host "Mounting VHD:" $disk.Path
            Mount-VHD $disk.Path -NoDriveLetter -Readonly

            $size_gb = (Get-Item $disk.Path).Length / 1GB
            Write-Host "Start optimize first time. Disk size: " $size_gb "GB"
            Optimize-VHD $disk.Path -Mode Full
            $size_gb = (Get-Item $disk.Path).Length / 1GB
            Write-Host "End optimize. Disk size: " $size_gb "GB"

            $size_gb = (Get-Item $disk.Path).Length / 1GB
            Write-Host "Start optimize second time. Disk size: " $size_gb "GB"
            Optimize-VHD $disk.Path -Mode Full
            $size_gb = (Get-Item $disk.Path).Length / 1GB
            Write-Host "End optimize. Disk size: " $size_gb "GB"

            Write-Host "Dismounting VHD:" $disk.Path
            Dismount-VHD $disk.Path
        }

        if ($restart_required) {
            Start-VM -Name $vm.Name
            Write-Host $VM.Name "is started."
        }

        Write-Host "Optimization is completed!`r`n"
    }
    catch {
        Write-Host "Following error is occured while optimize" $vm_name
        Write-Host $PSItem.Exception.Message
    }
}


if ($TargetVM) {
    OptimizeVHD $TargetVM
} else {
    $vms = Get-VM
    foreach ($vm in $vms) {
        OptimizeVHD $vm.Name
    }
}

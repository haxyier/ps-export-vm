################################
# Export specified VMs. 
################################

# Configure parameters.
Set-Variable DST_BASE_DIR "W:\vm" -Option Constant                      # Directory to export VMs.
Set-Variable CONFIG_FILE "export-vm-list.txt" -Option Constant          # File name of target VMs list.
Set-Variable MAX_GENERATIONS 4 -Option Constant                         # Number of generations to be stored.
Set-variable ERROR_LOG_NAME "error.log" -Option Constant                # File name of Error log.

$script_file_name = [System.IO.Path]::GetFileNameWithoutExtension($(Split-Path -Leaf $PSCommandPath))
$log_file = Join-Path $(Convert-Path .) ($script_file_name + ".log")

function Log($message, $loglevel="INFO") {
    [string]::Format("{0} - [{1}] {2}", $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss"), $loglevel, $message) | Out-File $log_file -Append -Force -Encoding utf8
}

function ErrorLog($message) {
    Log $message "ERROR"
}

function ExportVM($machine_name, $dst_dir) {
    try {
        Export-VM -Name $machine_name -Path $dst_dir -CaptureLiveState CaptureSavedState -ErrorAction Stop
        Log ("Export succeeded. Machine name: " + $machine_name)
    }
    catch {
        ErrorLog $PSItem.Exception.Message
        ErrorLog ("Export failed. Machine name: " + $machine_name)

        $error[0] | Out-File $(Join-Path $dst_dir $ERROR_LOG_NAME) -Append -Force -Encoding utf8
        return $false
    }
    return $true
}

function RemoveBackup($dir) {
    try {
        Remove-Item $dir -Recurse -ErrorAction Stop
        Log ("Removed old backup. Directory name: " + $dir)
    }
    catch {
        ErrorLog $PSItem.Exception.Message
        ErrorLog ("Remove failed. Directory name: " + $dir)
    }
}

function SelectBackup($dir) {
    $backups = @()
    $child_dirs = Get-ChildItem $dir | Sort-Object Name

    foreach ($child_dir in $child_dirs) {
        if (!($child_dir.Name -match "\d{14}")) {
            continue
        }
        $backups += $child_dir
    }
    return $backups
}
function RotateBackup() {
    try {
        $backups = SelectBackup $DST_BASE_DIR
        if ($backups.Count -le $MAX_GENERATIONS) {
            return
        }

        $delete_count = $backups.Count - $MAX_GENERATIONS
        $backups | Select-Object -First $delete_count | ForEach-Object {
            RemoveBackup $_.FullName
        }
    }
    catch {
        ErrorLog $PSItem.Exception.Message
        ErrorLog "Backup rotation was aborted with unexpected error."
    }
}

try {
    Log "Job started."

    $datetime_now =  Get-Date -Format "yyyyMMddHHmmss"
    $dst_dir = Join-Path $DST_BASE_DIR $datetime_now
    $target_vms = (Get-Content $CONFIG_FILE -ErrorAction Stop) -as [string[]]

    New-Item $dst_dir -ItemType Directory -ErrorAction Stop

    $contains_error = $false
    foreach ($vm in $target_vms) {
        $result = ExportVM $vm $dst_dir
        if ($result -eq $false) {
            $contains_error = $true
        }
    }

    # If backup completed without any errors, backup rotation process is invoked.
    if (!$contains_error) {
        RotateBackup
    }
}
catch {
    ErrorLog $PSItem.Exception.Message
    ErrorLog "Job exit with unexpected error."
}
finally {
    Log "Job completed."
}

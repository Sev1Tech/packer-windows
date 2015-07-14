$psake.use_exit_on_error = $true
properties {
  $baseDir = (Split-Path -parent $psake.build_script_dir)
}


task build-packer {
  exec { packer build -force (Join-Path $baseDir vbox-2012r2.json) }
}

task prepare-hyperv {
    $vmPath = Join-Path $baseDir 'hyper-v-output' 'Virtual Machines' 'vm.xml'
    [xml]$vmXml = Get-Content $vmPath
    $vmXml.configuration.properties.name.'#text' = '2012R2Min'
    $vmXml.Save($vmPath)

    $vboxDisk = Resolve-Path(Join-Path $baseDir 'output-virtualbox-iso' '*.vmdk')
    $hyperVDir = Join-Path $baseDir 'hyper-v-output' 'Virtual Hard Disks'
    if(!(Test-Path $hyperVDir)) { mkdir $hyperVDir }
    $hyperVDisk = Join-Path $hyperVDir 'disk.vhd'
    if(Test-Path $hyperVDisk) { Remove-Item $hyperVDisk -Force }
    $hyperVVagrantFile = Join-Path $baseDir 'hyper-v-output' 'Vagrantfile'
    if(Test-Path $hyperVVagrantFile) { Remove-Item $hyperVVagrantFile -Force }
    Copy-Item (Join-Path $baseDir vagrantfile-windows.template) $hyperVVagrantFile
}

task convert-tovhd {
  $vboxDisk = Resolve-Path(Join-Path $baseDir 'output-virtualbox-iso' '*.vmdk')
  $hyperVDir = Join-Path $baseDir 'hyper-v-output' 'Virtual Hard Disks'
  ."$env:programfiles\oracle\VirtualBox\VBoxManage.exe" clonehd $vboxDisk $hyperVDisk --format vhd
}

task package-hyperv {
  ."$env:chocolateyInstall\tools\7za.exe" a -ttar (join-path $baseDir "package-hyper-v.tar") (Join-Path $baseDir "hyper-v-output\*")
  ."$env:chocolateyInstall\tools\7za.exe" a -tgzip (join-path $baseDir "package-hyper-v.box") (join-path $baseDir "package-hyper-v.tar")
}

task Upload-Box {
  $path = (join-path $baseDir "package-hyper-v.box")
  $storageAccountKey = Get-AzureStorageKey wrock | %{ $_.Primary }
  $context = New-AzureStorageContext -StorageAccountName wrock -StorageAccountKey $storageAccountKey
  Set-AzureStorageBlobContent -Blob (Split-Path -Path $path -Leaf) -Container vhds -File $path -Context $context -Force
}
param (
  [Parameter(Mandatory = $true)]
  [string]$ClientName,

  [string]$CpaqVersion = "latest",

  [string]$PortalVersion = "latest",

  [Parameter(Mandatory = $true)]
  [securestring]$SqlPassword,

  [Parameter(Mandatory = $true)]
  [securestring]$SqlUser,

  [Parameter(Mandatory = $true)]
  [string]$SqlDatabase,

  [Parameter(Mandatory = $true)]
  [string]$SqlServer
)

function Protect-Secret {
  param (
    [Parameter(Mandatory = $true)]
    [string]$SecretValue,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$SecretName
  )

  return Set-Variable /p="$SecretValue" | kubeseal --raw --namespace $Namespace --name $SecretName
}

$Namespace = "cpaq-$ClientName"
$RelativePath = "..\clusters\dev\$Namespace"

# Ensure the directory exists
if (-not (Test-Path -Path $RelativePath)) {
  Write-Host "Directory does not exist. Creating directory $RelativePath"
  New-Item -ItemType Directory -Path $RelativePath
}

$IngressTemplatePath = ".\templates\ingress-patch.tpl.json"

if (Test-Path $IngressTemplatePath) {
  $JsonTemplate = Get-Content -Path $IngressTemplatePath -Raw

  
  $Domain = "$ClientName.int-dev-aks.cordiccloud.com"
  
  $JsonTemplate = $JsonTemplate -replace "{{Domain}}", $Domain

  $JsonFilePath = Join-Path $RelativePath "ingress-patch.json"
  $JsonTemplate | Set-Content -Path $JsonFilePath

  Write-Host "JSON file created at: $JsonFilePath"
}
else {
  Write-Host "JSON template file not found: $IngressTemplatePath"
}

$NamespaceTemplatePath = ".\templates\namespace.tpl.yaml"

if (Test-Path $NamespaceTemplatePath) {
  $YamlTemplate = Get-Content -Path $NamespaceTemplatePath -Raw

  $YamlTemplate = $YamlTemplate -replace "{{Namespace}}", $Namespace

  $YamlFilePath = Join-Path $RelativePath "namespace.yaml"
  $YamlTemplate | Set-Content -Path $YamlFilePath

  Write-Host "Namespace YAML file created at: $YamlFilePath"
}
else {
  Write-Host "Namespace YAML template file not found: $NamespaceTemplatePath"
}

$KustomizationTemplatePath = ".\templates\cpaqportal.tpl.yaml"

if (Test-Path $KustomizationTemplatePath) {
  $YamlTemplate = Get-Content -Path $KustomizationTemplatePath -Raw

  $YamlTemplate = $YamlTemplate -replace "{{Namespace}}", $Namespace
  $YamlTemplate = $YamlTemplate -replace "{{CpaqVersion}}", $CpaqVersion
  $YamlTemplate = $YamlTemplate -replace "{{PortalVersion}}", $PortalVersion

  $YamlFilePath = Join-Path $RelativePath "kustomization.yaml"
  $YamlTemplate | Set-Content -Path $YamlFilePath

  Write-Host "Kustomization YAML file created at: $YamlFilePath"
}
else {
  Write-Host "Kustomization YAML template file not found: $KustomizationTemplatePath"
}

$SecretsTemplatePath = ".\templates\secrets.tpl.yaml"

if (Test-Path $SecretsTemplatePath) {
  $YamlTemplate = Get-Content -Path $SecretsTemplatePath -Raw

  $YamlTemplate = $YamlTemplate -replace "{{SqlServer}}", "$(Protect-Secret -SecretValue $SqlServer -Namespace $Namespace -SecretName "dbsecrets")"
  $YamlTemplate = $YamlTemplate -replace "{{SqlDatabase}}", "$(Protect-Secret -SecretValue $SqlDatabase -Namespace $Namespace -SecretName "dbsecrets")"
  $YamlTemplate = $YamlTemplate -replace "{{SqlUser}}", "$(Protect-Secret -SecretValue $SqlUser -Namespace $Namespace -SecretName "dbsecrets")"
  $YamlTemplate = $YamlTemplate -replace "{{SqlPassword}}", "$(Protect-Secret -SecretValue $SqlPassword -Namespace $Namespace -SecretName "dbsecrets")"

  $YamlFilePath = Join-Path $RelativePath "secrets.yaml"
  $YamlTemplate | Set-Content -Path $YamlFilePath

  Write-Host "Secrets YAML file created at: $YamlFilePath"
}
else {
  Write-Host "Secrets YAML template file not found: $SecretsTemplatePath"
}

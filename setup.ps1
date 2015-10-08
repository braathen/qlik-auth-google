$nl = [Environment]::NewLine

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Write-Host $nl"Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Break
}

$confirm = Read-Host "This script will install the Google Auth module, do you want to proceed? [Y/n]"
if ($confirm -eq 'n') {
  Break
}

# Set black background
$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

# define some variables
$temp="c:\Temp\GoogleAuthSetup-yFH4gu"
$npm="npm-1.4.12.zip"
$config="c:\Program Files\Qlik\Sense\ServiceDispatcher"
$target="$config\Node\Google-Auth"

# check if module is installed
if(!(Test-Path -Path "$target\node_modules")) {

    # check if npm has been downloaded already
	if(!(Test-Path -Path "$temp\$npm")) {
        New-Item -Path "$temp" -Type directory -force | Out-Null
		Invoke-WebRequest "http://nodejs.org/dist/npm/$npm" -OutFile "$temp\$npm"
	}

    # check if module has been downloaded
    if(!(Test-Path -Path "$target\src")) {
        New-Item -Path "$target\src" -Type directory | Out-Null
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-auth-google/master/service.js" -OutFile "$target\src\service.js"
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-auth-google/master/package.json" -OutFile "$target\package.json"
    }

    # check if npm has been unzipped already
    if(!(Test-Path -Path "$temp\node_modules")) {
        Write-Host "Extracting files..."
        Add-Type -assembly "system.io.compression.filesystem"
        [io.compression.zipfile]::ExtractToDirectory("$temp\$npm", "$temp")
    }

    # install module with dependencies
	Write-Host "Installing modules..."
    Push-Location "$target\src"
    $env:Path=$env:Path + ";$config\Node"
	&$temp\npm.cmd config set spin=false
	&$temp\npm.cmd --prefix "$target" install
    Pop-Location

    # cleanup temporary data
    Write-Host "Removing temporary files..."
    Remove-Item $temp -recurse
}

function Read-Default($text, $defaultValue) { $prompt = Read-Host "$($text) [$($defaultValue)]"; return ($defaultValue,$prompt)[[bool]$prompt]; }

# check if config has been added already
if (!(Select-String -path "$config\services.conf" -pattern "Identity=rfn-google-auth" -quiet)) {

	$settings = "

[google-auth]
Identity=rfn-google-auth
Enabled=true
DisplayName=Google Auth
ExecType=nodejs
ExePath=Node\node.exe
Script=Node\google-auth\src\service.js
    
[google-auth.parameters]
domain=
user_directory=
client_id=
client_secret=
redirect_uris=
"
	Add-Content "services.conf" $settings
}

# look for client secret json file from Google
if((Test-Path -Path "client_secret*.json")) {
    $json = Get-Content -Raw -Path client_secret*.json | ConvertFrom-Json
    $client_id = $json.web.client_id
    $client_secret = $json.web.client_secret
    $redirect_uri = $json.web.redirect_uris[0]
}

# configure module
Write-Host $nl"CONFIGURE MODULE"
Write-Host $nl"To make changes to the configuration in the future just re-run this script."

$domain=Read-Default $nl"Enter domain for valid email addresses" "gmail.com"
$user_directory=Read-Default $nl"Enter name of user directory" "GOOGLE"
$client_id=Read-Default $nl"ClientID" $client_id
$client_secret=Read-Default $nl"Client Secret" $client_secret
$redirect_uri=Read-Default $nl"Redirect URI" $redirect_uri

function Set-Config( $file, $key, $value )
{
    $regreplace = $("(?<=$key).*?=.*")
    $regvalue = $("=" + $value)
    if (([regex]::Match((Get-Content $file),$regreplace)).success) {
        (Get-Content $file) `
            |Foreach-Object { [regex]::Replace($_,$regreplace,$regvalue)
         } | Set-Content $file
    } else {
        Add-Content -Path $file -Value $("`n" + $key + "=" + $value)          
    }
}

# write changes to configuration file
Write-Host $nl"Updating configuration..."
Set-Config -file "$config\services.conf" -key "domain" -value $domain
Set-Config -file "$config\services.conf" -key "user_directory" -value $user_directory
Set-Config -file "$config\services.conf" -key "client_id" -value $client_id
Set-Config -file "$config\services.conf" -key "client_secret" -value $client_secret
Set-Config -file "$config\services.conf" -key "redirect_uris" -value $redirect_uri

Write-Host $nl"Done! Please restart the 'Qlik Sense Service Dispatcher' service for changes to take affect."$nl

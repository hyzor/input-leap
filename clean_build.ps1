
# The following packets need to be installed via Chocolatey in order to run this script:
# cmake, openssl, aqt (version 3.1.17), InnoSetup
# Qt needs to be installed either manually or by running:
# aqt install-qt windows desktop 6.4.2 win64_msvc2019_64 -O C:\Qt
# or
# aqt install-qt windows desktop 5.15.2 win64_msvc2019_64 -O C:\Qt
# Note that Powershell may need to be restarted in order to changes to take effect.

$bonjour_path = '.\deps\BonjourSDKLike'

New-Item -Force -ItemType Directory -Path .\deps | Out-Null
Invoke-WebRequest 'https://github.com/nelsonjchen/mDNSResponder/releases/download/v2019.05.08.1/x64_RelWithDebInfo.zip' -OutFile 'deps\BonjourSDKLike.zip' ;
if (Test-Path -LiteralPath $bonjour_path) {
    Remove-Item -LiteralPath $bonjour_path -Recurse
}

# CMake configuration expects this to be absolute path
$bonjour_path = -join((Get-Location).Path, '\', $bonjour_path);

Expand-Archive .\deps\BonjourSDKLike.zip -DestinationPath .\deps\BonjourSDKLike
Remove-Item deps\BonjourSDKLike.zip

$vs_locations = @(
    @{version='Visual Studio 17 2022';
      path='C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat'},
    @{version='Visual Studio 17 2022';
      path='C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat'},
    @{version='Visual Studio 17 2022';
      path='C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat'},
    @{version='Visual Studio 16 2019';
      path='C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat'},
    @{version='Visual Studio 16 2019';
      path='C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\Tools\VsDevCmd.bat'},
    @{version='Visual Studio 16 2019';
      path='C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\Tools\VsDevCmd.bat'}
);

$vs_version = '';
$vs_path = '';

Foreach ($location in $vs_locations) {
    if (Test-Path -LiteralPath $location.path) {
        $vs_version = $location.version;
        $vs_path = $location.path;
        break;
    }
}

$build_env_dir = -join((Get-Location).Path, '\', 'build_env.ps1');

# Allow local customizations to build environment
if (Test-Path $build_env_dir) {
    Write-Output "Using local build environment at $build_env_dir";
    invoke-expression -Command $build_env_dir
}

if ($vs_version -eq '') {
    Write-Output "Could not find Visual studio version";
    break;
}

Write-Output "Using Visual Studio version $vs_version at $vs_path";

$build_type = 'Release';
if ($null -ne $env:B_BUILD_TYPE) {
    $build_type = $env:B_BUILD_TYPE;
}
$qt_major_version = '6';
if ($null -ne $env:B_QT_MAJOR_VERSION) {
    $qt_major_version = $env:B_QT_MAJOR_VERSION;
}
$qt_root = (Resolve-Path C:\Qt\$qt_major_version*\* 2>$null).Path;
if ($null -ne $env:B_QT_ROOT) {
    $qt_root = $env:B_QT_ROOT;
} elseif ($null -eq $qt_root) {
    Write-Output "Could not find Qt and B_QT_ROOT is not provided";
    break;
}

Write-Output "Using Qt at $qt_root";

if (Test-Path -LiteralPath build) {
    Remove-Item -LiteralPath build -Recurse;
}
New-Item -Force -ItemType Directory -Path .\build | Out-Null
Push-Location build

try {
    $env:BONJOUR_SDK_HOME="$bonjour_path"
    cmake .. -G "$vs_version" -A x64 `
        "-DCMAKE_BUILD_TYPE=$build_type" `
        "-DCMAKE_PREFIX_PATH=$qt_root" `
        "-DQT_DEFAULT_MAJOR_VERSION=$qt_major_version" `
        -DDNSSD_LIB="$bonjour_path\Lib\x64\dnssd.lib" `
        -DCMAKE_INSTALL_PREFIX=input-leap-install

    cmake --build . --parallel --config $build_type --target install
    ISCC /Qp installer-inno\input-leap.iss
} finally {
    Pop-Location
}

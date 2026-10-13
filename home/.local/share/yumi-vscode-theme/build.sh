#!/usr/bin/env bash
# Собрать yumi.wallbash-theme-1.0.0.vsix из этой папки и установить в VS Code.
set -eu
cd "$(dirname "$0")"
python3 -I - <<'PY'
import json, zipfile, os
pkg = json.load(open("package.json"))
ident = f'{pkg["publisher"]}.{pkg["name"]}-{pkg["version"]}'
manifest = f'''<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{pkg["name"]}" Version="{pkg["version"]}" Publisher="{pkg["publisher"]}" />
    <DisplayName>{pkg["displayName"]}</DisplayName>
    <Description xml:space="preserve">{pkg["description"]}</Description>
    <Tags>theme,color-theme,wallbash,yumi</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg["engines"]["vscode"]}" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="ui,workspace" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true" />
  </Assets>
</PackageManifest>
'''
types = '''<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".md" ContentType="text/markdown" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
</Types>
'''
out = ident + ".vsix"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("extension.vsixmanifest", manifest)
    z.writestr("[Content_Types].xml", types)
    for f in ("package.json", "README.md", "themes/wallbash.json"):
        z.write(f, "extension/" + f)
print("собран", out)
PY
code --install-extension "yumi.wallbash-theme-1.0.0.vsix" --force

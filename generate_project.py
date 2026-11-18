#!/usr/bin/env python3
"""Generate a small deterministic Xcode project without external Python packages."""
from pathlib import Path
import hashlib

ROOT=Path(__file__).parent
PROJ=ROOT/'StreamPlayLegacy.xcodeproj'
PROJ.mkdir(exist_ok=True)
(PROJ/'xcshareddata'/'xcschemes').mkdir(parents=True,exist_ok=True)

def ref(label):
    return hashlib.md5(('streamplay-legacy-'+label).encode()).hexdigest().upper()[:24]

main=ref('source.main')
icon2=ref('resource.icon2')
icon3=ref('resource.icon3')
plist=ref('plist.info')
launch=ref('resource.launchscreen')
frameworks=['UIKit','Foundation','AVFoundation','WebKit','MobileCoreServices','QuartzCore']
files=[('main.m',main,'sourcecode.c.objc','StreamPlayLegacy'),
       ('Info.plist',plist,'text.plist.xml','StreamPlayLegacy'),
       ('LaunchScreen.storyboard',launch,'file.storyboard','StreamPlayLegacy'),
       ('AppIcon60x60@2x.png',icon2,'image.png','StreamPlayLegacy/Resources'),
       ('AppIcon60x60@3x.png',icon3,'image.png','StreamPlayLegacy/Resources')]

lines=['// !$*UTF8*$!', '{','\tarchiveVersion = 1;', '\tclasses = {};', '\tobjectVersion = 56;', '\tobjects = {']

def section(title,entries):
    lines.append(f'/* Begin {title} section */')
    lines.extend(entries)
    lines.append(f'/* End {title} section */')

builds=[(ref('build.'+name), ident,name) for name,ident,_,_ in files if name !='Info.plist']
frame_ids=[(ref('framework.'+name),ref('build.framework.'+name),name) for name in frameworks]
section('PBXBuildFile',[
    f'\t\t{build} /* {name} in {"Sources" if name=="main.m" else "Resources"} */ = {{isa = PBXBuildFile; fileRef = {fileid} /* {name} */; }};'
    for build,fileid,name in builds
]+[f'\t\t{build} /* {name}.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ident} /* {name}.framework */; }};'
    for ident,build,name in frame_ids])

section('PBXFileReference',[
    f'\t\t{ident} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {filetype}; path = "{name}"; sourceTree = "<group>"; }};'
    for name,ident,filetype,_ in files
]+[
    f'\t\t{ident} /* {name}.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {name}.framework; path = System/Library/Frameworks/{name}.framework; sourceTree = SDKROOT; }};'
    for ident,build,name in frame_ids
]+[f'\t\t{ref("app")} /* StreamPlayLegacy.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = StreamPlayLegacy.app; sourceTree = BUILT_PRODUCTS_DIR; }};'])

section('PBXFrameworksBuildPhase',[f'''\t\t{ref('phase.framework')} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(f'\t\t\t\t{build} /* {name}.framework in Frameworks */,' for ident,build,name in frame_ids)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''])

section('PBXGroup',[f'''\t\t{ref('group.root')} /* Root */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ( {ref('group.src')} /* StreamPlayLegacy */, {ref('group.framework')} /* Frameworks */, {ref('group.product')} /* Products */ );
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ref('group.src')} /* StreamPlayLegacy */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ( {main} /* main.m */, {plist} /* Info.plist */, {launch} /* LaunchScreen.storyboard */, {ref('group.resources')} /* Resources */ );
\t\t\tpath = StreamPlayLegacy;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ref('group.resources')} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ( {icon2} /* AppIcon60x60@2x.png */, {icon3} /* AppIcon60x60@3x.png */ );
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ref('group.framework')} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ( {', '.join(ident+' /* '+name+'.framework */' for ident,build,name in frame_ids)} );
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ref('group.product')} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({ref('app')} /* StreamPlayLegacy.app */);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};'''])

section('PBXNativeTarget',[f'''\t\t{ref('target')} /* StreamPlayLegacy */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ref('configlist.target')} /* Build configuration list for PBXNativeTarget "StreamPlayLegacy" */;
\t\t\tbuildPhases = ( {ref('phase.source')} /* Sources */, {ref('phase.framework')} /* Frameworks */, {ref('phase.resource')} /* Resources */ );
\t\t\tbuildRules = ( );
\t\t\tdependencies = ( );
\t\t\tname = StreamPlayLegacy;
\t\t\tproductName = StreamPlayLegacy;
\t\t\tproductReference = {ref('app')} /* StreamPlayLegacy.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};'''])

section('PBXProject',[f'''\t\t{ref('project')} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{ LastUpgradeCheck = 1600; TargetAttributes = {{ {ref('target')} = {{ CreatedOnToolsVersion = 16.4; }}; }}; }};
\t\t\tbuildConfigurationList = {ref('configlist.project')} /* Build configuration list for PBXProject "StreamPlayLegacy" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = pt_BR;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = ( pt_BR, en, Base );
\t\t\tmainGroup = {ref('group.root')} /* Root */;
\t\t\tproductRefGroup = {ref('group.product')} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({ref('target')} /* StreamPlayLegacy */);
\t\t}};'''])
section('PBXResourcesBuildPhase',[f'''\t\t{ref('phase.resource')} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({ref('build.AppIcon60x60@2x.png')} /* AppIcon60x60@2x.png in Resources */, {ref('build.AppIcon60x60@3x.png')} /* AppIcon60x60@3x.png in Resources */, {ref('build.LaunchScreen.storyboard')} /* LaunchScreen.storyboard in Resources */);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''])
section('PBXSourcesBuildPhase',[f'''\t\t{ref('phase.source')} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({ref('build.main.m')} /* main.m in Sources */);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''])

def xcconfig(name,ident,settings):
    return f'''\t\t{ident} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{chr(10).join('                '+key+' = '+value+';' for key,value in settings.items())}
\t\t\t}};
\t\t\tname = {name};
\t\t}};'''
base={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'12.0', 'TARGETED_DEVICE_FAMILY':'1'}
settings={
 ('project','Debug'):base | {'GCC_OPTIMIZATION_LEVEL':'0','DEBUG_INFORMATION_FORMAT':'dwarf','ENABLE_TESTABILITY':'YES'},
 ('project','Release'):base | {'GCC_OPTIMIZATION_LEVEL':'s','DEBUG_INFORMATION_FORMAT':'"dwarf-with-dsym"','ENABLE_TESTABILITY':'NO'},
 ('target','Debug'):{'CODE_SIGN_STYLE':'Automatic','PRODUCT_BUNDLE_IDENTIFIER':'com.drotavio.streamplaylegacy','INFOPLIST_FILE':'StreamPlayLegacy/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CURRENT_PROJECT_VERSION':'2','MARKETING_VERSION':'1.1','PRODUCT_NAME':'"$(TARGET_NAME)"','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'12.0','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"','ASSETCATALOG_COMPILER_APPICON_NAME':'""'},
 ('target','Release'):{'CODE_SIGN_STYLE':'Automatic','PRODUCT_BUNDLE_IDENTIFIER':'com.drotavio.streamplaylegacy','INFOPLIST_FILE':'StreamPlayLegacy/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CURRENT_PROJECT_VERSION':'2','MARKETING_VERSION':'1.1','PRODUCT_NAME':'"$(TARGET_NAME)"','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'12.0','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"','ASSETCATALOG_COMPILER_APPICON_NAME':'""'},
}
section('XCBuildConfiguration',[xcconfig(name,ref(f'xcconfig.{kind}.{name}'),settings[kind,name]) for kind in ('project','target') for name in ('Debug','Release')])
section('XCConfigurationList',[f'''\t\t{ref('configlist.'+kind)} /* Build configuration list */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({ref('xcconfig.'+kind+'.Debug')} /* Debug */, {ref('xcconfig.'+kind+'.Release')} /* Release */);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''' for kind in ('project','target')])
lines.extend(['\t};', f'\trootObject = {ref("project")} /* Project object */;', '}'])
(PROJ/'project.pbxproj').write_text('\n'.join(lines)+'\n')
(PROJ/'xcshareddata'/'xcschemes'/'StreamPlayLegacy.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('target')}" BuildableName="StreamPlayLegacy.app" BlueprintName="StreamPlayLegacy" ReferencedContainer="container:StreamPlayLegacy.xcodeproj"/>
    </BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('target')}" BuildableName="StreamPlayLegacy.app" BlueprintName="StreamPlayLegacy" ReferencedContainer="container:StreamPlayLegacy.xcodeproj"/></BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('target')}" BuildableName="StreamPlayLegacy.app" BlueprintName="StreamPlayLegacy" ReferencedContainer="container:StreamPlayLegacy.xcodeproj"/></BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Created:',PROJ)

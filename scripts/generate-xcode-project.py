"""Generate a dependency-free macOS app + XCTest UI project from the Swift sources."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
project = root / 'PersonalLife.xcodeproj'
project.mkdir(exist_ok=True)
objects = []
def key(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, body):
    objects.append(f'{key(name)} = {{ {body} }};')
    return key(name)
def quote(s): return '"' + str(s).replace('\\','\\\\').replace('"','\\"') + '"'
apprefs=[]; appbuild=[]; testrefs=[]; testbuild=[]
for target, paths, refs, builds in [('app', sorted((root/'Sources/LifeApp').glob('*.swift')), apprefs, appbuild),('test', sorted((root/'UITests').glob('*.swift')), testrefs,testbuild)]:
    for path in paths:
        name=path.relative_to(root).as_posix()
        ref=obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(name)}; sourceTree = "<group>";')
        refs.append(ref)
        builds.append(obj(name+'build', f'isa = PBXBuildFile; fileRef = {ref};'))
appProduct=obj('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = PersonalLife.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PersonalLifeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({appProduct},{testProduct}); name = Products; sourceTree = "<group>";')
mainGroup=obj('mainGroup',f'isa = PBXGroup; children = ({",".join(apprefs+testrefs+[products])}); sourceTree = "<group>";')
package=obj('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
core=obj('core',f'isa = XCSwiftPackageProductDependency; package = {package}; productName = LifeCore;')
coreBuild=obj('coreBuild',f'isa = PBXBuildFile; productRef = {core};')
for name, files in [('appSources',appbuild),('testSources',testbuild)]: obj(name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(files)}); runOnlyForDeploymentPostprocessing = 0;')
obj('appFrameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({coreBuild}); runOnlyForDeploymentPostprocessing = 0;')
obj('testFrameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {key("project")}; proxyType = 1; remoteGlobalIDString = {key("app")}; remoteInfo = PersonalLife;')
obj('dependency',f'isa = PBXTargetDependency; target = {key("app")}; targetProxy = {key("proxy")};')
for target in ['project','app','test']:
    configs=[]
    for conf in ['Debug','Release']:
        settings={'ONLY_ACTIVE_ARCH':'YES','SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','SWIFT_VERSION':'5.0','CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','ENABLE_HARDENED_RUNTIME':'NO','CLANG_ENABLE_MODULES':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if conf=='Debug' else '-O'}
        if target!='project':
            settings.update({'GENERATE_INFOPLIST_FILE':'YES','PRODUCT_NAME':'PersonalLife' if target=='app' else 'PersonalLifeUITests','PRODUCT_BUNDLE_IDENTIFIER':'com.xunisgood.personallife.uitestapp' if target=='app' else 'com.xunisgood.personallife.uitests','SWIFT_EMIT_LOC_STRINGS':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'})
        if target=='app': settings.update({'INFOPLIST_KEY_CFBundleDisplayName':'我的日常 UI 测试','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.productivity','ENABLE_APP_SANDBOX':'NO','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1'})
        if target=='test': settings.update({'TEST_TARGET_NAME':'PersonalLifeDesktop','ENABLE_APP_SANDBOX':'NO'})
        values=' '.join(f'{k} = {quote(v)};' for k,v in settings.items())
        configs.append(obj(target+conf,f'isa = XCBuildConfiguration; buildSettings = {{ {values} }}; name = {conf};'))
    obj(target+'Configs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('app',f'isa = PBXNativeTarget; buildConfigurationList = {key("appConfigs")}; buildPhases = ({key("appSources")},{key("appFrameworks")}); buildRules = (); dependencies = (); name = PersonalLifeDesktop; packageProductDependencies = ({core}); productName = PersonalLife; productReference = {appProduct}; productType = "com.apple.product-type.application";')
obj('test',f'isa = PBXNativeTarget; buildConfigurationList = {key("testConfigs")}; buildPhases = ({key("testSources")},{key("testFrameworks")}); buildRules = (); dependencies = ({key("dependency")}); name = PersonalLifeUITests; productName = PersonalLifeUITests; productReference = {testProduct}; productType = "com.apple.product-type.bundle.ui-testing";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2630; }}; buildConfigurationList = {key("projectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {mainGroup}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; packageReferences = ({package}); targets = ({key("app")},{key("test")});')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+key('project')+'; }\n')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(target,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key(target)}" BuildableName="{name}" BlueprintName="{'PersonalLifeDesktop' if target == 'app' else name.split('.')[0]}" ReferencedContainer="container:PersonalLife.xcodeproj"/>'
(schemes/'PersonalLife.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('app','PersonalLife.app')}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref('test','PersonalLifeUITests.xctest')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('test','PersonalLifeUITests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('app','PersonalLife.app')}</BuildableProductRunnable></LaunchAction>
</Scheme>''')
print('Generated',project)

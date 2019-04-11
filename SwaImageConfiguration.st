"-=-=-=-=-="
|balloon progdir base|

"Initial Setup"
FileStream startUp: true.
TranscriptStream redirectToStdOut: true.
Deprecation showDeprecationWarnings: false.

"To account for an issue together with the current SwaSource"
MCHttpRepository useSharedWebClientInstance: false.

progdir := (Smalltalk commandLine argumentAt: 1) ifNil: [FileDirectory default fullName].
base := (Smalltalk commandLine argumentAt: 2) ifNil: ['SWA'].

[[MCMcmUpdater default doUpdate: false. "non-interactive"]
	on: MCEmptyVersion do: [:warning | warning resume].

"-=-=-=-=-="

"For all trunk repositories add the inbox repository."
(MCWorkingCopy allManagers collect: #repositoryGroup) do: [:g | 
	g addRepository: ReleaseBuilder inboxRepository].

"-=-=-=-=-="

Installer ensureRecentMetacello.

"-=-=-=-=-="
Preferences removeAllPreferencesSuchThat: [:ea | ea provider == (Smalltalk at: #MCGitBasedNetworkRepository)].
"-=-=-=-=-="

"-=-=-=-=-="
Installer squeakTrunk install: 'Help-Squeak-CorePackages'.

Utilities setAuthorInitials: 'hpi'. "changed at end"

[(Smalltalk at: #Metacello) new
	baseline: 'SwaLint';
	repository: 'github://hpi-swa-teaching/SwaLint:master/packages';
	get;
	load: #default]
		on: (Smalltalk at: #MetacelloSkipDirtyPackageLoad) new 
		do: [:e | e resume: false].

(Smalltalk at: #Metacello) new
	baseline: 'Koans';
	githubUser: 'HPI-SWA-Teaching' project: 'Koans' commitish: '' path: 'src';
	load.
	
(Smalltalk at: #Metacello) new
	configuration: 'RefactoringTools';
	load.

"-=-=-=-=-="

"Install Squot-develop for latest fixes"
[(Smalltalk at: #Metacello) new
  baseline: 'Squot';
  repository: 'github://hpi-swa/Squot:master/src';
  load.
] on: Warning do: [:e | e resume].

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
    baseline: 'LBGit';
    repository: 'github://LeonBein/SmalltalkGitTesting';
    load.

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
  baseline: 'AutoTDD';
  repository: 'github://hpi-swa-teaching/AutoTDD:master/packages';
  onConflict: [:ex | ex allow];
  load.

"-=-=-=-=-="

Preferences disable: #projectZoom.
Preferences enable: #mouseOverForKeyboardFocus.

Preferences disable: #alternativeBrowseIt.
SystemBrowser default: Browser.
TextEditor autoEnclose: false.
TextEditor destructiveBackWord: true.

"-=-=-=-=-="

Project current resourceManager reset.
Smalltalk cleanUp: true.
MCHttpRepository clearCredentials.
Environment allInstancesDo: [:env | env purgeUndeclared].
Undeclared removeUnreferencedKeys.
Smalltalk garbageCollect.

"-=-=-=-=-="

Utilities setAuthorInitials: 'hpi'. "changed at end"

"Vivide needs to be loaded after UI-Theme reset (via Smalltalk cleanUp: true)"
[(Smalltalk at: #Metacello) new
	repository: 'github://hpi-swa/Vivide:master-squot/repository';
	baseline: 'Vivide';
	load.
] on: AssertionFailure do: [:e | e resume].

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://Salami555/Squeak-ToolIconsPlus:master';
	baseline: 'ToolIconsPlus';
	load.

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://MrModder/Autocompletion:master/packages';
	baseline: 'Autocompletion';
	load.

(Smalltalk at: #ECPreferences) perform: #smartCharacters: with: false.
(Smalltalk at: #ECPreferences) matchSubStrings: true.

"-=-=-=-=-="

MCFileBasedRepository flushAllCaches.
MCCacheRepository instVarNamed: 'default' put: nil.
ChangeSet current clear.
ChangeSet current name: 'Unnamed1'.
Smalltalk garbageCollect.
MCCacheRepository cacheDirectory recursiveDelete.
Smalltalk fixObsoleteReferences.

"-=-=-=-=-="

Utilities setAuthorInitials: 'hpi'. "changed at end"

#(('../HPIicon.png' 'smallFullscreenOnIcon') ('../HPIicon_sw.png' 'smallFullscreenOffIcon')) do: [:info | | image stream |
	FileStream fileNamed: (info first) do: [:f | |writer |
		writer := PNGReadWriter on: f.
		image := [writer nextImage] ensure: [writer close]].
	"store string representation"
	stream := String new writeStream.
	stream
		nextPutAll: info last, 'Contents' ; cr;
		nextPutAll: (MenuIcons methodStart: (info last)).
	image storeOn: stream.
	stream nextPutAll: MenuIcons methodEnd.
	MenuIcons class compile: stream contents classified: '*HPI-private icons-override' notifying: nil.
	"create accessor method"
	stream := String new writeStream.
	stream
		nextPutAll: info last ; cr;
		nextPutAll: (MenuIcons methodAccessorFor: (info last)).
	MenuIcons class compile: stream contents classified: '*HPI-accessing icons-override' notifying: nil.
].
MenuIcons initializeIcons.

HostWindowProxy new primitiveWindowSize: 1 x: 1024 y: 768.
Preferences disable: #showSharedFlaps.

Utilities setAuthorInitials: String empty.
Smalltalk garbageCollect.

(World findA: PreferenceWizardMorph) ifNotNil: [:m | m perform: #showSqueak].

"-=-=-=-=-="
Project current in: [:oldProject | 
	WorldState addDeferredUIMessage: [
		"-=-=-=-=-="
		Project deletingProject: oldProject.
		ProjectHistory forget: oldProject.
		Project forget: oldProject.
		Project current setParent: Project current.
		Preferences disable: #showSharedFlaps.
		UIManager default builderClass: MorphicToolBuilder.
		"-=-=-=-=-="
		TheWorldMainDockingBar updateInstances.
		(UserInterfaceTheme named: 'Squeak') apply.
		Smalltalk saveAs: base, '.image'.
		WorldState addDeferredUIMessage: [
			ReleaseBuilder openWelcomeWorkspacesWith: nil.
			PreferenceWizardMorph open].
		Smalltalk snapshot: true andQuit: true.
	].
	(Smalltalk at: #AnimMorphicProject) new enter: false.
]] ensure: [
	TranscriptStream redirectToStdOut: false.]

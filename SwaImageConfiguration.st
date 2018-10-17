"-=-=-=-=-="
|balloon progdir base|

"Initial Setup"
FileStream startUp: true.
TranscriptStream redirectToStdOut: true.
Deprecation showDeprecationWarnings: false.

progdir := (Smalltalk commandLine argumentAt: 1) ifNil: [FileDirectory default fullName].
base := (Smalltalk commandLine argumentAt: 2) ifNil: ['SWA'].

[[MCMcmUpdater default doUpdate: false. "non-interactive"]
	on: MCEmptyVersion do: [:warning | warning resume].

"-=-=-=-=-="

"Get the Metacello configuration (for Squeak users)"
Installer gemsource
    project: 'metacello';
    addPackage: 'ConfigurationOfMetacello';
    install.

"Bootstrap Metacello Preview, using mcz files (#'previewBootstrap' symbolic version"
((Smalltalk at: #ConfigurationOfMetacello) project 
  version: #'previewBootstrap') load.

"Quickfix"
Installer squeak
	project: 'trunk';
	install: 'SqueakSSL-Core';
	install: 'WebClient-Core';
	yourself.

"Load the Preview version of Metacello from GitHub"
(Smalltalk at: #Metacello) new
  configuration: 'MetacelloPreview';
  version: #stable;
  repository: 'github://Metacello/metacello:configuration';
  load.

"Quickfix"
Installer squeak
	project: 'trunk';
	install: 'SqueakSSL-Core';
	install: 'WebClient-Core';
	yourself.

"Now load latest version of Metacello"
(Smalltalk at: #Metacello) new
  baseline: 'Metacello';
  repository: 'github://Metacello/metacello:master/repository';
  get.
(Smalltalk at: #Metacello) new
  baseline: 'Metacello';
  repository: 'github://Metacello/metacello:master/repository';
  load.

"-=-=-=-=-="
Preferences removeAllPreferencesSuchThat: [:ea | ea provider == (Smalltalk at: #MCGitBasedNetworkRepository)].
"-=-=-=-=-="

"-=-=-=-=-="
Installer squeakTrunk install: 'Help-Squeak-CorePackages'.

Utilities setAuthorInitials: 'hpi'. "changed at end"

[(Smalltalk at: #Metacello) new
	baseline: 'SwaLint';
	repository: 'github://hpi-swa-teaching/SwaLint:release/packages';
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

(Smalltalk at: #Metacello) new
	configuration: 'OCompletion';
	load.

"Disables until refactored
(Smalltalk at: #Metacello) new
	baseline: 'MorphicTutorial';
	githubUser: 'HPI-SWA-Teaching' project: 'SWT18-Project-06' commitish: '' path: 'packages';
	load."
	
(Smalltalk at: #Metacello) new
	baseline: 'GM';
	repository: 'github://hpi-swa-teaching/GameMecha/source';
	load: 'test'.

(Smalltalk at: #ECPreferences) perform: #smartCharacters: with: false.

"-=-=-=-=-="

"Install Squot-develop for latest fixes"
[(Smalltalk at: #Metacello) new
  baseline: 'Squot';
  repository: 'github://hpi-swa/Squot:master/src';
  load.
] on: Warning do: [:e | e resume].

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
	githubUser: 'hpi-swa' project: 'vivide' commitish: '' path: 'repository';
	baseline: 'Vivide';
	load.
] on: AssertionFailure do: [:e | e resume].

"-=-=-=-=-="

MCFileBasedRepository flushAllCaches.
MCCacheRepository instVarNamed: 'default' put: nil.
Categorizer sortAllCategories.
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

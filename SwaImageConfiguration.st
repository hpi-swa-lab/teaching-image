"-=-=-=-=-="
|progdir base options|

"Initial Setup"
FileStream startUp: true.
TranscriptStream redirectToStdOut: true.
Deprecation showDeprecationWarnings: false.

"To account for an issue together with the current SwaSource"
MCHttpRepository useSharedWebClientInstance: false.

"The following code is copied from SmalltalkImage>>arguments which seems to return nil here ..."
options := Smalltalk commandLine arguments.
				
Transcript showln: 'Received options: ', options.
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
Installer squeakTrunk install: 'Help-Squeak-CorePackages'.

Utilities setAuthorInitials: 'hpi'. "changed at end"

[(Smalltalk at: #Metacello) new
	baseline: 'SwaLint';
	repository: 'github://hpi-swa-teaching/SwaLint:main/packages';
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

"Install Squot SWA UI."
"[(Smalltalk at: #Metacello) new
  baseline: 'Squot';
  repository: 'github://hpi-swa/Squot:swa-ui/src';
  load.
] on: Warning do: [:e | e resume]."


	
"The tools menu in the docking bar should use the swa git ui"
"(Smalltalk at: #TheWorldMainDockingBar) compile: 'installAndOpenGitBrowser 
	
	(Smalltalk hasClassNamed: #SquitBrowser)
		ifFalse: [ (UIManager default
					confirm: ''The Git infrastructure and browser is not yet installed.\\Do you want to install the Git Browser?\\(Note that this step requires an internet connection and\may take several minutes.)'' withCRs translated
					title: ''Confirm Installation Request'' )
			ifTrue: [ Installer
						ensureRecentMetacello;
						installGitInfrastructure.
					TheWorldMainDockingBar updateInstances ]
			ifFalse: [ ^self ] ].
	(Smalltalk classNamed: #SwaSquitBrowser) open.'."

"-=-=-=-=-="
	
"Install new Git Client made by Marius and Tom for WiSe 23/24"
Metacello new
  baseline: 'Squot';
  repository: 'github://hpi-swa/Squot:mapper/src';
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
	
Workspace shouldStyle: true.
	
SoundPlayer stopReverb.

"-=-=-=-=-="

Project current resourceManager reset.
Smalltalk cleanUp: true except: {Warning}.
MCHttpRepository clearCredentials.
Environment allInstancesDo: [:env | env purgeUndeclared].
Undeclared removeUnreferencedKeys.
Smalltalk garbageCollect.

"-=-=-=-=-="

Utilities setAuthorInitials: 'hpi'. "changed at end"

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://LinqLover/Squeak-TipOfTheDay/packages';
	baseline: 'TipOfTheDay';
	load.

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://MrModder/Autocompletion:master/packages';
	baseline: 'Autocompletion';
	load.

(Smalltalk at: #ECPreferences) perform: #smartCharacters: with: false.
(Smalltalk at: #ECPreferences) matchSubStrings: true.

"-=-=-=-=-="
	
(Smalltalk at: #Metacello) new
	baseline: 'GM';
	repository: 'github://hpi-swa-teaching/GameMecha/source';
	load: 'swa'.
	
"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://hpi-swa/signals:master/repository';
	baseline: 'Signals';
	load.
	
"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://hpi-swa/animations:master/repository';
	baseline: 'Animations';
	load.

"-=-=-=-=-="
	
(Smalltalk at: #Metacello) new
	baseline: 'MorphicTutorial';
	repository: 'github://hpi-swa-teaching/SWT18-Project-06:master/packages';
	load.

"-=-=-=-=-="
"w shortcut to delete windows - experimental for SWA WiSe 23/24"

(Smalltalk at: #SystemWindow) compile: 'filterEvent: aKeyboardEvent for: anObject
	"Provide keyboard shortcuts."

	aKeyboardEvent isKeystroke
		ifFalse: [^ aKeyboardEvent].

	aKeyboardEvent hand halo ifNotNil: [ : halo | halo target isSystemWindow ifTrue: [ aKeyboardEvent hand removeHalo ] ].
	
	aKeyboardEvent commandKeyPressed ifTrue: [
		aKeyboardEvent keyCharacter caseOf: { 
			[$\] -> [self class sendTopWindowToBack].
			[Character escape] -> [self class deleteTopWindow].
			[$w] -> [self class deleteTopWindow].
			[$/] -> [self class bringWindowUnderHandToFront].
		} otherwise: [^ aKeyboardEvent "no hit"].
		^ aKeyboardEvent ignore "hit!"].
	
	aKeyboardEvent controlKeyPressed ifTrue: [
		aKeyboardEvent keyCharacter caseOf: {
			[Character escape] -> [self world findWindow: aKeyboardEvent].
		} otherwise: [^ aKeyboardEvent ""no hit""].
		^ aKeyboardEvent ignore "hit!"].

	^ aKeyboardEvent "no hit"'.

"-=-=-=-=-="
"Remove Git Updates from PreferenceWizard as we use a special git version"
	
(Smalltalk at: #PreferenceWizardMorph) compile: 'initializePage99ExtraPackages
	"Let the user install extra packages."

	| currentPage packagesList installButton |
	currentPage := self createPage.
	currentPage
		cellPositioning: #topCenter;
		addMorphBack: self createHorizontalSpacer;
		addMorphBack: ((self createLabel: ''Do you want to install extra packages?'' translated color: Color white)
			hResizing: #shrinkWrap;
			averageLineLength: 65;
			yourself);
		addMorphBack: ((self createLabel: ''Note that the installation process requires a network connection with Internet access and might take several minutes.'' translated color: (Color gray: 0.9))
			hResizing: #shrinkWrap;
			averageLineLength: 65;
			yourself).
	
	currentPage submorphs last text addAttribute: TextAlignment centered.
	currentPage submorphs last layoutChanged.
	
	currentPage addMorphBack: (self createVerticalSpace height: self layoutInset).
	
	packagesList := self createScrollPane.
	packagesList
		width: (self defaultTextStyle compositionWidthFor: 65);
		hResizing: #rigid;
		vResizing: #spaceFill.

	packagesList scroller firstSubmorph addAllMorphsBack: {
		self createCheckbox: ''Latest system updates'' translated for: #InstallLatestUpdates help: ''Install the latest patches for '' translated, SystemVersion current version.
		self createCheckbox: ''Refactoring support in code browsers'' translated for: #InstallRefactoringTools help: ''Refactoring is a process of re-writing or re-organizing text or code. The purpose of a refactor is to make the code or text more understandable and readable while exactly preserving its meaning and behavior'' translated.
		self createCheckbox: ''Autocomplete in code editors'' translated for: #InstallAutoComplete help: ''Package that provides interactive, context-sensitive auto-completion for Squeak'' translated.
		self createCheckbox: ''Foreign function interface (FFI)'' translated for: #InstallFFI help: ''FFI, the Squeak Foreign Function Interface, is used to call functions located in shared libraries that are not part of the Squeak VM nor its plugins'' translated.
		self createCheckbox: ''Access OS functions'' translated for: #InstallOSProcess help: ''OSProcess provides access to operating system functions, including pipes and child process creation'' translated.
		self createCheckbox: ''Integrate Squeak''''s mailing lists'' translated for: #InstallSqueakInboxTalk help: ''Through Squeak Inbox Talk, you can engage with our community from within Squeak using tools that integrate our mailing lists such as squeak-dev and vm-dev'' translated.
	}.
		
	currentPage addMorphBack: packagesList.

	currentPage addMorphBack: ((self createLabel: ''Find more on www.squeak.org/projects'' color: (Color gray: 0.9))
		hResizing: #shrinkWrap; yourself).
	
	installButton := self createButton
		action: #installExtraPackagesVia:;
		label: ''Yes, install selected packages.'' translated;
		yourself.
	installButton
		setProperty: #label toValue: installButton label;
		arguments: {installButton}.
	
	currentPage addMorphBack: installButton.
	currentPage addMorphBack: (self createButton action: #showSqueak; label: ''No, maybe later.'' translated).
	
	^ currentPage'.
	
"-=-=-=-=-="

(options includes: '-startrack') ifTrue:
	[(Smalltalk at: #Metacello) new
		baseline: 'StarTrack';
		repository: 'github://hpi-swa-lab/learning-liveness/packages';
		load: 'client'].


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

#(('/HPIicon.png' 'smallFullscreenOnIcon') ('/HPIicon_sw.png' 'smallFullscreenOffIcon')) do: [:info | | image stream |
	FileStream fileNamed: (progdir , info first) do: [:f | |writer |
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

HostWindowProxy new primitiveWindowSize: 1 x: 1240 y: 800.
Preferences disable: #showSharedFlaps.

Utilities setAuthorInitials: String empty.
Smalltalk garbageCollect.

"-=-=-=-=-="
Project current in: [:oldProject | 
	WorldState addDeferredUIMessage: [
		"-=-=-=-=-="
		Project deletingProject: oldProject.
		ProjectHistory forget: oldProject.
		Project forget: oldProject.
		Project current setParent: Project current.
		Project rebuildAllProjects.
		Preferences disable: #showSharedFlaps.
		UIManager default builderClass: MorphicToolBuilder.
		"-=-=-=-=-="
		TheWorldMainDockingBar updateInstances.
		(UserInterfaceTheme named: 'Squeak') apply.
		Preferences increaseFontSize.
		WorldState addDeferredUIMessage: [
			ReleaseBuilder openWelcomeWorkspacesWith: nil.
			PreferenceWizardMorph open].
		"The following is a desperate measure to get the 22/23 image built without the debugger window resulting from some command line argument passing issue"
		"Doing this on the first opening of the image is super desperate. This should be fixed in subsequent terms."
		TheWorldMainDockingBar instance closeAllWindows.
		Smalltalk snapshot: true andQuit: true.
	].
	(Smalltalk at: #AnimMorphicProject) new enter: false.
]] ensure: [
	TranscriptStream redirectToStdOut: false.]

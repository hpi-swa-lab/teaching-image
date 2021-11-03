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
Preferences removeAllPreferencesSuchThat: [:ea | ea provider == (Smalltalk at: #MCGitBasedNetworkRepository)].
"-=-=-=-=-="

"-=-=-=-=-="
Installer squeakTrunk install: 'Help-Squeak-CorePackages'.

"-=-=-=-=-="
" Christoph's fixes needed for ECMA regex parsing "
Installer squeakInbox
	install: 'Kernel-ct.1419';
	install: 'Multilingual-ct.259';
	install: 'Regex-Core-ct.71.mcz';
	install: 'Regex-Tests-Core-ct.28'.

RxsCharSet compile:  a Text for 'predicatePartPredicateIgnoringCase: aBoolean

	| predicates size |
	"Answer a predicate that tests all of my elements that cannot be enumerated, or nil if such elements don''t exist."
	predicates := elements reject: [:some | some isEnumerable].
	(size := predicates size) = 0 ifTrue: ["We could return a real predicate block - like [ :char | negated ] - here, but it wouldn''t be used anyway. This way we signal that this character set has no predicates."
	^ nil].
	size = 1 ifTrue: [
		negated ifTrue: [^ predicates first predicateNegationIgnoringCase: aBoolean].
		^ predicates first predicateIgnoringCase: aBoolean].
	predicates replace: [:each | each predicateIgnoringCase: aBoolean].
	negated ifTrue: [^ [:char | predicates noneSatisfy: [:some | some value: char]]].
	^ [:char | predicates anySatisfy: [:some | some value: char]]'.

"-=-=-=-=-="

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

"Install Squot-develop for latest fixes"
[(Smalltalk at: #Metacello) new
  baseline: 'Squot';
  repository: 'github://hpi-swa/Squot:develop/src';
  load.
] on: Warning do: [:e | e resume].

"Remove after bug is fixed in Squot-master --pre"
(Smalltalk at: #SquitBrowser) compile: 'refresh
	Cursor wait showWhile:
		[self changed: #projectList.
		self changed: #projectIndex.
		self loadBranchList.
		self loadCommitList.
		self changed: #hasProjectSelection.
		self changed: #hasBranchSelection.
		self changed: #hasCommitSelection.
		self changed: #hasSearchTerm.
		self changed: #contents.
		self changed: #labelString.
		self objectCacheRefreshAsync].'.

(Smalltalk at: #SquotPackageShadow) compile: 'squotPreferredSerializer
  ^ (packageName endsWith: ''.package'') ifTrue: [self class squotPreferredSerializer] ifFalse: [SquotTonelSerializer]'.

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
UIManager openToolsAttachedToMouseCursor: true.
TextEditor autoEnclose: true.
TextEditor encloseSelection: true.
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

"Vivide needs to be loaded after UI-Theme reset (via Smalltalk cleanUp: true)"
"[(Smalltalk at: #Metacello) new
	repository: 'github://hpi-swa/Vivide:master-squot/repository';
	baseline: 'Vivide';
	load.
] on: AssertionFailure do: [:e | e resume]."

"-=-=-=-=-="

"(Smalltalk at: #Metacello) new
repository: 'github://LinqLover/Squeak-TipOfTheDay/packages';
baseline: 'TipOfTheDay';
load."

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://MrModder/Autocompletion:master/packages';
	baseline: 'Autocompletion';
	load.

(Smalltalk at: #ECPreferences) perform: #smartCharacters: with: false.
(Smalltalk at: #ECPreferences) matchSubStrings: true.

"-=-=-=-=-="
	
"(Smalltalk at: #Metacello) new
baseline: 'GM';
repository: 'github://hpi-swa-teaching/GameMecha/source';
load: 'test'."
	
"-=-=-=-=-="
	
"(Smalltalk at: #Metacello) new
baseline: 'MorphicTutorial';
repository: 'github://hpi-swa-teaching/SWT18-Project-06:master/packages';
load."
	
"-=-=-=-=-="

"(options includes: '-startrack') ifTrue:
[(Smalltalk at: #Metacello) new
baseline: 'StarTrack';
repository: 'github://hpi-swa-lab/learning-liveness/packages';
load: 'client']."


"-=-=-=-=-="

(Smalltalk at: #Metacello) new
  configuration: 'OSProcess';
  load.
(Smalltalk at: #Metacello) new
  configuration: 'FFI';
  load: #development.

(Smalltalk at: #Metacello) new
	baseline: 'Sandblocks';
	githubUser: 'tom95' project: 'sandblocks' commitish: 'master' path: 'packages';
	load: #tutorial.
CodeHolder addSandblocksDefault: false.

"-=-=-=-=-="

" working shortcut for closing top window "
SystemWindow compile: 'filterEvent: aKeyboardEvent for: anObject
	"Provide keyboard shortcuts."

	aKeyboardEvent isKeystroke
		ifFalse: [^ aKeyboardEvent].

	aKeyboardEvent hand halo ifNotNil: [ : halo | halo target isSystemWindow ifTrue: [ aKeyboardEvent hand removeHalo ] ].
	
	aKeyboardEvent commandKeyPressed ifTrue: [
		aKeyboardEvent keyCharacter caseOf: { 
			[$\] -> [self class sendTopWindowToBack].
			[$w] -> [self class deleteTopWindow].
			[$/] -> [self class bringWindowUnderHandToFront].
		} otherwise: [^ aKeyboardEvent "no hit"].
		^ aKeyboardEvent ignore "hit"].
	
	aKeyboardEvent controlKeyPressed ifTrue: [
		aKeyboardEvent keyCharacter caseOf: {
			[Character escape] -> [self world findWindow: aKeyboardEvent].
		} otherwise: [^ aKeyboardEvent "no hit"].
		^ aKeyboardEvent ignore "hit"].

	^ aKeyboardEvent
'.

"-=-=-=-=-="

" address enclose quotation mark bug "

TextEditor compile: 'enclose: aKeyboardEvent
	"Insert or remove bracket characters around the current selection."

	| character left right startIndex stopIndex oldSelection which t |
	character := aKeyboardEvent shiftPressed
					ifTrue: [''{}|''''<>'' at: (''[]\'''',.'' indexOf: aKeyboardEvent keyCharacter) ifAbsent: [aKeyboardEvent keyCharacter]]
					ifFalse: [aKeyboardEvent keyCharacter].
	self closeTypeIn.
	startIndex := self startIndex.
	stopIndex := self stopIndex.
	oldSelection := self selection.
	which := ''([<{|"''''9'' indexOf: character ifAbsent: [ ^ false ].
	"Allow Control key in lieu of Alt+Shift for (, {, and double-quote."
	left := ((Preferences cmdKeysInText and: [ aKeyboardEvent controlKeyPressed ])
		ifTrue: [ ''({<{|""('' ]
		ifFalse: [''([<{|"''''('']) at: which.
	right := ((Preferences cmdKeysInText and: [ aKeyboardEvent controlKeyPressed ])
		ifTrue: [ '')}>}|"")'' ] 
		ifFalse: ['')]>}|"'''')'']) at: which.
	t := self text.
	((startIndex > 1 and: [stopIndex <= t size])
			and: [ (t at: startIndex-1) = left and: [(t at: stopIndex) = right]])
		ifTrue:
			["already enclosed; strip off brackets"
			self selectFrom: startIndex-1 to: stopIndex.
			self replaceSelectionWith: oldSelection]
		ifFalse:
			["not enclosed; enclose by matching brackets"
			self replaceSelectionWith:
				(Text string: (String with: left), oldSelection string, (String with: right) attributes: emphasisHere).
			self selectFrom: startIndex+1 to: stopIndex].
	^true'.

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
		Project rebuildAllProjects.
		Preferences disable: #showSharedFlaps.
		UIManager default builderClass: MorphicToolBuilder.
		"-=-=-=-=-="
		TheWorldMainDockingBar updateInstances.
		(UserInterfaceTheme named: 'Squeak') apply.
		Transcript showln: 'Saving as ', base, '.image'.
		Smalltalk saveAs: base, '.image'.
		WorldState addDeferredUIMessage: [
			"ReleaseBuilder openWelcomeWorkspacesWith: nil."
			SimpleButtonMorph new
				target: [CodeHolder toggleSandblocksDefault];
				actionSelector: #value;
				label: 'toggleSandblocksDefault';
				position: 30 @ 30;
				openInWorld.
			(Smalltalk at: #SBEditor) openExample.
			"PreferenceWizardMorph open"].
		Smalltalk snapshot: true andQuit: true.
	].
	(Smalltalk at: #MorphicProject) new enter: false.
]] ensure: [
	TranscriptStream redirectToStdOut: false.]

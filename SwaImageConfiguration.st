"-=-=-=-=-="
|progdir base options balloon|

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

["Debugging convenience & fail-safety (copied from https://github.com/LinqLover/create-image/blob/36aaa650f39f8fd86d0176ec8f0d72b404f6c0a5/src/prepareImage.st#L3-L17)"
thisContext insertSender: (Context contextOn: UnhandledError, ProvideAnswerNotification do: [:ex |
	Transcript showln: (String streamContents: [:stream | ex signalerContext errorReportOn: stream]).
	Smalltalk snapshot: true andQuitWithExitCode: 1]).
thisContext
	insertSender: (Context contextOn: ProgressInitiationException do: [:ex |
		ex sendNotificationsTo: [:min :max :curr |
			Transcript showln: ('[Progress] [{1}/{2}:{3}] {4}' format: {curr. min. max. ex messageText})]]);
	insertSender: (Context contextOn: ProgressNotification do: [:ex |
		Transcript showln: ('[Progress] {1}' format: {({ex messageText. ex extraParam}) joinSeparatedBy: $|}).
		ex resume]).

"-=-=-=-=-="

"When we are using a custom upstream, update version information here"

customEdition := nil. "'Squeak6.1swe-2026-edition' -> 'https://www.squeaksource.com/swe2026edition'."
customEdition ifNotNil:
	[Utilities setAuthorInitials: 'hpi'. "changed at end"
	[ReleaseBuilder setNewSystemVersion: customEdition key] valueSuppressingAllMessages.
	ReleaseBuilder switchToNewRepository: (MCRepository location: customEdition value)].

[MCMcmUpdater default doUpdate: false. "non-interactive"]
	on: MCEmptyVersion do: [:warning | warning resume].

"-=-=-=-=-="

Installer ensureRecentMetacello.

"-=-=-=-=-="

Utilities setAuthorInitials: 'hpi'. "restored at end of this script"

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
(Smalltalk at: #TheWorldMainDockingBar) compile: 'installAndOpenGitBrowser 
	
	self inform: ''Unavailable. Please use\	Apps > Git Browser\	Apps > Git Asset Browser'' withCRs.' classified: '*hpi-override'.

"-=-=-=-=-="
	
"Install new Git Client made by Marius and Tom for WiSe 24/25"
[Metacello new
  baseline: 'GitS';
  repository: 'github://hpi-swa/git-s:latest-release/src';
  load]
    valueSuppressingAllMessages. "git-s changelog"

"-=-=-=-=-="

"Just for convenience, install ExternalWebBrowser by default."
Metacello new
		configuration: 'FFI';
		load.
Installer ss project: 'ExternalWebBrowser'; install: 'ExternalWebBrowser'.
WebBrowser default: ExternalWebBrowser. self flag: #moveUpstream. "ExternalWebBrowser could do this by itself"

"-=-=-=-=-="

FileStream
	readOnlyFileNamed: progdir, '/patches/ChangeList-selectAllDefinitionsFromHere.cs'
	do: [:stream | stream fileIn].

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
  baseline: 'AutoTDD';
  repository: 'github://hpi-swa-teaching/AutoTDD:master/packages';
  onConflict: [:ex | ex allow];
  load.

"-=-=-=-=-="

Preferences disable: #projectZoom.
Preferences enable: #mouseOverForKeyboardFocus.
Model windowActiveOnFirstClick: true.
Preferences enable: #traceMessages.
Preferences disable: #alternativeBrowseIt.

SystemBrowser default: TreeBrowser.
TextEditor autoEnclose: true.
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

customEdition ifNil:
	["For all trunk repositories add the inbox repository."
	(MCWorkingCopy allManagers collect: #repositoryGroup) do: [:g | 
		g addRepository: ReleaseBuilder inboxRepository]].

"-=-=-=-=-="

Utilities setAuthorInitials: 'hpi'. "changed at end"

"-=-=-=-=-="
"Squeak by Example Reader - see: https://github.com/hpi-swa-lab/SqueakByExample-english/pull/222 (still not merged!!)"
Metacello new
	baseline: 'SBE';
	repository: 'github://hpi-swa-lab/SqueakByExample-english:extract-book/SmalltalkSources';
	get;
	load: #'SBE-Book'.

Project uiManager informUser: 'Loading book (this might take a while)...' during:
	[| book |
	book := (Smalltalk classNamed: #SBEBook) readFrom:
		(WebClient httpGet: 'https://github.com/LinqLover/SqueakByExample-english/raw/extract-book-builds/sbe60.sbebook') content.
	book perform: #fixUpImages.
	Smalltalk garbageCollect.
	(Smalltalk classNamed: #SBEHelp) book: book].
"inject book cover"
(Smalltalk classNamed: #SBEHelp) class compile: (((Smalltalk classNamed: #SBEHelp) class sourceCodeAt: #introduction) copyReplaceAll: 'nextChunkText)' with: ('nextChunkText , String cr , ''<br><img src="data:image/png;base64,' , (ByteArray streamContents: [:stream | PNGReadWriter putForm: ((Form fromBinaryStream: (HTTPSocket httpGetDocument:  'https://github.com/LinqLover/SqueakByExample-english/raw/refs/heads/extract-book-builds/sbe60-cover.jpg') contentStream) scaledToWidth: 200) onStream: stream]) base64Encoded , '">'' asTextFromHtml)')) classified: '*hpi-override'.

"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://LinqLover/Squeak-TipOfTheDay/packages';
	baseline: 'TipOfTheDay';
	load.

"-=-=-=-=-="

[Metacello new
	baseline: 'SnapshotReminder';
	repository: 'github://hpi-swa-teaching/squeak-snapshot-reminder:main';
	get; "for updates"
	load: #withRecommended]
		valueSupplyingAnswer: #('Tonel support is missing*' true).
(Smalltalk at: #SnapshotReminder) assureDefault startProcess.
	
"-=-=-=-=-="

(Smalltalk at: #Metacello) new
	repository: 'github://LeonMatthes/Autocompletion:master/packages';
	baseline: 'Autocompletion';
	load.

(Smalltalk at: #ECPreferences) perform: #smartCharacters: with: false.
(Smalltalk at: #ECPreferences) matchSubStrings: true.

"-=-=-=-=-="
	
"(Smalltalk at: #Metacello) new
	baseline: 'GameMecha';
	repository: 'github://hpi-swa-teaching/GameMecha:main/src';
	load: 'test'." "more examples and tests"
	
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

Metacello new
	baseline: 'PoppyPrint';
	repository: 'github://tom95/poppy-print/packages';
	load.

Behavior compile: 'prettyPrinterClass ^ PPFormatter' classified: '*hpi-override'.

FileStream
	readOnlyFileNamed: progdir, '/patches/pretty-fix2.cs'
	do: [:stream | stream fileIn].
FileStream
	readOnlyFileNamed: progdir, '/patches/FormatOnSavePreference.cs'
	do: [:stream | stream fileIn].
	do: [:stream | stream fileIn].

"-=-=-=-=-="

"Do update again to update JSON, overwritten prior other projects."
[MCMcmUpdater default doUpdate: false. "non-interactive"]
	on: MCEmptyVersion do: [:warning | warning resume].

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
		^ aKeyboardEvent ignore "hit!!"].
	
	aKeyboardEvent controlKeyPressed ifTrue: [
		aKeyboardEvent keyCharacter caseOf: {
			[Character escape] -> [self world findWindow: aKeyboardEvent].
		} otherwise: [^ aKeyboardEvent "no hit"].
		^ aKeyboardEvent ignore "hit!!"].
	^ aKeyboardEvent "no hit"' classified: '*hpi-override'.

"-=-=-=-=-="
"Lock preinstalled/modified packages in PreferenceWizard, but show them anyway to educate the user about them."
	
FileStream
	readOnlyFileNamed: progdir, '/patches/PreferenceWizardMorph-oneWayCheckboxes.cs'
	do: [:stream | stream fileIn].
	
"-=-=-=-=-="

"(options includes: '-startrack') ifTrue:
	[(Smalltalk at: #Metacello) new
		baseline: 'StarTrack';
		repository: 'github://hpi-swa-lab/learning-liveness/packages';
		load: 'client']."


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

"Load fancy clean Arc UI theme."
Metacello new
	baseline: 'ArcTheme';
	repository: 'github://hpi-swa-lab/sq-arc-theme:main';
    get;
	load.

Utilities setAuthorInitials: String empty.
Smalltalk garbageCollect.

"-=-=-=-=-="
Project current in: [:oldProject | 
	WorldState addDeferredUIMessage: [
		ReleaseBuilder configureProjects.

		Model useColorfulWindows: true.
		SystemWindow roundedWindowCorners: true.
		(UserInterfaceTheme named: 'Arc (light)') applyScaled.
		ReleaseBuilder deleteAllWindows.
		ReleaseBuilder deleteAllOtherMorphs.
		Project current removeMainDockingBar.
		TheWorldMainDockingBar updateInstances.
		[Flaps disableGlobalFlaps] valueSupplyingAnswer: true.

		balloon := Form fromFileNamed: progdir, '/balloon.png'.
		ReleaseBuilder classPool at: #DeferredTask put: [
			DisplayScreen checkForNewScreenScaleFactor; checkForNewScreenSize.
			ReleaseBuilder openWelcomeWorkspacesWith: balloon.
			ObjectlandMorph openObjectlandStarter. ChangesOrganizer noteChangeSetsInRelease.
			PreferenceWizardMorph open.

			(Smalltalk at: #GSGitWorkingCopy) initializeLastImageHash "prevent 'the image is not where it used to be' popup"].
		
		ReleaseBuilder setDisplayExtent: 1024@768.
		Project current world doOneCycle.
		Display platformScaleFactor: nil; platformScaleFactor: 1.0.
		Smalltalk snapshot: true andQuit: true.
	].
	(Smalltalk at: #AnimMorphicProject) new enter: false.
]] ensure: [
	TranscriptStream redirectToStdOut: false.]

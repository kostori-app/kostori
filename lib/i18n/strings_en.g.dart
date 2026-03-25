///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// en: '${a} to add • ${b} to remove • ${c} to move'
	String aToAddBToRemoveCToMove({required Object a, required Object b, required Object c}) => '${a} to add • ${b} to remove • ${c} to move';

	/// en: '${a} to add • ${b} to remove'
	String aToAddBToRemove({required Object a, required Object b}) => '${a} to add • ${b} to remove';

	/// en: '${c} updates'
	String cUpdates({required Object c}) => '${c} updates';

	/// en: 'A new version is available. Do you want to update now?'
	String get aNewVersionIsAvailableDoYouWantToUpdateNow => 'A new version is available. Do you want to update now?';

	/// en: 'APP'
	String get app => 'APP';

	/// en: 'About'
	String get about => 'About';

	/// en: 'Accounts'
	String get accounts => 'Accounts';

	/// en: 'Add a anime source in home page'
	String get addAAnimeSourceInHomePage => 'Add a anime source in home page';

	/// en: 'Add anime source'
	String get addAnimeSource => 'Add anime source';

	/// en: 'Add new favorite to'
	String get addNewFavoriteTo => 'Add new favorite to';

	/// en: 'Add to favorites'
	String get addToFavorites => 'Add to favorites';

	/// en: 'Image Properties'
	String get imageProperties => 'Image Properties';

	/// en: 'File Name'
	String get fileName => 'File Name';

	/// en: 'File Size'
	String get fileSize => 'File Size';

	/// en: 'Modified Time'
	String get modifiedTime => 'Modified Time';

	/// en: 'Path'
	String get path => 'Path';

	/// en: 'Title copied'
	String get titleCopied => 'Title copied';

	/// en: 'Format'
	String get imageFormat => 'Format';

	/// en: 'Confirm delete this image?'
	String get confirmDeleteImage => 'Confirm delete this image?';

	/// en: 'Bangumi Plan'
	String get bangumiPlan => 'Bangumi Plan';

	/// en: 'Switch Favorite User'
	String get switchFavoriteUser => 'Switch Favorite User';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Added ${count} animes to download queue.'
	String addedCountAnimesToDownloadQueue({required Object count}) => 'Added ${count} animes to download queue.';

	/// en: 'Added'
	String get added => 'Added';

	/// en: 'Aggregated Search'
	String get aggregatedSearch => 'Aggregated Search';

	/// en: 'Aggregated'
	String get aggregated => 'Aggregated';

	/// en: 'AI Source'
	String get aiSource => 'AI Source';

	/// en: 'AI'
	String get ai => 'AI';

	/// en: 'Soul Profile'
	String get soulProfile => 'Soul Profile';

	/// en: 'Based on your watch history, analyze your anime personality'
	String get soulProfilerDescription => 'Based on your watch history, analyze your anime personality';

	/// en: 'AI Image Tag'
	String get imageTag => 'AI Image Tag';

	/// en: 'Generate AI painting style tags based on your preferences'
	String get imageTagDescription => 'Generate AI painting style tags based on your preferences';

	/// en: 'AI Chat'
	String get aiChat => 'AI Chat';

	/// en: 'Multi-round conversation with AI with context memory'
	String get aiChatDescription => 'Multi-round conversation with AI with context memory';

	/// en: 'Summary'
	String get summary => 'Summary';

	/// en: 'Auto-generate your anime watch weekly/monthly report'
	String get summaryDescription => 'Auto-generate your anime watch weekly/monthly report';

	/// en: 'Basic Info'
	String get basicInfo => 'Basic Info';

	/// en: 'All Episodes'
	String get allEpisodes => 'All Episodes';

	/// en: 'Related Entries'
	String get relatedEntries => 'Related Entries';

	/// en: 'Also remove files on disk'
	String get alsoRemoveFilesOnDisk => 'Also remove files on disk';

	/// en: 'Anime Source list'
	String get animeSourceList => 'Anime Source list';

	/// en: 'Anime Source'
	String get animeSource => 'Anime Source';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Are you sure you want to clear your history?'
	String get areYouSureYouWantToClearYourHistory => 'Are you sure you want to clear your history?';

	/// en: 'Are you sure you want to clear your progress?'
	String get areYouSureYouWantToClearYourProgress => 'Are you sure you want to clear your progress?';

	/// en: 'Authorization Required'
	String get authorizationRequired => 'Authorization Required';

	/// en: 'Auto Page Turning'
	String get autoPageTurning => 'Auto Page Turning';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Bangumi'
	String get bangumi => 'Bangumi';

	/// en: 'Block'
	String get block => 'Block';

	/// en: 'Blue'
	String get blue => 'Blue';

	/// en: 'Brief'
	String get brief => 'Brief';

	/// en: 'Cache Limit'
	String get cacheLimit => 'Cache Limit';

	/// en: 'Cache Size'
	String get cacheSize => 'Cache Size';

	/// en: 'Cache cleared'
	String get cacheCleared => 'Cache cleared';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Categories'
	String get categories => 'Categories';

	/// en: 'Category Pages'
	String get categoryPages => 'Category Pages';

	/// en: 'Characters'
	String get characters => 'Characters';

	/// en: 'Check for updates on startup'
	String get checkForUpdatesOnStartup => 'Check for updates on startup';

	/// en: 'Check for updates'
	String get checkForUpdates => 'Check for updates';

	/// en: 'Check updates'
	String get checkUpdates => 'Check updates';

	/// en: 'Check'
	String get check => 'Check';

	/// en: 'Clear Cache'
	String get clearCache => 'Clear Cache';

	/// en: 'Clear History'
	String get clearHistory => 'Clear History';

	/// en: 'Clear Progress'
	String get clearProgress => 'Clear Progress';

	/// en: 'Clear Search History'
	String get clearSearchHistory => 'Clear Search History';

	/// en: 'Clear Unfavorited'
	String get clearUnfavorited => 'Clear Unfavorited';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Click if login expired'
	String get clickIfLoginExpired => 'Click if login expired';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Comment'
	String get comment => 'Comment';

	/// en: 'Comments'
	String get comments => 'Comments';

	/// en: 'Confirm'
	String get confirm => 'Confirm';

	/// en: 'Continue'
	String get kContinue => 'Continue';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Analyze'
	String get analyze => 'Analyze';

	/// en: 'Analyzing...'
	String get analyzing => 'Analyzing...';

	/// en: 'Analysis Result'
	String get analysisResult => 'Analysis Result';

	/// en: 'Your Question'
	String get yourQuestion => 'Your Question';

	/// en: 'Please enter a prompt'
	String get pleaseEnterAPrompt => 'Please enter a prompt';

	/// en: 'e.g., What kind of anime do I like?'
	String get egWhatKindOfAnimeDoILike => 'e.g., What kind of anime do I like?';

	/// en: 'AI source not available'
	String get aiSourceNotAvailable => 'AI source not available';

	/// en: 'Copy ID'
	String get copyId => 'Copy ID';

	/// en: 'Copy Title'
	String get copyTitle => 'Copy Title';

	/// en: 'Copy URL'
	String get copyUrl => 'Copy URL';

	/// en: 'Copy to folder'
	String get copyToFolder => 'Copy to folder';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Create Account'
	String get createAccount => 'Create Account';

	/// en: 'Create Folder'
	String get createFolder => 'Create Folder';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Currently seen ${ep}'
	String currentlySeenEp({required Object ep}) => 'Currently seen ${ep}';

	/// en: 'DNS Overrides'
	String get dnsOverrides => 'DNS Overrides';

	/// en: 'Dark'
	String get dark => 'Dark';

	/// en: 'Data Sync'
	String get dataSync => 'Data Sync';

	/// en: 'Data'
	String get data => 'Data';

	/// en: 'Date Desc'
	String get dateDesc => 'Date Desc';

	/// en: 'Date'
	String get date => 'Date';

	/// en: 'Default Search Target'
	String get defaultSearchTarget => 'Default Search Target';

	/// en: 'Delete ${c} animes?'
	String deleteCAnimes({required Object c}) => 'Delete ${c} animes?';

	/// en: 'Delete Anime'
	String get deleteAnime => 'Delete Anime';

	/// en: 'Delete Folder'
	String get deleteFolder => 'Delete Folder';

	/// en: 'Delete anime source '${n}' ?'
	String deleteAnimeSourceN({required Object n}) => 'Delete anime source \'${n}\' ?';

	/// en: 'Delete folder '${f}' ?'
	String deleteFolderF({required Object f}) => 'Delete folder \'${f}\' ?';

	/// en: 'Delete folder?'
	String get deleteFolderPrompt => 'Delete folder?';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Delete Room'
	String get deleteRoom => 'Delete Room';

	/// en: 'Description'
	String get description => 'Description';

	/// en: 'Deselect'
	String get deselect => 'Deselect';

	/// en: 'Detailed'
	String get detailed => 'Detailed';

	/// en: 'Details'
	String get details => 'Details';

	/// en: 'Determine the binding: ${a} ?'
	String determineTheBindingA({required Object a}) => 'Determine the binding: ${a} ?';

	/// en: 'Disable'
	String get disable => 'Disable';

	/// en: 'Disabled'
	String get disabled => 'Disabled';

	/// en: 'Discover the new version ${v}'
	String discoverTheNewVersionV({required Object v}) => 'Discover the new version ${v}';

	/// en: 'Display mode of anime tile'
	String get displayModeOfAnimeTile => 'Display mode of anime tile';

	/// en: 'Display time & battery info in reader'
	String get displayTimeAndBatteryInfoInReader => 'Display time & battery info in reader';

	/// en: 'Do not report any issues related to sources to App repo.'
	String get doNotReportAnyIssuesRelatedToSourcesToAppRepo => 'Do not report any issues related to sources to App repo.';

	/// en: 'Download All'
	String get downloadAll => 'Download All';

	/// en: 'Download Selected'
	String get downloadSelected => 'Download Selected';

	/// en: 'Download Threads'
	String get downloadThreads => 'Download Threads';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Downloading'
	String get downloading => 'Downloading';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Enable DNS Overrides'
	String get enableDnsOverrides => 'Enable DNS Overrides';

	/// en: 'Enable'
	String get enable => 'Enable';

	/// en: 'End'
	String get end => 'End';

	/// en: 'Episode ${ep}'
	String episodeEp({required Object ep}) => 'Episode ${ep}';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Exit Multi-Select'
	String get exitMultiSelect => 'Exit Multi-Select';

	/// en: 'Exit'
	String get exit => 'Exit';

	/// en: 'Explore Pages'
	String get explorePages => 'Explore Pages';

	/// en: 'Explore'
	String get explore => 'Explore';

	/// en: 'Export App Data'
	String get exportAppData => 'Export App Data';

	/// en: 'Export'
	String get export => 'Export';

	/// en: 'Failed to import'
	String get failedToImport => 'Failed to import';

	/// en: 'Fanyuan'
	String get fanyuan => 'Fanyuan';

	/// en: 'Favorite actions'
	String get favoriteActions => 'Favorite actions';

	/// en: 'Favorite'
	String get favorite => 'Favorite';

	/// en: 'Favorites'
	String get favorites => 'Favorites';

	/// en: 'Finished'
	String get finished => 'Finished';

	/// en: 'Folder Name'
	String get folderName => 'Folder Name';

	/// en: 'Folder'
	String get folder => 'Folder';

	/// en: 'Folders'
	String get folders => 'Folders';

	/// en: 'Following'
	String get following => 'Following';

	/// en: 'Full Screen'
	String get fullScreen => 'Full Screen';

	/// en: 'Fullscreen'
	String get fullscreen => 'Fullscreen';

	/// en: 'Git Mirror'
	String get gitMirror => 'Git Mirror';

	/// en: 'Green'
	String get green => 'Green';

	/// en: 'Help'
	String get help => 'Help';

	/// en: 'History'
	String get history => 'History';

	/// en: 'History Source'
	String get historySource => 'History Source';

	/// en: 'Home'
	String get home => 'Home';

	/// en: 'Icon producer'
	String get iconProducer => 'Icon producer';

	/// en: 'Ignore Certificate Errors'
	String get ignoreCertificateErrors => 'Ignore Certificate Errors';

	/// en: 'Import Animes'
	String get importAnimes => 'Import Animes';

	/// en: 'Import App Data'
	String get importAppData => 'Import App Data';

	/// en: 'Import from file'
	String get importFromFile => 'Import from file';

	/// en: 'Import'
	String get import => 'Import';

	/// en: 'Imported ${a} animes'
	String importedAAnimes({required Object a}) => 'Imported ${a} animes';

	/// en: 'Information'
	String get information => 'Information';

	/// en: 'My Rating'
	String get myRating => 'My Rating';

	/// en: 'Initial Page'
	String get initialPage => 'Initial Page';

	/// en: 'Invert Selection'
	String get invertSelection => 'Invert Selection';

	/// en: 'Keyword blocking'
	String get keywordBlocking => 'Keyword blocking';

	/// en: 'Kostori is a free and open-source app for anime watching.'
	String get kostoriIsAFreeAndOpenSourceAppForAnimeWatching => 'Kostori is a free and open-source app for anime watching.';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'Later'
	String get later => 'Later';

	/// en: 'Light'
	String get light => 'Light';

	/// en: 'Limit image width'
	String get limitImageWidth => 'Limit image width';

	/// en: 'Local Favorites'
	String get localFavorites => 'Local Favorites';

	/// en: 'Local'
	String get local => 'Local';

	/// en: 'Log in'
	String get logIn => 'Log in';

	/// en: 'Log out'
	String get logOut => 'Log out';

	/// en: 'Log'
	String get log => 'Log';

	/// en: 'Manual Translation'
	String get manualTranslation => 'Manual Translation';

	/// en: 'Enter text to translate'
	String get enterTextToTranslate => 'Enter text to translate';

	/// en: 'Translate'
	String get translate => 'Translate';

	/// en: 'Translating...'
	String get translating => 'Translating...';

	/// en: 'Translation result'
	String get translationResult => 'Translation result';

	/// en: 'Select Translation Language'
	String get selectTranslationLanguage => 'Select Translation Language';

	/// en: 'Please enter text to translate'
	String get pleaseEnterTextToTranslate => 'Please enter text to translate';

	/// en: 'Login with webview'
	String get loginWithWebview => 'Login with webview';

	/// en: 'Login'
	String get login => 'Login';

	/// en: 'Long press and drag to reorder.'
	String get longPressAndDragToReorder => 'Long press and drag to reorder.';

	/// en: 'Long press on the favorite button to quickly add to this folder'
	String get longPressOnTheFavoriteButtonToQuicklyAddToThisFolder => 'Long press on the favorite button to quickly add to this folder';

	/// en: 'Long press to zoom'
	String get longPressToZoom => 'Long press to zoom';

	/// en: 'Me'
	String get me => 'Me';

	/// en: 'Move To First'
	String get moveToFirst => 'Move To First';

	/// en: 'Move favorite after reading'
	String get moveFavoriteAfterReading => 'Move favorite after reading';

	/// en: 'Move to folder'
	String get moveToFolder => 'Move to folder';

	/// en: 'Move'
	String get move => 'Move';

	/// en: 'Multi-Select'
	String get multiSelect => 'Multi-Select';

	/// en: 'Multiple Animes'
	String get multipleAnimes => 'Multiple Animes';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Network Favorite Pages'
	String get networkFavoritePages => 'Network Favorite Pages';

	/// en: 'Network'
	String get network => 'Network';

	/// en: 'New Folder'
	String get newFolder => 'New Folder';

	/// en: 'New Version'
	String get newVersion => 'New Version';

	/// en: 'New version available'
	String get newVersionAvailable => 'New version available';

	/// en: 'Next'
	String get next => 'Next';

	/// en: 'No Explore Pages'
	String get noExplorePages => 'No Explore Pages';

	/// en: 'No new version available'
	String get noNewVersionAvailable => 'No new version available';

	/// en: 'No search results found'
	String get noSearchResultsFound => 'No search results found';

	/// en: 'No liked anime found'
	String get noLikedAnimeFound => 'No liked anime found';

	/// en: 'No updates'
	String get noUpdates => 'No updates';

	/// en: 'OK'
	String get ok => 'OK';

	/// en: 'Once the operation is successful, app will automatically sync data with the server.'
	String get onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer => 'Once the operation is successful, app will automatically sync data with the server.';

	/// en: 'Open Log'
	String get openLog => 'Open Log';

	/// en: 'Open anime'
	String get openAnime => 'Open anime';

	/// en: 'Open help'
	String get openHelp => 'Open help';

	/// en: 'Open in Browser'
	String get openInBrowser => 'Open in Browser';

	/// en: 'Open link'
	String get openLink => 'Open link';

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Operation'
	String get operation => 'Operation';

	/// en: 'Orange'
	String get orange => 'Orange';

	/// en: 'Order'
	String get order => 'Order';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Paused'
	String get paused => 'Paused';

	/// en: 'Pink'
	String get pink => 'Pink';

	/// en: 'Playlist'
	String get playlist => 'Playlist';

	/// en: 'Please check your settings'
	String get pleaseCheckYourSettings => 'Please check your settings';

	/// en: 'Preview'
	String get preview => 'Preview';

	/// en: 'Proxy'
	String get proxy => 'Proxy';

	/// en: 'Purple'
	String get purple => 'Purple';

	/// en: 'Quick Favorite'
	String get quickFavorite => 'Quick Favorite';

	/// en: 'Ranking'
	String get ranking => 'Ranking';

	/// en: 'Re-login'
	String get reLogin => 'Re-login';

	/// en: 'Read'
	String get read => 'Read';

	/// en: 'Reading'
	String get reading => 'Reading';

	/// en: 'Red'
	String get red => 'Red';

	/// en: 'Refresh'
	String get refresh => 'Refresh';

	/// en: 'Related'
	String get related => 'Related';

	/// en: 'Remove anime from favorite?'
	String get removeAnimeFromFavorite => 'Remove anime from favorite?';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Reorder'
	String get reorder => 'Reorder';

	/// en: 'Reset Bangumi-data'
	String get resetBangumiData => 'Reset Bangumi-data';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Reviews'
	String get reviews => 'Reviews';

	/// en: 'Save Image'
	String get saveImage => 'Save Image';

	/// en: 'Saved Failed'
	String get savedFailed => 'Saved Failed';

	/// en: 'Saved'
	String get saved => 'Saved';

	/// en: 'Search All'
	String get searchAll => 'Search All';

	/// en: 'Search History'
	String get searchHistory => 'Search History';

	/// en: 'Search in'
	String get searchIn => 'Search in';

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'Select All'
	String get selectAll => 'Select All';

	/// en: 'Select a directory which contains the anime files.'
	String get selectADirectoryWhichContainsTheAnimeFiles => 'Select a directory which contains the anime files.';

	/// en: 'Select a folder'
	String get selectAFolder => 'Select a folder';

	/// en: 'Select an image on screen'
	String get selectAnImageOnScreen => 'Select an image on screen';

	/// en: 'Select file'
	String get selectFile => 'Select file';

	/// en: 'Select in range'
	String get selectInRange => 'Select in range';

	/// en: 'Select'
	String get select => 'Select';

	/// en: 'Selected ${a} animes'
	String selectedAAnimes({required Object a}) => 'Selected ${a} animes';

	/// en: 'New Name'
	String get newName => 'New Name';

	/// en: 'Set Cache Limit'
	String get setCacheLimit => 'Set Cache Limit';

	/// en: 'Set New Storage Path'
	String get setNewStoragePath => 'Set New Storage Path';

	/// en: 'Set source list url'
	String get setSourceListUrl => 'Set source list url';

	/// en: 'Set'
	String get set => 'Set';

	/// en: 'Settings'
	String get settings => 'Settings';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Show all'
	String get showAll => 'Show all';

	/// en: 'Show favorite status on anime tile'
	String get showFavoriteStatusOnAnimeTile => 'Show favorite status on anime tile';

	/// en: 'Show history on anime tile'
	String get showHistoryOnAnimeTile => 'Show history on anime tile';

	/// en: 'Single Anime'
	String get singleAnime => 'Single Anime';

	/// en: 'Size in MB'
	String get sizeInMb => 'Size in MB';

	/// en: 'Size of anime tile'
	String get sizeOfAnimeTile => 'Size of anime tile';

	/// en: 'Sort'
	String get sort => 'Sort';

	/// en: 'Source Folder'
	String get sourceFolder => 'Source Folder';

	/// en: 'Source URL'
	String get sourceUrl => 'Source URL';

	/// en: 'StaffList'
	String get staffList => 'StaffList';

	/// en: 'Start'
	String get start => 'Start';

	/// en: 'Storage Path for local animes'
	String get storagePathForLocalAnimes => 'Storage Path for local animes';

	/// en: 'Submit'
	String get submit => 'Submit';

	/// en: 'Suggestions'
	String get suggestions => 'Suggestions';

	/// en: 'Sync Data'
	String get syncData => 'Sync Data';

	/// en: 'Sync'
	String get sync => 'Sync';

	/// en: 'Syncing Data'
	String get syncingData => 'Syncing Data';

	/// en: 'System'
	String get system => 'System';

	/// en: 'Tap to turn Pages'
	String get tapToTurnPages => 'Tap to turn Pages';

	/// en: 'The URL should point to a 'index.json' file'
	String get theUrlShouldPointToAIndexJsonFile => 'The URL should point to a \'index.json\' file';

	/// en: 'The folder is Linked to ${source}'
	String theFolderIsLinkedToSource({required Object source}) => 'The folder is Linked to ${source}';

	/// en: 'Theme Color'
	String get themeColor => 'Theme Color';

	/// en: 'Theme Mode'
	String get themeMode => 'Theme Mode';

	/// en: 'Timetable'
	String get timetable => 'Timetable';

	/// en: 'Topics'
	String get topics => 'Topics';

	/// en: 'TopicsLatest'
	String get topicsLatest => 'TopicsLatest';

	/// en: 'TopicsTrending'
	String get topicsTrending => 'TopicsTrending';

	/// en: 'Turn page by volume keys'
	String get turnPageByVolumeKeys => 'Turn page by volume keys';

	/// en: 'Unselected'
	String get unselected => 'Unselected';

	/// en: 'Update Animes Info'
	String get updateAnimesInfo => 'Update Animes Info';

	/// en: 'Update Time'
	String get updateTime => 'Update Time';

	/// en: 'Update'
	String get update => 'Update';

	/// en: 'Updates Available'
	String get updatesAvailable => 'Updates Available';

	/// en: 'Updating'
	String get updating => 'Updating';

	/// en: 'Upload Time'
	String get uploadTime => 'Upload Time';

	/// en: 'Upload'
	String get upload => 'Upload';

	/// en: 'Uploader'
	String get uploader => 'Uploader';

	/// en: 'Use a config file'
	String get useAConfigFile => 'Use a config file';

	/// en: 'User'
	String get user => 'User';

	/// en: 'Username'
	String get username => 'Username';

	/// en: 'User Profile Analysis'
	String get userProfileAnalysis => 'User Profile Analysis';

	/// en: 'View list'
	String get viewList => 'View list';

	/// en: 'View more'
	String get viewMore => 'View more';

	/// en: 'View'
	String get view => 'View';

	/// en: 'WebDAV Auto Sync'
	String get webDavAutoSync => 'WebDAV Auto Sync';

	/// en: 'default'
	String get kDefault => 'default';

	/// en: 'lastWatchTime ${time}'
	String lastWatchTimeTime({required Object time}) => 'lastWatchTime ${time}';

	/// en: 'minAppVersion ${version} is required'
	String minAppVersionRequired({required Object version}) => 'minAppVersion ${version} is required';

	/// en: 'more'
	String get more => 'more';

	/// en: 'Not Yet Airing'
	String get notYetAiring => 'Not Yet Airing';

	/// en: 'Full ${b} episodes released'
	String fullBEpisodesReleased({required Object b}) => 'Full ${b} episodes released';

	/// en: 'Up to ep ${s} • Total ${t} eps planned'
	String upToEpSTotalEpsPlanned({required Object s, required Object t}) => 'Up to ep ${s} • Total ${t} eps planned';

	/// en: 'Up to ep ${e} (${s}) • Total ${t} eps planned'
	String upToEpETotalEpsPlanned({required Object e, required Object s, required Object t}) => 'Up to ep ${e} (${s}) • Total ${t} eps planned';

	/// en: '${t} reviews | #${r}'
	String tReviewsR({required Object t, required Object r}) => '${t} reviews | #${r}';

	/// en: '${t} reviews'
	String tReviews({required Object t}) => '${t} reviews';

	/// en: 'Show more +'
	String get showMore => 'Show more +';

	/// en: 'Show less -'
	String get showLess => 'Show less -';

	/// en: 'Tags'
	String get tags => 'Tags';

	/// en: 'Clear Tags'
	String get clearTags => 'Clear Tags';

	/// en: 'Showing ${l} results'
	String showingLResults({required Object l}) => 'Showing ${l} results';

	/// en: 'Select Time'
	String get selectTime => 'Select Time';

	/// en: 'Switch Layout'
	String get switchLayout => 'Switch Layout';

	/// en: 'Enter keywords...'
	String get enterKeywords => 'Enter keywords...';

	/// en: 'Rating Chart'
	String get ratingChart => 'Rating Chart';

	/// en: 'Line Chart'
	String get lineChart => 'Line Chart';

	/// en: 'Bar Chart'
	String get barChart => 'Bar Chart';

	/// en: 'Standard Deviation: ${s}'
	String standardDeviationS({required Object s}) => 'Standard Deviation: ${s}';

	/// en: 'Nobody's posted anything yet...'
	String get nobodysPostedAnythingYet => 'Nobody\'s posted anything yet...';

	/// en: 'Reload'
	String get reload => 'Reload';

	/// en: 'Main Content'
	String get mainContent => 'Main Content';

	/// en: 'Switch'
	String get switchh => 'Switch';

	/// en: 'Failed to load, please try again.'
	String get failedToLoadPleaseTryAgain => 'Failed to load, please try again.';

	/// en: 'doing'
	String get doing => 'doing';

	/// en: 'collect'
	String get collect => 'collect';

	/// en: 'wish'
	String get wish => 'wish';

	/// en: 'on hold'
	String get onHold => 'on hold';

	/// en: 'dropped'
	String get dropped => 'dropped';

	/// en: 'Today Recommendation'
	String get todayRecommendation => 'Today Recommendation';

	/// en: '${t} Total count'
	String tTotalCount({required Object t}) => '${t} Total count';

	/// en: 'Introduction'
	String get introduction => 'Introduction';

	/// en: 'Latest Comments'
	String get latestComments => 'Latest Comments';

	/// en: 'Linked Items'
	String get linkedItems => 'Linked Items';

	/// en: 'Time: ${s}'
	String timeS({required Object s}) => 'Time: ${s}';

	/// en: 'Broadcast Time: ${a}'
	String broadcastTimeA({required Object a}) => 'Broadcast Time: ${a}';

	/// en: 'Profile Information'
	String get profileInformation => 'Profile Information';

	/// en: 'Character Introduction'
	String get characterIntroduction => 'Character Introduction';

	/// en: 'Voice Actor: ${c}'
	String voiceActorC({required Object c}) => 'Voice Actor: ${c}';

	/// en: 'Episode ${e}: ${n}'
	String episodeEN({required Object e, required Object n}) => 'Episode ${e}: ${n}';

	/// en: 'hotspot'
	String get hotspot => 'hotspot';

	/// en: 'Completed'
	String get completed => 'Completed';

	/// en: 'Main character'
	String get mainCharacter => 'Main character';

	/// en: 'Supporting character'
	String get supportingCharacter => 'Supporting character';

	/// en: 'Cameo'
	String get cameo => 'Cameo';

	/// en: 'Idle corner'
	String get idleCorner => 'Idle corner';

	/// en: 'Unknown'
	String get unknown => 'Unknown';

	/// en: 'Debug Info'
	String get debugInfo => 'Debug Info';

	/// en: 'Install'
	String get install => 'Install';

	/// en: 'View on GitHub'
	String get viewOnGithub => 'View on GitHub';

	/// en: 'No Proxy Overrides'
	String get noProxyOverrides => 'No Proxy Overrides';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Mirror'
	String get mirror => 'Mirror';

	/// en: 'Result'
	String get result => 'Result';

	/// en: 'All'
	String get all => 'All';

	/// en: 'Reload Configs'
	String get reloadConfigs => 'Reload Configs';

	/// en: 'Invalid url config'
	String get invalidUrlConfig => 'Invalid url config';

	/// en: 'Inconsistent versions'
	String get inconsistentVersions => 'Inconsistent versions';

	/// en: 'No update available for this architecture (${a})'
	String noUpdateAvailableForThisArchitectureA({required Object a}) => 'No update available for this architecture (${a})';

	/// en: 'Check update failed...'
	String get checkUpdateFailed => 'Check update failed...';

	/// en: 'Download failed'
	String get downloadFailed => 'Download failed';

	/// en: 'Failed to check the hash value. Please try again'
	String get failedToCheckTheHashValuePleaseTryAgain => 'Failed to check the hash value. Please try again';

	/// en: 'English'
	String get english => 'English';

	/// en: 'Dynamic color'
	String get dynamicColor => 'Dynamic color';

	/// en: 'Monday Schedule'
	String get mondaySchedule => 'Monday Schedule';

	/// en: 'Tuesday Schedule'
	String get tuesdaySchedule => 'Tuesday Schedule';

	/// en: 'Wednesday Schedule'
	String get wednesdaySchedule => 'Wednesday Schedule';

	/// en: 'Thursday Schedule'
	String get thursdaySchedule => 'Thursday Schedule';

	/// en: 'Friday Schedule'
	String get fridaySchedule => 'Friday Schedule';

	/// en: 'Saturday Schedule'
	String get saturdaySchedule => 'Saturday Schedule';

	/// en: 'Sunday Schedule'
	String get sundaySchedule => 'Sunday Schedule';

	/// en: 'Popularity Ranking'
	String get popularityRanking => 'Popularity Ranking';

	/// en: 'Image Operations'
	String get imageOperations => 'Image Operations';

	/// en: 'Save to Album'
	String get saveToAlbum => 'Save to Album';

	/// en: 'Stitch Long Image'
	String get stitchLongImage => 'Stitch Long Image';

	/// en: 'Stitch Horizontal Image'
	String get stitchHorizontalImage => 'Stitch Horizontal Image';

	/// en: 'Stitch Subtitles'
	String get stitchSubtitles => 'Stitch Subtitles';

	/// en: 'Save Long Image'
	String get saveLongImage => 'Save Long Image';

	/// en: 'Border Color'
	String get borderColor => 'Border Color';

	/// en: 'Conversation Title'
	String get conversationTitle => 'Conversation Title';

	/// en: 'AI Conversation'
	String get aiConversation => 'AI Conversation';

	/// en: 'Topic List'
	String get topicList => 'Topic List';

	/// en: 'Start a conversation with AI'
	String get startConversationWithAI => 'Start a conversation with AI';

	/// en: 'New Conversation'
	String get newConversation => 'New Conversation';

	/// en: 'Input message...'
	String get inputMessage => 'Input message...';

	/// en: 'No topics yet'
	String get noTopicsYet => 'No topics yet';

	/// en: 'Select AI Personality'
	String get selectAiPersonality => 'Select AI Personality';

	/// en: 'Apply'
	String get apply => 'Apply';

	/// en: 'Height(px)'
	String get heightPx => 'Height(px)';

	/// en: 'Set Uniform Height'
	String get setUniformHeight => 'Set Uniform Height';

	/// en: 'Uniform Height'
	String get uniformHeight => 'Uniform Height';

	/// en: 'Crop Image'
	String get cropImage => 'Crop Image';

	/// en: 'Finish Cropping'
	String get finishCropping => 'Finish Cropping';

	/// en: 'Sort Images'
	String get sortImages => 'Sort Images';

	/// en: 'Finish Sorting'
	String get finishSorting => 'Finish Sorting';

	/// en: 'No Images'
	String get noImages => 'No Images';

	/// en: 'Crop Height: ${c} px'
	String cropHeightCPx({required Object c}) => 'Crop Height: ${c} px';

	/// en: 'Enter hex color code, e.g. #FF000000'
	String get enterHexColorCode => 'Enter hex color code, e.g. #FF000000';

	/// en: 'Show Image Borders'
	String get showImageBorders => 'Show Image Borders';

	/// en: 'Outer Border Radius'
	String get outerBorderRadius => 'Outer Border Radius';

	/// en: 'Outer Border Width'
	String get outerBorderWidth => 'Outer Border Width';

	/// en: 'Outer Border Color'
	String get outerBorderColor => 'Outer Border Color';

	/// en: 'Show Outer Border'
	String get showOuterBorder => 'Show Outer Border';

	/// en: 'Inner Border Width'
	String get innerBorderWidth => 'Inner Border Width';

	/// en: 'Inner Border Color'
	String get innerBorderColor => 'Inner Border Color';

	/// en: 'Border Settings'
	String get borderSettings => 'Border Settings';

	/// en: 'Saving'
	String get saving => 'Saving';

	/// en: 'Save Successful'
	String get saveSuccessful => 'Save Successful';

	/// en: 'Save Failed: ${e}'
	String saveFailedE({required Object e}) => 'Save Failed: ${e}';

	/// en: 'Failed to load images or no images'
	String get failedToLoadImagesOrNoImages => 'Failed to load images or no images';

	/// en: 'Failed to pick image'
	String get failedToPickImage => 'Failed to pick image';

	/// en: 'Monday'
	String get monday => 'Monday';

	/// en: 'Tuesday'
	String get tuesday => 'Tuesday';

	/// en: 'Wednesday'
	String get wednesday => 'Wednesday';

	/// en: 'Thursday'
	String get thursday => 'Thursday';

	/// en: 'Friday'
	String get friday => 'Friday';

	/// en: 'Saturday'
	String get saturday => 'Saturday';

	/// en: 'Sunday'
	String get sunday => 'Sunday';

	/// en: 'Default Order'
	String get defaultOrder => 'Default Order';

	/// en: 'By Time'
	String get byTime => 'By Time';

	/// en: 'By Name'
	String get byName => 'By Name';

	/// en: 'Recently Watched'
	String get recentlyWatched => 'Recently Watched';

	/// en: 'Local Favorite Binding'
	String get localFavoriteBinding => 'Local Favorite Binding';

	/// en: 'Awful'
	String get awful => 'Awful';

	/// en: 'Terrible'
	String get terrible => 'Terrible';

	/// en: 'Bad'
	String get bad => 'Bad';

	/// en: 'Poor'
	String get poor => 'Poor';

	/// en: 'Okay'
	String get okay => 'Okay';

	/// en: 'Fine'
	String get fine => 'Fine';

	/// en: 'Good'
	String get good => 'Good';

	/// en: 'Great'
	String get great => 'Great';

	/// en: 'Master'
	String get master => 'Master';

	/// en: 'Epic'
	String get epic => 'Epic';

	/// en: 'Overview'
	String get overview => 'Overview';

	/// en: 'Discussion'
	String get discussion => 'Discussion';

	/// en: 'Logs'
	String get logs => 'Logs';

	/// en: 'Player Details'
	String get playerDetails => 'Player Details';

	/// en: 'Status'
	String get status => 'Status';

	/// en: 'Audio Option: Low Latency'
	String get audioOptionLowLatency => 'Audio Option: \n Low Latency';

	/// en: 'Audio Option: Compatibility'
	String get audioOptionCompatibility => 'Audio Option: \n Compatibility';

	/// en: 'Switch Successful'
	String get switchSuccessful => 'Switch Successful';

	/// en: 'Switch Failed'
	String get switchFailed => 'Switch Failed';

	/// en: 'Remote Cast'
	String get remoteCast => 'Remote Cast';

	/// en: 'Copy link'
	String get copyLink => 'Copy link';

	/// en: 'A valid WebDav directory URL'
	String get aValidWebDavDirectoryUrl => 'A valid WebDav directory URL';

	/// en: 'Auto Sync Data'
	String get autoSyncData => 'Auto Sync Data';

	/// en: 'Screenshot Share'
	String get screenshotShare => 'Screenshot Share';

	/// en: 'Best Match'
	String get bestMatch => 'Best Match';

	/// en: 'Top Rank'
	String get topRank => 'Top Rank';

	/// en: 'Most Favorited'
	String get mostFavorited => 'Most Favorited';

	/// en: 'Highest Rating'
	String get highestRating => 'Highest Rating';

	/// en: 'Select Color'
	String get selectColor => 'Select Color';

	/// en: 'Color Wheel'
	String get colorWheel => 'Color Wheel';

	/// en: 'Primary'
	String get primary => 'Primary';

	/// en: 'Accent'
	String get accent => 'Accent';

	/// en: 'Custom'
	String get custom => 'Custom';

	/// en: 'Confirm (${c})'
	String confirmC({required Object c}) => 'Confirm (${c})';

	/// en: 'Select ${c}'
	String selectC({required Object c}) => 'Select ${c}';

	/// en: 'Select Date'
	String get selectDate => 'Select Date';

	/// en: 'Start Date'
	String get startDate => 'Start Date';

	/// en: 'End Date'
	String get endDate => 'End Date';

	/// en: 'Clear Date'
	String get clearDate => 'Clear Date';

	/// en: 'Please select a date'
	String get pleaseSelectADate => 'Please select a date';

	/// en: 'End date cannot be earlier than start date'
	String get endDateCannotBeEarlierThanStartDate => 'End date cannot be earlier than start date';

	/// en: 'Type'
	String get type => 'Type';

	/// en: 'Background'
	String get background => 'Background';

	/// en: 'Emotion'
	String get emotion => 'Emotion';

	/// en: 'Source'
	String get source => 'Source';

	/// en: 'Audience'
	String get audience => 'Audience';

	/// en: 'Category'
	String get category => 'Category';

	/// en: 'Image Operations (${i})'
	String imageOperationsI({required Object i}) => 'Image Operations (${i})';

	/// en: '${s} selected'
	String sSelected({required Object s}) => '${s} selected';

	/// en: 'Simplified Chinese'
	String get simplifiedChinese => 'Simplified Chinese';

	/// en: 'Traditional Chinese'
	String get traditionalChinese => 'Traditional Chinese';

	/// en: 'Teal'
	String get teal => 'Teal';

	/// en: 'Deep Purple'
	String get deepPurple => 'Deep Purple';

	/// en: 'Yellow'
	String get yellow => 'Yellow';

	/// en: 'Cyan'
	String get cyan => 'Cyan';

	/// en: 'M3 Default'
	String get m3Default => 'M3 Default';

	/// en: 'Deep Orange'
	String get deepOrange => 'Deep Orange';

	/// en: 'Indigo'
	String get indigo => 'Indigo';

	/// en: 'Cloudy Blue'
	String get cloudyBlue => 'Cloudy Blue';

	/// en: 'Dark Pastel Green'
	String get darkPastelGreen => 'Dark Pastel Green';

	/// en: 'Dust'
	String get dust => 'Dust';

	/// en: 'Electric Lime'
	String get electricLime => 'Electric Lime';

	/// en: 'Fresh Green'
	String get freshGreen => 'Fresh Green';

	/// en: 'Light Eggplant'
	String get lightEggplant => 'Light Eggplant';

	/// en: 'Nasty Green'
	String get nastyGreen => 'Nasty Green';

	/// en: 'Really Light Blue'
	String get reallyLightBlue => 'Really Light Blue';

	/// en: 'Tea'
	String get tea => 'Tea';

	/// en: 'Warm Purple'
	String get warmPurple => 'Warm Purple';

	/// en: 'Yellowish Tan'
	String get yellowishTan => 'Yellowish Tan';

	/// en: 'Cement'
	String get cement => 'Cement';

	/// en: 'Dark Grass Green'
	String get darkGrassGreen => 'Dark Grass Green';

	/// en: 'Dusty Teal'
	String get dustyTeal => 'Dusty Teal';

	/// en: 'Grey Teal'
	String get greyTeal => 'Grey Teal';

	/// en: 'Macaroni And Cheese'
	String get macaroniAndCheese => 'Macaroni And Cheese';

	/// en: 'Pinkish Tan'
	String get pinkishTan => 'Pinkish Tan';

	/// en: 'Spruce'
	String get spruce => 'Spruce';

	/// en: 'Strong Blue'
	String get strongBlue => 'Strong Blue';

	/// en: 'Toxic Green'
	String get toxicGreen => 'Toxic Green';

	/// en: 'Windows Blue'
	String get windowsBlue => 'Windows Blue';

	/// en: 'Blue Blue'
	String get blueBlue => 'Blue Blue';

	/// en: 'Blue With A Hint Of Purple'
	String get blueWithAHintOfPurple => 'Blue With A Hint Of Purple';

	/// en: 'Booger'
	String get booger => 'Booger';

	/// en: 'Bright Sea Green'
	String get brightSeaGreen => 'Bright Sea Green';

	/// en: 'Green Teal'
	String get greenTeal => 'Green Teal';

	/// en: 'Brownish'
	String get brownish => 'Brownish';

	/// en: 'Off Green'
	String get offGreen => 'Off Green';

	/// en: 'Tangerine'
	String get tangerine => 'Tangerine';

	/// en: 'Ugly Green'
	String get uglyGreen => 'Ugly Green';

	/// en: 'Secondary'
	String get secondary => 'Secondary';

	/// en: 'Tertiary'
	String get tertiary => 'Tertiary';

	/// en: 'Surface'
	String get surface => 'Surface';

	/// en: 'Jump to page'
	String get jumpToPage => 'Jump to page';

	/// en: 'Page'
	String get page => 'Page';

	/// en: 'Page ${p} / ${m}'
	String pagePM({required Object p, required Object m}) => 'Page ${p} / ${m}';

	/// en: 'First'
	String get first => 'First';

	/// en: 'Last'
	String get last => 'Last';

	/// en: 'Disable Length Limitation'
	String get disableLengthLimitation => 'Disable Length Limitation';

	/// en: 'Update log'
	String get updateLog => 'Update log';

	/// en: 'Liked'
	String get liked => 'Liked';

	/// en: 'Rating'
	String get rating => 'Rating';

	/// en: 'Pixel Format'
	String get pixelFormat => 'Pixel Format';

	/// en: 'HW Pixel Format'
	String get hwPixelFormat => 'HW Pixel Format';

	/// en: 'Resolution'
	String get resolution => 'Resolution';

	/// en: 'Display Width'
	String get displayWidth => 'Display Width';

	/// en: 'Display Height'
	String get displayHeight => 'Display Height';

	/// en: 'Aspect'
	String get aspect => 'Aspect';

	/// en: 'Pixel Aspect Ratio'
	String get pixelAspectRatio => 'Pixel Aspect Ratio';

	/// en: 'Colormatrix'
	String get colormatrix => 'Colormatrix';

	/// en: 'Color Levels'
	String get colorLevels => 'Color Levels';

	/// en: 'Primaries'
	String get primaries => 'Primaries';

	/// en: 'Gamma'
	String get gamma => 'Gamma';

	/// en: 'Signal Peak'
	String get signalPeak => 'Signal Peak';

	/// en: 'Lights'
	String get lights => 'Lights';

	/// en: 'Chroma Location'
	String get chromaLocation => 'Chroma Location';

	/// en: 'Rotate'
	String get rotate => 'Rotate';

	/// en: 'Stereo In'
	String get stereoIn => 'Stereo In';

	/// en: 'Average Bpp'
	String get averageBpp => 'Average Bpp';

	/// en: 'Alpha'
	String get alpha => 'Alpha';

	/// en: 'Track ID'
	String get trackId => 'Track ID';

	/// en: 'Track Title'
	String get trackTitle => 'Track Title';

	/// en: 'Track Language'
	String get trackLanguage => 'Track Language';

	/// en: 'Track Image'
	String get trackImage => 'Track Image';

	/// en: 'Track Album Art'
	String get trackAlbumArt => 'Track Album Art';

	/// en: 'Track Codec'
	String get trackCodec => 'Track Codec';

	/// en: 'Track Decoder'
	String get trackDecoder => 'Track Decoder';

	/// en: 'Track Width'
	String get trackWidth => 'Track Width';

	/// en: 'Track Height'
	String get trackHeight => 'Track Height';

	/// en: 'Track Channels Count'
	String get trackChannelsCount => 'Track Channels Count';

	/// en: 'Track Channels'
	String get trackChannels => 'Track Channels';

	/// en: 'Track Sample Rate'
	String get trackSampleRate => 'Track Sample Rate';

	/// en: 'Track FPS'
	String get trackFps => 'Track FPS';

	/// en: 'Track Bitrate'
	String get trackBitrate => 'Track Bitrate';

	/// en: 'Track Rotate'
	String get trackRotate => 'Track Rotate';

	/// en: 'Track PAR'
	String get trackPar => 'Track PAR';

	/// en: 'Track Audio Channels'
	String get trackAudioChannels => 'Track Audio Channels';

	/// en: 'Format'
	String get format => 'Format';

	/// en: 'Sample Rate'
	String get sampleRate => 'Sample Rate';

	/// en: 'Channel Count'
	String get channelCount => 'Channel Count';

	/// en: 'HR Channels'
	String get hrChannels => 'HR Channels';

	/// en: 'URI Track'
	String get uriTrack => 'URI Track';

	/// en: 'Channels Count'
	String get channelsCount => 'Channels Count';

	/// en: 'Channels'
	String get channels => 'Channels';

	/// en: 'FPS'
	String get fps => 'FPS';

	/// en: 'Bitrate'
	String get bitrate => 'Bitrate';

	/// en: 'PAR'
	String get par => 'PAR';

	/// en: 'Audio Channels'
	String get audioChannels => 'Audio Channels';

	/// en: 'AudioBitrate'
	String get audioBitrate => 'AudioBitrate';

	/// en: 'Audio'
	String get audio => 'Audio';

	/// en: 'Video'
	String get video => 'Video';

	/// en: 'Media'
	String get media => 'Media';

	/// en: 'No logs for ${l}'
	String noLogsForL({required Object l}) => 'No logs for ${l}';

	/// en: 'Only valid for this run'
	String get onlyValidForThisRun => 'Only valid for this run';

	/// en: 'name'
	String get nameField => 'name';

	/// en: 'brand'
	String get brandField => 'brand';

	/// en: 'model'
	String get modelField => 'model';

	/// en: 'device'
	String get deviceField => 'device';

	/// en: 'product'
	String get productField => 'product';

	/// en: 'manufacturer'
	String get manufacturerField => 'manufacturer';

	/// en: 'version_release'
	String get versionReleaseField => 'version_release';

	/// en: 'version_sdkInt'
	String get versionSdkIntField => 'version_sdkInt';

	/// en: 'display'
	String get displayField => 'display';

	/// en: 'hardware'
	String get hardwareField => 'hardware';

	/// en: 'physicalRamSize'
	String get physicalRamSizeField => 'physicalRamSize';

	/// en: 'availableRamSize'
	String get availableRamSizeField => 'availableRamSize';

	/// en: 'freeDiskSize'
	String get freeDiskSizeField => 'freeDiskSize';

	/// en: 'totalDiskSize'
	String get totalDiskSizeField => 'totalDiskSize';

	/// en: 'isPhysicalDevice'
	String get isPhysicalDeviceField => 'isPhysicalDevice';

	/// en: 'systemName'
	String get systemNameField => 'systemName';

	/// en: 'systemVersion'
	String get systemVersionField => 'systemVersion';

	/// en: 'modelName'
	String get modelNameField => 'modelName';

	/// en: 'identifierForVendor'
	String get identifierForVendorField => 'identifierForVendor';

	/// en: 'sysname'
	String get sysnameField => 'sysname';

	/// en: 'nodename'
	String get nodenameField => 'nodename';

	/// en: 'release'
	String get releaseField => 'release';

	/// en: 'version'
	String get versionField => 'version';

	/// en: 'machine'
	String get machineField => 'machine';

	/// en: 'computerName'
	String get computerNameField => 'computerName';

	/// en: 'numberOfCores'
	String get numberOfCoresField => 'numberOfCores';

	/// en: 'systemMemoryInMegabytes'
	String get systemMemoryInMegabytesField => 'systemMemoryInMegabytes';

	/// en: 'userName'
	String get userNameField => 'userName';

	/// en: 'majorVersion'
	String get majorVersionField => 'majorVersion';

	/// en: 'minorVersion'
	String get minorVersionField => 'minorVersion';

	/// en: 'buildNumber'
	String get buildNumberField => 'buildNumber';

	/// en: 'displayVersion'
	String get displayVersionField => 'displayVersion';

	/// en: 'productName'
	String get productNameField => 'productName';

	/// en: 'registeredOwner'
	String get registeredOwnerField => 'registeredOwner';

	/// en: 'releaseId'
	String get releaseIdField => 'releaseId';

	/// en: 'packageName'
	String get packageNameField => 'packageName';

	/// en: 'appName'
	String get appNameField => 'appName';

	/// en: 'buildSignature'
	String get buildSignatureField => 'buildSignature';

	/// en: 'installerStore'
	String get installerStoreField => 'installerStore';

	/// en: 'installTime'
	String get installTimeField => 'installTime';

	/// en: 'updateTime'
	String get updateTimeField => 'updateTime';

	/// en: 'January'
	String get january => 'January';

	/// en: 'February'
	String get february => 'February';

	/// en: 'March'
	String get march => 'March';

	/// en: 'April'
	String get april => 'April';

	/// en: 'May'
	String get may => 'May';

	/// en: 'June'
	String get june => 'June';

	/// en: 'July'
	String get july => 'July';

	/// en: 'August'
	String get august => 'August';

	/// en: 'September'
	String get september => 'September';

	/// en: 'October'
	String get october => 'October';

	/// en: 'November'
	String get november => 'November';

	/// en: 'December'
	String get december => 'December';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'Last 3 Days'
	String get last3Days => 'Last 3 Days';

	/// en: 'Last 7 Days'
	String get last7Days => 'Last 7 Days';

	/// en: 'Last 30 Days'
	String get last30Days => 'Last 30 Days';

	/// en: 'Last 3 Months'
	String get last3Months => 'Last 3 Months';

	/// en: 'Last 6 Months'
	String get last6Months => 'Last 6 Months';

	/// en: 'This Year'
	String get thisYear => 'This Year';

	/// en: 'Older'
	String get older => 'Older';

	/// en: 'Mark the selected favorites as'
	String get markTheSelectedFavoritesAs => 'Mark the selected favorites as';

	/// en: 'Favorite Type'
	String get favoriteType => 'Favorite Type';

	/// en: 'Doing'
	String get doingStatus => 'Doing';

	/// en: 'Wish'
	String get wishStatus => 'Wish';

	/// en: 'Collect'
	String get collectStatus => 'Collect';

	/// en: 'On Hold'
	String get onHoldStatus => 'On Hold';

	/// en: 'Dropped'
	String get droppedStatus => 'Dropped';

	/// en: 'Player'
	String get player => 'Player';

	/// en: 'Audio Option'
	String get audioOption => 'Audio Option';

	/// en: 'Hardware Decoding'
	String get hardwareDecoding => 'Hardware Decoding';

	/// en: 'Hardware decoder'
	String get hardwareDecoder => 'Hardware decoder';

	/// en: 'Video renderer'
	String get videoRenderer => 'Video renderer';

	/// en: 'Video synchronization mode'
	String get videoSynchronizationMode => 'Video synchronization mode';

	/// en: 'Enable No Proxy Overrides'
	String get enableNoProxyOverrides => 'Enable No Proxy Overrides';

	/// en: 'Actor'
	String get actor => 'Actor';

	/// en: 'Dub'
	String get dub => 'Dub';

	/// en: 'Chinese Dub'
	String get chineseDub => 'Chinese Dub';

	/// en: 'Japanese Dub'
	String get japaneseDub => 'Japanese Dub';

	/// en: 'English Dub'
	String get englishDub => 'English Dub';

	/// en: 'Korean Dub'
	String get koreanDub => 'Korean Dub';

	/// en: 'Selected ${a} character'
	String selectedACharacter({required Object a}) => 'Selected ${a} character';

	/// en: 'Search Options'
	String get searchOptions => 'Search Options';

	/// en: 'Search Sources'
	String get searchSources => 'Search Sources';

	/// en: 'Translation'
	String get translation => 'Translation';

	/// en: 'Translation Service'
	String get translationService => 'Translation Service';

	/// en: 'API key cannot be empty'
	String get apiKeyCannotBeEmpty => 'API key cannot be empty';

	/// en: 'Please configure API key in AI settings first'
	String get pleaseConfigureApiKeyInAiSettingsFirst => 'Please configure API key in AI settings first';

	/// en: 'Usage'
	String get usage => 'Usage';

	/// en: 'Editing'
	String get editing => 'Editing';

	/// en: 'Screenshot in progress...'
	String get screenshotInProgress => 'Screenshot in progress...';

	/// en: 'Move operation, target unknown'
	String get moveOperationTargetUnknown => 'Move operation, target unknown';

	/// en: 'Operation unknown'
	String get operationUnknown => 'Operation unknown';

	/// en: 'Please enter translation prompt, use ${a} as the placeholder for the target language'
	String pleaseEnterTranslationPrompt({required Object a}) => 'Please enter translation prompt, use ${a} as the placeholder for the target language';

	/// en: 'The prompt must contain ${a} as the placeholder for the target language'
	String thePromptMustContainAPlaceholderForTarget({required Object a}) => 'The prompt must contain ${a} as the placeholder for the target language';

	/// en: 'This field cannot be empty'
	String get thisFieldCannotBeEmpty => 'This field cannot be empty';

	/// en: 'The prompt must contain ${a} placeholder'
	String thePromptMustContainAPlaceholder({required Object a}) => 'The prompt must contain ${a} placeholder';

	/// en: 'Translation Prompt'
	String get translationPrompt => 'Translation Prompt';

	/// en: 'Model Name'
	String get modelName => 'Model Name';

	/// en: 'Api Configuration'
	String get apiConfiguration => 'Api Configuration';

	/// en: 'Word Cloud'
	String get wordCloud => 'Word Cloud';

	/// en: 'Stats Calendar'
	String get statsCalendar => 'Stats Calendar';

	/// en: 'Today's Records'
	String get todaysRecords => 'Today\'s Records';

	/// en: 'Daily Stats'
	String get dailyStats => 'Daily Stats';

	/// en: 'View All'
	String get viewAll => 'View All';

	/// en: 'Kostori Changelog'
	String get kostoriChangelog => 'Kostori Changelog';

	/// en: 'Copy Path'
	String get copyPath => 'Copy Path';

	/// en: 'Properties'
	String get properties => 'Properties';

	/// en: 'No endpoint'
	String get noEndpoint => 'No endpoint';

	/// en: 'Test All'
	String get testAll => 'Test All';

	/// en: 'Custom Endpoint'
	String get customEndpoint => 'Custom Endpoint';

	/// en: 'Ping Test'
	String get pingTest => 'Ping Test';

	/// en: 'Continuous Ping'
	String get continuousPing => 'Continuous Ping';

	/// en: 'Service'
	String get service => 'Service';

	/// en: 'Service Settings'
	String get serviceSettings => 'Service Settings';

	/// en: 'Enable Service'
	String get enableService => 'Enable Service';

	/// en: 'Service is stopped'
	String get serviceIsStopped => 'Service is stopped';

	/// en: 'Running on ${h}'
	String runningOnH({required Object h}) => 'Running on ${h}';

	/// en: 'API Key'
	String get apiKey => 'API Key';

	/// en: 'Active Key'
	String get activeKey => 'Active Key';

	/// en: 'Using fixed key'
	String get usingFixedKey => 'Using fixed key';

	/// en: 'Using random key (regenerated on startup)'
	String get usingRandomKeyRegeneratedOnStartup => 'Using random key (regenerated on startup)';

	/// en: 'Use Fixed Key'
	String get useFixedKey => 'Use Fixed Key';

	/// en: 'Keep the same key after restart'
	String get keepTheSameKeyAfterRestart => 'Keep the same key after restart';

	/// en: 'Fixed Key'
	String get fixedKey => 'Fixed Key';

	/// en: 'Leave empty to auto-generate'
	String get leaveEmptyToAutoGenerate => 'Leave empty to auto-generate';

	/// en: 'Enter fixed key'
	String get enterFixedKey => 'Enter fixed key';

	/// en: 'Regenerate Random Key'
	String get regenerateRandomKey => 'Regenerate Random Key';

	/// en: 'Generate a new random key immediately'
	String get generateANewRandomKeyImmediately => 'Generate a new random key immediately';

	/// en: 'Regenerate'
	String get regenerate => 'Regenerate';

	/// en: 'Port'
	String get port => 'Port';

	/// en: 'Default: ${p}'
	String defaultP({required Object p}) => 'Default: ${p}';

	/// en: 'Bind Mode'
	String get bindMode => 'Bind Mode';

	/// en: 'Choose IP version to listen on'
	String get chooseIpVersionToListenOn => 'Choose IP version to listen on';

	/// en: 'Hub Server'
	String get hubServer => 'Hub Server';

	/// en: 'Enable Hub'
	String get enableHub => 'Enable Hub';

	/// en: 'Hub server is stopped'
	String get hubServerIsStopped => 'Hub server is stopped';

	/// en: 'clients'
	String get clientsCount => 'clients';

	/// en: 'Hub Port'
	String get hubPort => 'Hub Port';

	/// en: 'Online Clients'
	String get onlineClients => 'Online Clients';

	/// en: 'Connected at'
	String get connectedAt => 'Connected at';

	/// en: 'Message History'
	String get messageHistory => 'Message History';

	/// en: 'Hub Client'
	String get hubClient => 'Hub Client';

	/// en: 'Connect to Hub'
	String get connectToHub => 'Connect to Hub';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'Not connected'
	String get notConnected => 'Not connected';

	/// en: 'Hub Address'
	String get hubAddress => 'Hub Address';

	/// en: 'Client Name'
	String get clientName => 'Client Name';

	/// en: 'Display name in hub'
	String get displayNameInHub => 'Display name in hub';

	/// en: 'My Device'
	String get myDevice => 'My Device';

	/// en: 'Hub Token'
	String get hubToken => 'Hub Token';

	/// en: 'Token from the hub server'
	String get tokenFromTheHubServer => 'Token from the hub server';

	/// en: 'Paste hub server token'
	String get pasteHubServerToken => 'Paste hub server token';

	/// en: 'Running on'
	String get runningOn => 'Running on';

	/// en: 'online'
	String get online => 'online';

	/// en: 'Rooms'
	String get rooms => 'Rooms';

	/// en: 'Managing'
	String get managing => 'Managing';

	/// en: 'Lobby'
	String get lobby => 'Lobby';

	/// en: 'No rooms'
	String get noRooms => 'No rooms';

	/// en: 'Current'
	String get current => 'Current';

	/// en: 'Join'
	String get join => 'Join';

	/// en: 'Leave Room'
	String get leaveRoom => 'Leave Room';

	/// en: 'Room Password'
	String get roomPassword => 'Room Password';

	/// en: 'Blacklist'
	String get blacklist => 'Blacklist';

	/// en: 'banned'
	String get bannedCount => 'banned';

	/// en: 'No banned users'
	String get noBannedUsers => 'No banned users';

	/// en: 'Remove from Blacklist'
	String get removeFromBlacklist => 'Remove from Blacklist';

	/// en: 'Add to Blacklist'
	String get addToBlacklist => 'Add to Blacklist';

	/// en: 'Mute 5min'
	String get mute5min => 'Mute 5min';

	/// en: 'Unmute'
	String get unmute => 'Unmute';

	/// en: 'Remove Global Admin'
	String get removeGlobalAdmin => 'Remove Global Admin';

	/// en: 'Set Global Admin'
	String get setGlobalAdmin => 'Set Global Admin';

	/// en: 'Kick'
	String get kick => 'Kick';

	/// en: 'Poke'
	String get poke => 'Poke';

	/// en: 'Banned'
	String get banned => 'Banned';

	/// en: 'joined'
	String get joinedEvent => 'joined';

	/// en: 'left'
	String get leftEvent => 'left';

	/// en: 'New room'
	String get newRoom => 'New room';

	/// en: 'Port & Bind Mode'
	String get portAndBindMode => 'Port & Bind Mode';

	/// en: 'Hub Management'
	String get hubManagement => 'Hub Management';

	/// en: 'Chat Room'
	String get chatRoom => 'Chat Room';

	/// en: 'Open chat dialog'
	String get openChatDialog => 'Open chat dialog';

	/// en: 'Hub Details'
	String get hubDetails => 'Hub Details';

	/// en: 'Connection Settings'
	String get connectionSettings => 'Connection Settings';

	/// en: 'Server Address'
	String get serverAddress => 'Server Address';

	/// en: 'Host'
	String get host => 'Host';

	/// en: 'Authentication'
	String get authentication => 'Authentication';

	/// en: 'Paste'
	String get paste => 'Paste';

	/// en: 'Unblock'
	String get unblock => 'Unblock';

	/// en: 'Profile & Room'
	String get profileAndRoom => 'Profile & Room';

	/// en: 'Room Settings'
	String get roomSettings => 'Room Settings';

	/// en: 'Room Name'
	String get roomName => 'Room Name';

	/// en: 'Room ID'
	String get roomId => 'Room ID';

	/// en: 'Announcements'
	String get announcements => 'Announcements';

	/// en: 'Room Admins'
	String get roomAdmins => 'Room Admins';

	/// en: 'No announcement'
	String get noAnnouncement => 'No announcement';

	/// en: 'Set Announcement'
	String get setAnnouncement => 'Set Announcement';

	/// en: 'Enter announcement...'
	String get enterAnnouncementPrompt => 'Enter announcement...';

	/// en: 'Remove Admin'
	String get removeAdmin => 'Remove Admin';

	/// en: 'Add Room Admin'
	String get addRoomAdmin => 'Add Room Admin';

	/// en: 'Room Bans'
	String get roomBans => 'Room Bans';

	/// en: 'Ban Member'
	String get banMember => 'Ban Member';

	/// en: 'Unban'
	String get unban => 'Unban';

	/// en: 'Server'
	String get server => 'Server';

	/// en: 'Mute'
	String get mute => 'Mute';

	/// en: 'Mute Duration'
	String get muteDuration => 'Mute Duration';

	/// en: 'Seconds'
	String get secondsLabel => 'Seconds';

	/// en: 'Server shutdown'
	String get serverShutdown => 'Server shutdown';

	/// en: 'You are now a global admin'
	String get youAreNowAGlobalAdmin => 'You are now a global admin';

	/// en: 'Your global admin has been revoked'
	String get yourGlobalAdminHasBeenRevoked => 'Your global admin has been revoked';

	/// en: 'You are now a room admin'
	String get youAreNowARoomAdmin => 'You are now a room admin';

	/// en: 'Your room admin has been revoked'
	String get yourRoomAdminHasBeenRevoked => 'Your room admin has been revoked';

	/// en: 'You are muted for'
	String get youAreMutedFor => 'You are muted for';

	/// en: 'seconds'
	String get secondsUnit => 'seconds';

	/// en: 'You have been unmuted'
	String get youHaveBeenUnmuted => 'You have been unmuted';

	/// en: 'You are banned from room'
	String get youAreBannedFromRoom => 'You are banned from room';

	/// en: 'You can now rejoin room'
	String get youCanNowRejoinRoom => 'You can now rejoin room';

	/// en: 'You have been kicked from the room'
	String get youHaveBeenKickedFromTheRoom => 'You have been kicked from the room';

	/// en: 'Room deleted, moved to lobby'
	String get roomDeletedMovedToLobby => 'Room deleted, moved to lobby';

	/// en: 'Event Log'
	String get eventLog => 'Event Log';

	/// en: 'Ping Interval'
	String get pingInterval => 'Ping Interval';

	/// en: 'online'
	String get onlineStatus => 'online';

	/// en: 'No messages yet'
	String get noMessagesYet => 'No messages yet';

	/// en: 'New messages'
	String get newMessages => 'New messages';

	/// en: 'Reply'
	String get reply => 'Reply';

	/// en: 'Recall'
	String get recall => 'Recall';

	/// en: 'Enter to send · Ctrl+Enter for newline'
	String get enterToSend => 'Enter to send  ·  Ctrl+Enter for newline';

	/// en: 'Message...'
	String get messagePlaceholder => 'Message...';

	/// en: 'Connection timed out'
	String get connectionTimedOut => 'Connection timed out';

	/// en: 'Blocked Users'
	String get blockedUsers => 'Blocked Users';

	/// en: 'blocked'
	String get blockedCount => 'blocked';

	/// en: 'blocked'
	String get blocked => 'blocked';

	/// en: 'Blocked Invites'
	String get blockedInvites => 'Blocked Invites';

	/// en: 'No blocked invites'
	String get noBlockedInvites => 'No blocked invites';

	/// en: 'members'
	String get members => 'members';

	/// en: 'Not set'
	String get notSet => 'Not set';

	/// en: 'Current Room'
	String get currentRoom => 'Current Room';

	/// en: 'Edit Profile'
	String get editProfile => 'Edit Profile';

	/// en: 'No blocked users'
	String get noBlockedUsers => 'No blocked users';

	/// en: 'Create Room'
	String get createRoom => 'Create Room';

	/// en: 'Chat'
	String get chat => 'Chat';

	/// en: 'No one online'
	String get noOneOnline => 'No one online';

	/// en: 'Show'
	String get show => 'Show';

	/// en: 'Hide'
	String get hide => 'Hide';

	/// en: 'Server Blacklist'
	String get serverBlacklist => 'Server Blacklist';

	/// en: 'User Key'
	String get userKey => 'User Key';

	/// en: 'Admin Key'
	String get adminKey => 'Admin Key';

	/// en: 'Keep the same keys after restart'
	String get keepTheSameKeysAfterRestart => 'Keep the same keys after restart';

	/// en: 'Regenerated on every startup'
	String get regeneratedOnEveryStartup => 'Regenerated on every startup';

	/// en: 'No Key Required'
	String get noKeyRequired => 'No Key Required';

	/// en: 'Anyone can connect without API key'
	String get anyoneCanConnectWithoutApiKey => 'Anyone can connect without API key';

	/// en: 'Clients must provide a valid API key'
	String get clientsMustProvideAValidApiKey => 'Clients must provide a valid API key';

	/// en: 'Endpoint must be a valid http(s) URL'
	String get endpointMustBeAValidUrl => 'Endpoint must be a valid http(s) URL';

	/// en: 'Bucket cannot be empty'
	String get bucketCannotBeEmpty => 'Bucket cannot be empty';

	/// en: 'Access Key ID cannot be empty'
	String get accessKeyIdCannotBeEmpty => 'Access Key ID cannot be empty';

	/// en: 'Access Key Secret cannot be empty'
	String get accessKeySecretCannotBeEmpty => 'Access Key Secret cannot be empty';

	/// en: 'CDN Domain must be a valid URL'
	String get cdnDomainMustBeAValidUrl => 'CDN Domain must be a valid URL';

	/// en: 'Max size must be 1–100 MB'
	String get maxSizeMustBe1to100Mb => 'Max size must be 1–100 MB';

	/// en: 'Cleared'
	String get cleared => 'Cleared';

	/// en: 'Image Upload'
	String get imageUpload => 'Image Upload';

	/// en: 'Client Image Upload'
	String get clientImageUpload => 'Client Image Upload';

	/// en: 'Server OSS'
	String get serverOss => 'Server OSS';

	/// en: 'Client OSS'
	String get clientOss => 'Client OSS';

	/// en: 'Images stored on server disk, served via /hub/files/'
	String get imagesStoredOnServerDisk => 'Images stored on server disk, served via /hub/files/';

	/// en: 'Server receives and proxies image to OSS. Keys stay on server.'
	String get serverReceivesAndProxiesImageToOss => 'Server receives and proxies image to OSS. Keys stay on server.';

	/// en: 'Client uploads directly to OSS. Server only gets the final URL.'
	String get clientUploadsDirectlyToOss => 'Client uploads directly to OSS. Server only gets the final URL.';

	/// en: 'Max Size (MB)'
	String get maxSizeMb => 'Max Size (MB)';

	/// en: 'Store Path'
	String get storePath => 'Store Path';

	/// en: 'Leave empty for default'
	String get leaveEmptyForDefault => 'Leave empty for default';

	/// en: 'Not configured · will use server or base64'
	String get notConfiguredWillUseServerOrBase64 => 'Not configured · will use server or base64';

	/// en: 'Image too large to send'
	String get imageTooLargeToSend => 'Image too large to send';

	/// en: 'Please configure server upload or client OSS.'
	String get pleaseConfigureServerUploadOrClientOss => 'Please configure server upload or client OSS.';

	/// en: 'Stop the server to change upload mode'
	String get stopTheServerToChangeUploadMode => 'Stop the server to change upload mode';

	/// en: 'Enable Client OSS'
	String get enableClientOss => 'Enable Client OSS';

	/// en: 'Upload images directly from client to OSS'
	String get uploadImagesDirectlyFromClientToOss => 'Upload images directly from client to OSS';

	/// en: 'OSS not configured'
	String get ossNotConfigured => 'OSS not configured';

	/// en: 'Drop to send image'
	String get dropToSendImage => 'Drop to send image';

	/// en: 'Long press image to save'
	String get longPressImageToSave => 'Long press image to save';

	/// en: 'Please enter a valid URL starting with http:// or https://'
	String get pleaseEnterAValidUrl => 'Please enter a valid URL starting with http:// or https://';

	/// en: 'Set Room Password'
	String get setRoomPassword => 'Set Room Password';

	/// en: 'Admin Panel'
	String get adminPanel => 'Admin Panel';

	/// en: 'Enter room name'
	String get enterRoomName => 'Enter room name';

	/// en: 'Room announcement'
	String get roomAnnouncement => 'Room announcement';

	/// en: 'Leave empty for public room'
	String get leaveEmptyForPublicRoom => 'Leave empty for public room';

	/// en: 'Max Participants'
	String get maxParticipants => 'Max Participants';

	/// en: 'Up to'
	String get upTo => 'Up to';

	/// en: 'people'
	String get peopleLabel => 'people';

	/// en: 'No limit'
	String get noLimit => 'No limit';

	/// en: 'optional'
	String get optional => 'optional';

	/// en: 'Enter display name'
	String get enterDisplayName => 'Enter display name';

	/// en: 'Enter bio'
	String get enterBio => 'Enter bio';

	/// en: 'Auto Reconnect'
	String get autoReconnect => 'Auto Reconnect';

	/// en: 'Direct Message'
	String get directMessage => 'Direct Message';

	/// en: 'No announcements yet'
	String get noAnnouncementsYet => 'No announcements yet';

	/// en: 'Enter announcement text...'
	String get enterAnnouncementText => 'Enter announcement text...';

	/// en: 'Welcome Message'
	String get welcomeMessage => 'Welcome Message';

	/// en: 'No welcome message'
	String get noWelcomeMessage => 'No welcome message';

	/// en: 'Enter welcome message shown to users who join...'
	String get enterWelcomeMessage => 'Enter welcome message shown to users who join...';

	/// en: 'Security'
	String get security => 'Security';

	/// en: 'Change Password'
	String get changePassword => 'Change Password';

	/// en: 'Set Password'
	String get setPassword => 'Set Password';

	/// en: 'Protected'
	String get protectedStatus => 'Protected';

	/// en: 'Remove Password'
	String get removePassword => 'Remove Password';

	/// en: 'Enter password (leave empty to remove)'
	String get enterPasswordToChange => 'Enter password (leave empty to remove)';

	/// en: 'No admins yet'
	String get noAdminsYet => 'No admins yet';

	/// en: 'No banned members'
	String get noBannedMembers => 'No banned members';

	/// en: 'No members available'
	String get noMembersAvailable => 'No members available';

	/// en: 'Access Control'
	String get accessControl => 'Access Control';

	/// en: 'Broadcast'
	String get broadcast => 'Broadcast';

	/// en: 'Add Announcement'
	String get addAnnouncement => 'Add Announcement';

	/// en: 'Are you sure you want to delete ${r}? This cannot be undone.'
	String areYouSureYouWantToDeleteR({required Object r}) => 'Are you sure you want to delete ${r}? This cannot be undone.';

	/// en: 'Members'
	String get membersList => 'Members';

	/// en: 'Online Users'
	String get onlineUsersList => 'Online Users';

	/// en: 'No users online'
	String get noUsersOnline => 'No users online';

	/// en: 'Room'
	String get room => 'Room';

	/// en: 'No password set'
	String get noPasswordSet => 'No password set';

	/// en: 'Password protected'
	String get passwordProtected => 'Password protected';

	/// en: 'Image'
	String get imageLabel => 'Image';

	/// en: 'Stickers'
	String get stickersLabel => 'Stickers';

	/// en: 'poked you'
	String get pokedYou => 'poked you';

	/// en: 'Kicked from server by ${p}'
	String kickedFromServerByP({required Object p}) => 'Kicked from server by ${p}';

	/// en: 'Kicked from room by ${p}'
	String kickedFromRoomByP({required Object p}) => 'Kicked from room by ${p}';

	/// en: 'left the room'
	String get leftTheRoom => 'left the room';

	/// en: 'joined the room'
	String get joinedTheRoom => 'joined the room';

	/// en: '${p} was kicked by ${o}'
	String pWasKickedByO({required Object p, required Object o}) => '${p} was kicked by ${o}';

	/// en: 'You'
	String get youLabel => 'You';

	/// en: 'left the server'
	String get leftTheServer => 'left the server';

	/// en: 'joined the server'
	String get joinedTheServer => 'joined the server';

	/// en: 'updated the announcement'
	String get updatedTheAnnouncement => 'updated the announcement';

	/// en: 'recalled a message'
	String get recalledAMessage => 'recalled a message';

	/// en: '${p} reacted with ${o}'
	String pReactedWithO({required Object p, required Object o}) => '${p} reacted with ${o}';

	/// en: '${p} removed reaction ${o}'
	String pRemovedReactionO({required Object p, required Object o}) => '${p} removed reaction ${o}';

	/// en: 'No users available to invite'
	String get noUsersAvailableToInvite => 'No users available to invite';

	/// en: 'Invite to Room'
	String get inviteToRoom => 'Invite to Room';

	/// en: 'Invite'
	String get invite => 'Invite';

	/// en: 'invited'
	String get invited => 'invited';

	/// en: 'Room Invite'
	String get roomInvite => 'Room Invite';

	/// en: 'invited you to'
	String get invitedYouTo => 'invited you to';

	/// en: 'Accept'
	String get acceptInvite => 'Accept';

	/// en: 'accepted your invite'
	String get acceptedYourInvite => 'accepted your invite';

	/// en: 'declined your invite'
	String get declinedYourInvite => 'declined your invite';

	/// en: 'blocked your invites'
	String get blockedYourInvites => 'blocked your invites';

	/// en: 'Blocked Invites'
	String get blockedInvitesList => 'Blocked Invites';

	/// en: 'Allow Member Invites'
	String get allowMemberInvites => 'Allow Member Invites';

	/// en: 'Let all members invite others'
	String get letAllMembersInviteOthers => 'Let all members invite others';

	/// en: 'Decline & Block'
	String get declineAndBlock => 'Decline & Block';

	/// en: 'Memes'
	String get memes => 'Memes';

	/// en: 'Meme saved'
	String get memeSaved => 'Meme saved';

	/// en: 'Network Info'
	String get networkInfo => 'Network Info';

	/// en: 'Hub Info'
	String get hubInfo => 'Hub Info';

	/// en: 'Stats Info'
	String get statsInfo => 'Stats Info';

	/// en: 'Rating Details'
	String get ratingDetails => 'Rating Details';

	/// en: 'Source Info'
	String get sourceInfo => 'Source Info';

	/// en: 'Player Info'
	String get playerInfo => 'Player Info';

	/// en: 'Hide'
	String get hideLabel => 'Hide';

	/// en: 'Show'
	String get showLabel => 'Show';

	/// en: 'Persona Management'
	String get personaManagement => 'Persona Management';

	/// en: 'Prompt Configuration'
	String get promptConfiguration => 'Prompt Configuration';

	/// en: 'System Prompt'
	String get systemPrompt => 'System Prompt';

	/// en: 'Temperature'
	String get temperature => 'Temperature';

	/// en: 'Prompt saved'
	String get promptSaved => 'Prompt saved';

	/// en: 'Edit System Prompt'
	String get editSystemPrompt => 'Edit System Prompt';

	/// en: 'No history yet'
	String get noHistoryYet => 'No history yet';

	/// en: 'Clear All'
	String get clearAll => 'Clear All';

	/// en: 'Config copied to clipboard'
	String get configCopiedToClipboard => 'Config copied to clipboard';

	/// en: 'Imported as new config'
	String get importedAsNewConfig => 'Imported as new config';

	/// en: 'Imported'
	String get imported => 'Imported';

	/// en: 'Invalid clipboard format'
	String get invalidClipboardFormat => 'Invalid clipboard format';

	/// en: 'Cannot modify system preset'
	String get cannotModifySystemPreset => 'Cannot modify system preset';

	/// en: '番剧卡片使用模糊背景'
	String get animeCardUseBlur => '番剧卡片使用模糊背景';

	/// en: '每日番剧表启动时搜寻集信息'
	String get calendarFetchEpisodes => '每日番剧表启动时搜寻集信息';

	/// en: 'Add keyword'
	String get addKeyword => 'Add keyword';

	/// en: 'Keyword'
	String get keyword => 'Keyword';

	/// en: 'Keyword already exists'
	String get keywordAlreadyExists => 'Keyword already exists';

	/// en: 'Folder name cannot be empty'
	String get folderNameCannotBeEmpty => 'Folder name cannot be empty';

	/// en: 'Folder name is too long'
	String get folderNameTooLong => 'Folder name is too long';

	/// en: 'Folder already exists'
	String get folderAlreadyExists => 'Folder already exists';

	/// en: 'Config Key already exists. Please change it.'
	String get configKeyAlreadyExists => 'Config Key already exists. Please change it.';

	/// en: 'Required'
	String get requiredField => 'Required';

	/// en: 'Config Key'
	String get configKey => 'Config Key';

	/// en: 'Memo'
	String get memoField => 'Memo';

	/// en: 'Value: 0.0 - 1.0'
	String get valueRange => 'Value: 0.0 - 1.0';

	/// en: 'Read-only System Preset'
	String get readOnlySystemPreset => 'Read-only System Preset';

	/// en: 'Delete Config'
	String get deleteConfig => 'Delete Config';

	/// en: 'Are you sure you want to delete'
	String get areYouSureYouWantToDeleteGeneric => 'Are you sure you want to delete';

	/// en: 'Base URL'
	String get baseUrl => 'Base URL';

	/// en: 'Optional'
	String get optionalField => 'Optional';

	/// en: 'Model'
	String get model => 'Model';

	/// en: 'Add Model'
	String get addModel => 'Add Model';

	/// en: 'Model ID'
	String get modelId => 'Model ID';

	/// en: 'Display Name'
	String get displayName => 'Display Name';

	/// en: 'No models. Add one above.'
	String get noModelsAddOneAbove => 'No models. Add one above.';

	/// en: 'Placeholders: ${animeCount} ${animeNames} ${topTags}'
	String placeholdersDescription({required Object animeCount, required Object animeNames, required Object topTags}) => 'Placeholders: ${animeCount} ${animeNames} ${topTags}';

	/// en: 'AI Hub'
	String get aiHub => 'AI Hub';

	/// en: 'Select Year & Month'
	String get selectYearAndMonth => 'Select Year & Month';

	/// en: 'Enter Year'
	String get enterYear => 'Enter Year';

	/// en: 'Select Day'
	String get selectDay => 'Select Day';

	/// en: 'Full Year'
	String get fullYear => 'Full Year';

	/// en: 'Quick Select'
	String get quickSelect => 'Quick Select';

	/// en: 'Select Date Range'
	String get selectDateRange => 'Select Date Range';

	/// en: 'Subject'
	String get subject => 'Subject';

	/// en: 'Character'
	String get character => 'Character';

	/// en: 'Person'
	String get person => 'Person';

	/// en: 'Manual Select'
	String get manualSelect => 'Manual Select';

	/// en: 'QR & Clipboard'
	String get qrAndClipboard => 'QR & Clipboard';

	/// en: 'Go'
	String get go => 'Go';

	/// en: 'Clipboard'
	String get clipboard => 'Clipboard';

	/// en: 'Recognize from Gallery'
	String get recognizeFromGallery => 'Recognize from Gallery';

	/// en: 'Scan QR Code'
	String get scanQrCode => 'Scan QR Code';

	/// en: 'Scan to Jump'
	String get scanToJump => 'Scan to Jump';

	/// en: 'QR Code'
	String get qrCode => 'QR Code';

	/// en: 'Share method: In anime/Bangumi page, click share → generate token or QR code'
	String get shareMethodDescription => 'Share method: In anime/Bangumi page, click share → generate token or QR code';

	/// en: 'Share QR Code'
	String get shareQrCode => 'Share QR Code';

	/// en: 'Exporting...'
	String get exporting => 'Exporting...';

	/// en: 'Token copied to clipboard'
	String get tokenCopiedToClipboard => 'Token copied to clipboard';

	/// en: 'Generate QR Code to Share'
	String get generateQrCodeShare => 'Generate QR Code to Share';

	/// en: 'AI Settings'
	String get aiSettings => 'AI Settings';

	/// en: 'AI Config Missing'
	String get aiConfigMissing => 'AI Config Missing';

	/// en: 'Generating...'
	String get generating => 'Generating...';

	/// en: 'Generated Tags'
	String get generatedTags => 'Generated Tags';

	/// en: 'Export Screenshot'
	String get exportScreenshot => 'Export Screenshot';

	/// en: 'Copy all'
	String get copyAll => 'Copy all';

	/// en: 'Time Range'
	String get timeRange => 'Time Range';

	/// en: 'This Week'
	String get thisWeek => 'This Week';

	/// en: 'This Month'
	String get thisMonth => 'This Month';

	/// en: 'Generate Summary'
	String get generateSummary => 'Generate Summary';

	/// en: 'Generate Tag'
	String get generateTag => 'Generate Tag';

	/// en: 'Summary Report'
	String get summaryReport => 'Summary Report';

	/// en: 'No activity in this time range'
	String get noActivityInTimeRange => 'No activity in this time range';

	/// en: 'Weekly Summary'
	String get weeklySummary => 'Weekly Summary';

	/// en: 'Monthly Summary'
	String get monthlySummary => 'Monthly Summary';

	/// en: 'Tag copied'
	String get tagCopied => 'Tag copied';

	/// en: 'AI Service Configuration'
	String get aiServiceConfig => 'AI Service Configuration';

	/// en: 'Connection to server disconnected'
	String get connectionDisconnected => 'Connection to server disconnected';

	/// en: 'Please enter server address'
	String get enterServerAddress => 'Please enter server address';

	/// en: 'Tap to share'
	String get tapToShare => 'Tap to share';

	/// en: 'No configurations found'
	String get noConfigurationsFound => 'No configurations found';

	/// en: 'No data'
	String get noData => 'No data';

	/// en: 'Login with password is disabled'
	String get loginWithPasswordIsDisabled => 'Login with password is disabled';

	/// en: 'Cannot be empty'
	String get cannotBeEmpty => 'Cannot be empty';

	/// en: 'Invalid cookies'
	String get invalidCookies => 'Invalid cookies';

	/// en: 'Webview is not available'
	String get webviewIsNotAvailable => 'Webview is not available';

	/// en: 'Sources'
	String get sources => 'Sources';

	/// en: 'Translation failed, please try again later'
	String get translationFailedPleaseTryAgainLater => 'Translation failed, please try again later';

	/// en: 'Write your review'
	String get writeYourReview => 'Write your review';

	/// en: 'Draft'
	String get draft => 'Draft';

	/// en: 'Content'
	String get content => 'Content';

	/// en: 'Toggle'
	String get toggle => 'Toggle';

	/// en: 'Room Ban'
	String get roomBan => 'Room Ban';

	/// en: 'Pinned Messages'
	String get pinnedMessages => 'Pinned Messages';

	/// en: 'Announcement'
	String get announcement => 'Announcement';

	/// en: 'Image'
	String get image => 'Image';

	/// en: 'Enter to send · Ctrl+Enter for newline'
	String get enterToSendCtrlEnterForNewline => 'Enter to send  ·  Ctrl+Enter for newline';

	/// en: 'Message...'
	String get message => 'Message...';

	/// en: 'Stickers'
	String get stickers => 'Stickers';

	/// en: 'No stickers yet'
	String get noStickersYet => 'No stickers yet';

	/// en: 'Remove sticker'
	String get removeSticker => 'Remove sticker';

	/// en: 'No search sources'
	String get noSearchSources => 'No search sources';

	/// en: 'Please add some sources'
	String get pleaseAddSomeSources => 'Please add some sources';

	/// en: 'Manage'
	String get manage => 'Manage';

	/// en: 'Import Persona'
	String get importPersona => 'Import Persona';

	/// en: 'New Persona'
	String get newPersona => 'New Persona';

	/// en: 'Not configured'
	String get notConfigured => 'Not configured';

	/// en: 'Enabled'
	String get enabled => 'Enabled';

	/// en: 'Required'
	String get required => 'Required';

	/// en: 'Link format error, cannot parse anime info'
	String get linkFormatErrorCannotParseAnimeInfo => 'Link format error, cannot parse anime info';

	/// en: 'Source not found, please confirm source is installed'
	String get sourceNotFoundPleaseConfirmSourceInstalled => 'Source not found, please confirm source is installed';

	/// en: 'Link format error, cannot parse Bangumi ID'
	String get linkFormatErrorCannotParseBangumiId => 'Link format error, cannot parse Bangumi ID';

	/// en: 'Fetching Bangumi info...'
	String get fetchingBangumiInfo => 'Fetching Bangumi info...';

	/// en: 'Bangumi entry not found'
	String get bangumiEntryNotFound => 'Bangumi entry not found';

	/// en: 'Failed to fetch Bangumi info'
	String get failedToFetchBangumiInfo => 'Failed to fetch Bangumi info';

	/// en: 'Link format error, cannot parse character ID'
	String get linkFormatErrorCannotParseCharacterId => 'Link format error, cannot parse character ID';

	/// en: 'Verifying character info...'
	String get verifyingCharacterInfo => 'Verifying character info...';

	/// en: 'Character not found'
	String get characterNotFound => 'Character not found';

	/// en: 'Failed to fetch character info'
	String get failedToFetchCharacterInfo => 'Failed to fetch character info';

	/// en: 'Link format error, cannot parse person ID'
	String get linkFormatErrorCannotParsePersonId => 'Link format error, cannot parse person ID';

	/// en: 'Verifying person info...'
	String get verifyingPersonInfo => 'Verifying person info...';

	/// en: 'Person not found'
	String get personNotFound => 'Person not found';

	/// en: 'Failed to fetch person info'
	String get failedToFetchPersonInfo => 'Failed to fetch person info';

	/// en: 'Unrecognized link'
	String get unrecognizedLink => 'Unrecognized link';

	/// en: 'No Kostori link found in clipboard'
	String get noKostoriLinkFoundInClipboard => 'No Kostori link found in clipboard';

	/// en: 'QR code feature only available on mobile'
	String get qrCodeFeatureOnlyOnMobile => 'QR code feature only available on mobile';

	/// en: 'Unrecognized Kostori protocol'
	String get unrecognizedKostoriProtocol => 'Unrecognized Kostori protocol';

	/// en: 'Please drag in image file'
	String get pleaseDragImageFile => 'Please drag in image file';

	/// en: 'Image download failed'
	String get imageDownloadFailed => 'Image download failed';

	/// en: 'Failed to fetch network image'
	String get failedToFetchNetworkImage => 'Failed to fetch network image';

	/// en: 'Image decode failed'
	String get imageDecodeFailed => 'Image decode failed';

	/// en: 'No QR code found in image'
	String get noQrCodeFoundInImage => 'No QR code found in image';

	/// en: 'Copied to clipboard'
	String get copiedToClipboard => 'Copied to clipboard';

	/// en: 'Like success'
	String get likeSuccess => 'Like success';

	/// en: 'Unlike success'
	String get unlikeSuccess => 'Unlike success';

	/// en: 'Operation success'
	String get operationSuccess => 'Operation success';

	/// en: 'Save success'
	String get saveSuccess => 'Save success';

	/// en: 'Save failed'
	String get saveFailed => 'Save failed';

	/// en: 'Save failed: $e'
	String saveFailedWithError({required Object e}) => 'Save failed: ${e}';

	/// en: 'Load success'
	String get loadSuccess => 'Load success';

	/// en: 'Address already exists'
	String get addressAlreadyExists => 'Address already exists';

	/// en: 'Please enable at least one address'
	String get pleaseEnableAtLeastOneAddress => 'Please enable at least one address';

	/// en: 'Request failed'
	String get requestFailed => 'Request failed';

	/// en: 'All copied success'
	String get allCopiedSuccess => 'All copied success';

	/// en: 'Bangumi ID bound successfully'
	String get bindBangumiIdSuccess => 'Bangumi ID bound successfully';

	/// en: 'Apply success'
	String get applySuccess => 'Apply success';

	/// en: 'No changes'
	String get noChanges => 'No changes';

	/// en: 'Apply failed'
	String get applyFailed => 'Apply failed';

	/// en: 'No results found, please try other keywords'
	String get noResultsTryOtherKeywords => 'No results found, please try other keywords';

	/// en: 'Jumping...'
	String get jumping => 'Jumping...';

	/// en: 'Query failed'
	String get queryFailed => 'Query failed';

	/// en: 'Screenshot success'
	String get screenshotSuccess => 'Screenshot success';

	/// en: 'Screenshot failed'
	String get screenshotFailed => 'Screenshot failed';

	/// en: 'No record for $month'
	String noRecordForMonth({required Object month}) => 'No record for ${month}';

	/// en: 'Screenshot failed, please retry'
	String get screenshotFailedPleaseRetry => 'Screenshot failed, please retry';

	/// en: 'Share failed'
	String get shareFailed => 'Share failed';

	/// en: 'Connection failed'
	String get connectionFailed => 'Connection failed';

	/// en: 'Copy success'
	String get copySuccess => 'Copy success';

	/// en: 'Add to favorites success'
	String get addToFavoritesSuccess => 'Add to favorites success';

	/// en: 'Delete failed'
	String get deleteFailed => 'Delete failed';

	/// en: 'Saving image...'
	String get savingImage => 'Saving image...';

	/// en: 'Save failed: permission or directory error'
	String get saveFailedPermission => 'Save failed: permission or directory error';

	/// en: 'Bangumi data update failed...'
	String get bangumiDataUpdateFailed => 'Bangumi data update failed...';

	/// en: 'Bangumi data reset failed...'
	String get bangumiDataResetFailed => 'Bangumi data reset failed...';

	/// en: 'Playing next episode'
	String get playingNextEpisode => 'Playing next episode';

	/// en: 'Failed to load episode'
	String get failedToLoadEpisode => 'Failed to load episode';

	/// en: 'No more episodes to play'
	String get noMoreEpisodes => 'No more episodes to play';

	/// en: 'Route not found'
	String get routeNotFound => 'Route not found';

	/// en: 'Loading duplicate episode'
	String get loadingDuplicateEpisode => 'Loading duplicate episode';

	/// en: 'Failed to get video URL'
	String get getVideoUrlFailed => 'Failed to get video URL';

	/// en: 'Start search'
	String get startSearch => 'Start search';

	/// en: 'DLNA error'
	String get dlnaError => 'DLNA error';

	/// en: 'Please enter episode number'
	String get pleaseEnterEpisodeNumber => 'Please enter episode number';

	/// en: 'Please enter a valid episode number between 1-999'
	String get pleaseEnterValidEpisodeNumber => 'Please enter a valid episode number between 1-999';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'aToAddBToRemoveCToMove' => ({required Object a, required Object b, required Object c}) => '${a} to add • ${b} to remove • ${c} to move',
			'aToAddBToRemove' => ({required Object a, required Object b}) => '${a} to add • ${b} to remove',
			'cUpdates' => ({required Object c}) => '${c} updates',
			'aNewVersionIsAvailableDoYouWantToUpdateNow' => 'A new version is available. Do you want to update now?',
			'app' => 'APP',
			'about' => 'About',
			'accounts' => 'Accounts',
			'addAAnimeSourceInHomePage' => 'Add a anime source in home page',
			'addAnimeSource' => 'Add anime source',
			'addNewFavoriteTo' => 'Add new favorite to',
			'addToFavorites' => 'Add to favorites',
			'imageProperties' => 'Image Properties',
			'fileName' => 'File Name',
			'fileSize' => 'File Size',
			'modifiedTime' => 'Modified Time',
			'path' => 'Path',
			'titleCopied' => 'Title copied',
			'imageFormat' => 'Format',
			'confirmDeleteImage' => 'Confirm delete this image?',
			'bangumiPlan' => 'Bangumi Plan',
			'switchFavoriteUser' => 'Switch Favorite User',
			'add' => 'Add',
			'addedCountAnimesToDownloadQueue' => ({required Object count}) => 'Added ${count} animes to download queue.',
			'added' => 'Added',
			'aggregatedSearch' => 'Aggregated Search',
			'aggregated' => 'Aggregated',
			'aiSource' => 'AI Source',
			'ai' => 'AI',
			'soulProfile' => 'Soul Profile',
			'soulProfilerDescription' => 'Based on your watch history, analyze your anime personality',
			'imageTag' => 'AI Image Tag',
			'imageTagDescription' => 'Generate AI painting style tags based on your preferences',
			'aiChat' => 'AI Chat',
			'aiChatDescription' => 'Multi-round conversation with AI with context memory',
			'summary' => 'Summary',
			'summaryDescription' => 'Auto-generate your anime watch weekly/monthly report',
			'basicInfo' => 'Basic Info',
			'allEpisodes' => 'All Episodes',
			'relatedEntries' => 'Related Entries',
			'alsoRemoveFilesOnDisk' => 'Also remove files on disk',
			'animeSourceList' => 'Anime Source list',
			'animeSource' => 'Anime Source',
			'appearance' => 'Appearance',
			'areYouSureYouWantToClearYourHistory' => 'Are you sure you want to clear your history?',
			'areYouSureYouWantToClearYourProgress' => 'Are you sure you want to clear your progress?',
			'authorizationRequired' => 'Authorization Required',
			'autoPageTurning' => 'Auto Page Turning',
			'back' => 'Back',
			'bangumi' => 'Bangumi',
			'block' => 'Block',
			'blue' => 'Blue',
			'brief' => 'Brief',
			'cacheLimit' => 'Cache Limit',
			'cacheSize' => 'Cache Size',
			'cacheCleared' => 'Cache cleared',
			'cancel' => 'Cancel',
			'categories' => 'Categories',
			'categoryPages' => 'Category Pages',
			'characters' => 'Characters',
			'checkForUpdatesOnStartup' => 'Check for updates on startup',
			'checkForUpdates' => 'Check for updates',
			'checkUpdates' => 'Check updates',
			'check' => 'Check',
			'clearCache' => 'Clear Cache',
			'clearHistory' => 'Clear History',
			'clearProgress' => 'Clear Progress',
			'clearSearchHistory' => 'Clear Search History',
			'clearUnfavorited' => 'Clear Unfavorited',
			'clear' => 'Clear',
			'clickIfLoginExpired' => 'Click if login expired',
			'close' => 'Close',
			'comment' => 'Comment',
			'comments' => 'Comments',
			'confirm' => 'Confirm',
			'kContinue' => 'Continue',
			'copied' => 'Copied',
			'analyze' => 'Analyze',
			'analyzing' => 'Analyzing...',
			'analysisResult' => 'Analysis Result',
			'yourQuestion' => 'Your Question',
			'pleaseEnterAPrompt' => 'Please enter a prompt',
			'egWhatKindOfAnimeDoILike' => 'e.g., What kind of anime do I like?',
			'aiSourceNotAvailable' => 'AI source not available',
			'copyId' => 'Copy ID',
			'copyTitle' => 'Copy Title',
			'copyUrl' => 'Copy URL',
			'copyToFolder' => 'Copy to folder',
			'copy' => 'Copy',
			'createAccount' => 'Create Account',
			'createFolder' => 'Create Folder',
			'create' => 'Create',
			'currentlySeenEp' => ({required Object ep}) => 'Currently seen ${ep}',
			'dnsOverrides' => 'DNS Overrides',
			'dark' => 'Dark',
			'dataSync' => 'Data Sync',
			'data' => 'Data',
			'dateDesc' => 'Date Desc',
			'date' => 'Date',
			'defaultSearchTarget' => 'Default Search Target',
			'deleteCAnimes' => ({required Object c}) => 'Delete ${c} animes?',
			'deleteAnime' => 'Delete Anime',
			'deleteFolder' => 'Delete Folder',
			'deleteAnimeSourceN' => ({required Object n}) => 'Delete anime source \'${n}\' ?',
			'deleteFolderF' => ({required Object f}) => 'Delete folder \'${f}\' ?',
			'deleteFolderPrompt' => 'Delete folder?',
			'delete' => 'Delete',
			'deleteRoom' => 'Delete Room',
			'description' => 'Description',
			'deselect' => 'Deselect',
			'detailed' => 'Detailed',
			'details' => 'Details',
			'determineTheBindingA' => ({required Object a}) => 'Determine the binding: ${a} ?',
			'disable' => 'Disable',
			'disabled' => 'Disabled',
			'discoverTheNewVersionV' => ({required Object v}) => 'Discover the new version ${v}',
			'displayModeOfAnimeTile' => 'Display mode of anime tile',
			'displayTimeAndBatteryInfoInReader' => 'Display time & battery info in reader',
			'doNotReportAnyIssuesRelatedToSourcesToAppRepo' => 'Do not report any issues related to sources to App repo.',
			'downloadAll' => 'Download All',
			'downloadSelected' => 'Download Selected',
			'downloadThreads' => 'Download Threads',
			'download' => 'Download',
			'downloading' => 'Downloading',
			'edit' => 'Edit',
			'enableDnsOverrides' => 'Enable DNS Overrides',
			'enable' => 'Enable',
			'end' => 'End',
			'episodeEp' => ({required Object ep}) => 'Episode ${ep}',
			'error' => 'Error',
			'exitMultiSelect' => 'Exit Multi-Select',
			'exit' => 'Exit',
			'explorePages' => 'Explore Pages',
			'explore' => 'Explore',
			'exportAppData' => 'Export App Data',
			'export' => 'Export',
			'failedToImport' => 'Failed to import',
			'fanyuan' => 'Fanyuan',
			'favoriteActions' => 'Favorite actions',
			'favorite' => 'Favorite',
			'favorites' => 'Favorites',
			'finished' => 'Finished',
			'folderName' => 'Folder Name',
			'folder' => 'Folder',
			'folders' => 'Folders',
			'following' => 'Following',
			'fullScreen' => 'Full Screen',
			'fullscreen' => 'Fullscreen',
			'gitMirror' => 'Git Mirror',
			'green' => 'Green',
			'help' => 'Help',
			'history' => 'History',
			'historySource' => 'History Source',
			'home' => 'Home',
			'iconProducer' => 'Icon producer',
			'ignoreCertificateErrors' => 'Ignore Certificate Errors',
			'importAnimes' => 'Import Animes',
			'importAppData' => 'Import App Data',
			'importFromFile' => 'Import from file',
			'import' => 'Import',
			'importedAAnimes' => ({required Object a}) => 'Imported ${a} animes',
			'information' => 'Information',
			'myRating' => 'My Rating',
			'initialPage' => 'Initial Page',
			'invertSelection' => 'Invert Selection',
			'keywordBlocking' => 'Keyword blocking',
			'kostoriIsAFreeAndOpenSourceAppForAnimeWatching' => 'Kostori is a free and open-source app for anime watching.',
			'language' => 'Language',
			'later' => 'Later',
			'light' => 'Light',
			'limitImageWidth' => 'Limit image width',
			'localFavorites' => 'Local Favorites',
			'local' => 'Local',
			'logIn' => 'Log in',
			'logOut' => 'Log out',
			'log' => 'Log',
			'manualTranslation' => 'Manual Translation',
			'enterTextToTranslate' => 'Enter text to translate',
			'translate' => 'Translate',
			'translating' => 'Translating...',
			'translationResult' => 'Translation result',
			'selectTranslationLanguage' => 'Select Translation Language',
			'pleaseEnterTextToTranslate' => 'Please enter text to translate',
			'loginWithWebview' => 'Login with webview',
			'login' => 'Login',
			'longPressAndDragToReorder' => 'Long press and drag to reorder.',
			'longPressOnTheFavoriteButtonToQuicklyAddToThisFolder' => 'Long press on the favorite button to quickly add to this folder',
			'longPressToZoom' => 'Long press to zoom',
			'me' => 'Me',
			'moveToFirst' => 'Move To First',
			'moveFavoriteAfterReading' => 'Move favorite after reading',
			'moveToFolder' => 'Move to folder',
			'move' => 'Move',
			'multiSelect' => 'Multi-Select',
			'multipleAnimes' => 'Multiple Animes',
			'name' => 'Name',
			'networkFavoritePages' => 'Network Favorite Pages',
			'network' => 'Network',
			'newFolder' => 'New Folder',
			'newVersion' => 'New Version',
			'newVersionAvailable' => 'New version available',
			'next' => 'Next',
			'noExplorePages' => 'No Explore Pages',
			'noNewVersionAvailable' => 'No new version available',
			'noSearchResultsFound' => 'No search results found',
			'noLikedAnimeFound' => 'No liked anime found',
			'noUpdates' => 'No updates',
			'ok' => 'OK',
			'onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer' => 'Once the operation is successful, app will automatically sync data with the server.',
			'openLog' => 'Open Log',
			'openAnime' => 'Open anime',
			'openHelp' => 'Open help',
			'openInBrowser' => 'Open in Browser',
			'openLink' => 'Open link',
			'open' => 'Open',
			'operation' => 'Operation',
			'orange' => 'Orange',
			'order' => 'Order',
			'password' => 'Password',
			'pause' => 'Pause',
			'paused' => 'Paused',
			'pink' => 'Pink',
			'playlist' => 'Playlist',
			'pleaseCheckYourSettings' => 'Please check your settings',
			'preview' => 'Preview',
			'proxy' => 'Proxy',
			'purple' => 'Purple',
			'quickFavorite' => 'Quick Favorite',
			'ranking' => 'Ranking',
			'reLogin' => 'Re-login',
			'read' => 'Read',
			'reading' => 'Reading',
			'red' => 'Red',
			'refresh' => 'Refresh',
			'related' => 'Related',
			'removeAnimeFromFavorite' => 'Remove anime from favorite?',
			'remove' => 'Remove',
			'rename' => 'Rename',
			'reorder' => 'Reorder',
			'resetBangumiData' => 'Reset Bangumi-data',
			'reset' => 'Reset',
			'retry' => 'Retry',
			'reviews' => 'Reviews',
			'saveImage' => 'Save Image',
			'savedFailed' => 'Saved Failed',
			'saved' => 'Saved',
			'searchAll' => 'Search All',
			'searchHistory' => 'Search History',
			'searchIn' => 'Search in',
			'search' => 'Search',
			'selectAll' => 'Select All',
			'selectADirectoryWhichContainsTheAnimeFiles' => 'Select a directory which contains the anime files.',
			'selectAFolder' => 'Select a folder',
			'selectAnImageOnScreen' => 'Select an image on screen',
			'selectFile' => 'Select file',
			'selectInRange' => 'Select in range',
			'select' => 'Select',
			'selectedAAnimes' => ({required Object a}) => 'Selected ${a} animes',
			'newName' => 'New Name',
			'setCacheLimit' => 'Set Cache Limit',
			'setNewStoragePath' => 'Set New Storage Path',
			'setSourceListUrl' => 'Set source list url',
			'set' => 'Set',
			'settings' => 'Settings',
			'share' => 'Share',
			'showAll' => 'Show all',
			'showFavoriteStatusOnAnimeTile' => 'Show favorite status on anime tile',
			'showHistoryOnAnimeTile' => 'Show history on anime tile',
			'singleAnime' => 'Single Anime',
			'sizeInMb' => 'Size in MB',
			'sizeOfAnimeTile' => 'Size of anime tile',
			'sort' => 'Sort',
			'sourceFolder' => 'Source Folder',
			'sourceUrl' => 'Source URL',
			'staffList' => 'StaffList',
			'start' => 'Start',
			'storagePathForLocalAnimes' => 'Storage Path for local animes',
			'submit' => 'Submit',
			'suggestions' => 'Suggestions',
			'syncData' => 'Sync Data',
			'sync' => 'Sync',
			'syncingData' => 'Syncing Data',
			'system' => 'System',
			'tapToTurnPages' => 'Tap to turn Pages',
			'theUrlShouldPointToAIndexJsonFile' => 'The URL should point to a \'index.json\' file',
			'theFolderIsLinkedToSource' => ({required Object source}) => 'The folder is Linked to ${source}',
			'themeColor' => 'Theme Color',
			'themeMode' => 'Theme Mode',
			'timetable' => 'Timetable',
			'topics' => 'Topics',
			'topicsLatest' => 'TopicsLatest',
			'topicsTrending' => 'TopicsTrending',
			'turnPageByVolumeKeys' => 'Turn page by volume keys',
			'unselected' => 'Unselected',
			'updateAnimesInfo' => 'Update Animes Info',
			'updateTime' => 'Update Time',
			'update' => 'Update',
			'updatesAvailable' => 'Updates Available',
			'updating' => 'Updating',
			'uploadTime' => 'Upload Time',
			'upload' => 'Upload',
			'uploader' => 'Uploader',
			'useAConfigFile' => 'Use a config file',
			'user' => 'User',
			'username' => 'Username',
			'userProfileAnalysis' => 'User Profile Analysis',
			'viewList' => 'View list',
			'viewMore' => 'View more',
			'view' => 'View',
			'webDavAutoSync' => 'WebDAV Auto Sync',
			'kDefault' => 'default',
			'lastWatchTimeTime' => ({required Object time}) => 'lastWatchTime ${time}',
			'minAppVersionRequired' => ({required Object version}) => 'minAppVersion ${version} is required',
			'more' => 'more',
			'notYetAiring' => 'Not Yet Airing',
			'fullBEpisodesReleased' => ({required Object b}) => 'Full ${b} episodes released',
			'upToEpSTotalEpsPlanned' => ({required Object s, required Object t}) => 'Up to ep ${s} • Total ${t} eps planned',
			'upToEpETotalEpsPlanned' => ({required Object e, required Object s, required Object t}) => 'Up to ep ${e} (${s}) • Total ${t} eps planned',
			'tReviewsR' => ({required Object t, required Object r}) => '${t} reviews | #${r}',
			'tReviews' => ({required Object t}) => '${t} reviews',
			'showMore' => 'Show more +',
			'showLess' => 'Show less -',
			'tags' => 'Tags',
			'clearTags' => 'Clear Tags',
			'showingLResults' => ({required Object l}) => 'Showing ${l} results',
			'selectTime' => 'Select Time',
			'switchLayout' => 'Switch Layout',
			'enterKeywords' => 'Enter keywords...',
			'ratingChart' => 'Rating Chart',
			'lineChart' => 'Line Chart',
			'barChart' => 'Bar Chart',
			'standardDeviationS' => ({required Object s}) => 'Standard Deviation: ${s}',
			'nobodysPostedAnythingYet' => 'Nobody\'s posted anything yet...',
			'reload' => 'Reload',
			'mainContent' => 'Main Content',
			'switchh' => 'Switch',
			'failedToLoadPleaseTryAgain' => 'Failed to load, please try again.',
			'doing' => 'doing',
			'collect' => 'collect',
			'wish' => 'wish',
			'onHold' => 'on hold',
			'dropped' => 'dropped',
			'todayRecommendation' => 'Today Recommendation',
			'tTotalCount' => ({required Object t}) => '${t} Total count',
			'introduction' => 'Introduction',
			'latestComments' => 'Latest Comments',
			'linkedItems' => 'Linked Items',
			'timeS' => ({required Object s}) => 'Time: ${s}',
			'broadcastTimeA' => ({required Object a}) => 'Broadcast Time: ${a}',
			'profileInformation' => 'Profile Information',
			'characterIntroduction' => 'Character Introduction',
			'voiceActorC' => ({required Object c}) => 'Voice Actor: ${c}',
			'episodeEN' => ({required Object e, required Object n}) => 'Episode ${e}: ${n}',
			'hotspot' => 'hotspot',
			'completed' => 'Completed',
			'mainCharacter' => 'Main character',
			'supportingCharacter' => 'Supporting character',
			'cameo' => 'Cameo',
			'idleCorner' => 'Idle corner',
			'unknown' => 'Unknown',
			'debugInfo' => 'Debug Info',
			'install' => 'Install',
			'viewOnGithub' => 'View on GitHub',
			'noProxyOverrides' => 'No Proxy Overrides',
			'save' => 'Save',
			'mirror' => 'Mirror',
			'result' => 'Result',
			'all' => 'All',
			'reloadConfigs' => 'Reload Configs',
			'invalidUrlConfig' => 'Invalid url config',
			'inconsistentVersions' => 'Inconsistent versions',
			'noUpdateAvailableForThisArchitectureA' => ({required Object a}) => 'No update available for this architecture (${a})',
			'checkUpdateFailed' => 'Check update failed...',
			'downloadFailed' => 'Download failed',
			'failedToCheckTheHashValuePleaseTryAgain' => 'Failed to check the hash value. Please try again',
			'english' => 'English',
			'dynamicColor' => 'Dynamic color',
			'mondaySchedule' => 'Monday Schedule',
			'tuesdaySchedule' => 'Tuesday Schedule',
			'wednesdaySchedule' => 'Wednesday Schedule',
			'thursdaySchedule' => 'Thursday Schedule',
			'fridaySchedule' => 'Friday Schedule',
			'saturdaySchedule' => 'Saturday Schedule',
			'sundaySchedule' => 'Sunday Schedule',
			'popularityRanking' => 'Popularity Ranking',
			'imageOperations' => 'Image Operations',
			'saveToAlbum' => 'Save to Album',
			'stitchLongImage' => 'Stitch Long Image',
			'stitchHorizontalImage' => 'Stitch Horizontal Image',
			'stitchSubtitles' => 'Stitch Subtitles',
			'saveLongImage' => 'Save Long Image',
			'borderColor' => 'Border Color',
			'conversationTitle' => 'Conversation Title',
			'aiConversation' => 'AI Conversation',
			'topicList' => 'Topic List',
			'startConversationWithAI' => 'Start a conversation with AI',
			'newConversation' => 'New Conversation',
			'inputMessage' => 'Input message...',
			'noTopicsYet' => 'No topics yet',
			'selectAiPersonality' => 'Select AI Personality',
			'apply' => 'Apply',
			'heightPx' => 'Height(px)',
			'setUniformHeight' => 'Set Uniform Height',
			'uniformHeight' => 'Uniform Height',
			'cropImage' => 'Crop Image',
			'finishCropping' => 'Finish Cropping',
			'sortImages' => 'Sort Images',
			'finishSorting' => 'Finish Sorting',
			'noImages' => 'No Images',
			'cropHeightCPx' => ({required Object c}) => 'Crop Height: ${c} px',
			'enterHexColorCode' => 'Enter hex color code, e.g. #FF000000',
			'showImageBorders' => 'Show Image Borders',
			'outerBorderRadius' => 'Outer Border Radius',
			'outerBorderWidth' => 'Outer Border Width',
			'outerBorderColor' => 'Outer Border Color',
			'showOuterBorder' => 'Show Outer Border',
			'innerBorderWidth' => 'Inner Border Width',
			'innerBorderColor' => 'Inner Border Color',
			'borderSettings' => 'Border Settings',
			'saving' => 'Saving',
			'saveSuccessful' => 'Save Successful',
			'saveFailedE' => ({required Object e}) => 'Save Failed: ${e}',
			'failedToLoadImagesOrNoImages' => 'Failed to load images or no images',
			'failedToPickImage' => 'Failed to pick image',
			'monday' => 'Monday',
			'tuesday' => 'Tuesday',
			'wednesday' => 'Wednesday',
			'thursday' => 'Thursday',
			'friday' => 'Friday',
			'saturday' => 'Saturday',
			'sunday' => 'Sunday',
			'defaultOrder' => 'Default Order',
			'byTime' => 'By Time',
			'byName' => 'By Name',
			'recentlyWatched' => 'Recently Watched',
			'localFavoriteBinding' => 'Local Favorite Binding',
			'awful' => 'Awful',
			'terrible' => 'Terrible',
			'bad' => 'Bad',
			'poor' => 'Poor',
			'okay' => 'Okay',
			'fine' => 'Fine',
			'good' => 'Good',
			'great' => 'Great',
			'master' => 'Master',
			'epic' => 'Epic',
			'overview' => 'Overview',
			'discussion' => 'Discussion',
			'logs' => 'Logs',
			'playerDetails' => 'Player Details',
			'status' => 'Status',
			'audioOptionLowLatency' => 'Audio Option: \n Low Latency',
			'audioOptionCompatibility' => 'Audio Option: \n Compatibility',
			'switchSuccessful' => 'Switch Successful',
			'switchFailed' => 'Switch Failed',
			'remoteCast' => 'Remote Cast',
			'copyLink' => 'Copy link',
			'aValidWebDavDirectoryUrl' => 'A valid WebDav directory URL',
			'autoSyncData' => 'Auto Sync Data',
			'screenshotShare' => 'Screenshot Share',
			'bestMatch' => 'Best Match',
			'topRank' => 'Top Rank',
			'mostFavorited' => 'Most Favorited',
			'highestRating' => 'Highest Rating',
			'selectColor' => 'Select Color',
			'colorWheel' => 'Color Wheel',
			'primary' => 'Primary',
			'accent' => 'Accent',
			'custom' => 'Custom',
			'confirmC' => ({required Object c}) => 'Confirm (${c})',
			'selectC' => ({required Object c}) => 'Select ${c}',
			'selectDate' => 'Select Date',
			'startDate' => 'Start Date',
			'endDate' => 'End Date',
			'clearDate' => 'Clear Date',
			'pleaseSelectADate' => 'Please select a date',
			'endDateCannotBeEarlierThanStartDate' => 'End date cannot be earlier than start date',
			'type' => 'Type',
			'background' => 'Background',
			'emotion' => 'Emotion',
			'source' => 'Source',
			'audience' => 'Audience',
			'category' => 'Category',
			'imageOperationsI' => ({required Object i}) => 'Image Operations (${i})',
			'sSelected' => ({required Object s}) => '${s} selected',
			'simplifiedChinese' => 'Simplified Chinese',
			'traditionalChinese' => 'Traditional Chinese',
			'teal' => 'Teal',
			'deepPurple' => 'Deep Purple',
			'yellow' => 'Yellow',
			'cyan' => 'Cyan',
			'm3Default' => 'M3 Default',
			'deepOrange' => 'Deep Orange',
			'indigo' => 'Indigo',
			'cloudyBlue' => 'Cloudy Blue',
			'darkPastelGreen' => 'Dark Pastel Green',
			'dust' => 'Dust',
			'electricLime' => 'Electric Lime',
			'freshGreen' => 'Fresh Green',
			'lightEggplant' => 'Light Eggplant',
			'nastyGreen' => 'Nasty Green',
			'reallyLightBlue' => 'Really Light Blue',
			'tea' => 'Tea',
			'warmPurple' => 'Warm Purple',
			'yellowishTan' => 'Yellowish Tan',
			'cement' => 'Cement',
			'darkGrassGreen' => 'Dark Grass Green',
			'dustyTeal' => 'Dusty Teal',
			'greyTeal' => 'Grey Teal',
			'macaroniAndCheese' => 'Macaroni And Cheese',
			'pinkishTan' => 'Pinkish Tan',
			'spruce' => 'Spruce',
			'strongBlue' => 'Strong Blue',
			_ => null,
		} ?? switch (path) {
			'toxicGreen' => 'Toxic Green',
			'windowsBlue' => 'Windows Blue',
			'blueBlue' => 'Blue Blue',
			'blueWithAHintOfPurple' => 'Blue With A Hint Of Purple',
			'booger' => 'Booger',
			'brightSeaGreen' => 'Bright Sea Green',
			'greenTeal' => 'Green Teal',
			'brownish' => 'Brownish',
			'offGreen' => 'Off Green',
			'tangerine' => 'Tangerine',
			'uglyGreen' => 'Ugly Green',
			'secondary' => 'Secondary',
			'tertiary' => 'Tertiary',
			'surface' => 'Surface',
			'jumpToPage' => 'Jump to page',
			'page' => 'Page',
			'pagePM' => ({required Object p, required Object m}) => 'Page ${p} / ${m}',
			'first' => 'First',
			'last' => 'Last',
			'disableLengthLimitation' => 'Disable Length Limitation',
			'updateLog' => 'Update log',
			'liked' => 'Liked',
			'rating' => 'Rating',
			'pixelFormat' => 'Pixel Format',
			'hwPixelFormat' => 'HW Pixel Format',
			'resolution' => 'Resolution',
			'displayWidth' => 'Display Width',
			'displayHeight' => 'Display Height',
			'aspect' => 'Aspect',
			'pixelAspectRatio' => 'Pixel Aspect Ratio',
			'colormatrix' => 'Colormatrix',
			'colorLevels' => 'Color Levels',
			'primaries' => 'Primaries',
			'gamma' => 'Gamma',
			'signalPeak' => 'Signal Peak',
			'lights' => 'Lights',
			'chromaLocation' => 'Chroma Location',
			'rotate' => 'Rotate',
			'stereoIn' => 'Stereo In',
			'averageBpp' => 'Average Bpp',
			'alpha' => 'Alpha',
			'trackId' => 'Track ID',
			'trackTitle' => 'Track Title',
			'trackLanguage' => 'Track Language',
			'trackImage' => 'Track Image',
			'trackAlbumArt' => 'Track Album Art',
			'trackCodec' => 'Track Codec',
			'trackDecoder' => 'Track Decoder',
			'trackWidth' => 'Track Width',
			'trackHeight' => 'Track Height',
			'trackChannelsCount' => 'Track Channels Count',
			'trackChannels' => 'Track Channels',
			'trackSampleRate' => 'Track Sample Rate',
			'trackFps' => 'Track FPS',
			'trackBitrate' => 'Track Bitrate',
			'trackRotate' => 'Track Rotate',
			'trackPar' => 'Track PAR',
			'trackAudioChannels' => 'Track Audio Channels',
			'format' => 'Format',
			'sampleRate' => 'Sample Rate',
			'channelCount' => 'Channel Count',
			'hrChannels' => 'HR Channels',
			'uriTrack' => 'URI Track',
			'channelsCount' => 'Channels Count',
			'channels' => 'Channels',
			'fps' => 'FPS',
			'bitrate' => 'Bitrate',
			'par' => 'PAR',
			'audioChannels' => 'Audio Channels',
			'audioBitrate' => 'AudioBitrate',
			'audio' => 'Audio',
			'video' => 'Video',
			'media' => 'Media',
			'noLogsForL' => ({required Object l}) => 'No logs for ${l}',
			'onlyValidForThisRun' => 'Only valid for this run',
			'nameField' => 'name',
			'brandField' => 'brand',
			'modelField' => 'model',
			'deviceField' => 'device',
			'productField' => 'product',
			'manufacturerField' => 'manufacturer',
			'versionReleaseField' => 'version_release',
			'versionSdkIntField' => 'version_sdkInt',
			'displayField' => 'display',
			'hardwareField' => 'hardware',
			'physicalRamSizeField' => 'physicalRamSize',
			'availableRamSizeField' => 'availableRamSize',
			'freeDiskSizeField' => 'freeDiskSize',
			'totalDiskSizeField' => 'totalDiskSize',
			'isPhysicalDeviceField' => 'isPhysicalDevice',
			'systemNameField' => 'systemName',
			'systemVersionField' => 'systemVersion',
			'modelNameField' => 'modelName',
			'identifierForVendorField' => 'identifierForVendor',
			'sysnameField' => 'sysname',
			'nodenameField' => 'nodename',
			'releaseField' => 'release',
			'versionField' => 'version',
			'machineField' => 'machine',
			'computerNameField' => 'computerName',
			'numberOfCoresField' => 'numberOfCores',
			'systemMemoryInMegabytesField' => 'systemMemoryInMegabytes',
			'userNameField' => 'userName',
			'majorVersionField' => 'majorVersion',
			'minorVersionField' => 'minorVersion',
			'buildNumberField' => 'buildNumber',
			'displayVersionField' => 'displayVersion',
			'productNameField' => 'productName',
			'registeredOwnerField' => 'registeredOwner',
			'releaseIdField' => 'releaseId',
			'packageNameField' => 'packageName',
			'appNameField' => 'appName',
			'buildSignatureField' => 'buildSignature',
			'installerStoreField' => 'installerStore',
			'installTimeField' => 'installTime',
			'updateTimeField' => 'updateTime',
			'january' => 'January',
			'february' => 'February',
			'march' => 'March',
			'april' => 'April',
			'may' => 'May',
			'june' => 'June',
			'july' => 'July',
			'august' => 'August',
			'september' => 'September',
			'october' => 'October',
			'november' => 'November',
			'december' => 'December',
			'today' => 'Today',
			'yesterday' => 'Yesterday',
			'last3Days' => 'Last 3 Days',
			'last7Days' => 'Last 7 Days',
			'last30Days' => 'Last 30 Days',
			'last3Months' => 'Last 3 Months',
			'last6Months' => 'Last 6 Months',
			'thisYear' => 'This Year',
			'older' => 'Older',
			'markTheSelectedFavoritesAs' => 'Mark the selected favorites as',
			'favoriteType' => 'Favorite Type',
			'doingStatus' => 'Doing',
			'wishStatus' => 'Wish',
			'collectStatus' => 'Collect',
			'onHoldStatus' => 'On Hold',
			'droppedStatus' => 'Dropped',
			'player' => 'Player',
			'audioOption' => 'Audio Option',
			'hardwareDecoding' => 'Hardware Decoding',
			'hardwareDecoder' => 'Hardware decoder',
			'videoRenderer' => 'Video renderer',
			'videoSynchronizationMode' => 'Video synchronization mode',
			'enableNoProxyOverrides' => 'Enable No Proxy Overrides',
			'actor' => 'Actor',
			'dub' => 'Dub',
			'chineseDub' => 'Chinese Dub',
			'japaneseDub' => 'Japanese Dub',
			'englishDub' => 'English Dub',
			'koreanDub' => 'Korean Dub',
			'selectedACharacter' => ({required Object a}) => 'Selected ${a} character',
			'searchOptions' => 'Search Options',
			'searchSources' => 'Search Sources',
			'translation' => 'Translation',
			'translationService' => 'Translation Service',
			'apiKeyCannotBeEmpty' => 'API key cannot be empty',
			'pleaseConfigureApiKeyInAiSettingsFirst' => 'Please configure API key in AI settings first',
			'usage' => 'Usage',
			'editing' => 'Editing',
			'screenshotInProgress' => 'Screenshot in progress...',
			'moveOperationTargetUnknown' => 'Move operation, target unknown',
			'operationUnknown' => 'Operation unknown',
			'pleaseEnterTranslationPrompt' => ({required Object a}) => 'Please enter translation prompt, use ${a} as the placeholder for the target language',
			'thePromptMustContainAPlaceholderForTarget' => ({required Object a}) => 'The prompt must contain ${a} as the placeholder for the target language',
			'thisFieldCannotBeEmpty' => 'This field cannot be empty',
			'thePromptMustContainAPlaceholder' => ({required Object a}) => 'The prompt must contain ${a} placeholder',
			'translationPrompt' => 'Translation Prompt',
			'modelName' => 'Model Name',
			'apiConfiguration' => 'Api Configuration',
			'wordCloud' => 'Word Cloud',
			'statsCalendar' => 'Stats Calendar',
			'todaysRecords' => 'Today\'s Records',
			'dailyStats' => 'Daily Stats',
			'viewAll' => 'View All',
			'kostoriChangelog' => 'Kostori Changelog',
			'copyPath' => 'Copy Path',
			'properties' => 'Properties',
			'noEndpoint' => 'No endpoint',
			'testAll' => 'Test All',
			'customEndpoint' => 'Custom Endpoint',
			'pingTest' => 'Ping Test',
			'continuousPing' => 'Continuous Ping',
			'service' => 'Service',
			'serviceSettings' => 'Service Settings',
			'enableService' => 'Enable Service',
			'serviceIsStopped' => 'Service is stopped',
			'runningOnH' => ({required Object h}) => 'Running on ${h}',
			'apiKey' => 'API Key',
			'activeKey' => 'Active Key',
			'usingFixedKey' => 'Using fixed key',
			'usingRandomKeyRegeneratedOnStartup' => 'Using random key (regenerated on startup)',
			'useFixedKey' => 'Use Fixed Key',
			'keepTheSameKeyAfterRestart' => 'Keep the same key after restart',
			'fixedKey' => 'Fixed Key',
			'leaveEmptyToAutoGenerate' => 'Leave empty to auto-generate',
			'enterFixedKey' => 'Enter fixed key',
			'regenerateRandomKey' => 'Regenerate Random Key',
			'generateANewRandomKeyImmediately' => 'Generate a new random key immediately',
			'regenerate' => 'Regenerate',
			'port' => 'Port',
			'defaultP' => ({required Object p}) => 'Default: ${p}',
			'bindMode' => 'Bind Mode',
			'chooseIpVersionToListenOn' => 'Choose IP version to listen on',
			'hubServer' => 'Hub Server',
			'enableHub' => 'Enable Hub',
			'hubServerIsStopped' => 'Hub server is stopped',
			'clientsCount' => 'clients',
			'hubPort' => 'Hub Port',
			'onlineClients' => 'Online Clients',
			'connectedAt' => 'Connected at',
			'messageHistory' => 'Message History',
			'hubClient' => 'Hub Client',
			'connectToHub' => 'Connect to Hub',
			'connected' => 'Connected',
			'notConnected' => 'Not connected',
			'hubAddress' => 'Hub Address',
			'clientName' => 'Client Name',
			'displayNameInHub' => 'Display name in hub',
			'myDevice' => 'My Device',
			'hubToken' => 'Hub Token',
			'tokenFromTheHubServer' => 'Token from the hub server',
			'pasteHubServerToken' => 'Paste hub server token',
			'runningOn' => 'Running on',
			'online' => 'online',
			'rooms' => 'Rooms',
			'managing' => 'Managing',
			'lobby' => 'Lobby',
			'noRooms' => 'No rooms',
			'current' => 'Current',
			'join' => 'Join',
			'leaveRoom' => 'Leave Room',
			'roomPassword' => 'Room Password',
			'blacklist' => 'Blacklist',
			'bannedCount' => 'banned',
			'noBannedUsers' => 'No banned users',
			'removeFromBlacklist' => 'Remove from Blacklist',
			'addToBlacklist' => 'Add to Blacklist',
			'mute5min' => 'Mute 5min',
			'unmute' => 'Unmute',
			'removeGlobalAdmin' => 'Remove Global Admin',
			'setGlobalAdmin' => 'Set Global Admin',
			'kick' => 'Kick',
			'poke' => 'Poke',
			'banned' => 'Banned',
			'joinedEvent' => 'joined',
			'leftEvent' => 'left',
			'newRoom' => 'New room',
			'portAndBindMode' => 'Port & Bind Mode',
			'hubManagement' => 'Hub Management',
			'chatRoom' => 'Chat Room',
			'openChatDialog' => 'Open chat dialog',
			'hubDetails' => 'Hub Details',
			'connectionSettings' => 'Connection Settings',
			'serverAddress' => 'Server Address',
			'host' => 'Host',
			'authentication' => 'Authentication',
			'paste' => 'Paste',
			'unblock' => 'Unblock',
			'profileAndRoom' => 'Profile & Room',
			'roomSettings' => 'Room Settings',
			'roomName' => 'Room Name',
			'roomId' => 'Room ID',
			'announcements' => 'Announcements',
			'roomAdmins' => 'Room Admins',
			'noAnnouncement' => 'No announcement',
			'setAnnouncement' => 'Set Announcement',
			'enterAnnouncementPrompt' => 'Enter announcement...',
			'removeAdmin' => 'Remove Admin',
			'addRoomAdmin' => 'Add Room Admin',
			'roomBans' => 'Room Bans',
			'banMember' => 'Ban Member',
			'unban' => 'Unban',
			'server' => 'Server',
			'mute' => 'Mute',
			'muteDuration' => 'Mute Duration',
			'secondsLabel' => 'Seconds',
			'serverShutdown' => 'Server shutdown',
			'youAreNowAGlobalAdmin' => 'You are now a global admin',
			'yourGlobalAdminHasBeenRevoked' => 'Your global admin has been revoked',
			'youAreNowARoomAdmin' => 'You are now a room admin',
			'yourRoomAdminHasBeenRevoked' => 'Your room admin has been revoked',
			'youAreMutedFor' => 'You are muted for',
			'secondsUnit' => 'seconds',
			'youHaveBeenUnmuted' => 'You have been unmuted',
			'youAreBannedFromRoom' => 'You are banned from room',
			'youCanNowRejoinRoom' => 'You can now rejoin room',
			'youHaveBeenKickedFromTheRoom' => 'You have been kicked from the room',
			'roomDeletedMovedToLobby' => 'Room deleted, moved to lobby',
			'eventLog' => 'Event Log',
			'pingInterval' => 'Ping Interval',
			'onlineStatus' => 'online',
			'noMessagesYet' => 'No messages yet',
			'newMessages' => 'New messages',
			'reply' => 'Reply',
			'recall' => 'Recall',
			'enterToSend' => 'Enter to send  ·  Ctrl+Enter for newline',
			'messagePlaceholder' => 'Message...',
			'connectionTimedOut' => 'Connection timed out',
			'blockedUsers' => 'Blocked Users',
			'blockedCount' => 'blocked',
			'blocked' => 'blocked',
			'blockedInvites' => 'Blocked Invites',
			'noBlockedInvites' => 'No blocked invites',
			'members' => 'members',
			'notSet' => 'Not set',
			'currentRoom' => 'Current Room',
			'editProfile' => 'Edit Profile',
			'noBlockedUsers' => 'No blocked users',
			'createRoom' => 'Create Room',
			'chat' => 'Chat',
			'noOneOnline' => 'No one online',
			'show' => 'Show',
			'hide' => 'Hide',
			'serverBlacklist' => 'Server Blacklist',
			'userKey' => 'User Key',
			'adminKey' => 'Admin Key',
			'keepTheSameKeysAfterRestart' => 'Keep the same keys after restart',
			'regeneratedOnEveryStartup' => 'Regenerated on every startup',
			'noKeyRequired' => 'No Key Required',
			'anyoneCanConnectWithoutApiKey' => 'Anyone can connect without API key',
			'clientsMustProvideAValidApiKey' => 'Clients must provide a valid API key',
			'endpointMustBeAValidUrl' => 'Endpoint must be a valid http(s) URL',
			'bucketCannotBeEmpty' => 'Bucket cannot be empty',
			'accessKeyIdCannotBeEmpty' => 'Access Key ID cannot be empty',
			'accessKeySecretCannotBeEmpty' => 'Access Key Secret cannot be empty',
			'cdnDomainMustBeAValidUrl' => 'CDN Domain must be a valid URL',
			'maxSizeMustBe1to100Mb' => 'Max size must be 1–100 MB',
			'cleared' => 'Cleared',
			'imageUpload' => 'Image Upload',
			'clientImageUpload' => 'Client Image Upload',
			'serverOss' => 'Server OSS',
			'clientOss' => 'Client OSS',
			'imagesStoredOnServerDisk' => 'Images stored on server disk, served via /hub/files/',
			'serverReceivesAndProxiesImageToOss' => 'Server receives and proxies image to OSS. Keys stay on server.',
			'clientUploadsDirectlyToOss' => 'Client uploads directly to OSS. Server only gets the final URL.',
			'maxSizeMb' => 'Max Size (MB)',
			'storePath' => 'Store Path',
			'leaveEmptyForDefault' => 'Leave empty for default',
			'notConfiguredWillUseServerOrBase64' => 'Not configured · will use server or base64',
			'imageTooLargeToSend' => 'Image too large to send',
			'pleaseConfigureServerUploadOrClientOss' => 'Please configure server upload or client OSS.',
			'stopTheServerToChangeUploadMode' => 'Stop the server to change upload mode',
			'enableClientOss' => 'Enable Client OSS',
			'uploadImagesDirectlyFromClientToOss' => 'Upload images directly from client to OSS',
			'ossNotConfigured' => 'OSS not configured',
			'dropToSendImage' => 'Drop to send image',
			'longPressImageToSave' => 'Long press image to save',
			'pleaseEnterAValidUrl' => 'Please enter a valid URL starting with http:// or https://',
			'setRoomPassword' => 'Set Room Password',
			'adminPanel' => 'Admin Panel',
			'enterRoomName' => 'Enter room name',
			'roomAnnouncement' => 'Room announcement',
			'leaveEmptyForPublicRoom' => 'Leave empty for public room',
			'maxParticipants' => 'Max Participants',
			'upTo' => 'Up to',
			'peopleLabel' => 'people',
			'noLimit' => 'No limit',
			'optional' => 'optional',
			'enterDisplayName' => 'Enter display name',
			'enterBio' => 'Enter bio',
			'autoReconnect' => 'Auto Reconnect',
			'directMessage' => 'Direct Message',
			'noAnnouncementsYet' => 'No announcements yet',
			'enterAnnouncementText' => 'Enter announcement text...',
			'welcomeMessage' => 'Welcome Message',
			'noWelcomeMessage' => 'No welcome message',
			'enterWelcomeMessage' => 'Enter welcome message shown to users who join...',
			'security' => 'Security',
			'changePassword' => 'Change Password',
			'setPassword' => 'Set Password',
			'protectedStatus' => 'Protected',
			'removePassword' => 'Remove Password',
			'enterPasswordToChange' => 'Enter password (leave empty to remove)',
			'noAdminsYet' => 'No admins yet',
			'noBannedMembers' => 'No banned members',
			'noMembersAvailable' => 'No members available',
			'accessControl' => 'Access Control',
			'broadcast' => 'Broadcast',
			'addAnnouncement' => 'Add Announcement',
			'areYouSureYouWantToDeleteR' => ({required Object r}) => 'Are you sure you want to delete ${r}? This cannot be undone.',
			'membersList' => 'Members',
			'onlineUsersList' => 'Online Users',
			'noUsersOnline' => 'No users online',
			'room' => 'Room',
			'noPasswordSet' => 'No password set',
			'passwordProtected' => 'Password protected',
			'imageLabel' => 'Image',
			'stickersLabel' => 'Stickers',
			'pokedYou' => 'poked you',
			'kickedFromServerByP' => ({required Object p}) => 'Kicked from server by ${p}',
			'kickedFromRoomByP' => ({required Object p}) => 'Kicked from room by ${p}',
			'leftTheRoom' => 'left the room',
			'joinedTheRoom' => 'joined the room',
			'pWasKickedByO' => ({required Object p, required Object o}) => '${p} was kicked by ${o}',
			'youLabel' => 'You',
			'leftTheServer' => 'left the server',
			'joinedTheServer' => 'joined the server',
			'updatedTheAnnouncement' => 'updated the announcement',
			'recalledAMessage' => 'recalled a message',
			'pReactedWithO' => ({required Object p, required Object o}) => '${p} reacted with ${o}',
			'pRemovedReactionO' => ({required Object p, required Object o}) => '${p} removed reaction ${o}',
			'noUsersAvailableToInvite' => 'No users available to invite',
			'inviteToRoom' => 'Invite to Room',
			'invite' => 'Invite',
			'invited' => 'invited',
			'roomInvite' => 'Room Invite',
			'invitedYouTo' => 'invited you to',
			'acceptInvite' => 'Accept',
			'acceptedYourInvite' => 'accepted your invite',
			'declinedYourInvite' => 'declined your invite',
			'blockedYourInvites' => 'blocked your invites',
			'blockedInvitesList' => 'Blocked Invites',
			'allowMemberInvites' => 'Allow Member Invites',
			'letAllMembersInviteOthers' => 'Let all members invite others',
			'declineAndBlock' => 'Decline & Block',
			'memes' => 'Memes',
			'memeSaved' => 'Meme saved',
			'networkInfo' => 'Network Info',
			'hubInfo' => 'Hub Info',
			'statsInfo' => 'Stats Info',
			'ratingDetails' => 'Rating Details',
			'sourceInfo' => 'Source Info',
			'playerInfo' => 'Player Info',
			'hideLabel' => 'Hide',
			'showLabel' => 'Show',
			'personaManagement' => 'Persona Management',
			'promptConfiguration' => 'Prompt Configuration',
			'systemPrompt' => 'System Prompt',
			'temperature' => 'Temperature',
			'promptSaved' => 'Prompt saved',
			'editSystemPrompt' => 'Edit System Prompt',
			'noHistoryYet' => 'No history yet',
			'clearAll' => 'Clear All',
			'configCopiedToClipboard' => 'Config copied to clipboard',
			'importedAsNewConfig' => 'Imported as new config',
			'imported' => 'Imported',
			'invalidClipboardFormat' => 'Invalid clipboard format',
			'cannotModifySystemPreset' => 'Cannot modify system preset',
			'animeCardUseBlur' => '番剧卡片使用模糊背景',
			'calendarFetchEpisodes' => '每日番剧表启动时搜寻集信息',
			'addKeyword' => 'Add keyword',
			'keyword' => 'Keyword',
			'keywordAlreadyExists' => 'Keyword already exists',
			'folderNameCannotBeEmpty' => 'Folder name cannot be empty',
			'folderNameTooLong' => 'Folder name is too long',
			'folderAlreadyExists' => 'Folder already exists',
			'configKeyAlreadyExists' => 'Config Key already exists. Please change it.',
			'requiredField' => 'Required',
			'configKey' => 'Config Key',
			'memoField' => 'Memo',
			'valueRange' => 'Value: 0.0 - 1.0',
			'readOnlySystemPreset' => 'Read-only System Preset',
			'deleteConfig' => 'Delete Config',
			'areYouSureYouWantToDeleteGeneric' => 'Are you sure you want to delete',
			'baseUrl' => 'Base URL',
			'optionalField' => 'Optional',
			'model' => 'Model',
			'addModel' => 'Add Model',
			'modelId' => 'Model ID',
			'displayName' => 'Display Name',
			'noModelsAddOneAbove' => 'No models. Add one above.',
			'placeholdersDescription' => ({required Object animeCount, required Object animeNames, required Object topTags}) => 'Placeholders: ${animeCount} ${animeNames} ${topTags}',
			'aiHub' => 'AI Hub',
			'selectYearAndMonth' => 'Select Year & Month',
			'enterYear' => 'Enter Year',
			'selectDay' => 'Select Day',
			'fullYear' => 'Full Year',
			'quickSelect' => 'Quick Select',
			'selectDateRange' => 'Select Date Range',
			'subject' => 'Subject',
			'character' => 'Character',
			'person' => 'Person',
			'manualSelect' => 'Manual Select',
			'qrAndClipboard' => 'QR & Clipboard',
			'go' => 'Go',
			'clipboard' => 'Clipboard',
			'recognizeFromGallery' => 'Recognize from Gallery',
			'scanQrCode' => 'Scan QR Code',
			'scanToJump' => 'Scan to Jump',
			'qrCode' => 'QR Code',
			'shareMethodDescription' => 'Share method: In anime/Bangumi page, click share → generate token or QR code',
			'shareQrCode' => 'Share QR Code',
			'exporting' => 'Exporting...',
			'tokenCopiedToClipboard' => 'Token copied to clipboard',
			'generateQrCodeShare' => 'Generate QR Code to Share',
			'aiSettings' => 'AI Settings',
			'aiConfigMissing' => 'AI Config Missing',
			'generating' => 'Generating...',
			'generatedTags' => 'Generated Tags',
			'exportScreenshot' => 'Export Screenshot',
			'copyAll' => 'Copy all',
			'timeRange' => 'Time Range',
			'thisWeek' => 'This Week',
			'thisMonth' => 'This Month',
			'generateSummary' => 'Generate Summary',
			'generateTag' => 'Generate Tag',
			'summaryReport' => 'Summary Report',
			'noActivityInTimeRange' => 'No activity in this time range',
			'weeklySummary' => 'Weekly Summary',
			'monthlySummary' => 'Monthly Summary',
			'tagCopied' => 'Tag copied',
			'aiServiceConfig' => 'AI Service Configuration',
			'connectionDisconnected' => 'Connection to server disconnected',
			'enterServerAddress' => 'Please enter server address',
			'tapToShare' => 'Tap to share',
			_ => null,
		} ?? switch (path) {
			'noConfigurationsFound' => 'No configurations found',
			'noData' => 'No data',
			'loginWithPasswordIsDisabled' => 'Login with password is disabled',
			'cannotBeEmpty' => 'Cannot be empty',
			'invalidCookies' => 'Invalid cookies',
			'webviewIsNotAvailable' => 'Webview is not available',
			'sources' => 'Sources',
			'translationFailedPleaseTryAgainLater' => 'Translation failed, please try again later',
			'writeYourReview' => 'Write your review',
			'draft' => 'Draft',
			'content' => 'Content',
			'toggle' => 'Toggle',
			'roomBan' => 'Room Ban',
			'pinnedMessages' => 'Pinned Messages',
			'announcement' => 'Announcement',
			'image' => 'Image',
			'enterToSendCtrlEnterForNewline' => 'Enter to send  ·  Ctrl+Enter for newline',
			'message' => 'Message...',
			'stickers' => 'Stickers',
			'noStickersYet' => 'No stickers yet',
			'removeSticker' => 'Remove sticker',
			'noSearchSources' => 'No search sources',
			'pleaseAddSomeSources' => 'Please add some sources',
			'manage' => 'Manage',
			'importPersona' => 'Import Persona',
			'newPersona' => 'New Persona',
			'notConfigured' => 'Not configured',
			'enabled' => 'Enabled',
			'required' => 'Required',
			'linkFormatErrorCannotParseAnimeInfo' => 'Link format error, cannot parse anime info',
			'sourceNotFoundPleaseConfirmSourceInstalled' => 'Source not found, please confirm source is installed',
			'linkFormatErrorCannotParseBangumiId' => 'Link format error, cannot parse Bangumi ID',
			'fetchingBangumiInfo' => 'Fetching Bangumi info...',
			'bangumiEntryNotFound' => 'Bangumi entry not found',
			'failedToFetchBangumiInfo' => 'Failed to fetch Bangumi info',
			'linkFormatErrorCannotParseCharacterId' => 'Link format error, cannot parse character ID',
			'verifyingCharacterInfo' => 'Verifying character info...',
			'characterNotFound' => 'Character not found',
			'failedToFetchCharacterInfo' => 'Failed to fetch character info',
			'linkFormatErrorCannotParsePersonId' => 'Link format error, cannot parse person ID',
			'verifyingPersonInfo' => 'Verifying person info...',
			'personNotFound' => 'Person not found',
			'failedToFetchPersonInfo' => 'Failed to fetch person info',
			'unrecognizedLink' => 'Unrecognized link',
			'noKostoriLinkFoundInClipboard' => 'No Kostori link found in clipboard',
			'qrCodeFeatureOnlyOnMobile' => 'QR code feature only available on mobile',
			'unrecognizedKostoriProtocol' => 'Unrecognized Kostori protocol',
			'pleaseDragImageFile' => 'Please drag in image file',
			'imageDownloadFailed' => 'Image download failed',
			'failedToFetchNetworkImage' => 'Failed to fetch network image',
			'imageDecodeFailed' => 'Image decode failed',
			'noQrCodeFoundInImage' => 'No QR code found in image',
			'copiedToClipboard' => 'Copied to clipboard',
			'likeSuccess' => 'Like success',
			'unlikeSuccess' => 'Unlike success',
			'operationSuccess' => 'Operation success',
			'saveSuccess' => 'Save success',
			'saveFailed' => 'Save failed',
			'saveFailedWithError' => ({required Object e}) => 'Save failed: ${e}',
			'loadSuccess' => 'Load success',
			'addressAlreadyExists' => 'Address already exists',
			'pleaseEnableAtLeastOneAddress' => 'Please enable at least one address',
			'requestFailed' => 'Request failed',
			'allCopiedSuccess' => 'All copied success',
			'bindBangumiIdSuccess' => 'Bangumi ID bound successfully',
			'applySuccess' => 'Apply success',
			'noChanges' => 'No changes',
			'applyFailed' => 'Apply failed',
			'noResultsTryOtherKeywords' => 'No results found, please try other keywords',
			'jumping' => 'Jumping...',
			'queryFailed' => 'Query failed',
			'screenshotSuccess' => 'Screenshot success',
			'screenshotFailed' => 'Screenshot failed',
			'noRecordForMonth' => ({required Object month}) => 'No record for ${month}',
			'screenshotFailedPleaseRetry' => 'Screenshot failed, please retry',
			'shareFailed' => 'Share failed',
			'connectionFailed' => 'Connection failed',
			'copySuccess' => 'Copy success',
			'addToFavoritesSuccess' => 'Add to favorites success',
			'deleteFailed' => 'Delete failed',
			'savingImage' => 'Saving image...',
			'saveFailedPermission' => 'Save failed: permission or directory error',
			'bangumiDataUpdateFailed' => 'Bangumi data update failed...',
			'bangumiDataResetFailed' => 'Bangumi data reset failed...',
			'playingNextEpisode' => 'Playing next episode',
			'failedToLoadEpisode' => 'Failed to load episode',
			'noMoreEpisodes' => 'No more episodes to play',
			'routeNotFound' => 'Route not found',
			'loadingDuplicateEpisode' => 'Loading duplicate episode',
			'getVideoUrlFailed' => 'Failed to get video URL',
			'startSearch' => 'Start search',
			'dlnaError' => 'DLNA error',
			'pleaseEnterEpisodeNumber' => 'Please enter episode number',
			'pleaseEnterValidEpisodeNumber' => 'Please enter a valid episode number between 1-999',
			_ => null,
		};
	}
}

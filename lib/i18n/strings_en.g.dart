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

	/// en: 'Add to Unsorted'
	String get addToDefault => 'Add to Unsorted';

	/// en: 'Remove from favorites'
	String get removeFromFavorites => 'Remove from favorites';

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

	/// en: 'bangumi'
	String get bangumiPlan => 'bangumi';

	/// en: 'Switch Favorite User'
	String get switchFavoriteUser => 'Switch Favorite User';

	/// en: 'Enter Bangumi User Name'
	String get enterBangumiUserName => 'Enter Bangumi User Name';

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

	/// en: 'Add repository'
	String get addRepo => 'Add repository';

	/// en: 'Repositories'
	String get repo => 'Repositories';

	/// en: 'Repo URL: http(s) link or local index.json path (file://)'
	String get repoUrlHint => 'Repo URL: http(s) link or local index.json path (file://)';

	/// en: 'No sources in this repository'
	String get repoEmpty => 'No sources in this repository';

	/// en: 'All'
	String get filterAll => 'All';

	/// en: 'No matching sources'
	String get noMatchingSource => 'No matching sources';

	/// en: '${count} sources'
	String sourceCount({required Object count}) => '${count} sources';

	/// en: 'Others'
	String get filterNonBangumi => 'Others';

	/// en: 'Default'
	String get sortByDefault => 'Default';

	/// en: 'Ascending'
	String get sortAsc => 'Ascending';

	/// en: 'Descending'
	String get sortDesc => 'Descending';

	/// en: 'Name'
	String get sortByName => 'Name';

	/// en: 'ID'
	String get sortById => 'ID';

	/// en: 'Switch source'
	String get switchSource => 'Switch source';

	/// en: 'Search this title on other sources'
	String get searchSourceHint => 'Search this title on other sources';

	/// en: 'Needs verification'
	String get needVerification => 'Needs verification';

	/// en: 'Tap to verify'
	String get tapToVerify => 'Tap to verify';

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

	/// en: 'Anime Details'
	String get bangumiInfo => 'Anime Details';

	/// en: 'Block'
	String get block => 'Block';

	/// en: 'Super Resolution'
	String get superResolution => 'Super Resolution';

	/// en: 'Off'
	String get superResolutionOff => 'Off';

	/// en: 'Efficiency'
	String get superResolutionEfficiency => 'Efficiency';

	/// en: 'Quality'
	String get superResolutionQuality => 'Quality';

	/// en: 'Glimmer Mode'
	String get glimmerMode => 'Glimmer Mode';

	/// en: 'On'
	String get glimmerModeOn => 'On';

	/// en: 'Off'
	String get glimmerModeOff => 'Off';

	/// en: 'Blue'
	String get blue => 'Blue';

	/// en: 'Brief'
	String get brief => 'Brief';

	/// en: 'Masonry'
	String get masonry => 'Masonry';

	/// en: 'Poster'
	String get poster => 'Poster';

	/// en: 'Follow global default'
	String get sourceDisplayModeReset => 'Follow global default';

	/// en: 'Follow source default'
	String get followSourceDefault => 'Follow source default';

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

	/// en: 'Hub Uploaded Images'
	String get hubUploadedImages => 'Hub Uploaded Images';

	/// en: 'image(s) stored on this device'
	String get hubUploadedImagesHint => 'image(s) stored on this device';

	/// en: 'No uploaded images'
	String get noHubUploads => 'No uploaded images';

	/// en: 'Delete all Hub uploaded images?'
	String get clearHubUploadsConfirm => 'Delete all Hub uploaded images?';

	/// en: 'Hub Stickers'
	String get hubStickers => 'Hub Stickers';

	/// en: 'sticker(s)'
	String get hubStickersHint => 'sticker(s)';

	/// en: 'No stickers'
	String get noHubStickers => 'No stickers';

	/// en: 'Delete all Hub stickers?'
	String get clearHubStickersConfirm => 'Delete all Hub stickers?';

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
	String get continueText => 'Continue';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Enter captcha code'
	String get captchaHint => 'Enter captcha code';

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

	/// en: 'anime'
	String get animes => 'anime';

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

	/// en: 'Import all'
	String get importAll => 'Import all';

	/// en: 'Import selected'
	String get importSelected => 'Import selected';

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

	/// en: 'Account'
	String get account => 'Account';

	/// en: 'Log'
	String get log => 'Log';

	/// en: 'Manual Translation'
	String get manualTranslation => 'Manual Translation';

	/// en: 'Translate text into your preferred language'
	String get manualTranslationHint => 'Translate text into your preferred language';

	/// en: 'Enter text to translate'
	String get enterTextToTranslate => 'Enter text to translate';

	/// en: 'Translate'
	String get translate => 'Translate';

	/// en: 'Translation failed'
	String get translationFailed => 'Translation failed';

	/// en: 'Translating...'
	String get translating => 'Translating...';

	/// en: 'Auto-detect'
	String get autoDetect => 'Auto-detect';

	/// en: 'Source language'
	String get sourceLanguage => 'Source language';

	/// en: 'Target language'
	String get targetLanguage => 'Target language';

	/// en: 'Enter text above and tap Translate to see the result here'
	String get noTranslationYet => 'Enter text above and tap Translate to see the result here';

	/// en: 'Plugin Modules'
	String get pluginModules => 'Plugin Modules';

	/// en: 'Add Plugin'
	String get addPlugin => 'Add Plugin';

	/// en: 'Edit Plugin'
	String get editPlugin => 'Edit Plugin';

	/// en: 'No plugin modules yet, tap + to add one'
	String get noPluginsYet => 'No plugin modules yet, tap + to add one';

	/// en: 'Built-in plugins cannot be deleted'
	String get builtinPluginCannotDelete => 'Built-in plugins cannot be deleted';

	/// en: 'Icon (emoji)'
	String get pluginIcon => 'Icon (emoji)';

	/// en: 'Description'
	String get pluginDescription => 'Description';

	/// en: 'Prompt'
	String get pluginPrompt => 'Prompt';

	/// en: 'The prompt defines what this module does. The text you type is sent as the input; leave empty to use a generic prompt.'
	String get pluginPromptHint => 'The prompt defines what this module does. The text you type is sent as the input; leave empty to use a generic prompt.';

	/// en: 'Processing...'
	String get processing => 'Processing...';

	/// en: 'Run'
	String get run => 'Run';

	/// en: 'Output'
	String get output => 'Output';

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

	/// en: 'Custom Loading Image'
	String get playerLoadingImage => 'Custom Loading Image';

	/// en: 'Enter image path or data: base64 (GIF/PNG/JPG/WebP)'
	String get inputImagePath => 'Enter image path or data: base64 (GIF/PNG/JPG/WebP)';

	/// en: 'Loading video'
	String get loadingVideo => 'Loading video';

	/// en: 'Open Log'
	String get openLog => 'Open Log';

	/// en: 'Open anime'
	String get openAnime => 'Open anime';

	/// en: 'Anime source "${source}" is not installed. Add it in Source settings to open this anime'
	String sourceNotInstalled({required Object source}) => 'Anime source "${source}" is not installed. Add it in Source settings to open this anime';

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

	/// en: 'Staff'
	String get staffList => 'Staff';

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

	/// en: 'Last sync'
	String get lastSyncTime => 'Last sync';

	/// en: 'Never synced'
	String get neverSynced => 'Never synced';

	/// en: 'Configured'
	String get configured => 'Configured';

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

	/// en: 'This Week Total'
	String get weekTotal => 'This Week Total';

	/// en: 'Today Total'
	String get todayTotal => 'Today Total';

	/// en: 'Broadcasting Today'
	String get todayBroadcast => 'Broadcasting Today';

	/// en: 'Active Days'
	String get broadcastDays => 'Active Days';

	/// en: 'Generated by Kostori v${version}'
	String generatedBy({required Object version}) => 'Generated by Kostori v${version}';

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

	/// en: 'Unsorted'
	String get kDefault => 'Unsorted';

	/// en: 'Default: ${v}'
	String defaultValue({required Object v}) => 'Default: ${v}';

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

	/// en: 'Plugins'
	String get mePagePlugin => 'Plugins';

	/// en: 'No plugins (put *.js into plugins folder)'
	String get noMePagePlugin => 'No plugins (put *.js into plugins folder)';

	/// en: 'Open Folder'
	String get openDir => 'Open Folder';

	/// en: 'Create Plugin'
	String get createPlugin => 'Create Plugin';

	/// en: 'Plugin Source URL'
	String get pluginSourceUrl => 'Plugin Source URL';

	/// en: 'Fetch Plugins'
	String get fetchPlugins => 'Fetch Plugins';

	/// en: 'Plugin file name'
	String get pluginName => 'Plugin file name';

	/// en: 'already exists'
	String get alreadyExists => 'already exists';

	/// en: 'Main Content'
	String get mainContent => 'Main Content';

	/// en: 'Switch'
	String get switchh => 'Switch';

	/// en: 'Failed to load, please try again.'
	String get failedToLoadPleaseTryAgain => 'Failed to load, please try again.';

	/// en: 'Failed to open'
	String get failedToOpen => 'Failed to open';

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

	/// en: 'Cloudflare verification required'
	String get cloudflareVerificationRequired => 'Cloudflare verification required';

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

	/// en: 'First image shown at full height'
	String get firstImageFullHeight => 'First image shown at full height';

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

	/// en: 'Select Images'
	String get selectImages => 'Select Images';

	/// en: 'Add Images'
	String get addImages => 'Add Images';

	/// en: 'Imported ${i} image(s)'
	String importedCountI({required Object i}) => 'Imported ${i} image(s)';

	/// en: 'Copy / Share'
	String get exportImage => 'Copy / Share';

	/// en: 'Save & Share'
	String get saveAndShare => 'Save & Share';

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

	/// en: 'Playing next episode'
	String get watcherPlayingNext => 'Playing next episode';

	/// en: 'Failed to load episode: ${error}'
	String watcherEpisodeLoadError({required Object error}) => 'Failed to load episode: ${error}';

	/// en: 'No more episodes to play'
	String get watcherNoMoreEpisodes => 'No more episodes to play';

	/// en: 'Route not found'
	String get watcherRouteNotFound => 'Route not found';

	/// en: 'Episode already loaded'
	String get watcherDuplicateEpisode => 'Episode already loaded';

	/// en: 'Estimating…'
	String get vceEstimating => 'Estimating…';

	/// en: 'Reload preview clip'
	String get vceReloadPreview => 'Reload preview clip';

	/// en: 'Reload'
	String get vceReload => 'Reload';

	/// en: 'Reload current episode'
	String get reloadEpisode => 'Reload current episode';

	/// en: 'Video timeline thumbnails'
	String get vceTimelineThumbnails => 'Video timeline thumbnails';

	/// en: 'Start'
	String get vceStart => 'Start';

	/// en: 'End'
	String get vceEnd => 'End';

	/// en: 'Modify start'
	String get vceModifyStart => 'Modify start';

	/// en: 'Modify end'
	String get vceModifyEnd => 'Modify end';

	/// en: 'Supported formats: 90, 01:30, 1.5...'
	String get vceTimeFormatHint => 'Supported formats: 90, 01:30, 1.5...';

	/// en: 'Plain numbers are treated as seconds'
	String get vcePureNumberIsSeconds => 'Plain numbers are treated as seconds';

	/// en: 'Export settings'
	String get vceExportSettings => 'Export settings';

	/// en: 'Quality (CRF)'
	String get vceQualityCrf => 'Quality (CRF)';

	/// en: 'High quality'
	String get vceHighQuality => 'High quality';

	/// en: 'Standard'
	String get vceStandard => 'Standard';

	/// en: 'Compressed'
	String get vceCompressed => 'Compressed';

	/// en: 'Original'
	String get vceOriginal => 'Original';

	/// en: 'Fixed bitrate (optional, overrides CRF)'
	String get vceFixedBitrateOptional => 'Fixed bitrate (optional, overrides CRF)';

	/// en: 'Fixed bitrate ${kbps}kbps'
	String vceFixedBitrateKbps({required Object kbps}) => 'Fixed bitrate  ${kbps}kbps';

	/// en: 'Include audio'
	String get vceIncludeAudio => 'Include audio';

	/// en: 'Frame rate ${fps} fps'
	String vceFrameRate({required Object fps}) => 'Frame rate  ${fps} fps';

	/// en: 'Palette colors ${n} (fewer = smaller)'
	String vcePaletteColors({required Object n}) => 'Palette colors  ${n}  (fewer = smaller)';

	/// en: '${n} colors'
	String vceColorCount({required Object n}) => '${n} colors';

	/// en: 'Enable dithering (better quality, slightly larger)'
	String get vceEnableDithering => 'Enable dithering (better quality, slightly larger)';

	/// en: 'WebP quality ${n}'
	String vceWebpQuality({required Object n}) => 'WebP quality  ${n}';

	/// en: 'with audio'
	String get vceWithAudio => 'with audio';

	/// en: 'no audio'
	String get vceWithoutAudio => 'no audio';

	/// en: 'dithering on'
	String get vceDitherOn => 'dithering on';

	/// en: 'dithering off'
	String get vceDitherOff => 'dithering off';

	/// en: 'H.264 · ${bitrate}kbps · ${audio}'
	String vceH264Summary({required Object bitrate, required Object audio}) => 'H.264 · ${bitrate}kbps · ${audio}';

	/// en: 'H.264 · CRF ${crf} · ${audio}'
	String vceH264CrfSummary({required Object crf, required Object audio}) => 'H.264 · CRF ${crf} · ${audio}';

	/// en: 'GIF · ${fps} fps · ${colors} colors · ${dither} · ${audio}'
	String vceGifSummary({required Object fps, required Object colors, required Object dither, required Object audio}) => 'GIF · ${fps} fps · ${colors} colors · ${dither} · ${audio}';

	/// en: 'APNG · ${fps} fps · ${audio} · browser friendly'
	String vceApngSummary({required Object fps, required Object audio}) => 'APNG · ${fps} fps · ${audio} · browser friendly';

	/// en: 'WebP · ${fps} fps · quality ${quality} · smallest size'
	String vceWebpSummary({required Object fps, required Object quality}) => 'WebP · ${fps} fps · quality ${quality} · smallest size';

	/// en: 'Crop'
	String get vceCrop => 'Crop';

	/// en: 'Aspect ratio presets'
	String get vceAspectPresets => 'Aspect ratio presets';

	/// en: 'Hide crop overlay'
	String get vceHideCropOverlay => 'Hide crop overlay';

	/// en: 'Show crop overlay (draggable)'
	String get vceShowCropOverlay => 'Show crop overlay (draggable)';

	/// en: 'When enabled you can drag to select the export area'
	String get vceCropDragHint => 'When enabled you can drag to select the export area';

	/// en: '${w}×${h}px start(${x}, ${y}) [${pct}]'
	String vceCropInfo({required Object w, required Object h, required Object x, required Object y, required Object pct}) => '${w}×${h}px  start(${x}, ${y})  [${pct}]';

	/// en: 'Details & Logs'
	String get watcherDetailsLogs => 'Details & Logs';

	/// en: 'Mini window'
	String get watcherMiniWindow => 'Mini window';

	/// en: 'Drag to adjust clip range'
	String get rangePickerDragHint => 'Drag to adjust clip range';

	/// en: 'Start watching'
	String get bangumiStartWatch => 'Start watching';

	/// en: 'Last seen: episode ${episode}'
	String bangumiLastSeen({required Object episode}) => 'Last seen: episode ${episode}';

	/// en: 'My rating: ${score}'
	String bangumiMyRating({required Object score}) => 'My rating: ${score}';

	/// en: 'Watching'
	String get animeWatching => 'Watching';

	/// en: 'Completed'
	String get animeCompleted => 'Completed';

	/// en: 'Dropped'
	String get animeDropped => 'Dropped';

	/// en: '${n} watching'
	String animeWatchingCount({required Object n}) => '${n} watching';

	/// en: '${n} completed'
	String animeCompletedCount({required Object n}) => '${n} completed';

	/// en: '${n} dropped'
	String animeDroppedCount({required Object n}) => '${n} dropped';

	/// en: 'Air date: ${date}'
	String animeAirDate({required Object date}) => 'Air date: ${date}';

	/// en: 'Send failed: ${error}'
	String remoteSendFailed({required Object error}) => 'Send failed: ${error}';

	/// en: '@ Mention'
	String get hubAiBotTriggerMention => '@ Mention';

	/// en: 'Prefix'
	String get hubAiBotTriggerPrefix => 'Prefix';

	/// en: 'Keyword'
	String get hubAiBotTriggerKeyword => 'Keyword';

	/// en: 'All'
	String get hubAiBotTriggerAll => 'All';

	/// en: 'AI Assistant'
	String get hubAiBotDefaultName => 'AI Assistant';

	/// en: 'Add tag'
	String get addTag => 'Add tag';

	/// en: '${month}'
	String searchMonthSuffix({required Object month}) => '${month}';

	/// en: '${month} ${year}'
	String searchYearMonth({required Object month, required Object year}) => '${month} ${year}';

	/// en: '${n} times'
	String searchUseCount({required Object n}) => '${n} times';

	/// en: 'Add address'
	String get addAddress => 'Add address';

	/// en: 'No addresses'
	String get noAddress => 'No addresses';

	/// en: 'New chat ${time}'
	String newChatTitle({required Object time}) => 'New chat ${time}';

	/// en: 'Auto'
	String get auto => 'Auto';

	/// en: 'Short'
	String get lengthShort => 'Short';

	/// en: 'Medium'
	String get lengthMedium => 'Medium';

	/// en: 'Delete ${n} images'
	String deleteImagesCount({required Object n}) => 'Delete ${n} images';

	/// en: 'No search results'
	String get noSearchResults => 'No search results';

	/// en: '${n} items'
	String itemsCount({required Object n}) => '${n} items';

	/// en: 'Enable skipping Bangumi schedule'
	String get enableSkipBangumiSchedule => 'Enable skipping Bangumi schedule';

	/// en: 'Client ID'
	String get bangumiClientId => 'Client ID';

	/// en: 'Client Secret'
	String get bangumiClientSecret => 'Client Secret';

	/// en: 'Register an app on bgm.tv/dev to get the client ID and secret'
	String get bangumiOAuthHint => 'Register an app on bgm.tv/dev to get the client ID and secret';

	/// en: 'Bangumi Login'
	String get bangumiOAuthLogin => 'Bangumi Login';

	/// en: 'Show NSFW content'
	String get bangumiShowNsfw => 'Show NSFW content';

	/// en: 'Logging in...'
	String get bangumiLoggingIn => 'Logging in...';

	/// en: 'Logout'
	String get bangumiOAuthLogout => 'Logout';

	/// en: 'Logged in'
	String get bangumiLoggedIn => 'Logged in';

	/// en: 'Not logged in'
	String get bangumiNotLoggedIn => 'Not logged in';

	/// en: 'Login successful'
	String get bangumiLoginSuccess => 'Login successful';

	/// en: 'Login failed'
	String get bangumiLoginFailed => 'Login failed';

	/// en: 'Incorrect captcha or password, please retry'
	String get bangumiCaptchaOrPasswordError => 'Incorrect captcha or password, please retry';

	/// en: 'Tap the captcha image or refresh button to change it'
	String get bangumiCaptchaHint => 'Tap the captcha image or refresh button to change it';

	/// en: 'Token status'
	String get bangumiTokenStatus => 'Token status';

	/// en: 'Refresh token'
	String get bangumiRefreshToken => 'Refresh token';

	/// en: 'User ID'
	String get bangumiUserId => 'User ID';

	/// en: 'Expires'
	String get bangumiTokenExpires => 'Expires';

	/// en: 'Expired'
	String get bangumiTokenExpired => 'Expired';

	/// en: 'Token refreshed'
	String get bangumiTokenRefreshSuccess => 'Token refreshed';

	/// en: 'Token refresh failed'
	String get bangumiTokenRefreshFailed => 'Token refresh failed';

	/// en: 'Please fill in the client ID first'
	String get bangumiClientIdSecretRequired => 'Please fill in the client ID first';

	/// en: 'Failed to read image, please retry'
	String get recognizeImageFailed => 'Failed to read image, please retry';

	/// en: 'Recognition failed'
	String get recognizeFailed => 'Recognition failed';

	/// en: 'New chat'
	String get newChat => 'New chat';

	/// en: 'episode ${n}'
	String recognizeEpisodeSuffix({required Object n}) => 'episode ${n}';

	/// en: 'I uploaded a screenshot. Recognition result: 《${title}》${episode} (${from} → ${to}, similarity ${similarity}). Please introduce this anime.'
	String recognizePrompt({required Object title, required Object episode, required Object from, required Object to, required Object similarity}) => 'I uploaded a screenshot. Recognition result: 《${title}》${episode} (${from} → ${to}, similarity ${similarity}). Please introduce this anime.';

	/// en: ' · ${n} steps'
	String aiStepsSuffix({required Object n}) => ' · ${n} steps';

	/// en: 'Comments'
	String get bangumiCommentsTitle => 'Comments';

	/// en: 'Markdown rendering'
	String get aiExtMarkdown => 'Markdown rendering';

	/// en: 'Whether to enable Markdown in reply bubbles'
	String get aiExtMarkdownHint => 'Whether to enable Markdown in reply bubbles';

	/// en: 'Image understanding'
	String get aiExtImageUnderstanding => 'Image understanding';

	/// en: 'Whether to allow sending images to the model'
	String get aiExtImageUnderstandingHint => 'Whether to allow sending images to the model';

	/// en: 'Player is not open'
	String get lanPlayerNotOpen => 'Player is not open';

	/// en: 'No episode info'
	String get lanNoEpisodes => 'No episode info';

	/// en: 'This device is being remotely controlled'
	String get lanBeingControlled => 'This device is being remotely controlled';

	/// en: 'Desktop connected and can control this device'
	String get lanDesktopConnected => 'Desktop connected and can control this device';

	/// en: 'Disconnect'
	String get lanDisconnect => 'Disconnect';

	/// en: 'Network self-test'
	String get lanSelfTest => 'Network self-test';

	/// en: 'Cancel connection'
	String get lanCancelConnect => 'Cancel connection';

	/// en: 'IP address'
	String get lanIpHint => 'IP address';

	/// en: 'Port'
	String get lanPortHint => 'Port';

	/// en: 'Manual connect'
	String get lanManualConnect => 'Manual connect';

	/// en: 'Device name'
	String get lanDeviceName => 'Device name';

	/// en: 'Leave empty to use default name'
	String get lanNameEmptyHint => 'Leave empty to use default name';

	/// en: 'Name shown when other devices discover this device'
	String get lanNameDisplayHint => 'Name shown when other devices discover this device';

	/// en: 'Port must be between 1024-65535'
	String get lanPortRangeError => 'Port must be between 1024-65535';

	/// en: 'This week'
	String get summaryThisWeek => 'This week';

	/// en: 'This month'
	String get summaryThisMonth => 'This month';

	/// en: 'This week summary'
	String get summaryThisWeekTitle => 'This week summary';

	/// en: 'This month summary'
	String get summaryThisMonthTitle => 'This month summary';

	/// en: 'Soul profile'
	String get soulProfileTitle => 'Soul profile';

	/// en: 'Playback complete'
	String get vtPlaybackComplete => 'Playback complete';

	/// en: 'Replay'
	String get vtReplay => 'Replay';

	/// en: 'Enter playback link…'
	String get vtInputUrlHint => 'Enter playback link…';

	/// en: 'Load'
	String get vtLoad => 'Load';

	/// en: 'Request Headers'
	String get vtHeaders => 'Request Headers';

	/// en: 'No headers, click "Add" to create one'
	String get vtNoHeaders => 'No headers, click "Add" to create one';

	/// en: 'No request headers'
	String get playerNoRequestHeaders => 'No request headers';

	/// en: 'Apply and load'
	String get vtApplyAndLoad => 'Apply and load';

	/// en: 'Main title (Anime name)'
	String get downloadMainTitle => 'Main title (Anime name)';

	/// en: 'Ignore episode titles'
	String get downloadIgnoreEpisodeTitle => 'Ignore episode titles';

	/// en: 'Some episode titles are meaningless (e.g. 1 / video); when on, use episode numbers for file names'
	String get downloadIgnoreEpisodeTitleDesc => 'Some episode titles are meaningless (e.g. 1 / video); when on, use episode numbers for file names';

	/// en: 'Merging'
	String get downloadMerging => 'Merging';

	/// en: 'Rational'
	String get aiTagRational => 'Rational';

	/// en: 'Humorous'
	String get aiTagHumorous => 'Humorous';

	/// en: 'Sarcastic'
	String get aiTagSarcastic => 'Sarcastic';

	/// en: 'Gentle'
	String get aiTagGentle => 'Gentle';

	/// en: 'Rigorous'
	String get aiTagRigorous => 'Rigorous';

	/// en: 'Passionate'
	String get aiTagPassionate => 'Passionate';

	/// en: 'Calm'
	String get aiTagCalm => 'Calm';

	/// en: 'Aloof'
	String get aiTagCool => 'Aloof';

	/// en: 'Energetic'
	String get aiTagEnergetic => 'Energetic';

	/// en: 'Chuunibyou'
	String get aiTagChuuni => 'Chuunibyou';

	/// en: 'Scheming'
	String get aiTagCunning => 'Scheming';

	/// en: 'Friendly'
	String get aiTagFriendly => 'Friendly';

	/// en: 'Formal'
	String get aiToneFormal => 'Formal';

	/// en: 'Concise'
	String get aiToneConcise => 'Concise';

	/// en: 'Natural'
	String get aiToneNatural => 'Natural';

	/// en: 'General assistant'
	String get aiPersonaGeneral => 'General assistant';

	/// en: 'Reliable and friendly, always happy to help users solve problems clearly and logically.'
	String get aiPersonaGeneralDesc => 'Reliable and friendly, always happy to help users solve problems clearly and logically.';

	/// en: 'Senior engineer'
	String get aiPersonaEngineer => 'Senior engineer';

	/// en: 'Proficient in many programming languages and mainstream frameworks, skilled at code review, debugging and architecture design.'
	String get aiPersonaEngineerDesc => 'Proficient in many programming languages and mainstream frameworks, skilled at code review, debugging and architecture design.';

	/// en: 'Life butler'
	String get aiPersonaButler => 'Life butler';

	/// en: 'Thoughtful and meticulous life assistant, familiar with daily scheduling, healthy eating and travel planning.'
	String get aiPersonaButlerDesc => 'Thoughtful and meticulous life assistant, familiar with daily scheduling, healthy eating and travel planning.';

	/// en: 'Writing inspiration'
	String get aiPersonaWriter => 'Writing inspiration';

	/// en: 'Imaginative wordsmith, good at novels, essays, copywriting and creative brainstorming.'
	String get aiPersonaWriterDesc => 'Imaginative wordsmith, good at novels, essays, copywriting and creative brainstorming.';

	/// en: 'Knowledge advisor'
	String get aiPersonaAdvisor => 'Knowledge advisor';

	/// en: 'Erudite and rigorous, good at explaining concepts, answering questions and deep research.'
	String get aiPersonaAdvisorDesc => 'Erudite and rigorous, good at explaining concepts, answering questions and deep research.';

	/// en: 'Caring friend'
	String get aiPersonaFriend => 'Caring friend';

	/// en: 'Warm and close, listens, accompanies and encourages like a friend.'
	String get aiPersonaFriendDesc => 'Warm and close, listens, accompanies and encourages like a friend.';

	/// en: 'Recognizing QR code in image…'
	String get qrRecognizing => 'Recognizing QR code in image…';

	/// en: 'Place the QR code in the frame to scan'
	String get qrScanHint => 'Place the QR code in the frame to scan';

	/// en: 'Network request failed'
	String get networkRequestFailed => 'Network request failed';

	/// en: 'No anime this day'
	String get calNoAnimeToday => 'No anime this day';

	/// en: 'Refresh status'
	String get calRefreshStatus => 'Refresh status';

	/// en: 'Screenshot & save'
	String get calScreenshotSave => 'Screenshot & save';

	/// en: 'Loading schedule data...'
	String get calLoadingSchedule => 'Loading schedule data...';

	/// en: 'Data not updated yet (´;ω;`)'
	String get calDataNotUpdated => 'Data not updated yet (´;ω;`)';

	/// en: 'Screenshot preview'
	String get calScreenshotPreview => 'Screenshot preview';

	/// en: 'This week'
	String get calThisWeek => 'This week';

	/// en: 'Today'
	String get calToday => 'Today';

	/// en: 'Loading image...'
	String get calLoadingImage => 'Loading image...';

	/// en: 'Generating screenshot...'
	String get calGeneratingScreenshot => 'Generating screenshot...';

	/// en: '${month}/${day}'
	String calDateDay({required Object month, required Object day}) => '${month}/${day}';

	/// en: 'Voice cast'
	String get personTabVoice => 'Voice cast';

	/// en: 'Comments'
	String get personTabChat => 'Comments';

	/// en: 'Character relations'
	String get personTabRelation => 'Character relations';

	/// en: 'Producer info'
	String get personTabStaffInfo => 'Producer info';

	/// en: 'Works'
	String get personTabWorks => 'Works';

	/// en: 'Character profile'
	String get personTabProfile => 'Character profile';

	/// en: 'Person'
	String get personSubtitle => 'Person';

	/// en: 'UDP broadcast port is used for device discovery, WebSocket port for remote control'
	String get lanUdpPortHint => 'UDP broadcast port is used for device discovery, WebSocket port for remote control';

	/// en: 'Multicast address (multi-threaded broadcast)'
	String get lanMulticastTitle => 'Multicast address (multi-threaded broadcast)';

	/// en: 'Enter a valid multicast address (224.0.0.0 - 239.255.255.255)'
	String get lanMulticastInvalid => 'Enter a valid multicast address (224.0.0.0 - 239.255.255.255)';

	/// en: 'Multicast (multi-threaded broadcast) is used for discovery; a custom address can bypass router/firewall filtering of the default multicast address'
	String get lanMulticastHint => 'Multicast (multi-threaded broadcast) is used for discovery; a custom address can bypass router/firewall filtering of the default multicast address';

	/// en: 'Connection PIN verification'
	String get lanPinTitle => 'Connection PIN verification';

	/// en: '4-6 digits'
	String get lanPinLengthHint => '4-6 digits';

	/// en: 'Enter a 4-6 digit PIN'
	String get lanPinInvalid => 'Enter a 4-6 digit PIN';

	/// en: 'When enabled, other devices must enter this PIN to connect'
	String get lanPinEnableHint => 'When enabled, other devices must enter this PIN to connect';

	/// en: 'Self-test failed: ${error}'
	String lanSelfTestFailed({required Object error}) => 'Self-test failed: ${error}';

	/// en: 'Device: ${platform} UDP port: ${udpPort} Discovery: ${state}'
	String lanSelfTestDetail({required Object platform, required Object udpPort, required Object state}) => 'Device: ${platform}  UDP port: ${udpPort}  Discovery: ${state}';

	/// en: 'PIN verification: ${status}'
	String lanPinStatus({required Object status}) => 'PIN verification: ${status}';

	/// en: 'Enabled'
	String get lanEnabled => 'Enabled';

	/// en: 'Disabled'
	String get lanDisabled => 'Disabled';

	/// en: 'Retest'
	String get lanRetest => 'Retest';

	/// en: 'Troubleshooting: both devices on the same Wi-Fi/router; disable 'AP isolation/client isolation' on the router; both on the latest code.'
	String get lanTroubleshoot => 'Troubleshooting: both devices on the same Wi-Fi/router; disable \'AP isolation/client isolation\' on the router; both on the latest code.';

	/// en: 'Status'
	String get status => 'Status';

	/// en: 'DLNA Error'
	String get dlnaError => 'DLNA Error';

	/// en: 'Start searching'
	String get startSearching => 'Start searching';

	/// en: 'Searching for devices…'
	String get searchingDevices => 'Searching for devices…';

	/// en: 'No devices found'
	String get noDevicesFound => 'No devices found';

	/// en: 'Trying to cast to'
	String get tryingToCast => 'Trying to cast to';

	/// en: 'DLNA exception'
	String get dlnaException => 'DLNA exception';

	/// en: 'Audio Option: Low Latency'
	String get audioOptionLowLatency => 'Audio Option: \n Low Latency';

	/// en: 'Audio Option: Compatibility'
	String get audioOptionCompatibility => 'Audio Option: \n Compatibility';

	/// en: 'Audio Output Device'
	String get audioOutputDevice => 'Audio Output Device';

	/// en: 'No audio device detected'
	String get noAudioDevice => 'No audio device detected';

	/// en: 'Volume Boost'
	String get volumeBoost => 'Volume Boost';

	/// en: 'Volume Boost: On'
	String get volumeBoostEnabled => 'Volume Boost: On';

	/// en: 'Volume Boost: Off'
	String get volumeBoostDisabled => 'Volume Boost: Off';

	/// en: 'Volume'
	String get volume => 'Volume';

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

	late final Translations$colors$en colors = Translations$colors$en.internal(_root);

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

	/// en: 'Invalid page'
	String get invalidPage => 'Invalid page';

	/// en: 'Unknown error'
	String get unknownError => 'Unknown error';

	/// en: 'loadPage and loadNext can't be null at the same time'
	String get loadPageAndLoadNextCantBeNull => 'loadPage and loadNext can\'t be null at the same time';

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

	/// en: 'Low-latency audio'
	String get audioOption => 'Low-latency audio';

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

	/// en: 'CV'
	String get cv => 'CV';

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

	/// en: 'All'
	String get searchGroupAll => 'All';

	/// en: 'Bangumi'
	String get searchGroupBangumi => 'Bangumi';

	/// en: 'Default'
	String get searchGroupDefault => 'Default';

	/// en: 'Choose Search Source'
	String get chooseSearchSource => 'Choose Search Source';

	/// en: 'Single Source'
	String get singleSourceSearch => 'Single Source';

	/// en: 'Built-in groups'
	String get searchGroupBuiltIn => 'Built-in groups';

	/// en: 'My groups'
	String get searchGroupCustom => 'My groups';

	/// en: 'Manage Groups'
	String get manageGroups => 'Manage Groups';

	/// en: 'New Group'
	String get newGroup => 'New Group';

	/// en: 'Group Name'
	String get groupName => 'Group Name';

	/// en: 'Group name already exists'
	String get groupExists => 'Group name already exists';

	/// en: 'Sources in group'
	String get groupSources => 'Sources in group';

	/// en: 'Assign sources'
	String get assignSources => 'Assign sources';

	/// en: 'Delete Group'
	String get deleteGroup => 'Delete Group';

	/// en: 'Delete this group?'
	String get deleteGroupConfirm => 'Delete this group?';

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

	/// en: 'Failed to start Hub server'
	String get hubServerStartFailed => 'Failed to start Hub server';

	/// en: 'Enable HTTPS/WSS'
	String get enableTls => 'Enable HTTPS/WSS';

	/// en: 'Hub will serve over HTTPS/WSS (requires certificate)'
	String get tlsEnabledDesc => 'Hub will serve over HTTPS/WSS (requires certificate)';

	/// en: 'Hub serves over HTTP/WS'
	String get tlsDisabledDesc => 'Hub serves over HTTP/WS';

	/// en: 'TLS Certificate'
	String get tlsCertificate => 'TLS Certificate';

	/// en: 'PEM certificate chain (Let's Encrypt: fullchain.pem)'
	String get tlsCertificateHint => 'PEM certificate chain (Let\'s Encrypt: fullchain.pem)';

	/// en: 'TLS Private Key'
	String get tlsPrivateKey => 'TLS Private Key';

	/// en: 'PEM private key file path'
	String get tlsPrivateKeyHint => 'PEM private key file path';

	/// en: 'TLS Key Password'
	String get tlsPassword => 'TLS Key Password';

	/// en: 'Leave empty if the key is not encrypted'
	String get tlsPasswordHint => 'Leave empty if the key is not encrypted';

	/// en: 'Browse'
	String get browse => 'Browse';

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

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';

	/// en: 'Saved Servers'
	String get savedServers => 'Saved Servers';

	/// en: 'No saved servers yet'
	String get noSavedServers => 'No saved servers yet';

	/// en: 'Save Current Config'
	String get saveCurrentConfig => 'Save Current Config';

	/// en: 'Server Name'
	String get serverName => 'Server Name';

	/// en: 'Select a server'
	String get selectServer => 'Select a server';

	/// en: 'Export Rooms'
	String get exportRooms => 'Export Rooms';

	/// en: 'Import Rooms'
	String get importRooms => 'Import Rooms';

	/// en: 'Danmaku Settings'
	String get danmakuSettings => 'Danmaku Settings';

	/// en: 'Color'
	String get danmakuColor => 'Color';

	/// en: 'Font Size'
	String get danmakuFontSize => 'Font Size';

	/// en: 'Opacity'
	String get danmakuOpacity => 'Opacity';

	/// en: 'Display Area'
	String get danmakuArea => 'Display Area';

	/// en: 'Duration'
	String get danmakuDuration => 'Duration';

	/// en: 'Line Height'
	String get danmakuLineHeight => 'Line Height';

	/// en: 'Danmaku'
	String get danmaku => 'Danmaku';

	/// en: 'Watch Together'
	String get watchTogether => 'Watch Together';

	/// en: 'The watch-together room is not bound to an anime'
	String get watchTogetherRoomHasNoAnime => 'The watch-together room is not bound to an anime';

	/// en: 'Watch anime with friends, create or join a room to chat and share screenshots and subtitles.'
	String get watchTogetherDesc => 'Watch anime with friends, create or join a room to chat and share screenshots and subtitles.';

	/// en: 'Select a room to start watching together'
	String get selectRoomToStart => 'Select a room to start watching together';

	/// en: 'Sync to Owner'
	String get syncToOwner => 'Sync to Owner';

	/// en: 'Synced to owner progress'
	String get syncedToOwner => 'Synced to owner progress';

	/// en: 'Owner is not sharing progress'
	String get ownerNotSharing => 'Owner is not sharing progress';

	/// en: 'You are not watching "${title}". Open this anime first to sync'
	String syncRequiresSameAnime({required Object title}) => 'You are not watching "${title}". Open this anime first to sync';

	/// en: 'You are the owner, sharing playback progress'
	String get sharingAsOwner => 'You are the owner, sharing playback progress';

	/// en: 'Episode ${n}'
	String episodeNEp({required Object n}) => 'Episode ${n}';

	/// en: 'Join Watch Together Room'
	String get joinHubRoom => 'Join Watch Together Room';

	/// en: 'Join a watch together room'
	String get hubRoomInvite => 'Join a watch together room';

	/// en: 'Join ${room} to watch together'
	String hubRoomInviteWithRoom({required Object room}) => 'Join ${room} to watch together';

	/// en: 'Invalid watch-together room link'
	String get invalidHubRoomLink => 'Invalid watch-together room link';

	/// en: 'Connecting to Hub...'
	String get connectingToHub => 'Connecting to Hub...';

	/// en: 'Joined the room'
	String get joinedRoom => 'Joined the room';

	/// en: 'Share Room QR Code'
	String get shareRoomQr => 'Share Room QR Code';

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

	/// en: 'Forward ${s} s'
	String seekForward({required Object s}) => 'Forward ${s} s';

	/// en: 'Backward ${s} s'
	String seekBackward({required Object s}) => 'Backward ${s} s';

	/// en: 'Not yet aired'
	String get notBroadcast => 'Not yet aired';

	/// en: 'items'
	String get items => 'items';

	/// en: 'WS Bot Connections'
	String get wsBotConnections => 'WS Bot Connections';

	/// en: 'Subscription Management'
	String get subscriptionManagement => 'Subscription Management';

	/// en: 'Add subscription'
	String get addSubscription => 'Add subscription';

	/// en: 'No subscriptions. Tap + in the top-right to add.'
	String get noSubscriptions => 'No subscriptions. Tap + in the top-right to add.';

	/// en: 'Connection type'
	String get connectionType => 'Connection type';

	/// en: 'WS Forward (Hub listens)'
	String get wsForward => 'WS Forward (Hub listens)';

	/// en: 'WS Reverse (connect to target)'
	String get wsReverse => 'WS Reverse (connect to target)';

	/// en: 'Webhook (URL push)'
	String get webhookConnection => 'Webhook (URL push)';

	/// en: 'HTTP Server (listen)'
	String get httpServer => 'HTTP Server (listen)';

	/// en: 'Forward'
	String get forward => 'Forward';

	/// en: 'Reverse'
	String get reverse => 'Reverse';

	/// en: 'Listen address'
	String get listenAddress => 'Listen address';

	/// en: 'Listen port'
	String get listenPort => 'Listen port';

	/// en: 'Target URL'
	String get targetUrl => 'Target URL';

	/// en: 'Heartbeat interval (ms, optional)'
	String get heartbeat => 'Heartbeat interval (ms, optional)';

	/// en: 'token (optional)'
	String get token => 'token (optional)';

	/// en: 'Note'
	String get note => 'Note';

	/// en: 'Running'
	String get running => 'Running';

	/// en: 'Stopped'
	String get stopped => 'Stopped';

	/// en: 'Hub connects to your bot's WebSocket server as a client and pushes room messages / system events in real time. The bot maintains a WS listener to receive them.'
	String get wsBotDescription => 'Hub connects to your bot\'s WebSocket server as a client and pushes room messages / system events in real time. The bot maintains a WS listener to receive them.';

	/// en: 'Bot WebSocket URL'
	String get wsBotUrl => 'Bot WebSocket URL';

	/// en: 'Handshake Secret (optional)'
	String get wsBotSecret => 'Handshake Secret (optional)';

	/// en: 'Message Events'
	String get wsBotMessageEvents => 'Message Events';

	/// en: 'System Events'
	String get wsBotSystemEvents => 'System Events';

	/// en: 'Reverse: Bot connects to Hub'
	String get wsReverseTitle => 'Reverse: Bot connects to Hub';

	/// en: 'The bot can also connect to this Hub as a WebSocket client: ws://${host}/hub, then authenticate with the Hub API Key (type: auth, token: <key>). This gives full two-way messaging. See HUB_BOT_API.md for the protocol.'
	String wsReverseInfo({required Object host}) => 'The bot can also connect to this Hub as a WebSocket client: ws://${host}/hub, then authenticate with the Hub API Key (type: auth, token: <key>). This gives full two-way messaging. See HUB_BOT_API.md for the protocol.';

	/// en: 'Hub Management'
	String get hubManagement => 'Hub Management';

	/// en: 'Chat Room'
	String get chatRoom => 'Chat Room';

	/// en: 'Room Type'
	String get roomType => 'Room Type';

	/// en: 'Webhooks'
	String get webhooks => 'Webhooks';

	/// en: 'Inbound Webhooks'
	String get inboundWebhooks => 'Inbound Webhooks';

	/// en: 'Outbound Webhooks'
	String get outboundWebhooks => 'Outbound Webhooks';

	/// en: 'Create Webhook'
	String get createWebhook => 'Create Webhook';

	/// en: 'Webhook Name'
	String get webhookName => 'Webhook Name';

	/// en: 'Webhook URL'
	String get webhookUrl => 'Webhook URL';

	/// en: 'Webhook Secret (HMAC-SHA256)'
	String get webhookSecret => 'Webhook Secret (HMAC-SHA256)';

	/// en: 'Send a POST request with {"text": "..."} to push a message to the room:'
	String get webhookUsageHint => 'Send a POST request with {"text": "..."} to push a message to the room:';

	/// en: 'Message Events'
	String get webhookMessageEvents => 'Message Events';

	/// en: 'System Events'
	String get webhookSystemEvents => 'System Events';

	/// en: 'No webhooks configured'
	String get noWebhooks => 'No webhooks configured';

	/// en: 'AI Companion Bot'
	String get hubAiBot => 'AI Companion Bot';

	/// en: 'Enable AI Bot'
	String get hubAiBotEnabled => 'Enable AI Bot';

	/// en: 'Enabled'
	String get hubAiBotStatus => 'Enabled';

	/// en: 'Disabled'
	String get hubAiBotStatusDisabled => 'Disabled';

	/// en: 'Configure'
	String get hubAiBotConfigure => 'Configure';

	/// en: 'Name, provider, model & persona'
	String get hubAiBotConfigureDesc => 'Name, provider, model & persona';

	/// en: 'AI Companion Bot Settings'
	String get hubAiBotConfigTitle => 'AI Companion Bot Settings';

	/// en: 'Bot Name'
	String get hubAiBotName => 'Bot Name';

	/// en: 'AI Provider'
	String get hubAiBotProvider => 'AI Provider';

	/// en: 'e.g. deepseek'
	String get hubAiBotProviderHint => 'e.g. deepseek';

	/// en: 'Provider source key in AI settings. Must have an enabled API key.'
	String get hubAiBotProviderHelper => 'Provider source key in AI settings. Must have an enabled API key.';

	/// en: 'Model (optional)'
	String get hubAiBotModel => 'Model (optional)';

	/// en: 'Leave empty for provider default'
	String get hubAiBotModelHint => 'Leave empty for provider default';

	/// en: 'Use provider default model'
	String get hubAiBotModelDefault => 'Use provider default model';

	/// en: 'Persona / System Prompt'
	String get hubAiBotSystemPrompt => 'Persona / System Prompt';

	/// en: 'Context messages'
	String get hubAiBotContextMessages => 'Context messages';

	/// en: 'Trigger Mode'
	String get hubAiBotTriggerMode => 'Trigger Mode';

	/// en: 'Trigger pattern'
	String get hubAiBotTriggerPattern => 'Trigger pattern';

	/// en: 'e.g.'
	String get hubAiBotKeywordHint => 'e.g.';

	/// en: 'Min reply interval (s)'
	String get hubAiBotMinInterval => 'Min reply interval (s)';

	/// en: 'Reply to private messages'
	String get hubAiBotReplyDm => 'Reply to private messages';

	/// en: 'Satori Bot Management'
	String get satoriBotManage => 'Satori Bot Management';

	/// en: 'Third-party Satori bots'
	String get satoriBotManageDesc => 'Third-party Satori bots';

	/// en: 'bot(s)'
	String get satoriBotCountUnit => 'bot(s)';

	/// en: 'Add Bot'
	String get satoriBotAdd => 'Add Bot';

	/// en: 'Edit Bot'
	String get satoriBotEdit => 'Edit Bot';

	/// en: 'Delete Bot'
	String get satoriBotDelete => 'Delete Bot';

	/// en: 'Bot Name'
	String get satoriBotName => 'Bot Name';

	/// en: 'Display name shown in the room member list and @ mentions'
	String get satoriBotNameHint => 'Display name shown in the room member list and @ mentions';

	/// en: 'Avatar'
	String get satoriBotAvatar => 'Avatar';

	/// en: 'Biography'
	String get satoriBotBio => 'Biography';

	/// en: 'Connection Token'
	String get satoriBotToken => 'Connection Token';

	/// en: 'The token used by the Satori client to connect and bind to this bot'
	String get satoriBotTokenHint => 'The token used by the Satori client to connect and bind to this bot';

	/// en: 'Regenerate'
	String get satoriBotTokenRegen => 'Regenerate';

	/// en: 'Enabled'
	String get satoriBotEnabled => 'Enabled';

	/// en: 'Delete this bot? Connected clients will be disconnected.'
	String get satoriBotDeleteConfirm => 'Delete this bot? Connected clients will be disconnected.';

	/// en: 'Token copied'
	String get satoriBotTokenCopied => 'Token copied';

	/// en: 'Satori Bot'
	String get satoriBotConfigTitle => 'Satori Bot';

	/// en: 'Web Admin Settings'
	String get webAdminSettings => 'Web Admin Settings';

	/// en: 'What is Web Admin?'
	String get webAdminWhatIs => 'What is Web Admin?';

	/// en: 'The Web Admin provides a browser-based dashboard for managing the Hub. Open the address in any device browser to view server status, manage rooms & clients, browse logs, edit config, control the AI bot & webhooks, and restart the Hub. It uses the existing Hub API Key for authentication.'
	String get webAdminDescription => 'The Web Admin provides a browser-based dashboard for managing the Hub. Open the address in any device browser to view server status, manage rooms & clients, browse logs, edit config, control the AI bot & webhooks, and restart the Hub. It uses the existing Hub API Key for authentication.';

	/// en: 'Available Features'
	String get webAdminFeatures => 'Available Features';

	/// en: 'Status overview'
	String get webAdminFeatureOverview => 'Status overview';

	/// en: 'Rooms & sending messages'
	String get webAdminFeatureRooms => 'Rooms & sending messages';

	/// en: 'Online clients'
	String get webAdminFeatureClients => 'Online clients';

	/// en: 'Logs'
	String get webAdminFeatureLogs => 'Logs';

	/// en: 'Configuration'
	String get webAdminFeatureConfig => 'Configuration';

	/// en: 'AI bot'
	String get webAdminFeatureAi => 'AI bot';

	/// en: 'Webhooks'
	String get webAdminFeatureWebhooks => 'Webhooks';

	/// en: 'Restart Hub'
	String get webAdminFeatureRestart => 'Restart Hub';

	/// en: 'Web Admin Dashboard'
	String get webAdminDashboard => 'Web Admin Dashboard';

	/// en: 'Enable Web Admin'
	String get webAdminEnabled => 'Enable Web Admin';

	/// en: 'Port'
	String get webAdminOnPort => 'Port';

	/// en: 'Web Admin Port'
	String get webAdminPort => 'Web Admin Port';

	/// en: 'Open in browser'
	String get webAdminUrl => 'Open in browser';

	/// en: 'Restart Hub to apply'
	String get restartHubToApply => 'Restart Hub to apply';

	/// en: 'Watching: ${a}'
	String watchingAnime({required Object a}) => 'Watching: ${a}';

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

	/// en: 'Protocol'
	String get protocol => 'Protocol';

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

	/// en: 'Upload avatar'
	String get uploadAvatar => 'Upload avatar';

	/// en: 'Avatar'
	String get avatar => 'Avatar';

	/// en: 'Connect to a server first to upload an avatar'
	String get connectFirstToUploadAvatar => 'Connect to a server first to upload an avatar';

	/// en: 'Avatar uploaded'
	String get avatarUploaded => 'Avatar uploaded';

	/// en: 'Upload failed'
	String get uploadFailed => 'Upload failed';

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

	/// en: 'Max upload size must be 1–100 MB'
	String get maxSizeMustBe1to100Mb => 'Max upload size must be 1–100 MB';

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

	/// en: 'Max Upload Size (MB)'
	String get maxSizeMb => 'Max Upload Size (MB)';

	/// en: 'Store Path'
	String get storePath => 'Store Path';

	/// en: 'Leave empty for default'
	String get leaveEmptyForDefault => 'Leave empty for default';

	/// en: 'Public Base URL'
	String get publicBaseUrl => 'Public Base URL';

	/// en: 'External base address for uploaded images (public IPv4/IPv6 or domain); leave empty to use connection address'
	String get publicBaseUrlHint => 'External base address for uploaded images (public IPv4/IPv6 or domain); leave empty to use connection address';

	/// en: 'Public IP detected'
	String get publicIpDetected => 'Public IP detected';

	/// en: 'Failed to detect public IP'
	String get publicIpDetectFailed => 'Failed to detect public IP';

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

	/// en: 'Display name is required'
	String get displayNameRequired => 'Display name is required';

	/// en: 'Enter bio'
	String get enterBio => 'Enter bio';

	/// en: 'Auto Reconnect'
	String get autoReconnect => 'Auto Reconnect';

	/// en: 'Allow Self-signed Certificate'
	String get allowSelfSignedCert => 'Allow Self-signed Certificate';

	/// en: 'Trust self-signed certificates when connecting over WSS'
	String get allowSelfSignedCertHint => 'Trust self-signed certificates when connecting over WSS';

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

	/// en: 'Log Privacy Protection'
	String get logPrivacyProtection => 'Log Privacy Protection';

	/// en: 'Mask tokens, keys, passwords and other sensitive info in logs'
	String get logPrivacyProtectionDesc => 'Mask tokens, keys, passwords and other sensitive info in logs';

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

	/// en: 'Anime Card Use Blur Background'
	String get animeCardUseBlur => 'Anime Card Use Blur Background';

	/// en: 'Show anime card overlay'
	String get showAnimeCardOverlay => 'Show anime card overlay';

	/// en: 'Card Title Marquee'
	String get tileTitleMarquee => 'Card Title Marquee';

	/// en: 'Horizontal Layout'
	String get horizontalLayout => 'Horizontal Layout';

	/// en: 'Anime Card Per Row'
	String get bangumiCardPerRow => 'Anime Card Per Row';

	/// en: 'Auto'
	String get bangumiCardPerRowAuto => 'Auto';

	/// en: 'Fetch episode info on daily anime table startup'
	String get calendarFetchEpisodes => 'Fetch episode info on daily anime table startup';

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

	/// en: 'tokens'
	String get tokens => 'tokens';

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

	/// en: 'Auxiliary Task Models'
	String get auxModelSettings => 'Auxiliary Task Models';

	/// en: 'Provider'
	String get auxProviderSelection => 'Provider';

	/// en: 'Follow session provider'
	String get auxFollowSession => 'Follow session provider';

	/// en: 'This task will use the provider configured in the current chat session.'
	String get auxFollowSessionHint => 'This task will use the provider configured in the current chat session.';

	/// en: 'Context Compression'
	String get contextCompression => 'Context Compression';

	/// en: 'Follow-up Suggestions'
	String get followUpSuggestions => 'Follow-up Suggestions';

	/// en: 'Auto Title'
	String get autoTitle => 'Auto Title';

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

	/// en: 'The AI translation provider does not support your current region. Please switch provider or use a different network'
	String get translationErrorRegionNotSupported => 'The AI translation provider does not support your current region. Please switch provider or use a different network';

	/// en: 'The configured model is not supported by this provider. Please change it in AI settings'
	String get translationErrorModelNotSupported => 'The configured model is not supported by this provider. Please change it in AI settings';

	/// en: 'The API key is invalid or lacks permission. Please check it in AI settings'
	String get translationErrorApiKeyInvalid => 'The API key is invalid or lacks permission. Please check it in AI settings';

	/// en: 'Too many requests or insufficient quota. Please try again later'
	String get translationErrorRateLimited => 'Too many requests or insufficient quota. Please try again later';

	/// en: 'Translation request failed'
	String get translationErrorRequestFailed => 'Translation request failed';

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

	/// en: 'Invalid number'
	String get invalidNumber => 'Invalid number';

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

	/// en: 'This anime is not bound to a Bangumi entry'
	String get notBoundToBangumi => 'This anime is not bound to a Bangumi entry';

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

	/// en: 'Deleted'
	String get deleteSuccessful => 'Deleted';

	/// en: 'This cannot be undone'
	String get confirmDeleteImageHint => 'This cannot be undone';

	/// en: 'Delete this AI provider configuration?'
	String get confirmDeleteAiProvider => 'Delete this AI provider configuration?';

	/// en: 'No tag data'
	String get noTagData => 'No tag data';

	/// en: 'Authentication Required'
	String get authenticationRequired => 'Authentication Required';

	/// en: 'Please authenticate to continue'
	String get pleaseAuthenticate => 'Please authenticate to continue';

	/// en: 'Shut Down'
	String get shutDown => 'Shut Down';

	/// en: 'Uploading data...'
	String get uploadingData => 'Uploading data...';

	/// en: 'Glimmer mode: on'
	String get glimmerModeEnabled => 'Glimmer mode: on';

	/// en: 'Glimmer mode: off'
	String get glimmerModeDisabled => 'Glimmer mode: off';

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

	/// en: 'Please enter episode number'
	String get pleaseEnterEpisodeNumber => 'Please enter episode number';

	/// en: 'Please enter a valid episode number between 1-999'
	String get pleaseEnterValidEpisodeNumber => 'Please enter a valid episode number between 1-999';

	/// en: 'Title'
	String get imageTitle => 'Title';

	/// en: 'Subtitle'
	String get imageSubtitle => 'Subtitle';

	/// en: 'Select Background'
	String get selectBackground => 'Select Background';

	/// en: 'Change Background'
	String get changeBackground => 'Change Background';

	/// en: 'Clear Background'
	String get clearBackground => 'Clear Background';

	/// en: '${count} chars'
	String charCount({required Object count}) => '${count} chars';

	/// en: 'M3u8 Ad Filter'
	String get m3u8AdFilter => 'M3u8 Ad Filter';

	/// en: 'Enable Ad Filter'
	String get enableAdFilter => 'Enable Ad Filter';

	/// en: 'Filter Rules'
	String get filterRules => 'Filter Rules';

	/// en: 'Ad Filter Rules'
	String get adFilterRules => 'Ad Filter Rules';

	/// en: 'Add Rule'
	String get addRule => 'Add Rule';

	/// en: 'Rule Name'
	String get ruleName => 'Rule Name';

	/// en: 'URL Regex'
	String get urlRegex => 'URL Regex';

	/// en: 'Domain Block'
	String get domainBlock => 'Domain Block';

	/// en: 'Duration Filter'
	String get durationFilter => 'Duration Filter';

	/// en: 'Tag Mark'
	String get tagMark => 'Tag Mark';

	/// en: 'Regex pattern, e.g. preroll|/ads?/'
	String get regexHint => 'Regex pattern, e.g. preroll|/ads?/';

	/// en: 'Domains, separated by commas'
	String get domainHint => 'Domains, separated by commas';

	/// en: 'Seconds, e.g. 4.0'
	String get durationHint => 'Seconds, e.g. 4.0';

	/// en: 'e.g. #EXT-X-CUE-OUT'
	String get tagHint => 'e.g. #EXT-X-CUE-OUT';

	/// en: 'CUE Ad Tag'
	String get cueAdTag => 'CUE Ad Tag';

	/// en: 'Ultra Short Segment'
	String get ultraShortSegment => 'Ultra Short Segment';

	/// en: 'Common Ad URL Pattern'
	String get commonAdUrlPattern => 'Common Ad URL Pattern';

	/// en: 'Keyword Match'
	String get keywordMatch => 'Keyword Match';

	/// en: 'Substring, e.g. advert or adservice'
	String get keywordHint => 'Substring, e.g. advert or adservice';

	/// en: 'Common Ad Keyword'
	String get commonAdKeyword => 'Common Ad Keyword';

	/// en: 'Video Details'
	String get videoDetails => 'Video Details';

	/// en: 'Synopsis'
	String get synopsis => 'Synopsis';

	/// en: 'Current Episode'
	String get currentEpisode => 'Current Episode';

	/// en: 'Playback Route'
	String get playbackRoute => 'Playback Route';

	/// en: 'Progress'
	String get progress => 'Progress';

	/// en: 'Playback Speed'
	String get playbackSpeed => 'Playback Speed';

	/// en: 'Other Settings'
	String get otherSettings => 'Other Settings';

	/// en: 'Audio: Low Latency'
	String get audioLowLatency => 'Audio: Low Latency';

	/// en: 'Audio: Compatibility'
	String get audioCompatibility => 'Audio: Compatibility';

	/// en: 'Video Clip Editor'
	String get videoClipEditor => 'Video Clip Editor';

	/// en: 'Start Time'
	String get clipStartTime => 'Start Time';

	/// en: 'End Time'
	String get clipEndTime => 'End Time';

	/// en: 'Duration'
	String get clipDuration => 'Duration';

	/// en: 'Preview'
	String get previewClip => 'Preview';

	/// en: 'Export'
	String get exportClip => 'Export';

	/// en: 'Export Format'
	String get exportFormat => 'Export Format';

	/// en: 'Export Quality'
	String get exportQuality => 'Export Quality';

	/// en: 'Export Size'
	String get exportSize => 'Export Size';

	/// en: 'Crop Area'
	String get cropArea => 'Crop Area';

	/// en: 'Select Crop Area'
	String get selectCropArea => 'Select Crop Area';

	/// en: 'Full Frame'
	String get fullFrame => 'Full Frame';

	/// en: 'Custom Crop'
	String get customCrop => 'Custom Crop';

	/// en: 'Low Quality'
	String get qualityLow => 'Low Quality';

	/// en: 'Medium Quality'
	String get qualityMedium => 'Medium Quality';

	/// en: 'High Quality'
	String get qualityHigh => 'High Quality';

	/// en: 'GIF Export'
	String get gifExport => 'GIF Export';

	/// en: 'APNG Export'
	String get apngExport => 'APNG Export';

	/// en: 'MP4 Export'
	String get mp4Export => 'MP4 Export';

	/// en: 'Export Success'
	String get exportSuccess => 'Export Success';

	/// en: 'Export Failed'
	String get exportFailed => 'Export Failed';

	/// en: 'Select Time Range'
	String get selectTimeRange => 'Select Time Range';

	/// en: 'Record'
	String get recordingFeature => 'Record';

	/// en: 'Tap to Record'
	String get tapToRecord => 'Tap to Record';

	/// en: 'LAN Discovery'
	String get lanDiscovery => 'LAN Discovery';

	/// en: 'Auto Discovery on Page Enter'
	String get lanAutoDiscovery => 'Auto Discovery on Page Enter';

	/// en: 'Discover Devices'
	String get lanDiscoverDevices => 'Discover Devices';

	/// en: 'Remote Control'
	String get lanRemoteControl => 'Remote Control';

	/// en: 'Start Discovery'
	String get lanStartDiscovery => 'Start Discovery';

	/// en: 'Stop Discovery'
	String get lanStopDiscovery => 'Stop Discovery';

	/// en: 'No Devices Found'
	String get lanNoDevicesFound => 'No Devices Found';

	/// en: 'Searching...'
	String get lanSearching => 'Searching...';

	/// en: 'Show QR Code'
	String get lanShowQrCode => 'Show QR Code';

	/// en: 'Device Info'
	String get lanDeviceInfo => 'Device Info';

	/// en: 'Device does not support QR pairing'
	String get lanDeviceDoesNotSupportQrPairing => 'Device does not support QR pairing';

	/// en: 'QR Code for'
	String get lanQrCodeFor => 'QR Code for';

	/// en: 'Scan QR code to connect remote device'
	String get lanScanQrCodeToConnect => 'Scan QR code to connect remote device';

	/// en: 'Generating QR Code...'
	String get lanGeneratingQrCode => 'Generating QR Code...';

	/// en: 'After scanning, you can remotely control this device'
	String get lanRemoteControlDescription => 'After scanning, you can remotely control this device';

	/// en: 'Pairing Request Received'
	String get lanPairingRequestReceived => 'Pairing Request Received';

	/// en: 'Device'
	String get lanDevice => 'Device';

	/// en: 'Connecting to remote device...'
	String get lanConnectingToRemoteDevice => 'Connecting to remote device...';

	/// en: 'Remote control connected'
	String get lanRemoteControlConnected => 'Remote control connected';

	/// en: 'Remote control connection failed'
	String get lanRemoteControlConnectionFailed => 'Remote control connection failed';

	/// en: 'Invalid remote control link'
	String get lanInvalidRemoteControlLink => 'Invalid remote control link';

	/// en: 'Remote Control Connection'
	String get lanRemoteControlConnection => 'Remote Control Connection';

	/// en: 'Accept'
	String get lanAccept => 'Accept';

	/// en: 'Device ID'
	String get lanDeviceId => 'Device ID';

	/// en: 'Connect'
	String get lanConnect => 'Connect';

	/// en: 'Exit Control'
	String get lanExitControl => 'Exit Control';

	/// en: 'Connected Devices'
	String get lanConnectedDevices => 'Connected Devices';

	/// en: 'No device connected'
	String get lanNoDeviceConnected => 'No device connected';

	/// en: 'Player Control'
	String get lanPlayerControl => 'Player Control';

	/// en: 'Navigation Control'
	String get lanNavigationControl => 'Navigation Control';

	/// en: 'Home'
	String get lanNavHome => 'Home';

	/// en: 'Search'
	String get lanNavSearch => 'Search';

	/// en: 'Settings'
	String get lanNavSettings => 'Settings';

	/// en: 'Seek Back'
	String get lanSeekBack => 'Seek Back';

	/// en: 'Seek Forward'
	String get lanSeekForward => 'Seek Forward';

	/// en: 'Navigation'
	String get lanNavigation => 'Navigation';

	/// en: 'Search'
	String get lanSearch => 'Search';

	/// en: 'Playback Control'
	String get lanPlaybackControl => 'Playback Control';

	/// en: 'Play'
	String get lanPlay => 'Play';

	/// en: 'Pause'
	String get lanPause => 'Pause';

	/// en: 'Seek to'
	String get lanSeekTo => 'Seek to';

	/// en: 'Volume'
	String get lanVolume => 'Volume';

	/// en: 'Playback Speed'
	String get lanPlaybackSpeed => 'Playback Speed';

	/// en: 'Select Episode'
	String get lanSelectEpisode => 'Select Episode';

	/// en: 'Next Episode'
	String get lanNextEpisode => 'Next Episode';

	/// en: 'Previous Episode'
	String get lanPreviousEpisode => 'Previous Episode';

	/// en: 'Toggle Fullscreen'
	String get lanToggleFullscreen => 'Toggle Fullscreen';

	/// en: 'Volume Up'
	String get lanVolumeUp => 'Volume Up';

	/// en: 'Volume Down'
	String get lanVolumeDown => 'Volume Down';

	/// en: 'Waiting for the controlled device to send episode info...'
	String get lanWaitingForEpisodeInfo => 'Waiting for the controlled device to send episode info...';

	/// en: 'Sync Status'
	String get lanSyncStatus => 'Sync Status';

	/// en: 'Syncing...'
	String get lanSyncing => 'Syncing...';

	/// en: 'Last sync time'
	String get lanLastSyncTime => 'Last sync time';

	/// en: 'Pending changes'
	String get lanPendingChanges => 'Pending changes';

	/// en: 'Conflict Detected'
	String get lanConflictDetected => 'Conflict Detected';

	/// en: 'Conflict Resolution'
	String get lanConflictResolution => 'Conflict Resolution';

	/// en: 'Keep Local'
	String get lanLocalWins => 'Keep Local';

	/// en: 'Keep Remote'
	String get lanRemoteWins => 'Keep Remote';

	/// en: 'Keep Both'
	String get lanKeepBoth => 'Keep Both';

	/// en: 'Manual Resolution'
	String get lanManualResolution => 'Manual Resolution';

	/// en: 'Conflicting field'
	String get lanConflictField => 'Conflicting field';

	/// en: 'Error occurred'
	String get lanErrorOccurred => 'Error occurred';

	/// en: 'Command executed'
	String get lanCommandExecuted => 'Command executed';

	/// en: 'Command failed'
	String get lanCommandFailed => 'Command failed';

	/// en: 'No permission'
	String get lanNoPermission => 'No permission';

	/// en: 'Open Anime Detail'
	String get lanOpenAnimeDetail => 'Open Anime Detail';

	/// en: 'Sync Progress'
	String get lanSyncProgress => 'Sync Progress';

	/// en: 'Aggregation Entry'
	String get aggregationEntry => 'Aggregation Entry';

	/// en: 'AI'
	String get aiLabel => 'AI';

	/// en: 'LAN'
	String get lanLabel => 'LAN';

	/// en: 'H.264 · CRF'
	String get h264CRF => 'H.264 · CRF';

	/// en: 'FFmpeg Not Found'
	String get ffmpegNotFound => 'FFmpeg Not Found';

	/// en: 'Desktop export requires FFmpeg, but no FFmpeg executable found. Please configure FFmpeg path in settings or ensure FFmpeg is in system PATH.'
	String get ffmpegNotFoundDesktop => 'Desktop export requires FFmpeg, but no FFmpeg executable found. Please configure FFmpeg path in settings or ensure FFmpeg is in system PATH.';

	/// en: 'Still Open'
	String get stillOpenAnyway => 'Still Open';

	/// en: 'Preparing…'
	String get preparing => 'Preparing…';

	/// en: 'Downloading preview clip…'
	String get downloadingPreviewClip => 'Downloading preview clip…';

	/// en: 'Loading player…'
	String get loadingPlayer => 'Loading player…';

	/// en: 'Cancel Export?'
	String get cancelExport => 'Cancel Export?';

	/// en: 'Export in progress, closing will interrupt export.'
	String get exportInProgress => 'Export in progress, closing will interrupt export.';

	/// en: 'Confirm Close'
	String get confirmClose => 'Confirm Close';

	/// en: 'Stop Preview'
	String get stopPreview => 'Stop Preview';

	/// en: 'Loading preview…'
	String get loadingPreview => 'Loading preview…';

	/// en: 'Preview load failed'
	String get previewLoadFailed => 'Preview load failed';

	/// en: 'Reload preview clip'
	String get reloadPreviewClip => 'Reload preview clip';

	/// en: 'Video timeline thumbnails'
	String get videoTimelineThumbnails => 'Video timeline thumbnails';

	/// en: 'Start'
	String get startPoint => 'Start';

	/// en: 'End'
	String get endPoint => 'End';

	/// en: 'Jump to start'
	String get jumpToStart => 'Jump to start';

	/// en: 'Set Start'
	String get setStartPoint => 'Set Start';

	/// en: 'Set End'
	String get setEndPoint => 'Set End';

	/// en: 'Edit Start'
	String get editStartPoint => 'Edit Start';

	/// en: 'Edit End'
	String get editEndPoint => 'Edit End';

	/// en: 'Supported formats: 90, 01:30, 1.5...'
	String get durationFormatHint => 'Supported formats: 90, 01:30, 1.5...';

	/// en: 'Pure numbers are treated as seconds'
	String get secondsAsNumber => 'Pure numbers are treated as seconds';

	/// en: 'Export Settings'
	String get exportSettings => 'Export Settings';

	/// en: 'Fixed bitrate (optional, overrides CRF)'
	String get fixedBitrateOptional => 'Fixed bitrate (optional, overrides CRF)';

	/// en: 'Fixed bitrate'
	String get fixedBitrate => 'Fixed bitrate';

	/// en: 'Palette colors'
	String get paletteColors => 'Palette colors';

	/// en: 'Fewer colors = smaller size'
	String get paletteColorsHint => 'Fewer colors = smaller size';

	/// en: 'Enable Dither'
	String get enableDither => 'Enable Dither';

	/// en: 'Better quality, slightly larger size'
	String get ditherHint => 'Better quality, slightly larger size';

	/// en: 'WebP Quality'
	String get webpQuality => 'WebP Quality';

	/// en: 'Aspect Ratio Presets'
	String get aspectRatioPresets => 'Aspect Ratio Presets';

	/// en: 'Hide Crop Box'
	String get hideCropBox => 'Hide Crop Box';

	/// en: 'Show Crop Box (draggable)'
	String get showCropBox => 'Show Crop Box (draggable)';

	/// en: 'After enabling, drag to select export area'
	String get dragToSelectExportArea => 'After enabling, drag to select export area';

	/// en: 'Edit crop box'
	String get editCropBox => 'Edit crop box';

	/// en: 'Start −1s'
	String get startPointMinus1s => 'Start −1s';

	/// en: 'End −1s'
	String get endPointMinus1s => 'End −1s';

	/// en: 'Start −0.1s'
	String get startPointMinus0_1s => 'Start −0.1s';

	/// en: 'End −0.1s'
	String get endPointMinus0_1s => 'End −0.1s';

	/// en: 'Start +0.1s'
	String get startPointPlus0_1s => 'Start +0.1s';

	/// en: 'End +0.1s'
	String get endPointPlus0_1s => 'End +0.1s';

	/// en: 'Start +1s'
	String get startPointPlus1s => 'Start +1s';

	/// en: 'End +1s'
	String get endPointPlus1s => 'End +1s';

	/// en: 'With Audio'
	String get withAudio => 'With Audio';

	/// en: 'No Audio'
	String get noAudio => 'No Audio';

	/// en: 'Dither On'
	String get ditherOn => 'Dither On';

	/// en: 'Dither Off'
	String get ditherOff => 'Dither Off';

	/// en: 'GIF'
	String get gifFormat => 'GIF';

	/// en: 'APNG'
	String get apngFormat => 'APNG';

	/// en: 'WebP'
	String get webpFormat => 'WebP';

	/// en: 'Browser compatible'
	String get browserCompatible => 'Browser compatible';

	/// en: 'Smallest size'
	String get smallestSize => 'Smallest size';

	/// en: 'Video Format'
	String get videoFormat => 'Video Format';

	/// en: 'Encoding…'
	String get encoding => 'Encoding…';

	/// en: 'Downloading video segments…'
	String get downloadingVideoSegments => 'Downloading video segments…';

	/// en: 'Manage'
	String get manage => 'Manage';

	/// en: 'Please add some sources'
	String get pleaseAddSomeSources => 'Please add some sources';

	/// en: 'No Category Pages'
	String get noCategoryPages => 'No Category Pages';

	/// en: 'videoTestLabel'
	String get videoTestLabel => 'videoTestLabel';

	/// en: 'uploading'
	String get uploading => 'uploading';

	/// en: 'Add image'
	String get addImage => 'Add image';

	/// en: 'Remove image'
	String get removeImage => 'Remove image';

	/// en: 'Compressing image...'
	String get compressingImage => 'Compressing image...';

	/// en: 'Skills'
	String get skills => 'Skills';

	/// en: 'Select skills'
	String get selectSkills => 'Select skills';

	/// en: 'No skills available'
	String get noSkillsAvailable => 'No skills available';

	/// en: 'Calling tools...'
	String get usingTools => 'Calling tools...';

	/// en: 'Calling ${tool}...'
	String toolCallingTool({required Object tool}) => 'Calling ${tool}...';

	/// en: 'Tool calls: ${count}'
	String toolCallLog({required Object count}) => 'Tool calls: ${count}';

	/// en: 'Generating reply...'
	String get generatingReply => 'Generating reply...';

	/// en: 'Stop generating'
	String get stopGenerating => 'Stop generating';

	/// en: 'Thinking'
	String get thinking => 'Thinking';

	/// en: 'Generation interrupted'
	String get streamInterrupted => 'Generation interrupted';

	/// en: 'Show thinking'
	String get showThinking => 'Show thinking';

	/// en: 'Hide thinking'
	String get hideThinking => 'Hide thinking';

	/// en: 'View process'
	String get viewProcess => 'View process';

	/// en: 'Thinking'
	String get stepThinking => 'Thinking';

	/// en: 'Tool'
	String get stepTool => 'Tool';

	/// en: 'Thinking...'
	String get thinkingInProgress => 'Thinking...';

	/// en: 'cached'
	String get statsCached => 'cached';

	/// en: 'No activity records'
	String get statsNoRecords => 'No activity records';

	/// en: 'Activity overview'
	String get statsActivityOverview => 'Activity overview';

	/// en: 'Watch duration'
	String get statsWatchDuration => 'Watch duration';

	/// en: 'Clicks'
	String get statsClicks => 'Clicks';

	/// en: 'Ratings'
	String get statsRatings => 'Ratings';

	/// en: 'Comments'
	String get statsComments => 'Comments';

	/// en: 'Favorites'
	String get statsFavorites => 'Favorites';

	/// en: 'Active items'
	String get statsActiveItems => 'Active items';

	/// en: 'Activity heatmap'
	String get statsActiveHeatmap => 'Activity heatmap';

	/// en: 'Watch trend'
	String get statsWatchTrend => 'Watch trend';

	/// en: 'Active items (top ${shown}/${total})'
	String statsActiveItemsTop({required Object shown, required Object total}) => 'Active items (top ${shown}/${total})';

	/// en: 'Watch duration distribution'
	String get statsWatchDistribution => 'Watch duration distribution';

	/// en: 'Frequent tags'
	String get statsFrequentTags => 'Frequent tags';

	/// en: 'Tag cloud'
	String get statsTagCloud => 'Tag cloud';

	/// en: 'Unknown'
	String get statsUnknown => 'Unknown';

	/// en: '${n} times'
	String statsCountTimes({required Object n}) => '${n} times';

	/// en: '${n} comments'
	String statsCountComments({required Object n}) => '${n} comments';

	/// en: '${n} items'
	String statsCountItems({required Object n}) => '${n} items';

	/// en: '${month}/${day}/${year}'
	String statsDateFull({required Object month, required Object day, required Object year}) => '${month}/${day}/${year}';

	/// en: '${month}/${day} - ${endMonth}/${endDay}, ${year}'
	String statsDateRangeWeek({required Object month, required Object day, required Object endMonth, required Object endDay, required Object year}) => '${month}/${day} - ${endMonth}/${endDay}, ${year}';

	/// en: '${year}.${month}'
	String statsDateMonth({required Object year, required Object month}) => '${year}.${month}';

	/// en: '${month} ${year}'
	String statsYearMonthName({required Object month, required Object year}) => '${month} ${year}';

	/// en: '${year}.${startMonth} - ${endMonth}'
	String statsDateRangeHalf({required Object year, required Object startMonth, required Object endMonth}) => '${year}.${startMonth} - ${endMonth}';

	/// en: '${year}'
	String statsDateYear({required Object year}) => '${year}';

	/// en: '${day}'
	String statsDateDay({required Object day}) => '${day}';

	/// en: '${month}'
	String statsDateMonthOnly({required Object month}) => '${month}';

	/// en: 'Mon'
	String get statsWeekdayMon => 'Mon';

	/// en: 'Tue'
	String get statsWeekdayTue => 'Tue';

	/// en: 'Wed'
	String get statsWeekdayWed => 'Wed';

	/// en: 'Thu'
	String get statsWeekdayThu => 'Thu';

	/// en: 'Fri'
	String get statsWeekdayFri => 'Fri';

	/// en: 'Sat'
	String get statsWeekdaySat => 'Sat';

	/// en: 'Sun'
	String get statsWeekdaySun => 'Sun';

	/// en: 'Yearly overview'
	String get statsYearlyOverview => 'Yearly overview';

	/// en: 'Time range stats'
	String get statsRangeOverview => 'Time range stats';

	/// en: 'Weekly'
	String get statsWeekly => 'Weekly';

	/// en: 'Monthly'
	String get statsMonthly => 'Monthly';

	/// en: 'Quarterly'
	String get statsQuarterly => 'Quarterly';

	/// en: 'Half-yearly'
	String get statsHalfYearly => 'Half-yearly';

	/// en: 'Yearly'
	String get statsYearly => 'Yearly';

	/// en: 'Daily'
	String get statsDaily => 'Daily';

	/// en: 'Source list'
	String get statsSourceList => 'Source list';

	/// en: 'Select date'
	String get statsSelectDate => 'Select date';

	/// en: 'Entry stats'
	String get statsTimelineTitle => 'Entry stats';

	/// en: 'Watched ${duration}'
	String statsTimelineWatch({required Object duration}) => 'Watched ${duration}';

	/// en: '${value} clicks'
	String statsTimelineClick({required Object value}) => '${value} clicks';

	/// en: 'No records yet'
	String get statsTimelineNoRecords => 'No records yet';

	/// en: 'Today's records'
	String get statsDayRecords => 'Today\'s records';

	/// en: '${year}'
	String statsYearSuffix({required Object year}) => '${year}';

	/// en: 'Copied to clipboard'
	String get statsCopiedToClipboard => 'Copied to clipboard';

	/// en: 'Future'
	String get statsFuture => 'Future';

	/// en: 'No records'
	String get statsNoRecordsOnDay => 'No records';

	/// en: 'January'
	String get statsMonth1 => 'January';

	/// en: 'February'
	String get statsMonth2 => 'February';

	/// en: 'March'
	String get statsMonth3 => 'March';

	/// en: 'April'
	String get statsMonth4 => 'April';

	/// en: 'May'
	String get statsMonth5 => 'May';

	/// en: 'June'
	String get statsMonth6 => 'June';

	/// en: 'July'
	String get statsMonth7 => 'July';

	/// en: 'August'
	String get statsMonth8 => 'August';

	/// en: 'September'
	String get statsMonth9 => 'September';

	/// en: 'October'
	String get statsMonth10 => 'October';

	/// en: 'November'
	String get statsMonth11 => 'November';

	/// en: 'December'
	String get statsMonth12 => 'December';

	/// en: '(at rating ${duration})'
	String statsRatedAt({required Object duration}) => '(at rating ${duration})';

	/// en: '${time} created a comment ${duration}:'
	String statsCreatedComment({required Object time, required Object duration}) => '${time} created a comment ${duration}:';

	/// en: '${time} modified the comment ${n} times ${duration}:'
	String statsModifiedComment({required Object time, required Object n, required Object duration}) => '${time} modified the comment ${n} times ${duration}:';

	/// en: '${time} rated ${duration}:'
	String statsCreatedRating({required Object time, required Object duration}) => '${time} rated ${duration}:';

	/// en: 'rated & commented'
	String get statsRateAndComment => 'rated & commented';

	/// en: '${time} changed the rating ${n} times ${duration}:'
	String statsModifiedRating({required Object time, required Object n, required Object duration}) => '${time} changed the rating ${n} times ${duration}:';

	/// en: '${source} clicked ${platform} ${value} times'
	String statsClickAt({required Object source, required Object platform, required Object value}) => '${source} clicked ${platform} ${value} times';

	/// en: 'Today's clicks: ${total}'
	String statsDailyClicks({required Object total}) => 'Today\'s clicks: ${total}';

	/// en: '${source} watched ${platform} ${duration}'
	String statsWatchAt({required Object source, required Object platform, required Object duration}) => '${source} watched ${platform} ${duration}';

	/// en: 'Today's watch time: ${duration}'
	String statsDailyWatch({required Object duration}) => 'Today\'s watch time: ${duration}';

	/// en: 'Records'
	String get statsRecords => 'Records';

	/// en: 'Last click today: ${time}'
	String statsLastClickAt({required Object time}) => 'Last click today: \n${time}';

	/// en: 'Last watch today: ${time}'
	String statsLastWatchAt({required Object time}) => 'Last watch today: \n${time}';

	/// en: 'Favorites: ${n}'
	String statsFavoritesTotal({required Object n}) => 'Favorites: ${n}';

	/// en: 'Completed: ${n}'
	String statsCompletedCount({required Object n}) => 'Completed: ${n}';

	/// en: 'Completion: ${n}'
	String statsCompletionRate({required Object n}) => 'Completion: ${n}';

	/// en: 'Average: ${n}'
	String statsAverageScore({required Object n}) => 'Average: ${n}';

	/// en: 'Std dev: ${n}'
	String statsStdDev({required Object n}) => 'Std dev: ${n}';

	/// en: 'Rated: ${n}'
	String statsRatingCount({required Object n}) => 'Rated: ${n}';

	/// en: 'Default'
	String get statsDefault => 'Default';

	/// en: '${n} items'
	String statsItemCountSuffix({required Object n}) => '${n} items';

	/// en: 'No works rated ${score}'
	String statsNoRatingItems({required Object score}) => 'No works rated ${score}';

	/// en: '${score} pts (${count})'
	String statsScoreCount({required Object score, required Object count}) => '${score} pts (${count})';

	/// en: 'Back to bottom'
	String get jumpToBottom => 'Back to bottom';

	/// en: 'The current model does not support image understanding'
	String get modelDoesNotSupportVision => 'The current model does not support image understanding';

	/// en: 'My message'
	String get myMessage => 'My message';

	/// en: 'AI message'
	String get aiMessage => 'AI message';

	/// en: 'Resend from here'
	String get resendFromHere => 'Resend from here';

	/// en: 'Regenerate this reply'
	String get regenerateReply => 'Regenerate this reply';

	/// en: 'No personality'
	String get noPersonality => 'No personality';

	/// en: 'No system prompt used'
	String get noSystemPromptUsed => 'No system prompt used';

	/// en: 'Query Balance'
	String get queryBalance => 'Query Balance';

	/// en: 'Balance'
	String get balance => 'Balance';

	/// en: 'Querying balance...'
	String get queryingBalance => 'Querying balance...';

	/// en: 'This provider does not support balance query'
	String get balanceQueryUnsupported => 'This provider does not support balance query';

	/// en: 'Balance Query URL'
	String get balanceQueryUrl => 'Balance Query URL';

	/// en: 'Result field path'
	String get balanceKeyPath => 'Result field path';

	/// en: 'Relative path or absolute URL'
	String get balanceQueryUrlHint => 'Relative path or absolute URL';

	/// en: 'Dot notation, e.g. data.balance'
	String get balanceKeyPathHint => 'Dot notation, e.g. data.balance';

	/// en: 'Balance Query Config'
	String get balanceQueryConfig => 'Balance Query Config';

	/// en: 'Custom Providers'
	String get customProviders => 'Custom Providers';

	/// en: 'No custom providers yet'
	String get noCustomProviders => 'No custom providers yet';

	/// en: 'New Custom Provider'
	String get newCustomProvider => 'New Custom Provider';

	/// en: 'New MCP Server'
	String get newMcpServer => 'New MCP Server';

	/// en: 'New Skill'
	String get newSkill => 'New Skill';

	/// en: 'Invalid JSON format'
	String get invalidJson => 'Invalid JSON format';

	/// en: 'Provider Key'
	String get providerKey => 'Provider Key';

	/// en: 'e.g. my-provider'
	String get providerKeyHint => 'e.g. my-provider';

	/// en: 'Provider key already exists. Please change it.'
	String get providerKeyExists => 'Provider key already exists. Please change it.';

	/// en: 'Default Model'
	String get defaultModel => 'Default Model';

	/// en: 'Main settings'
	String get mainSettings => 'Main settings';

	/// en: 'Model settings'
	String get modelSettings => 'Model settings';

	/// en: 'Edit model'
	String get editModel => 'Edit model';

	/// en: 'Open settings'
	String get openModelSettings => 'Open settings';

	/// en: 'Set as default model'
	String get setAsDefaultModel => 'Set as default model';

	/// en: 'Effective address'
	String get effectiveAddress => 'Effective address';

	/// en: 'Supports vision'
	String get supportsVision => 'Supports vision';

	/// en: 'Supports tool calling'
	String get supportsTools => 'Supports tool calling';

	/// en: 'Enable vision'
	String get enableVision => 'Enable vision';

	/// en: 'Disable vision'
	String get disableVision => 'Disable vision';

	/// en: 'Enable tool calling'
	String get enableTools => 'Enable tool calling';

	/// en: 'Disable tool calling'
	String get disableTools => 'Disable tool calling';

	/// en: 'Enter the provider key above to add models'
	String get enterProviderKeyToAddModel => 'Enter the provider key above to add models';

	/// en: 'MCP Servers'
	String get mcpServers => 'MCP Servers';

	/// en: 'No MCP servers yet'
	String get noMcpServers => 'No MCP servers yet';

	/// en: 'Server Name'
	String get mcpServerName => 'Server Name';

	/// en: 'Transport'
	String get transport => 'Transport';

	/// en: 'stdio'
	String get stdio => 'stdio';

	/// en: 'HTTP'
	String get http => 'HTTP';

	/// en: 'SSE'
	String get sse => 'SSE';

	/// en: 'Command'
	String get command => 'Command';

	/// en: 'Arguments (JSON)'
	String get args => 'Arguments (JSON)';

	/// en: 'Environment (JSON)'
	String get env => 'Environment (JSON)';

	/// en: 'Server URL'
	String get serverUrl => 'Server URL';

	/// en: 'Headers (JSON)'
	String get headers => 'Headers (JSON)';

	/// en: 'No skills yet'
	String get noSkillsYet => 'No skills yet';

	/// en: 'Skill Name'
	String get skillName => 'Skill Name';

	/// en: 'Skill Key'
	String get skillKey => 'Skill Key';

	/// en: 'Built-in'
	String get builtin => 'Built-in';

	/// en: 'Skills support Markdown'
	String get skillMarkdownHint => 'Skills support Markdown';

	/// en: 'Send message'
	String get sendMessage => 'Send message';

	/// en: 'Context too long, auto-compressed'
	String get contextAutoCompressed => 'Context too long, auto-compressed';

	/// en: 'How can I help you today?'
	String get chatGreeting => 'How can I help you today?';

	/// en: 'Summarize this text'
	String get chatStart1 => 'Summarize this text';

	/// en: 'Write a poem'
	String get chatStart2 => 'Write a poem';

	/// en: 'Explain a concept'
	String get chatStart3 => 'Explain a concept';

	/// en: 'Translate this'
	String get chatStart4 => 'Translate this';

	/// en: 'Import Skills'
	String get importSkills => 'Import Skills';

	/// en: 'Markdown file(s)'
	String get importSkillsFromFiles => 'Markdown file(s)';

	/// en: 'Import one or more .md skill files with YAML frontmatter'
	String get importSkillsFromFilesHint => 'Import one or more .md skill files with YAML frontmatter';

	/// en: 'Folder with SKILL.md'
	String get importSkillsFromFolder => 'Folder with SKILL.md';

	/// en: 'Import a folder containing a SKILL.md file'
	String get importSkillsFromFolderHint => 'Import a folder containing a SKILL.md file';

	/// en: 'Importing skills...'
	String get importingSkills => 'Importing skills...';

	/// en: 'No SKILL.md found in the selected folder'
	String get noSkillFileFound => 'No SKILL.md found in the selected folder';

	/// en: 'Imported ${count} skill(s)'
	String importedSkillCount({required Object count}) => 'Imported ${count} skill(s)';

	/// en: 'Imported ${imported} skill(s), skipped ${skipped} invalid file(s)'
	String importedSkillCountSkipped({required Object imported, required Object skipped}) => 'Imported ${imported} skill(s), skipped ${skipped} invalid file(s)';

	/// en: 'Assistant Profiles'
	String get assistantProfiles => 'Assistant Profiles';

	/// en: 'New Profile'
	String get newProfile => 'New Profile';

	/// en: 'Edit Profile'
	String get editAssistantProfile => 'Edit Profile';

	/// en: 'Profile Name'
	String get profileName => 'Profile Name';

	/// en: 'Icon'
	String get profileIcon => 'Icon';

	/// en: 'One emoji, e.g. 🤖'
	String get profileIconHint => 'One emoji, e.g. 🤖';

	/// en: 'Persona'
	String get profilePersona => 'Persona';

	/// en: 'Tone'
	String get profileTone => 'Tone';

	/// en: 'Prompt Fragments (one per line)'
	String get profilePromptFragments => 'Prompt Fragments (one per line)';

	/// en: 'Knowledge (one per line)'
	String get profileKnowledge => 'Knowledge (one per line)';

	/// en: 'Generation Parameters'
	String get profileParams => 'Generation Parameters';

	/// en: 'Behavior Preferences'
	String get profileBehaviorPrefs => 'Behavior Preferences';

	/// en: 'Leave empty to follow the provider default'
	String get customParamsHint => 'Leave empty to follow the provider default';

	/// en: 'Preview System Prompt'
	String get previewSystemPrompt => 'Preview System Prompt';

	/// en: 'Try Chatting'
	String get tryChatting => 'Try Chatting';

	/// en: 'Delete Profile'
	String get deleteProfile => 'Delete Profile';

	/// en: 'Are you sure you want to delete this profile?'
	String get confirmDeleteProfile => 'Are you sure you want to delete this profile?';

	/// en: 'No profiles yet'
	String get noProfilesYet => 'No profiles yet';

	/// en: 'Profile saved'
	String get profileSaved => 'Profile saved';

	/// en: 'Profile copied to clipboard'
	String get profileCopiedToClipboard => 'Profile copied to clipboard';

	/// en: 'Switched to ${name}'
	String switchedToProfile({required Object name}) => 'Switched to ${name}';

	/// en: 'Default'
	String get defaultAssistant => 'Default';

	/// en: 'Concise replies'
	String get conciseReplies => 'Concise replies';

	/// en: 'Use Markdown formatting'
	String get useMarkdownFormatting => 'Use Markdown formatting';

	/// en: 'Code first'
	String get codeFirst => 'Code first';

	/// en: 'Give actionable advice'
	String get actionableAdvice => 'Give actionable advice';

	/// en: 'Persona'
	String get profileTabPersona => 'Persona';

	/// en: 'Prompt'
	String get profileTabPrompt => 'Prompt';

	/// en: 'Skills'
	String get profileTabSkills => 'Skills';

	/// en: 'Params'
	String get profileTabParams => 'Params';

	/// en: 'Basic'
	String get profileTabBasic => 'Basic';

	/// en: 'Extensions'
	String get profileTabExtensions => 'Extensions';

	/// en: 'Memory'
	String get profileTabMemory => 'Memory';

	/// en: 'Request'
	String get profileTabRequest => 'Request';

	/// en: 'MCP'
	String get profileTabMcp => 'MCP';

	/// en: 'Bind MCP servers for this assistant (tools are imported on connection)'
	String get profileMcpHint => 'Bind MCP servers for this assistant (tools are imported on connection)';

	/// en: 'Tools'
	String get profileTabLocalTools => 'Tools';

	/// en: 'User nickname'
	String get userNickname => 'User nickname';

	/// en: 'Shown as the user name and injected into {{user_nickname}}'
	String get userNicknameHint => 'Shown as the user name and injected into {{user_nickname}}';

	/// en: 'Anime recognition'
	String get animeRecognize => 'Anime recognition';

	/// en: 'Pick an image to identify the anime source'
	String get chooseImageToRecognize => 'Pick an image to identify the anime source';

	/// en: 'Choose image'
	String get chooseImage => 'Choose image';

	/// en: 'Recognizing...'
	String get recognizing => 'Recognizing...';

	/// en: 'No anime recognized, this may not be an anime image'
	String get noAnimeFound => 'No anime recognized, this may not be an anime image';

	/// en: 'Try another image'
	String get chooseAnotherImage => 'Try another image';

	/// en: 'Recognition results'
	String get recognizeResult => 'Recognition results';

	/// en: 'EP'
	String get episodeLabel => 'EP';

	/// en: 'Unknown episode'
	String get unknownEpisode => 'Unknown episode';

	/// en: 'Video preview'
	String get openVideoPreview => 'Video preview';

	/// en: 'Discuss in AI'
	String get discussInAi => 'Discuss in AI';

	/// en: 'Drop an image to recognize'
	String get dropImageToRecognize => 'Drop an image to recognize';

	/// en: 'Drop a .js file to import'
	String get dropFileToImport => 'Drop a .js file to import';

	/// en: 'View on Bangumi'
	String get viewOnBangumi => 'View on Bangumi';

	/// en: 'Available variables: '
	String get templateVarHint => 'Available variables: ';

	/// en: 'Please select a persona first'
	String get profilePersonaRequired => 'Please select a persona first';

	/// en: 'The system default assistant cannot be deleted'
	String get defaultAssistantCannotDelete => 'The system default assistant cannot be deleted';

	/// en: 'This assistant has image understanding disabled'
	String get imageUnderstandingDisabled => 'This assistant has image understanding disabled';

	/// en: 'Model type'
	String get modelType => 'Model type';

	/// en: 'Input modalities'
	String get inputModality => 'Input modalities';

	/// en: 'Output modalities'
	String get outputModality => 'Output modalities';

	/// en: 'Supports reasoning'
	String get supportsReasoning => 'Supports reasoning';

	/// en: 'Capabilities'
	String get capabilities => 'Capabilities';

	/// en: 'Chat'
	String get modelTypeChat => 'Chat';

	/// en: 'Image'
	String get modelTypeImage => 'Image';

	/// en: 'Embedding'
	String get modelTypeEmbedding => 'Embedding';

	/// en: 'Audio'
	String get modelTypeAudio => 'Audio';

	/// en: 'Rerank'
	String get modelTypeRerank => 'Rerank';

	/// en: 'Other'
	String get modelTypeOther => 'Other';

	/// en: 'Text'
	String get modalityText => 'Text';

	/// en: 'Image'
	String get modalityImage => 'Image';

	/// en: 'Audio'
	String get modalityAudio => 'Audio';

	/// en: 'Video'
	String get modalityVideo => 'Video';

	/// en: 'Tools'
	String get capabilityTools => 'Tools';

	/// en: 'Reasoning'
	String get capabilityReasoning => 'Reasoning';

	/// en: 'API format'
	String get apiFormat => 'API format';

	/// en: 'OpenAI (chat)'
	String get apiFormatOpenai => 'OpenAI (chat)';

	/// en: 'OpenAI Responses'
	String get apiFormatOpenaiResponses => 'OpenAI Responses';

	/// en: 'Google (Gemini)'
	String get apiFormatGemini => 'Google (Gemini)';

	/// en: 'Claude (Anthropic)'
	String get apiFormatClaude => 'Claude (Anthropic)';

	/// en: 'Test connection'
	String get testConnection => 'Test connection';

	/// en: 'Test API key'
	String get testApiKey => 'Test API key';

	/// en: 'Enabled automatically when an API key is filled in'
	String get enabledByApiKey => 'Enabled automatically when an API key is filled in';

	/// en: 'Chat Completions'
	String get endpointChatCompletions => 'Chat Completions';

	/// en: 'Responses API'
	String get endpointResponses => 'Responses API';

	/// en: 'Connection OK'
	String get connectionOk => 'Connection OK';

	/// en: 'Models list API'
	String get modelsUrl => 'Models list API';

	/// en: 'Fetch models'
	String get fetchModels => 'Fetch models';

	/// en: 'No models returned'
	String get noModelsReturned => 'No models returned';

	/// en: 'Enable reasoning'
	String get enableReasoning => 'Enable reasoning';

	/// en: 'Disable reasoning'
	String get disableReasoning => 'Disable reasoning';

	/// en: 'Thinking level'
	String get thinkingLevel => 'Thinking level';

	/// en: 'Concise'
	String get thinkingLow => 'Concise';

	/// en: 'Standard'
	String get thinkingStandard => 'Standard';

	/// en: 'Deep'
	String get thinkingDeep => 'Deep';

	/// en: 'Assistant settings'
	String get assistantSettings => 'Assistant settings';

	/// en: 'Camera'
	String get takePhoto => 'Camera';

	/// en: 'Images'
	String get pickImages => 'Images';

	/// en: 'Upload file'
	String get uploadFile => 'Upload file';

	/// en: 'Compress history'
	String get compressHistory => 'Compress history';

	/// en: 'Compress this conversation's history to save tokens. Continue?'
	String get compressHistoryConfirm => 'Compress this conversation\'s history to save tokens. Continue?';

	/// en: 'Compressed'
	String get compressed => 'Compressed';

	/// en: 'Local tools'
	String get profileLocalTools => 'Local tools';

	/// en: 'Built-in tool chain toggles'
	String get profileLocalToolsHint => 'Built-in tool chain toggles';

	/// en: 'Skills'
	String get profileSkills => 'Skills';

	/// en: 'Bind skills imported in Extension Management'
	String get profileSkillsHint => 'Bind skills imported in Extension Management';

	/// en: 'Custom request'
	String get profileRequest => 'Custom request';

	/// en: 'Sensitive info (e.g. API Key) is persisted with the profile, fill in carefully'
	String get profileRequestSensitiveHint => 'Sensitive info (e.g. API Key) is persisted with the profile, fill in carefully';

	/// en: 'Base URL override'
	String get profileRequestBaseUrl => 'Base URL override';

	/// en: 'API Key override'
	String get profileRequestApiKey => 'API Key override';

	/// en: 'Custom headers (Key: Value per line)'
	String get profileRequestHeaders => 'Custom headers (Key: Value per line)';

	/// en: 'Extra body fields (JSON)'
	String get profileRequestExtraBody => 'Extra body fields (JSON)';

	/// en: 'Stop sequences (one per line)'
	String get profileRequestStop => 'Stop sequences (one per line)';

	/// en: 'Stop generating when this sequence is encountered'
	String get profileRequestStopHint => 'Stop generating when this sequence is encountered';

	/// en: 'App-level optional module toggles'
	String get profileExtensionsHint => 'App-level optional module toggles';

	/// en: 'Enable long-term memory'
	String get profileMemoryEnabled => 'Enable long-term memory';

	/// en: 'Records preferences, frequent topics and key conclusions; switches with the assistant'
	String get profileMemoryHint => 'Records preferences, frequent topics and key conclusions; switches with the assistant';

	/// en: 'Memory entry limit'
	String get profileMemoryMaxEntries => 'Memory entry limit';

	/// en: 'Memory entries'
	String get profileMemoryEntries => 'Memory entries';

	/// en: 'Clear'
	String get profileMemoryClear => 'Clear';

	/// en: 'No memory entries yet'
	String get profileMemoryEmpty => 'No memory entries yet';

	/// en: 'New memory entry'
	String get profileMemoryAdd => 'New memory entry';

	/// en: 'Duplicate'
	String get profileCopy => 'Duplicate';

	/// en: 'Export'
	String get profileExport => 'Export';

	/// en: 'Import'
	String get profileImport => 'Import';

	/// en: 'Exported to clipboard'
	String get profileExported => 'Exported to clipboard';

	/// en: 'Import failed'
	String get profileImportFailed => 'Import failed';

	/// en: 'Extension Management'
	String get extensionManagement => 'Extension Management';

	/// en: 'Auxiliary task models, role management, MCP servers and skills'
	String get extensionManagementHint => 'Auxiliary task models, role management, MCP servers and skills';

	/// en: 'Role Management'
	String get roleManagement => 'Role Management';

	/// en: 'Prompt'
	String get promptManagement => 'Prompt';

	/// en: 'Prompt Injection'
	String get promptInjection => 'Prompt Injection';

	/// en: 'Injection position decides where each fragment is inserted in the system prompt'
	String get promptInjectionHint => 'Injection position decides where each fragment is inserted in the system prompt';

	/// en: 'World Book'
	String get worldBook => 'World Book';

	/// en: 'World Book entries'
	String get worldBookEntries => 'World Book entries';

	/// en: 'New Injection'
	String get newPromptInjection => 'New Injection';

	/// en: 'Edit Injection'
	String get editPromptInjection => 'Edit Injection';

	/// en: 'Name'
	String get injectionName => 'Name';

	/// en: 'Content'
	String get injectionContent => 'Content';

	/// en: 'Injection position'
	String get injectionPosition => 'Injection position';

	/// en: 'After personality'
	String get injectionPositionAfterPersonality => 'After personality';

	/// en: 'After custom system prompt'
	String get injectionPositionAfterSystemPrompt => 'After custom system prompt';

	/// en: 'After knowledge'
	String get injectionPositionAfterKnowledge => 'After knowledge';

	/// en: 'After memory'
	String get injectionPositionAfterMemory => 'After memory';

	/// en: 'Before tool list'
	String get injectionPositionBeforeTools => 'Before tool list';

	/// en: 'Sort order'
	String get injectionSortOrder => 'Sort order';

	/// en: 'No prompt injections yet'
	String get noInjectionsYet => 'No prompt injections yet';

	/// en: 'Name'
	String get worldBookName => 'Name';

	/// en: 'Trigger words (one per line)'
	String get worldBookTriggers => 'Trigger words (one per line)';

	/// en: 'Injected when the user message contains any trigger word'
	String get worldBookTriggersHint => 'Injected when the user message contains any trigger word';

	/// en: 'Content'
	String get worldBookContent => 'Content';

	/// en: 'Priority (higher first)'
	String get worldBookPriority => 'Priority (higher first)';

	/// en: 'Higher priority entries are injected first'
	String get worldBookPriorityHint => 'Higher priority entries are injected first';

	/// en: 'New Entry'
	String get newWorldBookEntry => 'New Entry';

	/// en: 'Hit Test'
	String get worldBookHitTest => 'Hit Test';

	/// en: 'Type a sentence to see which entries will be triggered'
	String get worldBookHitTestHint => 'Type a sentence to see which entries will be triggered';

	/// en: 'Type a sentence...'
	String get worldBookHitTestPlaceholder => 'Type a sentence...';

	/// en: 'Matching entries'
	String get worldBookHitsResult => 'Matching entries';

	/// en: 'No entries matched'
	String get worldBookNoHits => 'No entries matched';

	/// en: 'No world book entries yet'
	String get noWorldBookEntriesYet => 'No world book entries yet';

	/// en: 'Temperature'
	String get auxTemperature => 'Temperature';

	/// en: 'Select an assistant'
	String get selectAssistantProfile => 'Select an assistant';

	/// en: 'Select model'
	String get selectModel => 'Select model';

	/// en: 'Personality tags'
	String get profilePersonalityTags => 'Personality tags';

	/// en: 'Multi-select tags, e.g. Rational / Humorous / Sharp-tongued / Gentle'
	String get profilePersonalityTagsHint => 'Multi-select tags, e.g. Rational / Humorous / Sharp-tongued / Gentle';

	/// en: 'Catchphrases'
	String get profileCatchphrases => 'Catchphrases';

	/// en: 'One per line'
	String get profileCatchphrasesHint => 'One per line';

	/// en: 'Example dialogs (few-shot)'
	String get profileExamples => 'Example dialogs (few-shot)';

	/// en: 'One pair per line, format: 用户: xxx | 助手: xxx'
	String get profileExamplesHint => 'One pair per line, format: 用户: xxx | 助手: xxx';

	/// en: 'Reply style'
	String get profileReplyStyle => 'Reply style';

	/// en: 'Reply length'
	String get replyLength => 'Reply length';

	/// en: 'Concise'
	String get replyLengthShort => 'Concise';

	/// en: 'Normal'
	String get replyLengthNormal => 'Normal';

	/// en: 'Detailed'
	String get replyLengthDetailed => 'Detailed';

	/// en: 'Use emoji'
	String get replyUseEmoji => 'Use emoji';

	/// en: 'Use Markdown formatting'
	String get replyUseMarkdown => 'Use Markdown formatting';

	/// en: 'Ask back at the end'
	String get replyAskBack => 'Ask back at the end';

	/// en: 'Connection status'
	String get mcpConnectionStatus => 'Connection status';

	/// en: 'Connected'
	String get mcpConnected => 'Connected';

	/// en: 'Disconnected'
	String get mcpDisconnected => 'Disconnected';

	/// en: 'tools imported'
	String get mcpToolsImported => 'tools imported';

	/// en: 'Reconnect'
	String get mcpReconnect => 'Reconnect';

	/// en: 'Test connection'
	String get mcpTestConnection => 'Test connection';

	/// en: 'Connecting...'
	String get mcpConnecting => 'Connecting...';

	/// en: 'Connection failed'
	String get mcpConnectionFailed => 'Connection failed';

	/// en: 'Source Builder'
	String get builderTitle => 'Source Builder';

	/// en: 'Build source'
	String get builderEntry => 'Build source';

	/// en: 'Basic Info'
	String get builderBasic => 'Basic Info';

	/// en: 'Name'
	String get builderName => 'Name';

	/// en: 'Key'
	String get builderKey => 'Key';

	/// en: 'Version'
	String get builderVersion => 'Version';

	/// en: 'Base URL'
	String get builderBaseUrl => 'Base URL';

	/// en: 'Search'
	String get builderSearch => 'Search';

	/// en: 'Search URL template'
	String get builderSearchUrl => 'Search URL template';

	/// en: 'List item selector'
	String get builderListSelector => 'List item selector';

	/// en: 'Title selector'
	String get builderTitleSelector => 'Title selector';

	/// en: 'Cover selector'
	String get builderCoverSelector => 'Cover selector';

	/// en: 'Cover attribute'
	String get builderCoverAttr => 'Cover attribute';

	/// en: 'Link selector'
	String get builderLinkSelector => 'Link selector';

	/// en: 'Page parameter'
	String get builderPageParam => 'Page parameter';

	/// en: 'Anime Detail'
	String get builderDetail => 'Anime Detail';

	/// en: 'Detail URL template'
	String get builderDetailUrl => 'Detail URL template';

	/// en: 'Description selector'
	String get builderDescSelector => 'Description selector';

	/// en: 'Episode list selector'
	String get builderEpisodeSelector => 'Episode list selector';

	/// en: 'Episode title selector'
	String get builderEpisodeTitleSelector => 'Episode title selector';

	/// en: 'Episode link selector'
	String get builderEpisodeLinkSelector => 'Episode link selector';

	/// en: 'Playback'
	String get builderPlay => 'Playback';

	/// en: 'Play page URL template'
	String get builderPlayUrl => 'Play page URL template';

	/// en: 'Playback URL regex'
	String get builderExtractRegex => 'Playback URL regex';

	/// en: 'Max page selector'
	String get builderMaxPageSelector => 'Max page selector';

	/// en: 'User-Agent'
	String get builderUserAgent => 'User-Agent';

	/// en: 'Directly return episode link'
	String get builderPlayDirect => 'Directly return episode link';

	/// en: 'The episode link itself is the playable URL (no extra request)'
	String get builderPlayDirectDesc => 'The episode link itself is the playable URL (no extra request)';

	/// en: 'Fetch the play page and extract the URL via regex'
	String get builderPlayRegexDesc => 'Fetch the play page and extract the URL via regex';

	/// en: 'Explore'
	String get builderExplore => 'Explore';

	/// en: 'Page title'
	String get builderExploreTitle => 'Page title';

	/// en: 'List URL template ({page})'
	String get builderExploreUrl => 'List URL template ({page})';

	/// en: 'Category'
	String get builderCategory => 'Category';

	/// en: 'Category title'
	String get builderCategoryTitle => 'Category title';

	/// en: 'Category names (one per line, "value-name")'
	String get builderCategoryNames => 'Category names (one per line, "value-name")';

	/// en: 'Category list URL ({category} {page})'
	String get builderCategoryUrl => 'Category list URL ({category} {page})';

	/// en: 'Generate & Import'
	String get builderGenerate => 'Generate & Import';

	/// en: 'Name is required'
	String get builderNameRequired => 'Name is required';

	/// en: 'Key is required'
	String get builderKeyRequired => 'Key is required';

	/// en: 'Key must contain only letters, digits and underscore'
	String get builderKeyInvalid => 'Key must contain only letters, digits and underscore';

	/// en: 'Source imported'
	String get builderImported => 'Source imported';

	/// en: 'Generate failed'
	String get builderGenerateFailed => 'Generate failed';

	/// en: 'Collapse sidebar'
	String get collapseSidebar => 'Collapse sidebar';

	/// en: 'Expand sidebar'
	String get expandSidebar => 'Expand sidebar';

	/// en: 'Clear finished downloads'
	String get clearFinishedDownload => 'Clear finished downloads';

	/// en: 'No download tasks'
	String get downloadEmpty => 'No download tasks';

	/// en: 'Queued'
	String get downloadQueued => 'Queued';

	/// en: 'Completed'
	String get downloadCompleted => 'Completed';

	/// en: 'Pause download'
	String get pauseDownload => 'Pause download';

	/// en: 'Resume download'
	String get resumeDownload => 'Resume download';

	/// en: 'Retry download'
	String get retryDownload => 'Retry download';

	/// en: 'Paused'
	String get pausedDownload => 'Paused';

	/// en: 'Download settings'
	String get downloadSettings => 'Download settings';

	/// en: 'Concurrent tasks'
	String get downloadConcurrent => 'Concurrent tasks';

	/// en: 'Segment concurrency'
	String get downloadSegmentConcurrent => 'Segment concurrency';

	/// en: 'Wi-Fi only'
	String get downloadWifiOnly => 'Wi-Fi only';

	/// en: 'Other'
	String get downloadOther => 'Other';

	/// en: 'Download records'
	String get downloadRecords => 'Download records';

	/// en: 'Open with other player'
	String get openWithOtherPlayer => 'Open with other player';

	/// en: 'Download title format'
	String get downloadTitleFormat => 'Download title format';

	/// en: 'Placeholders: {title} {episode} {author} {resolution} {source} {year}'
	String get downloadFormatHint => 'Placeholders: {title} {episode} {author} {resolution} {source} {year}';

	/// en: 'Download directory'
	String get downloadDir => 'Download directory';

	/// en: 'Resolving video address'
	String get loadingStepParse => 'Resolving video address';

	/// en: 'Initializing player'
	String get loadingStepInit => 'Initializing player';

	/// en: 'Loading media'
	String get loadingStepLoad => 'Loading media';

	/// en: 'Buffering'
	String get loadingStepBuffer => 'Buffering';

	/// en: 'Select episode to download'
	String get downloadEpisode => 'Select episode to download';

	/// en: 'No episodes available to download'
	String get downloadNotYet => 'No episodes available to download';

	/// en: 'Download ${n} episodes'
	String downloadSelectedCount({required Object n}) => 'Download ${n} episodes';

	/// en: 'Select resolution'
	String get selectResolution => 'Select resolution';

	/// en: 'Default'
	String get defaultResolution => 'Default';

	/// en: 'No more qualities available'
	String get noResolutionAvailable => 'No more qualities available';

	/// en: 'Series'
	String get series => 'Series';

	/// en: 'Single episode · 1 total'
	String get singleEpisode => 'Single episode · 1 total';

	/// en: 'Playing'
	String get playing => 'Playing';

	/// en: 'Select none'
	String get selectNone => 'Select none';

	/// en: 'Downloading'
	String get downloadActive => 'Downloading';

	/// en: 'Redownload'
	String get redownload => 'Redownload';

	/// en: 'Start all'
	String get startAll => 'Start all';

	/// en: 'Pause all'
	String get pauseAll => 'Pause all';

	/// en: 'Cancel all'
	String get cancelAll => 'Cancel all';

	/// en: 'No download records'
	String get recordsEmpty => 'No download records';

	/// en: 'File not found'
	String get fileNotFound => 'File not found';

	/// en: 'Deleted'
	String get deleted => 'Deleted';

	/// en: 'Long press to change speed'
	String get localPlayerSpeedTip => 'Long press to change speed';

	/// en: 'Audio track'
	String get audioTrack => 'Audio track';

	/// en: 'Subtitles'
	String get subtitle => 'Subtitles';

	/// en: 'Off'
	String get subtitleOff => 'Off';

	/// en: 'Quality'
	String get quality => 'Quality';

	/// en: 'Copied: ${x}'
	String copiedField({required Object x}) => 'Copied: ${x}';

	/// en: 'Select alias (${count})'
	String selectAliasCount({required Object count}) => 'Select alias (${count})';

	/// en: 'MMM d'
	String get monthDayFormat => 'MMM d';

	/// en: '${month}/${day}'
	String monthDay({required Object month, required Object day}) => '${month}/${day}';

	/// en: 'Anime ID: ${id} Source: ${source}'
	String qrAnimeId({required Object id, required Object source}) => 'Anime ID: ${id}\nSource: ${source}';

	/// en: 'Bangumi ID: ${id}'
	String qrBangumiId({required Object id}) => 'Bangumi ID: ${id}';

	/// en: 'Watch together room: ${room} Server: ${server}'
	String qrWatchRoom({required Object room, required Object server}) => 'Watch together room: ${room}\nServer: ${server}';

	/// en: 'Detected ${type} link'
	String qrDetectedType({required Object type}) => 'Detected ${type} link';

	/// en: '(Password resolved) '
	String get qrPasswordResolved => '(Password resolved)\n';

	/// en: 'Reviewed at ${time}'
	String reviewedAtTime({required Object time}) => 'Reviewed at ${time}';

	/// en: 'QR code copied to clipboard'
	String get qrCopiedToClipboard => 'QR code copied to clipboard';

	/// en: 'QR code saved'
	String get qrSavedToGallery => 'QR code saved';

	/// en: 'Reloaded successfully'
	String get reloadSuccess => 'Reloaded successfully';

	/// en: 'OP'
	String get floorOwner => 'OP';

	/// en: 'OP'
	String get postOwner => 'OP';

	/// en: 'Collapse'
	String get collapse => 'Collapse';

	/// en: 'Expand (${total})'
	String expandCount({required Object total}) => 'Expand (${total})';

	/// en: 'Reply deleted'
	String get deletedReply => 'Reply deleted';

	/// en: 'Author'
	String get author => 'Author';

	/// en: 'Episode title'
	String get episodeTitleLabel => 'Episode title';

	/// en: 'Manual switch'
	String get manualSwitch => 'Manual switch';

	/// en: 'Enter episode number'
	String get inputEpisodeNumber => 'Enter episode number';

	/// en: 'Enter a number between 1 and 999'
	String get episodeNumberHint => 'Enter a number between 1 and 999';

	/// en: 'Please enter an episode number'
	String get enterEpisodeNumber => 'Please enter an episode number';

	/// en: 'Please enter a valid number between 1 and 999'
	String get invalidEpisodeNumber => 'Please enter a valid number between 1 and 999';

	/// en: 'Ep. ${n}'
	String episodeN({required Object n}) => 'Ep. ${n}';

	/// en: 'No viewing record found for this episode'
	String get noViewingRecord => 'No viewing record found for this episode';

	/// en: 'Viewing record'
	String get viewingRecord => 'Viewing record';

	/// en: 'Watch duration: ${duration}'
	String watchDurationLabel({required Object duration}) => 'Watch duration: ${duration}';

	/// en: 'Completed: ${status}'
	String completedStatus({required Object status}) => 'Completed: ${status}';

	/// en: 'Yes'
	String get yes => 'Yes';

	/// en: 'No'
	String get no => 'No';

	/// en: 'Start time: ${time}'
	String startTimeLabel({required Object time}) => 'Start time: ${time}';

	/// en: 'End time: ${time}'
	String endTimeLabel({required Object time}) => 'End time: ${time}';

	/// en: 'App info'
	String get appInfo => 'App info';

	/// en: 'Some repositories failed to fetch: ${list}'
	String partRepoFetchFailed({required Object list}) => 'Some repositories failed to fetch: ${list}';

	/// en: 'Air time: ${time}'
	String airTimeLabel({required Object time}) => 'Air time: ${time}';

	/// en: 'Duration: ${duration}'
	String durationLabel({required Object duration}) => 'Duration: ${duration}';

	/// en: '[Reply]'
	String get replyBracket => '[Reply]';

	/// en: 'Want to watch'
	String get wantToWatch => 'Want to watch';

	/// en: 'Watching'
	String get watching => 'Watching';

	/// en: 'Add to ${folder}'
	String addToFolder({required Object folder}) => 'Add to ${folder}';

	/// en: 'Remove from ${folder}'
	String removeFromFolder({required Object folder}) => 'Remove from ${folder}';

	/// en: 'Move from ${from} to ${to}'
	String movedFromTo({required Object from, required Object to}) => 'Move from ${from} to ${to}';

	/// en: 'Unknown folder'
	String get unknownFolder => 'Unknown folder';

	/// en: 'Failed to get video link: ${detail}'
	String fetchVideoUrlError({required Object detail}) => 'Failed to get video link: ${detail}';

	/// en: 'Missing url'
	String get missingUrl => 'Missing url';

	/// en: 'Success'
	String get success => 'Success';

	/// en: 'Failed (${status})'
	String failedWithStatus({required Object status}) => 'Failed (${status})';

	/// en: 'Check in'
	String get checkIn => 'Check in';

	/// en: 'Button'
	String get button => 'Button';

	/// en: 'Request failed: ${error}'
	String requestFailedDetail({required Object error}) => 'Request failed: ${error}';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Next episode'
	String get nextEpisode => 'Next episode';

	/// en: 'Track ${n}'
	String trackN({required Object n}) => 'Track ${n}';

	/// en: 'Device info'
	String get deviceInfo => 'Device info';

	/// en: 'Conversation stream interrupted unexpectedly'
	String get conversationInterrupted => 'Conversation stream interrupted unexpectedly';

	/// en: 'Tool execution failed: ${error}'
	String toolExecutionFailed({required Object error}) => 'Tool execution failed: ${error}';

	/// en: '${source} API Key is not configured or is disabled'
	String apiKeyNotConfigured({required Object source}) => '${source} API Key is not configured or is disabled';

	/// en: 'Invalid image'
	String get imageInvalid => 'Invalid image';

	/// en: 'Recognition service is busy, please try again later'
	String get recognizeBusy => 'Recognition service is busy, please try again later';

	/// en: 'Connection timeout'
	String get connectionTimeout => 'Connection timeout';

	/// en: 'Incorrect PIN'
	String get pinError => 'Incorrect PIN';

	/// en: 'Connection closed'
	String get connectionClosed => 'Connection closed';

	/// en: 'Unknown command type: ${type}'
	String unknownCommand({required Object type}) => 'Unknown command type: ${type}';

	/// en: 'Processing failed: ${error}'
	String processingFailed({required Object error}) => 'Processing failed: ${error}';

	/// en: 'Execution failed: ${error}'
	String executionFailed({required Object error}) => 'Execution failed: ${error}';

	/// en: 'Unknown service provider: ${provider}'
	String unknownServiceProvider({required Object provider}) => 'Unknown service provider: ${provider}';

	/// en: 'Session not found: ${id}'
	String sessionNotFound({required Object id}) => 'Session not found: ${id}';

	/// en: 'Not enough history to compress'
	String get historyTooShort => 'Not enough history to compress';

	/// en: 'Message too large, maximum 64KB'
	String get messageTooLarge => 'Message too large, maximum 64KB';

	/// en: 'Too many requests, please try again later'
	String get rateLimit => 'Too many requests, please try again later';

	/// en: 'Ports ${start} to ${end} are all occupied'
	String portBusy({required Object start, required Object end}) => 'Ports ${start} to ${end} are all occupied';

	/// en: 'Only WebSocket connections are supported'
	String get webSocketOnly => 'Only WebSocket connections are supported';

	/// en: '${source} has too many tool call rounds'
	String toolRoundsExceeded({required Object source}) => '${source} has too many tool call rounds';

	/// en: 'Headers'
	String get requestHeaders => 'Headers';

	/// en: 'Direct'
	String get direct => 'Direct';

	/// en: 'Manual'
	String get manual => 'Manual';

	/// en: '${n} votes'
	String votes({required Object n}) => '${n} votes';

	/// en: '${n} pages'
	String pagesCount({required Object n}) => '${n} pages';

	/// en: 'Empty Page'
	String get emptyPage => 'Empty Page';

	/// en: 'Copy text command'
	String get copyTextCommand => 'Copy text command';

	/// en: 'Save failed: permission or directory error'
	String get saveFailedPermissionOrDirectory => 'Save failed: permission or directory error';

	/// en: 'Biometrics not supported'
	String get biometricsNotSupported => 'Biometrics not supported';

	/// en: 'Invalid file type: ${ext}'
	String invalidFileType({required Object ext}) => 'Invalid file type: ${ext}';

	/// en: 'Download canceled'
	String get downloadCanceled => 'Download canceled';

	/// en: 'Token invalid or expired'
	String get tokenInvalidOrExpired => 'Token invalid or expired';

	/// en: 'Errors: ${n}'
	String errorsLabel({required Object n}) => 'Errors: ${n}';

	/// en: 'Enter connection PIN'
	String get inputPinTitle => 'Enter connection PIN';

	/// en: 'Enter PIN code'
	String get inputPinHint => 'Enter PIN code';

	/// en: 'Post author'
	String get topicsPoster => 'Post author';

	/// en: '${timetable} (${count})'
	String timetableCount({required Object timetable, required Object count}) => '${timetable} (${count})';

	/// en: '${fetchPlugins}: ${count}'
	String fetchPluginsCount({required Object fetchPlugins, required Object count}) => '${fetchPlugins}: ${count}';

	/// en: 'Connect to ${device}'
	String connectToDevice({required Object device}) => 'Connect to ${device}';

	/// en: 'Receive Timeout: This indicates that the server is too busy to respond'
	String get receiveTimeout => 'Receive Timeout: This indicates that the server is too busy to respond';

	/// en: 'Connection terminated during handshake: This may be caused by the firewall blocking the connection or your requests are too frequent.'
	String get connectionTerminatedDuringHandshake => 'Connection terminated during handshake: This may be caused by the firewall blocking the connection or your requests are too frequent.';

	/// en: 'Connection reset by peer: The error is unrelated to the app, please check your network.'
	String get connectionResetByPeer => 'Connection reset by peer: The error is unrelated to the app, please check your network.';

	/// en: 'Started download'
	String get downloadStarted => 'Started download';

	/// en: 'Force merge'
	String get forceMerge => 'Force merge';

	/// en: 'Merging downloaded segments...'
	String get mergeProcessing => 'Merging downloaded segments...';

	/// en: 'Applied to both the base service and Hub server (shared certificate)'
	String get tlsSharedHint => 'Applied to both the base service and Hub server (shared certificate)';

	/// en: 'Login expired, please re-login'
	String get loginExpiredReLogin => 'Login expired, please re-login';

	/// en: 'View error'
	String get viewError => 'View error';

	/// en: 'Export log file'
	String get exportLogFile => 'Export log file';

	/// en: 'Delete log file'
	String get deleteLogFile => 'Delete log file';

	/// en: 'Delete the saved log files (logs.txt / logs.old.txt)?'
	String get clearLogsFileConfirm => 'Delete the saved log files (logs.txt / logs.old.txt)?';

	/// en: 'Clear logs'
	String get clearLog => 'Clear logs';

	/// en: 'Log settings'
	String get logSettings => 'Log settings';

	/// en: 'Keep archived log files'
	String get logRetainCount => 'Keep archived log files';

	/// en: 'Log file size limit (MB)'
	String get logFileSizeMb => 'Log file size limit (MB)';
}

// Path: colors
class Translations$colors$en {
	Translations$colors$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

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

	/// en: 'Orange'
	String get orange => 'Orange';

	/// en: 'Blue'
	String get blue => 'Blue';

	/// en: 'Pink'
	String get pink => 'Pink';

	/// en: 'Green'
	String get green => 'Green';

	/// en: 'Red'
	String get red => 'Red';

	/// en: 'Purple'
	String get purple => 'Purple';
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
			'addToDefault' => 'Add to Unsorted',
			'removeFromFavorites' => 'Remove from favorites',
			'imageProperties' => 'Image Properties',
			'fileName' => 'File Name',
			'fileSize' => 'File Size',
			'modifiedTime' => 'Modified Time',
			'path' => 'Path',
			'titleCopied' => 'Title copied',
			'imageFormat' => 'Format',
			'confirmDeleteImage' => 'Confirm delete this image?',
			'bangumiPlan' => 'bangumi',
			'switchFavoriteUser' => 'Switch Favorite User',
			'enterBangumiUserName' => 'Enter Bangumi User Name',
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
			'addRepo' => 'Add repository',
			'repo' => 'Repositories',
			'repoUrlHint' => 'Repo URL: http(s) link or local index.json path (file://)',
			'repoEmpty' => 'No sources in this repository',
			'filterAll' => 'All',
			'noMatchingSource' => 'No matching sources',
			'sourceCount' => ({required Object count}) => '${count} sources',
			'filterNonBangumi' => 'Others',
			'sortByDefault' => 'Default',
			'sortAsc' => 'Ascending',
			'sortDesc' => 'Descending',
			'sortByName' => 'Name',
			'sortById' => 'ID',
			'switchSource' => 'Switch source',
			'searchSourceHint' => 'Search this title on other sources',
			'needVerification' => 'Needs verification',
			'tapToVerify' => 'Tap to verify',
			'appearance' => 'Appearance',
			'areYouSureYouWantToClearYourHistory' => 'Are you sure you want to clear your history?',
			'areYouSureYouWantToClearYourProgress' => 'Are you sure you want to clear your progress?',
			'authorizationRequired' => 'Authorization Required',
			'autoPageTurning' => 'Auto Page Turning',
			'back' => 'Back',
			'bangumi' => 'Bangumi',
			'bangumiInfo' => 'Anime Details',
			'block' => 'Block',
			'superResolution' => 'Super Resolution',
			'superResolutionOff' => 'Off',
			'superResolutionEfficiency' => 'Efficiency',
			'superResolutionQuality' => 'Quality',
			'glimmerMode' => 'Glimmer Mode',
			'glimmerModeOn' => 'On',
			'glimmerModeOff' => 'Off',
			'blue' => 'Blue',
			'brief' => 'Brief',
			'masonry' => 'Masonry',
			'poster' => 'Poster',
			'sourceDisplayModeReset' => 'Follow global default',
			'followSourceDefault' => 'Follow source default',
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
			'hubUploadedImages' => 'Hub Uploaded Images',
			'hubUploadedImagesHint' => 'image(s) stored on this device',
			'noHubUploads' => 'No uploaded images',
			'clearHubUploadsConfirm' => 'Delete all Hub uploaded images?',
			'hubStickers' => 'Hub Stickers',
			'hubStickersHint' => 'sticker(s)',
			'noHubStickers' => 'No stickers',
			'clearHubStickersConfirm' => 'Delete all Hub stickers?',
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
			'continueText' => 'Continue',
			'copied' => 'Copied',
			'captchaHint' => 'Enter captcha code',
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
			'animes' => 'anime',
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
			'importAll' => 'Import all',
			'importSelected' => 'Import selected',
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
			'account' => 'Account',
			'log' => 'Log',
			'manualTranslation' => 'Manual Translation',
			'manualTranslationHint' => 'Translate text into your preferred language',
			'enterTextToTranslate' => 'Enter text to translate',
			'translate' => 'Translate',
			'translationFailed' => 'Translation failed',
			'translating' => 'Translating...',
			'autoDetect' => 'Auto-detect',
			'sourceLanguage' => 'Source language',
			'targetLanguage' => 'Target language',
			'noTranslationYet' => 'Enter text above and tap Translate to see the result here',
			'pluginModules' => 'Plugin Modules',
			'addPlugin' => 'Add Plugin',
			'editPlugin' => 'Edit Plugin',
			'noPluginsYet' => 'No plugin modules yet, tap + to add one',
			'builtinPluginCannotDelete' => 'Built-in plugins cannot be deleted',
			'pluginIcon' => 'Icon (emoji)',
			'pluginDescription' => 'Description',
			'pluginPrompt' => 'Prompt',
			'pluginPromptHint' => 'The prompt defines what this module does. The text you type is sent as the input; leave empty to use a generic prompt.',
			'processing' => 'Processing...',
			'run' => 'Run',
			'output' => 'Output',
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
			'playerLoadingImage' => 'Custom Loading Image',
			'inputImagePath' => 'Enter image path or data: base64 (GIF/PNG/JPG/WebP)',
			'loadingVideo' => 'Loading video',
			'openLog' => 'Open Log',
			'openAnime' => 'Open anime',
			'sourceNotInstalled' => ({required Object source}) => 'Anime source "${source}" is not installed. Add it in Source settings to open this anime',
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
			'staffList' => 'Staff',
			'start' => 'Start',
			'storagePathForLocalAnimes' => 'Storage Path for local animes',
			'submit' => 'Submit',
			'suggestions' => 'Suggestions',
			'syncData' => 'Sync Data',
			'lastSyncTime' => 'Last sync',
			'neverSynced' => 'Never synced',
			'configured' => 'Configured',
			'sync' => 'Sync',
			'syncingData' => 'Syncing Data',
			'system' => 'System',
			'tapToTurnPages' => 'Tap to turn Pages',
			'theUrlShouldPointToAIndexJsonFile' => 'The URL should point to a \'index.json\' file',
			'theFolderIsLinkedToSource' => ({required Object source}) => 'The folder is Linked to ${source}',
			'themeColor' => 'Theme Color',
			'themeMode' => 'Theme Mode',
			'timetable' => 'Timetable',
			'weekTotal' => 'This Week Total',
			'todayTotal' => 'Today Total',
			'todayBroadcast' => 'Broadcasting Today',
			'broadcastDays' => 'Active Days',
			'generatedBy' => ({required Object version}) => 'Generated by Kostori v${version}',
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
			'kDefault' => 'Unsorted',
			'defaultValue' => ({required Object v}) => 'Default: ${v}',
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
			'mePagePlugin' => 'Plugins',
			'noMePagePlugin' => 'No plugins (put *.js into plugins folder)',
			'openDir' => 'Open Folder',
			'createPlugin' => 'Create Plugin',
			'pluginSourceUrl' => 'Plugin Source URL',
			'fetchPlugins' => 'Fetch Plugins',
			'pluginName' => 'Plugin file name',
			'alreadyExists' => 'already exists',
			'mainContent' => 'Main Content',
			'switchh' => 'Switch',
			'failedToLoadPleaseTryAgain' => 'Failed to load, please try again.',
			'failedToOpen' => 'Failed to open',
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
			'cloudflareVerificationRequired' => 'Cloudflare verification required',
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
			'firstImageFullHeight' => 'First image shown at full height',
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
			'selectImages' => 'Select Images',
			'addImages' => 'Add Images',
			'importedCountI' => ({required Object i}) => 'Imported ${i} image(s)',
			_ => null,
		} ?? switch (path) {
			'exportImage' => 'Copy / Share',
			'saveAndShare' => 'Save & Share',
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
			'watcherPlayingNext' => 'Playing next episode',
			'watcherEpisodeLoadError' => ({required Object error}) => 'Failed to load episode: ${error}',
			'watcherNoMoreEpisodes' => 'No more episodes to play',
			'watcherRouteNotFound' => 'Route not found',
			'watcherDuplicateEpisode' => 'Episode already loaded',
			'vceEstimating' => 'Estimating…',
			'vceReloadPreview' => 'Reload preview clip',
			'vceReload' => 'Reload',
			'reloadEpisode' => 'Reload current episode',
			'vceTimelineThumbnails' => 'Video timeline thumbnails',
			'vceStart' => 'Start',
			'vceEnd' => 'End',
			'vceModifyStart' => 'Modify start',
			'vceModifyEnd' => 'Modify end',
			'vceTimeFormatHint' => 'Supported formats: 90, 01:30, 1.5...',
			'vcePureNumberIsSeconds' => 'Plain numbers are treated as seconds',
			'vceExportSettings' => 'Export settings',
			'vceQualityCrf' => 'Quality (CRF)',
			'vceHighQuality' => 'High quality',
			'vceStandard' => 'Standard',
			'vceCompressed' => 'Compressed',
			'vceOriginal' => 'Original',
			'vceFixedBitrateOptional' => 'Fixed bitrate (optional, overrides CRF)',
			'vceFixedBitrateKbps' => ({required Object kbps}) => 'Fixed bitrate  ${kbps}kbps',
			'vceIncludeAudio' => 'Include audio',
			'vceFrameRate' => ({required Object fps}) => 'Frame rate  ${fps} fps',
			'vcePaletteColors' => ({required Object n}) => 'Palette colors  ${n}  (fewer = smaller)',
			'vceColorCount' => ({required Object n}) => '${n} colors',
			'vceEnableDithering' => 'Enable dithering (better quality, slightly larger)',
			'vceWebpQuality' => ({required Object n}) => 'WebP quality  ${n}',
			'vceWithAudio' => 'with audio',
			'vceWithoutAudio' => 'no audio',
			'vceDitherOn' => 'dithering on',
			'vceDitherOff' => 'dithering off',
			'vceH264Summary' => ({required Object bitrate, required Object audio}) => 'H.264 · ${bitrate}kbps · ${audio}',
			'vceH264CrfSummary' => ({required Object crf, required Object audio}) => 'H.264 · CRF ${crf} · ${audio}',
			'vceGifSummary' => ({required Object fps, required Object colors, required Object dither, required Object audio}) => 'GIF · ${fps} fps · ${colors} colors · ${dither} · ${audio}',
			'vceApngSummary' => ({required Object fps, required Object audio}) => 'APNG · ${fps} fps · ${audio} · browser friendly',
			'vceWebpSummary' => ({required Object fps, required Object quality}) => 'WebP · ${fps} fps · quality ${quality} · smallest size',
			'vceCrop' => 'Crop',
			'vceAspectPresets' => 'Aspect ratio presets',
			'vceHideCropOverlay' => 'Hide crop overlay',
			'vceShowCropOverlay' => 'Show crop overlay (draggable)',
			'vceCropDragHint' => 'When enabled you can drag to select the export area',
			'vceCropInfo' => ({required Object w, required Object h, required Object x, required Object y, required Object pct}) => '${w}×${h}px  start(${x}, ${y})  [${pct}]',
			'watcherDetailsLogs' => 'Details & Logs',
			'watcherMiniWindow' => 'Mini window',
			'rangePickerDragHint' => 'Drag to adjust clip range',
			'bangumiStartWatch' => 'Start watching',
			'bangumiLastSeen' => ({required Object episode}) => 'Last seen: episode ${episode}',
			'bangumiMyRating' => ({required Object score}) => 'My rating: ${score}',
			'animeWatching' => 'Watching',
			'animeCompleted' => 'Completed',
			'animeDropped' => 'Dropped',
			'animeWatchingCount' => ({required Object n}) => '${n} watching',
			'animeCompletedCount' => ({required Object n}) => '${n} completed',
			'animeDroppedCount' => ({required Object n}) => '${n} dropped',
			'animeAirDate' => ({required Object date}) => 'Air date: ${date}',
			'remoteSendFailed' => ({required Object error}) => 'Send failed: ${error}',
			'hubAiBotTriggerMention' => '@ Mention',
			'hubAiBotTriggerPrefix' => 'Prefix',
			'hubAiBotTriggerKeyword' => 'Keyword',
			'hubAiBotTriggerAll' => 'All',
			'hubAiBotDefaultName' => 'AI Assistant',
			'addTag' => 'Add tag',
			'searchMonthSuffix' => ({required Object month}) => '${month}',
			'searchYearMonth' => ({required Object month, required Object year}) => '${month} ${year}',
			'searchUseCount' => ({required Object n}) => '${n} times',
			'addAddress' => 'Add address',
			'noAddress' => 'No addresses',
			'newChatTitle' => ({required Object time}) => 'New chat ${time}',
			'auto' => 'Auto',
			'lengthShort' => 'Short',
			'lengthMedium' => 'Medium',
			'deleteImagesCount' => ({required Object n}) => 'Delete ${n} images',
			'noSearchResults' => 'No search results',
			'itemsCount' => ({required Object n}) => '${n} items',
			'enableSkipBangumiSchedule' => 'Enable skipping Bangumi schedule',
			'bangumiClientId' => 'Client ID',
			'bangumiClientSecret' => 'Client Secret',
			'bangumiOAuthHint' => 'Register an app on bgm.tv/dev to get the client ID and secret',
			'bangumiOAuthLogin' => 'Bangumi Login',
			'bangumiShowNsfw' => 'Show NSFW content',
			'bangumiLoggingIn' => 'Logging in...',
			'bangumiOAuthLogout' => 'Logout',
			'bangumiLoggedIn' => 'Logged in',
			'bangumiNotLoggedIn' => 'Not logged in',
			'bangumiLoginSuccess' => 'Login successful',
			'bangumiLoginFailed' => 'Login failed',
			'bangumiCaptchaOrPasswordError' => 'Incorrect captcha or password, please retry',
			'bangumiCaptchaHint' => 'Tap the captcha image or refresh button to change it',
			'bangumiTokenStatus' => 'Token status',
			'bangumiRefreshToken' => 'Refresh token',
			'bangumiUserId' => 'User ID',
			'bangumiTokenExpires' => 'Expires',
			'bangumiTokenExpired' => 'Expired',
			'bangumiTokenRefreshSuccess' => 'Token refreshed',
			'bangumiTokenRefreshFailed' => 'Token refresh failed',
			'bangumiClientIdSecretRequired' => 'Please fill in the client ID first',
			'recognizeImageFailed' => 'Failed to read image, please retry',
			'recognizeFailed' => 'Recognition failed',
			'newChat' => 'New chat',
			'recognizeEpisodeSuffix' => ({required Object n}) => 'episode ${n}',
			'recognizePrompt' => ({required Object title, required Object episode, required Object from, required Object to, required Object similarity}) => 'I uploaded a screenshot. Recognition result: 《${title}》${episode} (${from} → ${to}, similarity ${similarity}). Please introduce this anime.',
			'aiStepsSuffix' => ({required Object n}) => ' · ${n} steps',
			'bangumiCommentsTitle' => 'Comments',
			'aiExtMarkdown' => 'Markdown rendering',
			'aiExtMarkdownHint' => 'Whether to enable Markdown in reply bubbles',
			'aiExtImageUnderstanding' => 'Image understanding',
			'aiExtImageUnderstandingHint' => 'Whether to allow sending images to the model',
			'lanPlayerNotOpen' => 'Player is not open',
			'lanNoEpisodes' => 'No episode info',
			'lanBeingControlled' => 'This device is being remotely controlled',
			'lanDesktopConnected' => 'Desktop connected and can control this device',
			'lanDisconnect' => 'Disconnect',
			'lanSelfTest' => 'Network self-test',
			'lanCancelConnect' => 'Cancel connection',
			'lanIpHint' => 'IP address',
			'lanPortHint' => 'Port',
			'lanManualConnect' => 'Manual connect',
			'lanDeviceName' => 'Device name',
			'lanNameEmptyHint' => 'Leave empty to use default name',
			'lanNameDisplayHint' => 'Name shown when other devices discover this device',
			'lanPortRangeError' => 'Port must be between 1024-65535',
			'summaryThisWeek' => 'This week',
			'summaryThisMonth' => 'This month',
			'summaryThisWeekTitle' => 'This week summary',
			'summaryThisMonthTitle' => 'This month summary',
			'soulProfileTitle' => 'Soul profile',
			'vtPlaybackComplete' => 'Playback complete',
			'vtReplay' => 'Replay',
			'vtInputUrlHint' => 'Enter playback link…',
			'vtLoad' => 'Load',
			'vtHeaders' => 'Request Headers',
			'vtNoHeaders' => 'No headers, click "Add" to create one',
			'playerNoRequestHeaders' => 'No request headers',
			'vtApplyAndLoad' => 'Apply and load',
			'downloadMainTitle' => 'Main title (Anime name)',
			'downloadIgnoreEpisodeTitle' => 'Ignore episode titles',
			'downloadIgnoreEpisodeTitleDesc' => 'Some episode titles are meaningless (e.g. 1 / video); when on, use episode numbers for file names',
			'downloadMerging' => 'Merging',
			'aiTagRational' => 'Rational',
			'aiTagHumorous' => 'Humorous',
			'aiTagSarcastic' => 'Sarcastic',
			'aiTagGentle' => 'Gentle',
			'aiTagRigorous' => 'Rigorous',
			'aiTagPassionate' => 'Passionate',
			'aiTagCalm' => 'Calm',
			'aiTagCool' => 'Aloof',
			'aiTagEnergetic' => 'Energetic',
			'aiTagChuuni' => 'Chuunibyou',
			'aiTagCunning' => 'Scheming',
			'aiTagFriendly' => 'Friendly',
			'aiToneFormal' => 'Formal',
			'aiToneConcise' => 'Concise',
			'aiToneNatural' => 'Natural',
			'aiPersonaGeneral' => 'General assistant',
			'aiPersonaGeneralDesc' => 'Reliable and friendly, always happy to help users solve problems clearly and logically.',
			'aiPersonaEngineer' => 'Senior engineer',
			'aiPersonaEngineerDesc' => 'Proficient in many programming languages and mainstream frameworks, skilled at code review, debugging and architecture design.',
			'aiPersonaButler' => 'Life butler',
			'aiPersonaButlerDesc' => 'Thoughtful and meticulous life assistant, familiar with daily scheduling, healthy eating and travel planning.',
			'aiPersonaWriter' => 'Writing inspiration',
			'aiPersonaWriterDesc' => 'Imaginative wordsmith, good at novels, essays, copywriting and creative brainstorming.',
			'aiPersonaAdvisor' => 'Knowledge advisor',
			'aiPersonaAdvisorDesc' => 'Erudite and rigorous, good at explaining concepts, answering questions and deep research.',
			'aiPersonaFriend' => 'Caring friend',
			'aiPersonaFriendDesc' => 'Warm and close, listens, accompanies and encourages like a friend.',
			'qrRecognizing' => 'Recognizing QR code in image…',
			'qrScanHint' => 'Place the QR code in the frame to scan',
			'networkRequestFailed' => 'Network request failed',
			'calNoAnimeToday' => 'No anime this day',
			'calRefreshStatus' => 'Refresh status',
			'calScreenshotSave' => 'Screenshot & save',
			'calLoadingSchedule' => 'Loading schedule data...',
			'calDataNotUpdated' => 'Data not updated yet (´;ω;`)',
			'calScreenshotPreview' => 'Screenshot preview',
			'calThisWeek' => 'This week',
			'calToday' => 'Today',
			'calLoadingImage' => 'Loading image...',
			'calGeneratingScreenshot' => 'Generating screenshot...',
			'calDateDay' => ({required Object month, required Object day}) => '${month}/${day}',
			'personTabVoice' => 'Voice cast',
			'personTabChat' => 'Comments',
			'personTabRelation' => 'Character relations',
			'personTabStaffInfo' => 'Producer info',
			'personTabWorks' => 'Works',
			'personTabProfile' => 'Character profile',
			'personSubtitle' => 'Person',
			'lanUdpPortHint' => 'UDP broadcast port is used for device discovery, WebSocket port for remote control',
			'lanMulticastTitle' => 'Multicast address (multi-threaded broadcast)',
			'lanMulticastInvalid' => 'Enter a valid multicast address (224.0.0.0 - 239.255.255.255)',
			'lanMulticastHint' => 'Multicast (multi-threaded broadcast) is used for discovery; a custom address can bypass router/firewall filtering of the default multicast address',
			'lanPinTitle' => 'Connection PIN verification',
			'lanPinLengthHint' => '4-6 digits',
			'lanPinInvalid' => 'Enter a 4-6 digit PIN',
			'lanPinEnableHint' => 'When enabled, other devices must enter this PIN to connect',
			'lanSelfTestFailed' => ({required Object error}) => 'Self-test failed: ${error}',
			'lanSelfTestDetail' => ({required Object platform, required Object udpPort, required Object state}) => 'Device: ${platform}  UDP port: ${udpPort}  Discovery: ${state}',
			'lanPinStatus' => ({required Object status}) => 'PIN verification: ${status}',
			'lanEnabled' => 'Enabled',
			'lanDisabled' => 'Disabled',
			'lanRetest' => 'Retest',
			'lanTroubleshoot' => 'Troubleshooting: both devices on the same Wi-Fi/router; disable \'AP isolation/client isolation\' on the router; both on the latest code.',
			'status' => 'Status',
			'dlnaError' => 'DLNA Error',
			'startSearching' => 'Start searching',
			'searchingDevices' => 'Searching for devices…',
			'noDevicesFound' => 'No devices found',
			'tryingToCast' => 'Trying to cast to',
			'dlnaException' => 'DLNA exception',
			'audioOptionLowLatency' => 'Audio Option: \n Low Latency',
			'audioOptionCompatibility' => 'Audio Option: \n Compatibility',
			'audioOutputDevice' => 'Audio Output Device',
			'noAudioDevice' => 'No audio device detected',
			'volumeBoost' => 'Volume Boost',
			'volumeBoostEnabled' => 'Volume Boost: On',
			'volumeBoostDisabled' => 'Volume Boost: Off',
			'volume' => 'Volume',
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
			'colors.teal' => 'Teal',
			'colors.deepPurple' => 'Deep Purple',
			'colors.yellow' => 'Yellow',
			'colors.cyan' => 'Cyan',
			'colors.m3Default' => 'M3 Default',
			'colors.deepOrange' => 'Deep Orange',
			'colors.indigo' => 'Indigo',
			'colors.cloudyBlue' => 'Cloudy Blue',
			'colors.darkPastelGreen' => 'Dark Pastel Green',
			'colors.dust' => 'Dust',
			'colors.electricLime' => 'Electric Lime',
			'colors.freshGreen' => 'Fresh Green',
			'colors.lightEggplant' => 'Light Eggplant',
			'colors.nastyGreen' => 'Nasty Green',
			'colors.reallyLightBlue' => 'Really Light Blue',
			'colors.tea' => 'Tea',
			'colors.warmPurple' => 'Warm Purple',
			'colors.yellowishTan' => 'Yellowish Tan',
			'colors.cement' => 'Cement',
			'colors.darkGrassGreen' => 'Dark Grass Green',
			'colors.dustyTeal' => 'Dusty Teal',
			'colors.greyTeal' => 'Grey Teal',
			'colors.macaroniAndCheese' => 'Macaroni And Cheese',
			'colors.pinkishTan' => 'Pinkish Tan',
			'colors.spruce' => 'Spruce',
			'colors.strongBlue' => 'Strong Blue',
			'colors.toxicGreen' => 'Toxic Green',
			'colors.windowsBlue' => 'Windows Blue',
			'colors.blueBlue' => 'Blue Blue',
			'colors.blueWithAHintOfPurple' => 'Blue With A Hint Of Purple',
			'colors.booger' => 'Booger',
			'colors.brightSeaGreen' => 'Bright Sea Green',
			'colors.greenTeal' => 'Green Teal',
			'colors.brownish' => 'Brownish',
			'colors.offGreen' => 'Off Green',
			'colors.tangerine' => 'Tangerine',
			'colors.uglyGreen' => 'Ugly Green',
			'colors.orange' => 'Orange',
			'colors.blue' => 'Blue',
			'colors.pink' => 'Pink',
			'colors.green' => 'Green',
			'colors.red' => 'Red',
			'colors.purple' => 'Purple',
			'secondary' => 'Secondary',
			'tertiary' => 'Tertiary',
			'surface' => 'Surface',
			'jumpToPage' => 'Jump to page',
			'page' => 'Page',
			'pagePM' => ({required Object p, required Object m}) => 'Page ${p} / ${m}',
			'first' => 'First',
			'last' => 'Last',
			'invalidPage' => 'Invalid page',
			'unknownError' => 'Unknown error',
			'loadPageAndLoadNextCantBeNull' => 'loadPage and loadNext can\'t be null at the same time',
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
			'audioOption' => 'Low-latency audio',
			'hardwareDecoding' => 'Hardware Decoding',
			'hardwareDecoder' => 'Hardware decoder',
			'videoRenderer' => 'Video renderer',
			'videoSynchronizationMode' => 'Video synchronization mode',
			'enableNoProxyOverrides' => 'Enable No Proxy Overrides',
			'actor' => 'Actor',
			'cv' => 'CV',
			'dub' => 'Dub',
			'chineseDub' => 'Chinese Dub',
			'japaneseDub' => 'Japanese Dub',
			'englishDub' => 'English Dub',
			'koreanDub' => 'Korean Dub',
			'selectedACharacter' => ({required Object a}) => 'Selected ${a} character',
			'searchOptions' => 'Search Options',
			'searchSources' => 'Search Sources',
			'searchGroupAll' => 'All',
			'searchGroupBangumi' => 'Bangumi',
			'searchGroupDefault' => 'Default',
			'chooseSearchSource' => 'Choose Search Source',
			'singleSourceSearch' => 'Single Source',
			'searchGroupBuiltIn' => 'Built-in groups',
			'searchGroupCustom' => 'My groups',
			'manageGroups' => 'Manage Groups',
			'newGroup' => 'New Group',
			'groupName' => 'Group Name',
			'groupExists' => 'Group name already exists',
			'groupSources' => 'Sources in group',
			'assignSources' => 'Assign sources',
			'deleteGroup' => 'Delete Group',
			'deleteGroupConfirm' => 'Delete this group?',
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
			_ => null,
		} ?? switch (path) {
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
			'hubServerStartFailed' => 'Failed to start Hub server',
			'enableTls' => 'Enable HTTPS/WSS',
			'tlsEnabledDesc' => 'Hub will serve over HTTPS/WSS (requires certificate)',
			'tlsDisabledDesc' => 'Hub serves over HTTP/WS',
			'tlsCertificate' => 'TLS Certificate',
			'tlsCertificateHint' => 'PEM certificate chain (Let\'s Encrypt: fullchain.pem)',
			'tlsPrivateKey' => 'TLS Private Key',
			'tlsPrivateKeyHint' => 'PEM private key file path',
			'tlsPassword' => 'TLS Key Password',
			'tlsPasswordHint' => 'Leave empty if the key is not encrypted',
			'browse' => 'Browse',
			'hubServerIsStopped' => 'Hub server is stopped',
			'clientsCount' => 'clients',
			'hubPort' => 'Hub Port',
			'onlineClients' => 'Online Clients',
			'connectedAt' => 'Connected at',
			'messageHistory' => 'Message History',
			'hubClient' => 'Hub Client',
			'connectToHub' => 'Connect to Hub',
			'connect' => 'Connect',
			'disconnect' => 'Disconnect',
			'savedServers' => 'Saved Servers',
			'noSavedServers' => 'No saved servers yet',
			'saveCurrentConfig' => 'Save Current Config',
			'serverName' => 'Server Name',
			'selectServer' => 'Select a server',
			'exportRooms' => 'Export Rooms',
			'importRooms' => 'Import Rooms',
			'danmakuSettings' => 'Danmaku Settings',
			'danmakuColor' => 'Color',
			'danmakuFontSize' => 'Font Size',
			'danmakuOpacity' => 'Opacity',
			'danmakuArea' => 'Display Area',
			'danmakuDuration' => 'Duration',
			'danmakuLineHeight' => 'Line Height',
			'danmaku' => 'Danmaku',
			'watchTogether' => 'Watch Together',
			'watchTogetherRoomHasNoAnime' => 'The watch-together room is not bound to an anime',
			'watchTogetherDesc' => 'Watch anime with friends, create or join a room to chat and share screenshots and subtitles.',
			'selectRoomToStart' => 'Select a room to start watching together',
			'syncToOwner' => 'Sync to Owner',
			'syncedToOwner' => 'Synced to owner progress',
			'ownerNotSharing' => 'Owner is not sharing progress',
			'syncRequiresSameAnime' => ({required Object title}) => 'You are not watching "${title}". Open this anime first to sync',
			'sharingAsOwner' => 'You are the owner, sharing playback progress',
			'episodeNEp' => ({required Object n}) => 'Episode ${n}',
			'joinHubRoom' => 'Join Watch Together Room',
			'hubRoomInvite' => 'Join a watch together room',
			'hubRoomInviteWithRoom' => ({required Object room}) => 'Join ${room} to watch together',
			'invalidHubRoomLink' => 'Invalid watch-together room link',
			'connectingToHub' => 'Connecting to Hub...',
			'joinedRoom' => 'Joined the room',
			'shareRoomQr' => 'Share Room QR Code',
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
			'seekForward' => ({required Object s}) => 'Forward ${s} s',
			'seekBackward' => ({required Object s}) => 'Backward ${s} s',
			'notBroadcast' => 'Not yet aired',
			'items' => 'items',
			'wsBotConnections' => 'WS Bot Connections',
			'subscriptionManagement' => 'Subscription Management',
			'addSubscription' => 'Add subscription',
			'noSubscriptions' => 'No subscriptions. Tap + in the top-right to add.',
			'connectionType' => 'Connection type',
			'wsForward' => 'WS Forward (Hub listens)',
			'wsReverse' => 'WS Reverse (connect to target)',
			'webhookConnection' => 'Webhook (URL push)',
			'httpServer' => 'HTTP Server (listen)',
			'forward' => 'Forward',
			'reverse' => 'Reverse',
			'listenAddress' => 'Listen address',
			'listenPort' => 'Listen port',
			'targetUrl' => 'Target URL',
			'heartbeat' => 'Heartbeat interval (ms, optional)',
			'token' => 'token (optional)',
			'note' => 'Note',
			'running' => 'Running',
			'stopped' => 'Stopped',
			'wsBotDescription' => 'Hub connects to your bot\'s WebSocket server as a client and pushes room messages / system events in real time. The bot maintains a WS listener to receive them.',
			'wsBotUrl' => 'Bot WebSocket URL',
			'wsBotSecret' => 'Handshake Secret (optional)',
			'wsBotMessageEvents' => 'Message Events',
			'wsBotSystemEvents' => 'System Events',
			'wsReverseTitle' => 'Reverse: Bot connects to Hub',
			'wsReverseInfo' => ({required Object host}) => 'The bot can also connect to this Hub as a WebSocket client: ws://${host}/hub, then authenticate with the Hub API Key (type: auth, token: <key>). This gives full two-way messaging. See HUB_BOT_API.md for the protocol.',
			'hubManagement' => 'Hub Management',
			'chatRoom' => 'Chat Room',
			'roomType' => 'Room Type',
			'webhooks' => 'Webhooks',
			'inboundWebhooks' => 'Inbound Webhooks',
			'outboundWebhooks' => 'Outbound Webhooks',
			'createWebhook' => 'Create Webhook',
			'webhookName' => 'Webhook Name',
			'webhookUrl' => 'Webhook URL',
			'webhookSecret' => 'Webhook Secret (HMAC-SHA256)',
			'webhookUsageHint' => 'Send a POST request with {"text": "..."} to push a message to the room:',
			'webhookMessageEvents' => 'Message Events',
			'webhookSystemEvents' => 'System Events',
			'noWebhooks' => 'No webhooks configured',
			'hubAiBot' => 'AI Companion Bot',
			'hubAiBotEnabled' => 'Enable AI Bot',
			'hubAiBotStatus' => 'Enabled',
			'hubAiBotStatusDisabled' => 'Disabled',
			'hubAiBotConfigure' => 'Configure',
			'hubAiBotConfigureDesc' => 'Name, provider, model & persona',
			'hubAiBotConfigTitle' => 'AI Companion Bot Settings',
			'hubAiBotName' => 'Bot Name',
			'hubAiBotProvider' => 'AI Provider',
			'hubAiBotProviderHint' => 'e.g. deepseek',
			'hubAiBotProviderHelper' => 'Provider source key in AI settings. Must have an enabled API key.',
			'hubAiBotModel' => 'Model (optional)',
			'hubAiBotModelHint' => 'Leave empty for provider default',
			'hubAiBotModelDefault' => 'Use provider default model',
			'hubAiBotSystemPrompt' => 'Persona / System Prompt',
			'hubAiBotContextMessages' => 'Context messages',
			'hubAiBotTriggerMode' => 'Trigger Mode',
			'hubAiBotTriggerPattern' => 'Trigger pattern',
			'hubAiBotKeywordHint' => 'e.g.',
			'hubAiBotMinInterval' => 'Min reply interval (s)',
			'hubAiBotReplyDm' => 'Reply to private messages',
			'satoriBotManage' => 'Satori Bot Management',
			'satoriBotManageDesc' => 'Third-party Satori bots',
			'satoriBotCountUnit' => 'bot(s)',
			'satoriBotAdd' => 'Add Bot',
			'satoriBotEdit' => 'Edit Bot',
			'satoriBotDelete' => 'Delete Bot',
			'satoriBotName' => 'Bot Name',
			'satoriBotNameHint' => 'Display name shown in the room member list and @ mentions',
			'satoriBotAvatar' => 'Avatar',
			'satoriBotBio' => 'Biography',
			'satoriBotToken' => 'Connection Token',
			'satoriBotTokenHint' => 'The token used by the Satori client to connect and bind to this bot',
			'satoriBotTokenRegen' => 'Regenerate',
			'satoriBotEnabled' => 'Enabled',
			'satoriBotDeleteConfirm' => 'Delete this bot? Connected clients will be disconnected.',
			'satoriBotTokenCopied' => 'Token copied',
			'satoriBotConfigTitle' => 'Satori Bot',
			'webAdminSettings' => 'Web Admin Settings',
			'webAdminWhatIs' => 'What is Web Admin?',
			'webAdminDescription' => 'The Web Admin provides a browser-based dashboard for managing the Hub. Open the address in any device browser to view server status, manage rooms & clients, browse logs, edit config, control the AI bot & webhooks, and restart the Hub. It uses the existing Hub API Key for authentication.',
			'webAdminFeatures' => 'Available Features',
			'webAdminFeatureOverview' => 'Status overview',
			'webAdminFeatureRooms' => 'Rooms & sending messages',
			'webAdminFeatureClients' => 'Online clients',
			'webAdminFeatureLogs' => 'Logs',
			'webAdminFeatureConfig' => 'Configuration',
			'webAdminFeatureAi' => 'AI bot',
			'webAdminFeatureWebhooks' => 'Webhooks',
			'webAdminFeatureRestart' => 'Restart Hub',
			'webAdminDashboard' => 'Web Admin Dashboard',
			'webAdminEnabled' => 'Enable Web Admin',
			'webAdminOnPort' => 'Port',
			'webAdminPort' => 'Web Admin Port',
			'webAdminUrl' => 'Open in browser',
			'restartHubToApply' => 'Restart Hub to apply',
			'watchingAnime' => ({required Object a}) => 'Watching: ${a}',
			'openChatDialog' => 'Open chat dialog',
			'hubDetails' => 'Hub Details',
			'connectionSettings' => 'Connection Settings',
			'serverAddress' => 'Server Address',
			'host' => 'Host',
			'protocol' => 'Protocol',
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
			'uploadAvatar' => 'Upload avatar',
			'avatar' => 'Avatar',
			'connectFirstToUploadAvatar' => 'Connect to a server first to upload an avatar',
			'avatarUploaded' => 'Avatar uploaded',
			'uploadFailed' => 'Upload failed',
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
			'maxSizeMustBe1to100Mb' => 'Max upload size must be 1–100 MB',
			'cleared' => 'Cleared',
			'imageUpload' => 'Image Upload',
			'clientImageUpload' => 'Client Image Upload',
			'serverOss' => 'Server OSS',
			'clientOss' => 'Client OSS',
			'imagesStoredOnServerDisk' => 'Images stored on server disk, served via /hub/files/',
			'serverReceivesAndProxiesImageToOss' => 'Server receives and proxies image to OSS. Keys stay on server.',
			'clientUploadsDirectlyToOss' => 'Client uploads directly to OSS. Server only gets the final URL.',
			'maxSizeMb' => 'Max Upload Size (MB)',
			'storePath' => 'Store Path',
			'leaveEmptyForDefault' => 'Leave empty for default',
			'publicBaseUrl' => 'Public Base URL',
			'publicBaseUrlHint' => 'External base address for uploaded images (public IPv4/IPv6 or domain); leave empty to use connection address',
			'publicIpDetected' => 'Public IP detected',
			'publicIpDetectFailed' => 'Failed to detect public IP',
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
			'displayNameRequired' => 'Display name is required',
			'enterBio' => 'Enter bio',
			'autoReconnect' => 'Auto Reconnect',
			'allowSelfSignedCert' => 'Allow Self-signed Certificate',
			'allowSelfSignedCertHint' => 'Trust self-signed certificates when connecting over WSS',
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
			'logPrivacyProtection' => 'Log Privacy Protection',
			'logPrivacyProtectionDesc' => 'Mask tokens, keys, passwords and other sensitive info in logs',
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
			'animeCardUseBlur' => 'Anime Card Use Blur Background',
			'showAnimeCardOverlay' => 'Show anime card overlay',
			'tileTitleMarquee' => 'Card Title Marquee',
			'horizontalLayout' => 'Horizontal Layout',
			'bangumiCardPerRow' => 'Anime Card Per Row',
			'bangumiCardPerRowAuto' => 'Auto',
			'calendarFetchEpisodes' => 'Fetch episode info on daily anime table startup',
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
			'tokens' => 'tokens',
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
			'auxModelSettings' => 'Auxiliary Task Models',
			'auxProviderSelection' => 'Provider',
			'auxFollowSession' => 'Follow session provider',
			'auxFollowSessionHint' => 'This task will use the provider configured in the current chat session.',
			'contextCompression' => 'Context Compression',
			'followUpSuggestions' => 'Follow-up Suggestions',
			'autoTitle' => 'Auto Title',
			'connectionDisconnected' => 'Connection to server disconnected',
			'enterServerAddress' => 'Please enter server address',
			'tapToShare' => 'Tap to share',
			'noConfigurationsFound' => 'No configurations found',
			'noData' => 'No data',
			'loginWithPasswordIsDisabled' => 'Login with password is disabled',
			'cannotBeEmpty' => 'Cannot be empty',
			'invalidCookies' => 'Invalid cookies',
			'webviewIsNotAvailable' => 'Webview is not available',
			'sources' => 'Sources',
			'translationFailedPleaseTryAgainLater' => 'Translation failed, please try again later',
			_ => null,
		} ?? switch (path) {
			'translationErrorRegionNotSupported' => 'The AI translation provider does not support your current region. Please switch provider or use a different network',
			'translationErrorModelNotSupported' => 'The configured model is not supported by this provider. Please change it in AI settings',
			'translationErrorApiKeyInvalid' => 'The API key is invalid or lacks permission. Please check it in AI settings',
			'translationErrorRateLimited' => 'Too many requests or insufficient quota. Please try again later',
			'translationErrorRequestFailed' => 'Translation request failed',
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
			'importPersona' => 'Import Persona',
			'newPersona' => 'New Persona',
			'notConfigured' => 'Not configured',
			'enabled' => 'Enabled',
			'required' => 'Required',
			'invalidNumber' => 'Invalid number',
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
			'notBoundToBangumi' => 'This anime is not bound to a Bangumi entry',
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
			'deleteSuccessful' => 'Deleted',
			'confirmDeleteImageHint' => 'This cannot be undone',
			'confirmDeleteAiProvider' => 'Delete this AI provider configuration?',
			'noTagData' => 'No tag data',
			'authenticationRequired' => 'Authentication Required',
			'pleaseAuthenticate' => 'Please authenticate to continue',
			'shutDown' => 'Shut Down',
			'uploadingData' => 'Uploading data...',
			'glimmerModeEnabled' => 'Glimmer mode: on',
			'glimmerModeDisabled' => 'Glimmer mode: off',
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
			'pleaseEnterEpisodeNumber' => 'Please enter episode number',
			'pleaseEnterValidEpisodeNumber' => 'Please enter a valid episode number between 1-999',
			'imageTitle' => 'Title',
			'imageSubtitle' => 'Subtitle',
			'selectBackground' => 'Select Background',
			'changeBackground' => 'Change Background',
			'clearBackground' => 'Clear Background',
			'charCount' => ({required Object count}) => '${count} chars',
			'm3u8AdFilter' => 'M3u8 Ad Filter',
			'enableAdFilter' => 'Enable Ad Filter',
			'filterRules' => 'Filter Rules',
			'adFilterRules' => 'Ad Filter Rules',
			'addRule' => 'Add Rule',
			'ruleName' => 'Rule Name',
			'urlRegex' => 'URL Regex',
			'domainBlock' => 'Domain Block',
			'durationFilter' => 'Duration Filter',
			'tagMark' => 'Tag Mark',
			'regexHint' => 'Regex pattern, e.g. preroll|/ads?/',
			'domainHint' => 'Domains, separated by commas',
			'durationHint' => 'Seconds, e.g. 4.0',
			'tagHint' => 'e.g. #EXT-X-CUE-OUT',
			'cueAdTag' => 'CUE Ad Tag',
			'ultraShortSegment' => 'Ultra Short Segment',
			'commonAdUrlPattern' => 'Common Ad URL Pattern',
			'keywordMatch' => 'Keyword Match',
			'keywordHint' => 'Substring, e.g. advert or adservice',
			'commonAdKeyword' => 'Common Ad Keyword',
			'videoDetails' => 'Video Details',
			'synopsis' => 'Synopsis',
			'currentEpisode' => 'Current Episode',
			'playbackRoute' => 'Playback Route',
			'progress' => 'Progress',
			'playbackSpeed' => 'Playback Speed',
			'otherSettings' => 'Other Settings',
			'audioLowLatency' => 'Audio: Low Latency',
			'audioCompatibility' => 'Audio: Compatibility',
			'videoClipEditor' => 'Video Clip Editor',
			'clipStartTime' => 'Start Time',
			'clipEndTime' => 'End Time',
			'clipDuration' => 'Duration',
			'previewClip' => 'Preview',
			'exportClip' => 'Export',
			'exportFormat' => 'Export Format',
			'exportQuality' => 'Export Quality',
			'exportSize' => 'Export Size',
			'cropArea' => 'Crop Area',
			'selectCropArea' => 'Select Crop Area',
			'fullFrame' => 'Full Frame',
			'customCrop' => 'Custom Crop',
			'qualityLow' => 'Low Quality',
			'qualityMedium' => 'Medium Quality',
			'qualityHigh' => 'High Quality',
			'gifExport' => 'GIF Export',
			'apngExport' => 'APNG Export',
			'mp4Export' => 'MP4 Export',
			'exportSuccess' => 'Export Success',
			'exportFailed' => 'Export Failed',
			'selectTimeRange' => 'Select Time Range',
			'recordingFeature' => 'Record',
			'tapToRecord' => 'Tap to Record',
			'lanDiscovery' => 'LAN Discovery',
			'lanAutoDiscovery' => 'Auto Discovery on Page Enter',
			'lanDiscoverDevices' => 'Discover Devices',
			'lanRemoteControl' => 'Remote Control',
			'lanStartDiscovery' => 'Start Discovery',
			'lanStopDiscovery' => 'Stop Discovery',
			'lanNoDevicesFound' => 'No Devices Found',
			'lanSearching' => 'Searching...',
			'lanShowQrCode' => 'Show QR Code',
			'lanDeviceInfo' => 'Device Info',
			'lanDeviceDoesNotSupportQrPairing' => 'Device does not support QR pairing',
			'lanQrCodeFor' => 'QR Code for',
			'lanScanQrCodeToConnect' => 'Scan QR code to connect remote device',
			'lanGeneratingQrCode' => 'Generating QR Code...',
			'lanRemoteControlDescription' => 'After scanning, you can remotely control this device',
			'lanPairingRequestReceived' => 'Pairing Request Received',
			'lanDevice' => 'Device',
			'lanConnectingToRemoteDevice' => 'Connecting to remote device...',
			'lanRemoteControlConnected' => 'Remote control connected',
			'lanRemoteControlConnectionFailed' => 'Remote control connection failed',
			'lanInvalidRemoteControlLink' => 'Invalid remote control link',
			'lanRemoteControlConnection' => 'Remote Control Connection',
			'lanAccept' => 'Accept',
			'lanDeviceId' => 'Device ID',
			'lanConnect' => 'Connect',
			'lanExitControl' => 'Exit Control',
			'lanConnectedDevices' => 'Connected Devices',
			'lanNoDeviceConnected' => 'No device connected',
			'lanPlayerControl' => 'Player Control',
			'lanNavigationControl' => 'Navigation Control',
			'lanNavHome' => 'Home',
			'lanNavSearch' => 'Search',
			'lanNavSettings' => 'Settings',
			'lanSeekBack' => 'Seek Back',
			'lanSeekForward' => 'Seek Forward',
			'lanNavigation' => 'Navigation',
			'lanSearch' => 'Search',
			'lanPlaybackControl' => 'Playback Control',
			'lanPlay' => 'Play',
			'lanPause' => 'Pause',
			'lanSeekTo' => 'Seek to',
			'lanVolume' => 'Volume',
			'lanPlaybackSpeed' => 'Playback Speed',
			'lanSelectEpisode' => 'Select Episode',
			'lanNextEpisode' => 'Next Episode',
			'lanPreviousEpisode' => 'Previous Episode',
			'lanToggleFullscreen' => 'Toggle Fullscreen',
			'lanVolumeUp' => 'Volume Up',
			'lanVolumeDown' => 'Volume Down',
			'lanWaitingForEpisodeInfo' => 'Waiting for the controlled device to send episode info...',
			'lanSyncStatus' => 'Sync Status',
			'lanSyncing' => 'Syncing...',
			'lanLastSyncTime' => 'Last sync time',
			'lanPendingChanges' => 'Pending changes',
			'lanConflictDetected' => 'Conflict Detected',
			'lanConflictResolution' => 'Conflict Resolution',
			'lanLocalWins' => 'Keep Local',
			'lanRemoteWins' => 'Keep Remote',
			'lanKeepBoth' => 'Keep Both',
			'lanManualResolution' => 'Manual Resolution',
			'lanConflictField' => 'Conflicting field',
			'lanErrorOccurred' => 'Error occurred',
			'lanCommandExecuted' => 'Command executed',
			'lanCommandFailed' => 'Command failed',
			'lanNoPermission' => 'No permission',
			'lanOpenAnimeDetail' => 'Open Anime Detail',
			'lanSyncProgress' => 'Sync Progress',
			'aggregationEntry' => 'Aggregation Entry',
			'aiLabel' => 'AI',
			'lanLabel' => 'LAN',
			'h264CRF' => 'H.264 · CRF',
			'ffmpegNotFound' => 'FFmpeg Not Found',
			'ffmpegNotFoundDesktop' => 'Desktop export requires FFmpeg, but no FFmpeg executable found. Please configure FFmpeg path in settings or ensure FFmpeg is in system PATH.',
			'stillOpenAnyway' => 'Still Open',
			'preparing' => 'Preparing…',
			'downloadingPreviewClip' => 'Downloading preview clip…',
			'loadingPlayer' => 'Loading player…',
			'cancelExport' => 'Cancel Export?',
			'exportInProgress' => 'Export in progress, closing will interrupt export.',
			'confirmClose' => 'Confirm Close',
			'stopPreview' => 'Stop Preview',
			'loadingPreview' => 'Loading preview…',
			'previewLoadFailed' => 'Preview load failed',
			'reloadPreviewClip' => 'Reload preview clip',
			'videoTimelineThumbnails' => 'Video timeline thumbnails',
			'startPoint' => 'Start',
			'endPoint' => 'End',
			'jumpToStart' => 'Jump to start',
			'setStartPoint' => 'Set Start',
			'setEndPoint' => 'Set End',
			'editStartPoint' => 'Edit Start',
			'editEndPoint' => 'Edit End',
			'durationFormatHint' => 'Supported formats: 90, 01:30, 1.5...',
			'secondsAsNumber' => 'Pure numbers are treated as seconds',
			'exportSettings' => 'Export Settings',
			'fixedBitrateOptional' => 'Fixed bitrate (optional, overrides CRF)',
			'fixedBitrate' => 'Fixed bitrate',
			'paletteColors' => 'Palette colors',
			'paletteColorsHint' => 'Fewer colors = smaller size',
			'enableDither' => 'Enable Dither',
			'ditherHint' => 'Better quality, slightly larger size',
			'webpQuality' => 'WebP Quality',
			'aspectRatioPresets' => 'Aspect Ratio Presets',
			'hideCropBox' => 'Hide Crop Box',
			'showCropBox' => 'Show Crop Box (draggable)',
			'dragToSelectExportArea' => 'After enabling, drag to select export area',
			'editCropBox' => 'Edit crop box',
			'startPointMinus1s' => 'Start −1s',
			'endPointMinus1s' => 'End −1s',
			'startPointMinus0_1s' => 'Start −0.1s',
			'endPointMinus0_1s' => 'End −0.1s',
			'startPointPlus0_1s' => 'Start +0.1s',
			'endPointPlus0_1s' => 'End +0.1s',
			'startPointPlus1s' => 'Start +1s',
			'endPointPlus1s' => 'End +1s',
			'withAudio' => 'With Audio',
			'noAudio' => 'No Audio',
			'ditherOn' => 'Dither On',
			'ditherOff' => 'Dither Off',
			'gifFormat' => 'GIF',
			'apngFormat' => 'APNG',
			'webpFormat' => 'WebP',
			'browserCompatible' => 'Browser compatible',
			'smallestSize' => 'Smallest size',
			'videoFormat' => 'Video Format',
			'encoding' => 'Encoding…',
			'downloadingVideoSegments' => 'Downloading video segments…',
			'manage' => 'Manage',
			'pleaseAddSomeSources' => 'Please add some sources',
			'noCategoryPages' => 'No Category Pages',
			'videoTestLabel' => 'videoTestLabel',
			'uploading' => 'uploading',
			'addImage' => 'Add image',
			'removeImage' => 'Remove image',
			'compressingImage' => 'Compressing image...',
			'skills' => 'Skills',
			'selectSkills' => 'Select skills',
			'noSkillsAvailable' => 'No skills available',
			'usingTools' => 'Calling tools...',
			'toolCallingTool' => ({required Object tool}) => 'Calling ${tool}...',
			'toolCallLog' => ({required Object count}) => 'Tool calls: ${count}',
			'generatingReply' => 'Generating reply...',
			'stopGenerating' => 'Stop generating',
			'thinking' => 'Thinking',
			'streamInterrupted' => 'Generation interrupted',
			'showThinking' => 'Show thinking',
			'hideThinking' => 'Hide thinking',
			'viewProcess' => 'View process',
			'stepThinking' => 'Thinking',
			'stepTool' => 'Tool',
			'thinkingInProgress' => 'Thinking...',
			'statsCached' => 'cached',
			'statsNoRecords' => 'No activity records',
			'statsActivityOverview' => 'Activity overview',
			'statsWatchDuration' => 'Watch duration',
			'statsClicks' => 'Clicks',
			'statsRatings' => 'Ratings',
			'statsComments' => 'Comments',
			'statsFavorites' => 'Favorites',
			'statsActiveItems' => 'Active items',
			'statsActiveHeatmap' => 'Activity heatmap',
			'statsWatchTrend' => 'Watch trend',
			'statsActiveItemsTop' => ({required Object shown, required Object total}) => 'Active items (top ${shown}/${total})',
			'statsWatchDistribution' => 'Watch duration distribution',
			'statsFrequentTags' => 'Frequent tags',
			'statsTagCloud' => 'Tag cloud',
			'statsUnknown' => 'Unknown',
			'statsCountTimes' => ({required Object n}) => '${n} times',
			'statsCountComments' => ({required Object n}) => '${n} comments',
			'statsCountItems' => ({required Object n}) => '${n} items',
			'statsDateFull' => ({required Object month, required Object day, required Object year}) => '${month}/${day}/${year}',
			'statsDateRangeWeek' => ({required Object month, required Object day, required Object endMonth, required Object endDay, required Object year}) => '${month}/${day} - ${endMonth}/${endDay}, ${year}',
			'statsDateMonth' => ({required Object year, required Object month}) => '${year}.${month}',
			'statsYearMonthName' => ({required Object month, required Object year}) => '${month} ${year}',
			'statsDateRangeHalf' => ({required Object year, required Object startMonth, required Object endMonth}) => '${year}.${startMonth} - ${endMonth}',
			'statsDateYear' => ({required Object year}) => '${year}',
			'statsDateDay' => ({required Object day}) => '${day}',
			'statsDateMonthOnly' => ({required Object month}) => '${month}',
			'statsWeekdayMon' => 'Mon',
			'statsWeekdayTue' => 'Tue',
			'statsWeekdayWed' => 'Wed',
			'statsWeekdayThu' => 'Thu',
			'statsWeekdayFri' => 'Fri',
			'statsWeekdaySat' => 'Sat',
			'statsWeekdaySun' => 'Sun',
			'statsYearlyOverview' => 'Yearly overview',
			'statsRangeOverview' => 'Time range stats',
			'statsWeekly' => 'Weekly',
			'statsMonthly' => 'Monthly',
			'statsQuarterly' => 'Quarterly',
			'statsHalfYearly' => 'Half-yearly',
			'statsYearly' => 'Yearly',
			'statsDaily' => 'Daily',
			'statsSourceList' => 'Source list',
			'statsSelectDate' => 'Select date',
			'statsTimelineTitle' => 'Entry stats',
			'statsTimelineWatch' => ({required Object duration}) => 'Watched ${duration}',
			'statsTimelineClick' => ({required Object value}) => '${value} clicks',
			'statsTimelineNoRecords' => 'No records yet',
			'statsDayRecords' => 'Today\'s records',
			'statsYearSuffix' => ({required Object year}) => '${year}',
			'statsCopiedToClipboard' => 'Copied to clipboard',
			'statsFuture' => 'Future',
			'statsNoRecordsOnDay' => 'No records',
			'statsMonth1' => 'January',
			'statsMonth2' => 'February',
			'statsMonth3' => 'March',
			'statsMonth4' => 'April',
			'statsMonth5' => 'May',
			'statsMonth6' => 'June',
			'statsMonth7' => 'July',
			'statsMonth8' => 'August',
			'statsMonth9' => 'September',
			'statsMonth10' => 'October',
			'statsMonth11' => 'November',
			'statsMonth12' => 'December',
			'statsRatedAt' => ({required Object duration}) => '(at rating ${duration})',
			'statsCreatedComment' => ({required Object time, required Object duration}) => '${time} created a comment ${duration}:',
			'statsModifiedComment' => ({required Object time, required Object n, required Object duration}) => '${time} modified the comment ${n} times ${duration}:',
			'statsCreatedRating' => ({required Object time, required Object duration}) => '${time} rated ${duration}:',
			'statsRateAndComment' => 'rated & commented',
			'statsModifiedRating' => ({required Object time, required Object n, required Object duration}) => '${time} changed the rating ${n} times ${duration}:',
			'statsClickAt' => ({required Object source, required Object platform, required Object value}) => '${source} clicked ${platform} ${value} times',
			'statsDailyClicks' => ({required Object total}) => 'Today\'s clicks: ${total}',
			'statsWatchAt' => ({required Object source, required Object platform, required Object duration}) => '${source} watched ${platform} ${duration}',
			'statsDailyWatch' => ({required Object duration}) => 'Today\'s watch time: ${duration}',
			'statsRecords' => 'Records',
			'statsLastClickAt' => ({required Object time}) => 'Last click today: \n${time}',
			'statsLastWatchAt' => ({required Object time}) => 'Last watch today: \n${time}',
			'statsFavoritesTotal' => ({required Object n}) => 'Favorites: ${n}',
			'statsCompletedCount' => ({required Object n}) => 'Completed: ${n}',
			'statsCompletionRate' => ({required Object n}) => 'Completion: ${n}',
			'statsAverageScore' => ({required Object n}) => 'Average: ${n}',
			'statsStdDev' => ({required Object n}) => 'Std dev: ${n}',
			'statsRatingCount' => ({required Object n}) => 'Rated: ${n}',
			'statsDefault' => 'Default',
			'statsItemCountSuffix' => ({required Object n}) => '${n} items',
			'statsNoRatingItems' => ({required Object score}) => 'No works rated ${score}',
			'statsScoreCount' => ({required Object score, required Object count}) => '${score} pts (${count})',
			'jumpToBottom' => 'Back to bottom',
			'modelDoesNotSupportVision' => 'The current model does not support image understanding',
			'myMessage' => 'My message',
			'aiMessage' => 'AI message',
			'resendFromHere' => 'Resend from here',
			'regenerateReply' => 'Regenerate this reply',
			'noPersonality' => 'No personality',
			'noSystemPromptUsed' => 'No system prompt used',
			'queryBalance' => 'Query Balance',
			'balance' => 'Balance',
			'queryingBalance' => 'Querying balance...',
			'balanceQueryUnsupported' => 'This provider does not support balance query',
			'balanceQueryUrl' => 'Balance Query URL',
			'balanceKeyPath' => 'Result field path',
			'balanceQueryUrlHint' => 'Relative path or absolute URL',
			'balanceKeyPathHint' => 'Dot notation, e.g. data.balance',
			'balanceQueryConfig' => 'Balance Query Config',
			'customProviders' => 'Custom Providers',
			'noCustomProviders' => 'No custom providers yet',
			'newCustomProvider' => 'New Custom Provider',
			'newMcpServer' => 'New MCP Server',
			'newSkill' => 'New Skill',
			'invalidJson' => 'Invalid JSON format',
			'providerKey' => 'Provider Key',
			'providerKeyHint' => 'e.g. my-provider',
			'providerKeyExists' => 'Provider key already exists. Please change it.',
			'defaultModel' => 'Default Model',
			'mainSettings' => 'Main settings',
			'modelSettings' => 'Model settings',
			'editModel' => 'Edit model',
			'openModelSettings' => 'Open settings',
			'setAsDefaultModel' => 'Set as default model',
			'effectiveAddress' => 'Effective address',
			'supportsVision' => 'Supports vision',
			'supportsTools' => 'Supports tool calling',
			'enableVision' => 'Enable vision',
			'disableVision' => 'Disable vision',
			'enableTools' => 'Enable tool calling',
			'disableTools' => 'Disable tool calling',
			'enterProviderKeyToAddModel' => 'Enter the provider key above to add models',
			'mcpServers' => 'MCP Servers',
			'noMcpServers' => 'No MCP servers yet',
			'mcpServerName' => 'Server Name',
			'transport' => 'Transport',
			'stdio' => 'stdio',
			'http' => 'HTTP',
			'sse' => 'SSE',
			'command' => 'Command',
			'args' => 'Arguments (JSON)',
			'env' => 'Environment (JSON)',
			'serverUrl' => 'Server URL',
			'headers' => 'Headers (JSON)',
			'noSkillsYet' => 'No skills yet',
			'skillName' => 'Skill Name',
			'skillKey' => 'Skill Key',
			'builtin' => 'Built-in',
			'skillMarkdownHint' => 'Skills support Markdown',
			'sendMessage' => 'Send message',
			'contextAutoCompressed' => 'Context too long, auto-compressed',
			'chatGreeting' => 'How can I help you today?',
			'chatStart1' => 'Summarize this text',
			'chatStart2' => 'Write a poem',
			'chatStart3' => 'Explain a concept',
			'chatStart4' => 'Translate this',
			'importSkills' => 'Import Skills',
			'importSkillsFromFiles' => 'Markdown file(s)',
			'importSkillsFromFilesHint' => 'Import one or more .md skill files with YAML frontmatter',
			'importSkillsFromFolder' => 'Folder with SKILL.md',
			'importSkillsFromFolderHint' => 'Import a folder containing a SKILL.md file',
			'importingSkills' => 'Importing skills...',
			'noSkillFileFound' => 'No SKILL.md found in the selected folder',
			'importedSkillCount' => ({required Object count}) => 'Imported ${count} skill(s)',
			'importedSkillCountSkipped' => ({required Object imported, required Object skipped}) => 'Imported ${imported} skill(s), skipped ${skipped} invalid file(s)',
			'assistantProfiles' => 'Assistant Profiles',
			'newProfile' => 'New Profile',
			'editAssistantProfile' => 'Edit Profile',
			'profileName' => 'Profile Name',
			'profileIcon' => 'Icon',
			'profileIconHint' => 'One emoji, e.g. 🤖',
			'profilePersona' => 'Persona',
			'profileTone' => 'Tone',
			'profilePromptFragments' => 'Prompt Fragments (one per line)',
			'profileKnowledge' => 'Knowledge (one per line)',
			'profileParams' => 'Generation Parameters',
			'profileBehaviorPrefs' => 'Behavior Preferences',
			'customParamsHint' => 'Leave empty to follow the provider default',
			'previewSystemPrompt' => 'Preview System Prompt',
			'tryChatting' => 'Try Chatting',
			'deleteProfile' => 'Delete Profile',
			'confirmDeleteProfile' => 'Are you sure you want to delete this profile?',
			'noProfilesYet' => 'No profiles yet',
			'profileSaved' => 'Profile saved',
			'profileCopiedToClipboard' => 'Profile copied to clipboard',
			'switchedToProfile' => ({required Object name}) => 'Switched to ${name}',
			'defaultAssistant' => 'Default',
			'conciseReplies' => 'Concise replies',
			'useMarkdownFormatting' => 'Use Markdown formatting',
			'codeFirst' => 'Code first',
			'actionableAdvice' => 'Give actionable advice',
			'profileTabPersona' => 'Persona',
			'profileTabPrompt' => 'Prompt',
			'profileTabSkills' => 'Skills',
			'profileTabParams' => 'Params',
			'profileTabBasic' => 'Basic',
			'profileTabExtensions' => 'Extensions',
			'profileTabMemory' => 'Memory',
			'profileTabRequest' => 'Request',
			'profileTabMcp' => 'MCP',
			'profileMcpHint' => 'Bind MCP servers for this assistant (tools are imported on connection)',
			'profileTabLocalTools' => 'Tools',
			'userNickname' => 'User nickname',
			'userNicknameHint' => 'Shown as the user name and injected into {{user_nickname}}',
			'animeRecognize' => 'Anime recognition',
			'chooseImageToRecognize' => 'Pick an image to identify the anime source',
			_ => null,
		} ?? switch (path) {
			'chooseImage' => 'Choose image',
			'recognizing' => 'Recognizing...',
			'noAnimeFound' => 'No anime recognized, this may not be an anime image',
			'chooseAnotherImage' => 'Try another image',
			'recognizeResult' => 'Recognition results',
			'episodeLabel' => 'EP',
			'unknownEpisode' => 'Unknown episode',
			'openVideoPreview' => 'Video preview',
			'discussInAi' => 'Discuss in AI',
			'dropImageToRecognize' => 'Drop an image to recognize',
			'dropFileToImport' => 'Drop a .js file to import',
			'viewOnBangumi' => 'View on Bangumi',
			'templateVarHint' => 'Available variables: ',
			'profilePersonaRequired' => 'Please select a persona first',
			'defaultAssistantCannotDelete' => 'The system default assistant cannot be deleted',
			'imageUnderstandingDisabled' => 'This assistant has image understanding disabled',
			'modelType' => 'Model type',
			'inputModality' => 'Input modalities',
			'outputModality' => 'Output modalities',
			'supportsReasoning' => 'Supports reasoning',
			'capabilities' => 'Capabilities',
			'modelTypeChat' => 'Chat',
			'modelTypeImage' => 'Image',
			'modelTypeEmbedding' => 'Embedding',
			'modelTypeAudio' => 'Audio',
			'modelTypeRerank' => 'Rerank',
			'modelTypeOther' => 'Other',
			'modalityText' => 'Text',
			'modalityImage' => 'Image',
			'modalityAudio' => 'Audio',
			'modalityVideo' => 'Video',
			'capabilityTools' => 'Tools',
			'capabilityReasoning' => 'Reasoning',
			'apiFormat' => 'API format',
			'apiFormatOpenai' => 'OpenAI (chat)',
			'apiFormatOpenaiResponses' => 'OpenAI Responses',
			'apiFormatGemini' => 'Google (Gemini)',
			'apiFormatClaude' => 'Claude (Anthropic)',
			'testConnection' => 'Test connection',
			'testApiKey' => 'Test API key',
			'enabledByApiKey' => 'Enabled automatically when an API key is filled in',
			'endpointChatCompletions' => 'Chat Completions',
			'endpointResponses' => 'Responses API',
			'connectionOk' => 'Connection OK',
			'modelsUrl' => 'Models list API',
			'fetchModels' => 'Fetch models',
			'noModelsReturned' => 'No models returned',
			'enableReasoning' => 'Enable reasoning',
			'disableReasoning' => 'Disable reasoning',
			'thinkingLevel' => 'Thinking level',
			'thinkingLow' => 'Concise',
			'thinkingStandard' => 'Standard',
			'thinkingDeep' => 'Deep',
			'assistantSettings' => 'Assistant settings',
			'takePhoto' => 'Camera',
			'pickImages' => 'Images',
			'uploadFile' => 'Upload file',
			'compressHistory' => 'Compress history',
			'compressHistoryConfirm' => 'Compress this conversation\'s history to save tokens. Continue?',
			'compressed' => 'Compressed',
			'profileLocalTools' => 'Local tools',
			'profileLocalToolsHint' => 'Built-in tool chain toggles',
			'profileSkills' => 'Skills',
			'profileSkillsHint' => 'Bind skills imported in Extension Management',
			'profileRequest' => 'Custom request',
			'profileRequestSensitiveHint' => 'Sensitive info (e.g. API Key) is persisted with the profile, fill in carefully',
			'profileRequestBaseUrl' => 'Base URL override',
			'profileRequestApiKey' => 'API Key override',
			'profileRequestHeaders' => 'Custom headers (Key: Value per line)',
			'profileRequestExtraBody' => 'Extra body fields (JSON)',
			'profileRequestStop' => 'Stop sequences (one per line)',
			'profileRequestStopHint' => 'Stop generating when this sequence is encountered',
			'profileExtensionsHint' => 'App-level optional module toggles',
			'profileMemoryEnabled' => 'Enable long-term memory',
			'profileMemoryHint' => 'Records preferences, frequent topics and key conclusions; switches with the assistant',
			'profileMemoryMaxEntries' => 'Memory entry limit',
			'profileMemoryEntries' => 'Memory entries',
			'profileMemoryClear' => 'Clear',
			'profileMemoryEmpty' => 'No memory entries yet',
			'profileMemoryAdd' => 'New memory entry',
			'profileCopy' => 'Duplicate',
			'profileExport' => 'Export',
			'profileImport' => 'Import',
			'profileExported' => 'Exported to clipboard',
			'profileImportFailed' => 'Import failed',
			'extensionManagement' => 'Extension Management',
			'extensionManagementHint' => 'Auxiliary task models, role management, MCP servers and skills',
			'roleManagement' => 'Role Management',
			'promptManagement' => 'Prompt',
			'promptInjection' => 'Prompt Injection',
			'promptInjectionHint' => 'Injection position decides where each fragment is inserted in the system prompt',
			'worldBook' => 'World Book',
			'worldBookEntries' => 'World Book entries',
			'newPromptInjection' => 'New Injection',
			'editPromptInjection' => 'Edit Injection',
			'injectionName' => 'Name',
			'injectionContent' => 'Content',
			'injectionPosition' => 'Injection position',
			'injectionPositionAfterPersonality' => 'After personality',
			'injectionPositionAfterSystemPrompt' => 'After custom system prompt',
			'injectionPositionAfterKnowledge' => 'After knowledge',
			'injectionPositionAfterMemory' => 'After memory',
			'injectionPositionBeforeTools' => 'Before tool list',
			'injectionSortOrder' => 'Sort order',
			'noInjectionsYet' => 'No prompt injections yet',
			'worldBookName' => 'Name',
			'worldBookTriggers' => 'Trigger words (one per line)',
			'worldBookTriggersHint' => 'Injected when the user message contains any trigger word',
			'worldBookContent' => 'Content',
			'worldBookPriority' => 'Priority (higher first)',
			'worldBookPriorityHint' => 'Higher priority entries are injected first',
			'newWorldBookEntry' => 'New Entry',
			'worldBookHitTest' => 'Hit Test',
			'worldBookHitTestHint' => 'Type a sentence to see which entries will be triggered',
			'worldBookHitTestPlaceholder' => 'Type a sentence...',
			'worldBookHitsResult' => 'Matching entries',
			'worldBookNoHits' => 'No entries matched',
			'noWorldBookEntriesYet' => 'No world book entries yet',
			'auxTemperature' => 'Temperature',
			'selectAssistantProfile' => 'Select an assistant',
			'selectModel' => 'Select model',
			'profilePersonalityTags' => 'Personality tags',
			'profilePersonalityTagsHint' => 'Multi-select tags, e.g. Rational / Humorous / Sharp-tongued / Gentle',
			'profileCatchphrases' => 'Catchphrases',
			'profileCatchphrasesHint' => 'One per line',
			'profileExamples' => 'Example dialogs (few-shot)',
			'profileExamplesHint' => 'One pair per line, format: 用户: xxx | 助手: xxx',
			'profileReplyStyle' => 'Reply style',
			'replyLength' => 'Reply length',
			'replyLengthShort' => 'Concise',
			'replyLengthNormal' => 'Normal',
			'replyLengthDetailed' => 'Detailed',
			'replyUseEmoji' => 'Use emoji',
			'replyUseMarkdown' => 'Use Markdown formatting',
			'replyAskBack' => 'Ask back at the end',
			'mcpConnectionStatus' => 'Connection status',
			'mcpConnected' => 'Connected',
			'mcpDisconnected' => 'Disconnected',
			'mcpToolsImported' => 'tools imported',
			'mcpReconnect' => 'Reconnect',
			'mcpTestConnection' => 'Test connection',
			'mcpConnecting' => 'Connecting...',
			'mcpConnectionFailed' => 'Connection failed',
			'builderTitle' => 'Source Builder',
			'builderEntry' => 'Build source',
			'builderBasic' => 'Basic Info',
			'builderName' => 'Name',
			'builderKey' => 'Key',
			'builderVersion' => 'Version',
			'builderBaseUrl' => 'Base URL',
			'builderSearch' => 'Search',
			'builderSearchUrl' => 'Search URL template',
			'builderListSelector' => 'List item selector',
			'builderTitleSelector' => 'Title selector',
			'builderCoverSelector' => 'Cover selector',
			'builderCoverAttr' => 'Cover attribute',
			'builderLinkSelector' => 'Link selector',
			'builderPageParam' => 'Page parameter',
			'builderDetail' => 'Anime Detail',
			'builderDetailUrl' => 'Detail URL template',
			'builderDescSelector' => 'Description selector',
			'builderEpisodeSelector' => 'Episode list selector',
			'builderEpisodeTitleSelector' => 'Episode title selector',
			'builderEpisodeLinkSelector' => 'Episode link selector',
			'builderPlay' => 'Playback',
			'builderPlayUrl' => 'Play page URL template',
			'builderExtractRegex' => 'Playback URL regex',
			'builderMaxPageSelector' => 'Max page selector',
			'builderUserAgent' => 'User-Agent',
			'builderPlayDirect' => 'Directly return episode link',
			'builderPlayDirectDesc' => 'The episode link itself is the playable URL (no extra request)',
			'builderPlayRegexDesc' => 'Fetch the play page and extract the URL via regex',
			'builderExplore' => 'Explore',
			'builderExploreTitle' => 'Page title',
			'builderExploreUrl' => 'List URL template ({page})',
			'builderCategory' => 'Category',
			'builderCategoryTitle' => 'Category title',
			'builderCategoryNames' => 'Category names (one per line, "value-name")',
			'builderCategoryUrl' => 'Category list URL ({category} {page})',
			'builderGenerate' => 'Generate & Import',
			'builderNameRequired' => 'Name is required',
			'builderKeyRequired' => 'Key is required',
			'builderKeyInvalid' => 'Key must contain only letters, digits and underscore',
			'builderImported' => 'Source imported',
			'builderGenerateFailed' => 'Generate failed',
			'collapseSidebar' => 'Collapse sidebar',
			'expandSidebar' => 'Expand sidebar',
			'clearFinishedDownload' => 'Clear finished downloads',
			'downloadEmpty' => 'No download tasks',
			'downloadQueued' => 'Queued',
			'downloadCompleted' => 'Completed',
			'pauseDownload' => 'Pause download',
			'resumeDownload' => 'Resume download',
			'retryDownload' => 'Retry download',
			'pausedDownload' => 'Paused',
			'downloadSettings' => 'Download settings',
			'downloadConcurrent' => 'Concurrent tasks',
			'downloadSegmentConcurrent' => 'Segment concurrency',
			'downloadWifiOnly' => 'Wi-Fi only',
			'downloadOther' => 'Other',
			'downloadRecords' => 'Download records',
			'openWithOtherPlayer' => 'Open with other player',
			'downloadTitleFormat' => 'Download title format',
			'downloadFormatHint' => 'Placeholders: {title} {episode} {author} {resolution} {source} {year}',
			'downloadDir' => 'Download directory',
			'loadingStepParse' => 'Resolving video address',
			'loadingStepInit' => 'Initializing player',
			'loadingStepLoad' => 'Loading media',
			'loadingStepBuffer' => 'Buffering',
			'downloadEpisode' => 'Select episode to download',
			'downloadNotYet' => 'No episodes available to download',
			'downloadSelectedCount' => ({required Object n}) => 'Download ${n} episodes',
			'selectResolution' => 'Select resolution',
			'defaultResolution' => 'Default',
			'noResolutionAvailable' => 'No more qualities available',
			'series' => 'Series',
			'singleEpisode' => 'Single episode · 1 total',
			'playing' => 'Playing',
			'selectNone' => 'Select none',
			'downloadActive' => 'Downloading',
			'redownload' => 'Redownload',
			'startAll' => 'Start all',
			'pauseAll' => 'Pause all',
			'cancelAll' => 'Cancel all',
			'recordsEmpty' => 'No download records',
			'fileNotFound' => 'File not found',
			'deleted' => 'Deleted',
			'localPlayerSpeedTip' => 'Long press to change speed',
			'audioTrack' => 'Audio track',
			'subtitle' => 'Subtitles',
			'subtitleOff' => 'Off',
			'quality' => 'Quality',
			'copiedField' => ({required Object x}) => 'Copied: ${x}',
			'selectAliasCount' => ({required Object count}) => 'Select alias (${count})',
			'monthDayFormat' => 'MMM d',
			'monthDay' => ({required Object month, required Object day}) => '${month}/${day}',
			'qrAnimeId' => ({required Object id, required Object source}) => 'Anime ID: ${id}\nSource: ${source}',
			'qrBangumiId' => ({required Object id}) => 'Bangumi ID: ${id}',
			'qrWatchRoom' => ({required Object room, required Object server}) => 'Watch together room: ${room}\nServer: ${server}',
			'qrDetectedType' => ({required Object type}) => 'Detected ${type} link',
			'qrPasswordResolved' => '(Password resolved)\n',
			'reviewedAtTime' => ({required Object time}) => 'Reviewed at ${time}',
			'qrCopiedToClipboard' => 'QR code copied to clipboard',
			'qrSavedToGallery' => 'QR code saved',
			'reloadSuccess' => 'Reloaded successfully',
			'floorOwner' => 'OP',
			'postOwner' => 'OP',
			'collapse' => 'Collapse',
			'expandCount' => ({required Object total}) => 'Expand (${total})',
			'deletedReply' => 'Reply deleted',
			'author' => 'Author',
			'episodeTitleLabel' => 'Episode title',
			'manualSwitch' => 'Manual switch',
			'inputEpisodeNumber' => 'Enter episode number',
			'episodeNumberHint' => 'Enter a number between 1 and 999',
			'enterEpisodeNumber' => 'Please enter an episode number',
			'invalidEpisodeNumber' => 'Please enter a valid number between 1 and 999',
			'episodeN' => ({required Object n}) => 'Ep. ${n}',
			'noViewingRecord' => 'No viewing record found for this episode',
			'viewingRecord' => 'Viewing record',
			'watchDurationLabel' => ({required Object duration}) => 'Watch duration: ${duration}',
			'completedStatus' => ({required Object status}) => 'Completed: ${status}',
			'yes' => 'Yes',
			'no' => 'No',
			'startTimeLabel' => ({required Object time}) => 'Start time: ${time}',
			'endTimeLabel' => ({required Object time}) => 'End time: ${time}',
			'appInfo' => 'App info',
			'partRepoFetchFailed' => ({required Object list}) => 'Some repositories failed to fetch: ${list}',
			'airTimeLabel' => ({required Object time}) => 'Air time: ${time}',
			'durationLabel' => ({required Object duration}) => 'Duration: ${duration}',
			'replyBracket' => '[Reply]',
			'wantToWatch' => 'Want to watch',
			'watching' => 'Watching',
			'addToFolder' => ({required Object folder}) => 'Add to ${folder}',
			'removeFromFolder' => ({required Object folder}) => 'Remove from ${folder}',
			'movedFromTo' => ({required Object from, required Object to}) => 'Move from ${from} to ${to}',
			'unknownFolder' => 'Unknown folder',
			'fetchVideoUrlError' => ({required Object detail}) => 'Failed to get video link: ${detail}',
			'missingUrl' => 'Missing url',
			'success' => 'Success',
			'failedWithStatus' => ({required Object status}) => 'Failed (${status})',
			'checkIn' => 'Check in',
			'button' => 'Button',
			'requestFailedDetail' => ({required Object error}) => 'Request failed: ${error}',
			'play' => 'Play',
			'nextEpisode' => 'Next episode',
			'trackN' => ({required Object n}) => 'Track ${n}',
			'deviceInfo' => 'Device info',
			'conversationInterrupted' => 'Conversation stream interrupted unexpectedly',
			'toolExecutionFailed' => ({required Object error}) => 'Tool execution failed: ${error}',
			'apiKeyNotConfigured' => ({required Object source}) => '${source} API Key is not configured or is disabled',
			'imageInvalid' => 'Invalid image',
			'recognizeBusy' => 'Recognition service is busy, please try again later',
			'connectionTimeout' => 'Connection timeout',
			'pinError' => 'Incorrect PIN',
			'connectionClosed' => 'Connection closed',
			'unknownCommand' => ({required Object type}) => 'Unknown command type: ${type}',
			'processingFailed' => ({required Object error}) => 'Processing failed: ${error}',
			'executionFailed' => ({required Object error}) => 'Execution failed: ${error}',
			'unknownServiceProvider' => ({required Object provider}) => 'Unknown service provider: ${provider}',
			'sessionNotFound' => ({required Object id}) => 'Session not found: ${id}',
			'historyTooShort' => 'Not enough history to compress',
			'messageTooLarge' => 'Message too large, maximum 64KB',
			'rateLimit' => 'Too many requests, please try again later',
			'portBusy' => ({required Object start, required Object end}) => 'Ports ${start} to ${end} are all occupied',
			'webSocketOnly' => 'Only WebSocket connections are supported',
			'toolRoundsExceeded' => ({required Object source}) => '${source} has too many tool call rounds',
			'requestHeaders' => 'Headers',
			'direct' => 'Direct',
			'manual' => 'Manual',
			'votes' => ({required Object n}) => '${n} votes',
			'pagesCount' => ({required Object n}) => '${n} pages',
			'emptyPage' => 'Empty Page',
			'copyTextCommand' => 'Copy text command',
			'saveFailedPermissionOrDirectory' => 'Save failed: permission or directory error',
			'biometricsNotSupported' => 'Biometrics not supported',
			'invalidFileType' => ({required Object ext}) => 'Invalid file type: ${ext}',
			'downloadCanceled' => 'Download canceled',
			'tokenInvalidOrExpired' => 'Token invalid or expired',
			'errorsLabel' => ({required Object n}) => 'Errors: ${n}',
			'inputPinTitle' => 'Enter connection PIN',
			'inputPinHint' => 'Enter PIN code',
			'topicsPoster' => 'Post author',
			'timetableCount' => ({required Object timetable, required Object count}) => '${timetable} (${count})',
			'fetchPluginsCount' => ({required Object fetchPlugins, required Object count}) => '${fetchPlugins}: ${count}',
			'connectToDevice' => ({required Object device}) => 'Connect to ${device}',
			'receiveTimeout' => 'Receive Timeout: This indicates that the server is too busy to respond',
			'connectionTerminatedDuringHandshake' => 'Connection terminated during handshake: This may be caused by the firewall blocking the connection or your requests are too frequent.',
			'connectionResetByPeer' => 'Connection reset by peer: The error is unrelated to the app, please check your network.',
			'downloadStarted' => 'Started download',
			'forceMerge' => 'Force merge',
			'mergeProcessing' => 'Merging downloaded segments...',
			'tlsSharedHint' => 'Applied to both the base service and Hub server (shared certificate)',
			'loginExpiredReLogin' => 'Login expired, please re-login',
			'viewError' => 'View error',
			'exportLogFile' => 'Export log file',
			'deleteLogFile' => 'Delete log file',
			'clearLogsFileConfirm' => 'Delete the saved log files (logs.txt / logs.old.txt)?',
			'clearLog' => 'Clear logs',
			'logSettings' => 'Log settings',
			'logRetainCount' => 'Keep archived log files',
			'logFileSizeMb' => 'Log file size limit (MB)',
			_ => null,
		};
	}
}

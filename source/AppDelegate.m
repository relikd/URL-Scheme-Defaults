@import Cocoa;
@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSComboBoxCellDataSource>
@end

static NSMutableDictionary<NSString*, NSString*> *nameCache;

// ################################################################
// #
// #  MARK: - AppId -
// #
// ################################################################

@interface AppId : NSObject
@property (copy) NSString *bundleId;
@property (copy) NSString *name;
@end

@implementation AppId
+ (instancetype)bundleId:(NSString*)bundleId {
	AppId *a = [AppId new];
	a.bundleId = bundleId;
	[a updateAppName];
	return a;
}
/// First query name cache for available names. If not set, add new name to cache
- (void)updateAppName {
	self.name = nameCache[self.bundleId];
	if (!self.name) {
		self.name = [self applicationNameForBundleId:self.bundleId];
		if (!self.name) self.name = self.bundleId;
		[nameCache setValue:self.name forKey:self.bundleId];
	}
}
/// Returns application name for given identifier
- (NSString*)applicationNameForBundleId:(NSString*)bundleID {
	NSArray<NSURL*> *urls = CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)bundleID, NULL));
	if (urls.count > 0) {
		NSDictionary *info = CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)urls.firstObject));
		return info[(NSString*)kCFBundleExecutableKey];
	}
	return nil;
}
@end


// ################################################################
// #
// #  MARK: - Scheme -
// #
// ################################################################

@interface Scheme : NSObject
@property (copy) NSString *name;
@property (weak) AppId *registered;
@property (strong) NSArray<AppId*> *available;
@end

@implementation Scheme
+ (instancetype)name:(NSString*)name {
	Scheme *s = [Scheme new];
	s.name = name;
	[s prepareAvailable];
	return s;
}
- (BOOL)setBundleId:(NSString*)bundleId  {
	OSStatus s = LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)self.name, (__bridge CFStringRef)bundleId);
	return s == 0;
}
/// Select app at index and set it default. Checks whether set successful. Ignores setting same id.
- (void)setDefault:(NSUInteger)index {
	AppId *app = self.available[index];
	if (app != self.registered && [self setBundleId:app.bundleId])
		self.registered = app;
}
/// Add bundle id to available if not already. Then set the default.
- (void)setNewDefault:(NSString*)bundleId {
	NSUInteger idx = [self.available indexOfObjectPassingTest:^BOOL(AppId * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		return [obj.bundleId isEqualToString:bundleId];
	}];
	if (idx != NSNotFound) {
		[self setDefault:idx];
	} else {
		if ([self setBundleId:bundleId]) {
			AppId *newApp = [AppId bundleId:bundleId];
			self.available = [self.available arrayByAddingObject:newApp];
			self.registered = newApp;
		}
	}
}
/// Gathers all registered application for scheme and inserts to available
- (void)prepareAvailable {
	NSMutableArray *list = [NSMutableArray array];
	NSString *defaultId = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme((__bridge CFStringRef)self.name));
	NSArray<NSString*> *ids = CFBridgingRelease(LSCopyAllHandlersForURLScheme((__bridge CFStringRef)self.name));
	// LSCopyDefaultRoleHandlerForContentType, LSCopyAllRoleHandlersForContentType, kLSRolesAll
	for (NSString *bundleId in ids) {
		[list addObject:[AppId bundleId:bundleId]];
		if ([bundleId isEqualToString:defaultId])
			self.registered = list.lastObject;
	}
	self.available = [list sortedArrayUsingComparator:^NSComparisonResult(AppId *a, AppId *b) {
		return [[a.name lowercaseString] compare:[b.name lowercaseString]];
	}];
}
@end


// ################################################################
// #
// #  MARK: - Modal -
// #
// ################################################################

@interface ChangeSchemeModal : NSPanel
@property (weak) IBOutlet NSTextField *schemeLabel;
@property (weak) IBOutlet NSTextField *bundleIdField;
@property (weak) Scheme* selectedScheme;
@end

@implementation ChangeSchemeModal
- (void)setScheme:(Scheme*)scheme {
	self.selectedScheme = scheme;
	[self.schemeLabel setStringValue:[@"URL scheme: " stringByAppendingString:scheme.name]];
	[self.bundleIdField setStringValue:scheme.registered.bundleId];
}
- (IBAction)close:(NSButton*)sender {
	[self close];
}
- (IBAction)save:(NSButton*)sender {
	[self.selectedScheme setNewDefault: self.bundleIdField.stringValue];
	[self close];
}
@end

// ################################################################
// #
// #  MARK: - Main -
// #
// ################################################################

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTableView *table;
@property (weak) IBOutlet ChangeSchemeModal *modal;
@property (strong) NSMutableArray<Scheme*> *data;
@end


@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	nameCache = [NSMutableDictionary dictionary];
	self.data = [NSMutableArray array];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	for (NSString *urlScheme in [self readLaunchServicesSchemes]) {
		Scheme *s = [Scheme name:urlScheme];
		// if (s.available.count > 1)
		[self.data addObject:s];
	}
	[self.data sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
	[self.table reloadData];
}

- (NSSet*)readLaunchServicesSchemes {
	NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.LaunchServices/com.apple.launchservices.secure"];
	NSMutableSet<NSString*> *allSchemes = [NSMutableSet set];
	for (NSDictionary *handler in [ud arrayForKey:@"LSHandlers"]) {
		NSString *scheme = handler[@"LSHandlerURLScheme"]; // LSHandlerContentType
		if (scheme) [allSchemes addObject:scheme];
	}
	return allSchemes;
}


#pragma mark - TableView & ComboBox data source

// table view data source
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.data.count;
}
// table view data source
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if ([tableColumn.identifier isEqualToString:@"colScheme"])
		return self.data[row].name;
	return self.data[row].registered.name;
}
// table view data source
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
	[self.data sortUsingDescriptors:tableView.sortDescriptors];
	[tableView setNeedsDisplay];
}
// table view data source
- (void)tableView:(NSTableView *)tableView setObjectValue:(nullable id)object forTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
	if ([tableColumn.identifier isEqualToString:@"colEdit"]) {
		[self.modal setScheme:self.data[row]];
		[tableView.window beginSheet:self.modal completionHandler:nil];
	} else if ([tableColumn.identifier isEqualToString:@"colApp"]) {
		NSInteger idx = [[tableView selectedCell] indexOfSelectedItem];
		[self.data[row] setDefault:idx];
	}
}
// combo box data source
- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell {
	Scheme *s = self.data[self.table.selectedRow];
	comboBoxCell.representedObject = s.available;
	return s.available.count;
}
// combo box data source
- (id)comboBoxCell:(NSComboBoxCell *)comboBoxCell objectValueForItemAtIndex:(NSInteger)index {
	NSArray<AppId*> *apps = comboBoxCell.representedObject;
	return apps[index].name;
}

@end

// Rebuild Launch Services cache
// https://eclecticlight.co/2017/08/11/launch-services-database-problems-correcting-and-rebuilding/
// /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -v -apps u

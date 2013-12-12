//
//  XcAddedMarkupPlugin.m
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcAddedMarkupPlugin.h"
#import "XcodeColors.h"
#import "XcEmbeddedControls.h"

#define XCODE_COLORS "XcodeColors"


#define kXcAddedMarkupPluginDisabled    @"XcAddedMarkupPluginDisabled"
#define kXcAddedMarkupFixDisabled       @"XcAddedMarkupFixDisabled"
#define kXcAddedMarkupImagesDisabled    @"XcAddedMarkupImagesDisabled"
#define kXcAddedMarkupLinksDisabled     @"XcAddedMarkupLinksDisabled"
#define kXcAddedMarkupAnsiColorsDisabled    @"XcAddedMarkupAnsiColorsDisabled"

#define USERDEFAULTS_REFRESH_TIME 5.0

static IMP IMP_NSTextStorage_fixAttributesInRange = nil;
static IMP IMP_NSWorkspace_openURL = nil;

NSTimeInterval lastUserDefaultsSync = 0.0;


@implementation XcodeColors_NSTextStorage

- (BOOL)openURL:(NSURL *)url
{
    if (url && ! url.scheme) {
        NSString *path = [[url absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *theURL = [NSURL fileURLWithPath:path isDirectory:NO];
        if ([theURL checkResourceIsReachableAndReturnError:nil]) {
            return [[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Xcode"];
        }
    }
    return IMP_NSWorkspace_openURL(self, _cmd, url);
}

- (void)fixAttributesInRange:(NSRange)aRange
{
	// This method "overrides" the method within NSTextStorage.
	
	// First we invoke the actual NSTextStorage method.
	// This allows it to do any normal processing.
	
	IMP_NSTextStorage_fixAttributesInRange(self, _cmd, aRange);

    // Parts of this plugin can be enabled or disabled using shell commands like:
    // $ defaults write com.apple.dt.Xcode XcAddedMarkupAnsiColorsDisabled -bool no
    // To take changes into effect, we synchronize every few seconds if needed.
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastUserDefaultsSync >= USERDEFAULTS_REFRESH_TIME) {
        [[NSUserDefaults standardUserDefaults] synchronize];
        lastUserDefaultsSync = now;
    }

    BOOL plugin_disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupPluginDisabled];
    if (plugin_disabled) {
        return;
    }
    
    // Then we scan for our special escape sequences, and apply desired color attributes and other markup.
	
	char *xcode_colors = getenv(XCODE_COLORS);
	if (xcode_colors && (strcmp(xcode_colors, "YES") == 0))
	{
        if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupImagesDisabled]) {
            [[XcAddedMarkupPlugin globalMarker] attachEmbeddedImages:self textStorageRange:aRange];
        }
        
        if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupLinksDisabled]) {
            [[XcAddedMarkupPlugin globalMarker] attachEmbeddedLinks:self textStorageRange:aRange];
        }
        
        if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupAnsiColorsDisabled]) {
            ApplyANSIColors(self, aRange, XCODE_COLORS_ESCAPE);
        }
	}
}

@end


@implementation XcAddedMarkupPlugin

@synthesize marker;

static XcAddedMarkupPlugin *sharedPlugin = nil;
static XcEmbeddedControls *embeddedControls = nil;

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
		embeddedControls = [[XcEmbeddedControls alloc] init];
	});
}

+ (id)globalMarker
{
    return [sharedPlugin marker];
}

- (id)init
{
	if (self = [super init]) {
        BOOL plugin_disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupPluginDisabled];
        if (plugin_disabled) {
            return self;
        }
        
        marker = [[AddedRangeMarker alloc] init];


		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];

        BOOL plugin_fixdisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupPluginDisabled];
        if (! plugin_fixdisabled) {
            [self loadXcodeColors];
        }
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSLog(@"XcAddedMarkup plugin loaded");
}

- (void)loadXcodeColors
{
	char *xcode_colors = getenv(XCODE_COLORS);
	if (xcode_colors && (strcmp(xcode_colors, "YES") != 0))
		return;
	
    IMP_NSTextStorage_fixAttributesInRange = ReplaceInstanceMethod([NSTextStorage class], @selector(fixAttributesInRange:),
                                                                   [XcodeColors_NSTextStorage class], @selector(fixAttributesInRange:));
	
    IMP_NSWorkspace_openURL = ReplaceInstanceMethod([NSWorkspace class], @selector(openURL:),
                                                                   [XcodeColors_NSTextStorage class], @selector(openURL:));
	
	setenv(XCODE_COLORS, "YES", 0);
}


@end

//
//  XcAddedMarkupPlugin.m
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcAddedMarkupPlugin.h"
#import "XcAM_XcodeColors.h"
#import "XcEmbeddedControls.h"

#define XCODE_COLORS "XcodeColors"


#define kXcAddedMarkupPluginDisabled    @"XcAddedMarkupPluginDisabled"
#define kXcAddedMarkupFixDisabled       @"XcAddedMarkupFixDisabled"
#define kXcAddedMarkupImagesDisabled    @"XcAddedMarkupImagesDisabled"
#define kXcAddedMarkupLinksDisabled     @"XcAddedMarkupLinksDisabled"
#define kXcAddedMarkupAnsiColorsDisabled    @"XcAddedMarkupAnsiColorsDisabled"

#define USERDEFAULTS_REFRESH_TIME 5.0

static void (*IMP_XcAM_NSTextStorage_fixAttributesInRange)(id, SEL, NSRange)  = nil;
static IMP IMP_NSWorkspace_openURL = nil;
static BOOL XcodeColorsPluginPresent;

static NSTimeInterval lastUserDefaultsSync = 0.0;


@implementation XcAM_XcodeColors_NSTextStorage

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
    // It may also be the already swizzled method from the XcodeColors plugin

	IMP_XcAM_NSTextStorage_fixAttributesInRange(self, _cmd, aRange);
    
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
    if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupImagesDisabled]) {
        [[XcAddedMarkupPlugin globalMarker] attachEmbeddedImages:self textStorageRange:aRange];
    }
    
    if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupLinksDisabled]) {
        [[XcAddedMarkupPlugin globalMarker] attachEmbeddedLinks:self textStorageRange:aRange];
    }
    
    if (! [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupAnsiColorsDisabled]) {
        // If the XcodeColors plugin is present, we don't do the ANSI coloring ourself.
        if (! XcodeColorsPluginPresent) {
            XcAM_ApplyANSIColors(self, aRange, XCODE_COLORS_ESCAPE);
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
    
	// The the XcodeColors plugin is also present, we will swizzle to its XcodeColors_NSTextStorage class
    if (NSClassFromString(@"XcodeColors_NSTextStorage")) {
        XcodeColorsPluginPresent = YES;
    }
    IMP_XcAM_NSTextStorage_fixAttributesInRange = XcAM_ReplaceInstanceMethod([NSTextStorage class], @selector(fixAttributesInRange:),
                                                                             [XcAM_XcodeColors_NSTextStorage class], @selector(fixAttributesInRange:));
    IMP_NSWorkspace_openURL = XcAM_ReplaceInstanceMethod([NSWorkspace class], @selector(openURL:),
                                                                   [XcAM_XcodeColors_NSTextStorage class], @selector(openURL:));
	setenv(XCODE_COLORS, "YES", 0);
}


@end

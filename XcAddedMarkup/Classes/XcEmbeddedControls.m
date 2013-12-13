//
//  XcEmbeddedControls.m
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcEmbeddedControls.h"
#import "XcAMFrameView.h"
#import "XcAMPopoverViewController.h"

#define kXcAddedMarkupEmbeddedControlsDisabled	@"XcAddedMarkupEmbeddedControlsDisabled"
#define kXcAddedMarkupRLOServer	@"XcAddedMarkupRLOServer"
#define kXcAddedMarkupDefaultRLOServer	@"http://localhost:8080"


@implementation XcEmbeddedControls

@synthesize econtrolFrameView = _econtrolFrameView;
@synthesize selectedStringRange = _selectedStringRange;
@synthesize selectedStringContent = _selectedStringContent;

@synthesize textView=_textView;

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
		_rloGetIntRegex = [NSRegularExpression regularExpressionWithPattern:@"RLOGet(Float|Int)\\(@\"(.*?)\",.*?\\)" options:0 error:NULL];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
	if (editMenuItem) {
		[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *toggleEmbeddedControlsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Embedded RLO Controls" action:@selector(toggleEmbeddedControlsEnabled:) keyEquivalent:@""];
		[toggleEmbeddedControlsMenuItem setTarget:self];
		[[editMenuItem submenu] addItem:toggleEmbeddedControlsMenuItem];
    }
	
	BOOL highlightingEnabled = ![[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupEmbeddedControlsDisabled];
	if (highlightingEnabled) {
		[self activateEmbeddedControls];
	}
}

#pragma mark - Preferences

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(toggleEmbeddedControlsEnabled:)) {
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupEmbeddedControlsDisabled];
		[menuItem setState:enabled ? NSOffState : NSOnState];
		return YES;
	}
	return YES;
}

- (void)toggleEmbeddedControlsEnabled:(id)sender
{
	BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupEmbeddedControlsDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:kXcAddedMarkupEmbeddedControlsDisabled];
	if (enabled) {
		[self activateEmbeddedControls];
	} else {
		[self deactivateEmbeddedControls];
	}
}

- (void)activateEmbeddedControls
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChange:) name:NSTextViewDidChangeSelectionNotification object:nil];
	if (! self.textView) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
		if ([firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [firstResponder isKindOfClass:[NSTextView class]]) {
			self.textView = (NSTextView *)firstResponder;
		}
	}
	if (self.textView) {
		NSNotification *notification = [NSNotification notificationWithName:NSTextViewDidChangeSelectionNotification object:self.textView];
		[self selectionDidChange:notification];
	}
}

- (void)deactivateEmbeddedControls
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextViewDidChangeSelectionNotification object:nil];
	[self removeSelection];
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification
{
	if ([[notification object] isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [[notification object] isKindOfClass:[NSTextView class]]) {
		self.textView = (NSTextView *)[notification object];
		
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kXcAddedMarkupEmbeddedControlsDisabled];
		if (disabled) {
            return;
        }

		NSArray *selectedRanges = [self.textView selectedRanges];
		if (selectedRanges.count >= 1) {
			NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
			NSString *text = self.textView.textStorage.string;
			NSRange lineRange = [text lineRangeForRange:selectedRange];
			NSRange selectedRangeInLine = NSMakeRange(selectedRange.location - lineRange.location, selectedRange.length);
			NSString *line = [text substringWithRange:lineRange];
			
			_ecKeypathRange = NSMakeRange(NSNotFound, 0);
            NSRange resultRange = [self rloGetIntText:line selectedRange:selectedRangeInLine keypathRange:&_ecKeypathRange];
            if (resultRange.location != NSNotFound && _ecKeypathRange.location != NSNotFound) {
                NSString *keypath = [line substringWithRange:_ecKeypathRange];
                _ecKeypath = keypath;
                self.selectedStringContent = [line substringWithRange:_ecKeypathRange];
                
                // String's content
                self.selectedStringContent = [_selectedStringContent substringWithRange:NSMakeRange(1, _selectedStringContent.length - 2)];
				self.selectedStringRange = NSMakeRange(_ecKeypathRange.location + lineRange.location, _ecKeypathRange.length);

                // Draw the frame around the string
				self.econtrolFrameView.frame = NSInsetRect(NSIntegralRect([self rectInViewForRange:self.selectedStringRange]), -1, -1);
				[self.textView addSubview:self.econtrolFrameView];
                
                [self loadConfigAndShowPopup:self];
            } else {
                [self removeSelection];
            }
		} else {
            [self removeSelection];
        }
	}
}

- (void)dismissPopover
{
    if (_popover) {
        [_popover close];
    }
    [self.econtrolFrameView removeFromSuperview];
}

- (void)removeSelection
{
    [self dismissPopover];
    self.selectedStringContent = nil;
    self.selectedStringRange = NSMakeRange(NSNotFound, 0);
    _ecKeypath = nil;
    _ecKeypathRange = NSMakeRange(NSNotFound, 0);
}

- (void)loadConfigAndShowPopup:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadConfigAndShowPopup_:sender];
    });
}

- (void)loadConfigAndShowPopup_:(id)sender
{
    NSString *serverurl = [[NSUserDefaults standardUserDefaults] stringForKey:kXcAddedMarkupRLOServer];
    if (! serverurl) {
        serverurl = kXcAddedMarkupDefaultRLOServer;
    }

    NSString *configurl = [NSString stringWithFormat:@"%@/rloconfig", serverurl];
    NSError *error = nil;
    NSHTTPURLResponse *response;
    NSURL *url = [NSURL URLWithString:configurl];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod: @"GET"];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    BOOL success = NO;
    if (data) {
        NSError *error = nil;
        NSPropertyListFormat format;
        id plist = [NSPropertyListSerialization propertyListWithData:data
                                                             options:NSPropertyListMutableContainersAndLeaves
                                                              format:&format
                                                               error:&error];
        if (error || ! [plist isKindOfClass:[NSDictionary class]]) {
            NSLog(@"XcAddedMarkup: Error: invalid RLO config: %@", data);
        } else {
            ecConfiguration = plist;
            success = YES;
        }
    }
    if (success) {
        [self performSelectorOnMainThread:@selector(showPopover:) withObject:sender waitUntilDone:NO];
    }
}

- (void)showPopover:(id)sender
{
    if (_selectedStringRange.location == NSNotFound) {
        return;
    }

    if (! _popoverViewController) {
        _popoverViewController = [[XcAMPopoverViewController alloc] init];
        _popoverViewController.delegate = self;
    }
    
    _popoverViewController.ecKeypath = _ecKeypath;
    _popoverViewController.ecType = _ecType;
    _popoverViewController.ecConfiguration = ecConfiguration;
    [_popoverViewController updateControlSpec];
    
    NSSize size = NSMakeSize(150, 30);
    if(! _popover) {
        _popover = [[NSPopover alloc] init];
    }
    __block NSResponder *previousFirstResponder = self.textView.window.firstResponder;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSPopoverDidShowNotification
                                                      object:_popover queue:nil usingBlock:^(NSNotification *note) {
                                                          [self.textView.window makeKeyWindow]; //Reclaim key from popover
                                                          [self.textView.window makeFirstResponder:previousFirstResponder];
                                                      }];
    
    _popover.contentViewController = _popoverViewController;
    _popover.contentSize = size;
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.delegate = self;
    NSRect kprect = [self rectInViewForRange:_ecKeypathRange];
    [_popover showRelativeToRect:kprect
                          ofView:self.econtrolFrameView
                   preferredEdge:NSMinYEdge];
}

- (NSRect)rectInViewForRange:(NSRange)range
{
    NSRect rectOnScreen = [self.textView firstRectForCharacterRange:range];
    NSRect rectInWindow = [self.textView.window convertRectFromScreen:rectOnScreen];
    NSRect rectInView = [self.textView convertRect:rectInWindow fromView:nil];
    return rectInView;
}

#pragma mark - View Initialization

- (XcAMFrameView *)econtrolFrameView {
	if (!_econtrolFrameView) {
		_econtrolFrameView = [[XcAMFrameView alloc] initWithFrame:NSZeroRect];
	}
	return _econtrolFrameView;
}

- (void)controlValueDidChange:(id)value
{
    [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendRequest:[NSString stringWithFormat:@"%.3f", [value doubleValue]]];
    });
}

- (void)sendRequest:(NSString *)value
{
    NSString *update_url = [ecConfiguration valueForKeyPath:@"rlo.update_url"];
    if (! update_url) {
        return;
    }
    // rlo.update_url is generated by the RLO server and should be, e.g.: http://localhost:8080/update/GLExample
    NSString *theUrl = [NSString stringWithFormat:@"%@?%@=%@", update_url, _ecKeypath, value];
    NSError *error = nil;
    NSHTTPURLResponse *response;
    NSURL *url = [NSURL URLWithString:theUrl];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod: @"GET"];
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
}

#pragma mark - String Parsing

- (NSRange)rloGetIntText:(NSString *)text selectedRange:(NSRange)selectedRange keypathRange:(NSRangePointer)keypathRange
{
	__block NSString *keypath = nil;
    __block NSRange econtrolRange = NSMakeRange(NSNotFound, 0);

    [_rloGetIntRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange range = [result range];
        if (selectedRange.location >= range.location && NSMaxRange(selectedRange) <= NSMaxRange(range)) {
            NSRange kprange = [result rangeAtIndex:2];
            if (kprange.length > 0) {
                *stop = YES;
                keypath = [text substringWithRange:kprange];
                econtrolRange = [result range];
                if (keypathRange) {
                    *keypathRange = kprange;
                }
                NSString *typestring = [text substringWithRange:[result rangeAtIndex:1]];
                if ([typestring isEqualToString:@"Bool"]) {
                    _ecType = XcECTypeBool;
                } else if ([typestring isEqualToString:@"Int"]) {
                    _ecType = XcECTypeInt;
                } else if ([typestring isEqualToString:@"Float"]) {
                    _ecType = XcECTypeFloat;
                } else {
                    _ecType = XcECTypeNone;
                }
            }
        }
    }];

	return econtrolRange;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

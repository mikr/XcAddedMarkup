//
//  XcEmbeddedControls.h
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcAMTypes.h"
#import "XcAMFrameView.h"
#import "XcAMPopoverViewController.h"
#import "XcAMPopOver.h"


@interface XcEmbeddedControls : NSObject  <NSPopoverDelegate> {
	XcAMFrameView *_econtrolFrameView;
    XcAMPopoverViewController *_popoverViewController;
    XcAMPopOver *_popover;

    NSRange _ecKeypathRange;
    NSString *_ecKeypath;
    XcECType _ecType;
    NSRange _selectedStringRange;
	NSString *_selectedStringContent;
    
	NSTextView *_textView;
	
	NSRegularExpression *_rloGetIntRegex;
    NSDictionary *ecConfiguration;
    NSDate *ecConfigurationModificationDate;
}

@property (nonatomic, assign) NSRange selectedStringRange;
@property (nonatomic, copy) NSString *selectedStringContent;

@property (nonatomic, strong) XcAMFrameView *econtrolFrameView;

@property (nonatomic, strong) NSTextView *textView;

- (void)activateEmbeddedControls;
- (void)deactivateEmbeddedControls;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;

@end

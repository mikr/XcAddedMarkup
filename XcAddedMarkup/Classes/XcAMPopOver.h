//
//  XcAMPopOver.h
//  XcAddedMarkup
//
//  Copyright (c) 2014 Michael Krause. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XcAMPopOver : NSPopover

@property (strong) NSResponder *previousFirstResponder;
@property (strong) NSWindow *previousKeyWindow;

@end

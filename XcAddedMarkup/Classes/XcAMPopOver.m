//
//  XcAMPopOver.m
//  XcAddedMarkup
//
//  Copyright (c) 2014 Michael Krause. All rights reserved.
//

#import "XcAMPopOver.h"

@implementation XcAMPopOver

/*
 * When the popover appears the NSPopOver or _NSPopoverWindow becomes the first responder.
 * This is especially annoying when using the cursor keys to move the cursor around in which case
 * the appearing NSPopOver stops the cursor movement.
 * The easiest way to prevent the NSPopOver from becoming firstResponder is intercepting
 * and forwarding -keyDown: while also returning NO in -acceptsFirstResponder of the text field.
 */
- (void)keyDown:(NSEvent *)theEvent
{
    if (self.previousKeyWindow && self.previousFirstResponder) {
        [self.previousKeyWindow makeKeyWindow];
        [self.previousKeyWindow makeFirstResponder:self.previousFirstResponder];
    } else {
        [super keyDown:theEvent];
    }
}

@end

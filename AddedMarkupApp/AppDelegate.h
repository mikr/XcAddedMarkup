//
//  AppDelegate.h
//  AddedMarkupApp
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import <Cocoa/Cocoa.h>
#import "AttachEmbeddedImages.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    AddedRangeMarker *marker;
}

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSTextView *textView;

@end

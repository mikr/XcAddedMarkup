//
//  XcAMPopoverViewController.h
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcAMTypes.h"

@interface XcAMPopoverViewController : NSViewController <NSTextFieldDelegate> {
    NSView *_pview;
    NSTextField *_textfield;
    NSSlider *_slider;
    id _delegate;
    BOOL did_bind;
    
    NSNumber *_value;
}

@property (strong, nonatomic) id delegate;
@property (strong, nonatomic) NSString *ecKeypath;
@property XcECType ecType;
@property (strong, nonatomic) NSDictionary *ecConfiguration;

- (void)updateControlSpec;

@end

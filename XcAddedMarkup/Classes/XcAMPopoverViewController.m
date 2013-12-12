//
//  XcAMPopoverViewController.m
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "XcAMPopoverViewController.h"

static NSString *valueContext = @"XcAMPopoverViewController_value";

@implementation XcAMPopoverViewController

@synthesize delegate = _delegate;

- (NSView *)view
{
    if (! _pview) {
        _pview = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 40)];

        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        
        _textfield = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 4, 80, 32)];
        _textfield.formatter = numberFormatter;
        [_textfield setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable | NSViewMaxXMargin | NSViewMinXMargin];

        _slider = [[NSSlider alloc] initWithFrame:NSMakeRect(80, 0, 200, 40)];
        [_slider setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
        
        [_slider bind:@"value" toObject:self withKeyPath:@"value" options:nil];
        [_textfield bind:@"value" toObject:self withKeyPath:@"value" options:nil];
        [self addObserver:self forKeyPath:@"value" options:0 context:&valueContext];
        did_bind = YES;

        [_pview addSubview:_textfield];
        [_pview addSubview:_slider];
        
        [self updateControlSpec];
    }
    return _pview;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &valueContext && [keyPath isEqual:@"value"]) {
        if ([_delegate respondsToSelector:@selector(controlValueDidChange:)]) {
            [_delegate performSelector:@selector(controlValueDidChange:) withObject:@([self.value floatValue])];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
}

- (void)valueChanged:(id)sender
{
    if ([_delegate respondsToSelector:@selector(controlValueDidChange:)]) {
        [_delegate performSelector:@selector(controlValueDidChange:) withObject:@([self.value floatValue])];
    }
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:@"value"]) {
        return NO;
    }
    return YES;
}

- (void)setValue:(id)value
{
    [self willChangeValueForKey:@"value"];

    if (_ecType == XcECTypeInt) {
        _value = @(round([value floatValue]));
    } else {
        _value = value;
    }

    [self didChangeValueForKey:@"value"];
}

- (NSNumber *)value
{
    return _value;
}

- (void)updateControlSpec
{
    if (! _slider) {
        return;
    }
    NSString *speckey = [_ecKeypath stringByAppendingString:@"_spec"];
    NSDictionary *spec = _ecConfiguration[speckey];
    NSNumber *smin = spec[@"min"];
    NSNumber *smax = spec[@"max"];
    if (smin && smax) {
        _slider.minValue = [smin doubleValue];
        _slider.maxValue = [smax doubleValue];
    } else {
        _slider.minValue = 0.0;
        _slider.maxValue = 100.0;
    }
    
    NSNumber *value = _ecConfiguration[_ecKeypath];
    if (value) {
        self.value = value;
    }
}

- (void)dealloc
{
    if (did_bind) {
        [_slider unbind:@"value"];
        [_textfield unbind:@"value"];
        [self removeObserver:self forKeyPath:@"value"];
    }
    _delegate = nil;
}

@end

//
//  XcAddedMarkupPlugin.h
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import <Foundation/Foundation.h>
#import "AttachEmbeddedImages.h"

@interface XcAddedMarkupPlugin : NSObject {
    AddedRangeMarker *marker;
}

+ (AddedRangeMarker *)globalMarker;

@property (readonly) AddedRangeMarker *marker;

@end

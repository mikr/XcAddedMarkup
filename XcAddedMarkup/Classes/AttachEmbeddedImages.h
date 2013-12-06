//
//  AttachEmbeddedImages.h
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#ifndef XcodeColors_AttachEmbeddedImages_h
#define XcodeColors_AttachEmbeddedImages_h

#import "AddedMarkup.h"
#import "SimpleBase64.h"

@interface AddedRangeMarker : NSObject {
@public
    NSRegularExpression *_imageRegex;
    NSRegularExpression *_linkRegex;
}

- (void)attachEmbeddedImages:(NSTextStorage *)textStorage textStorageRange:(NSRange)textStorageRange;
- (void)attachEmbeddedLinks:(NSTextStorage *)textStorage textStorageRange:(NSRange)textStorageRange;

@end



void AttachEmbeddedLinks(NSTextStorage *textStorage, NSRange textStorageRange);
NSImage *resizeNSImage_AttachEmbeddedImages(NSImage *image, NSSize size, float zoom, float zoom2, NSImageInterpolation interpolation);
void AttachEmbeddedImages(NSTextStorage *textStorage, NSRange textStorageRange);

#endif

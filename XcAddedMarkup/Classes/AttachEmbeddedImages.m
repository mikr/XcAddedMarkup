//
//  AttachEmbeddedImages.m
//  XcAddedMarkup
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "AttachEmbeddedImages.h"


@interface EnhancedAttachmentCell : NSTextAttachmentCell {
    BOOL interpolate;
}

@property (assign) BOOL interpolate;

@end

@implementation EnhancedAttachmentCell

@synthesize interpolate;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    if (interpolate) {
        [super drawWithFrame:cellFrame inView:controlView];
    } else {
        NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
        NSImageInterpolation oldinterpolation = ctx.imageInterpolation;
        [ctx setImageInterpolation:NSImageInterpolationNone];
        [super drawWithFrame:cellFrame inView:controlView];
        [ctx setImageInterpolation:oldinterpolation];
    }
}

@end


@implementation AddedRangeMarker

#define REGEX_HIDE_IDX 1
#define REGEX_IMAGEPARAMETERS_IDX 2
#define REGEX_IMAGEDATA_IDX 3
#define REGEX_REF_IDX 4
#define REGEX_BASE64_IDX 5
#define REGEX_IMAGEPATH_IDX 6

- (id)init
{
    if (self = [super init]) {
        _imageRegex = [[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\n\
                                                                          %@  \\s*  # EMBEDDED_IMAGE_START \n\
                                                                          (!{0,2}) \\s* \n\
                                                                          (?:\\(        \n\
                                                                          (.*?)         # Zoom   \n\
                                                                          \\) \\s* )?                   \n\
                                                                          (      @ref=\"(.*?)\"         # URL reference \n\
                                                                          | \n\
                                                                          ([ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+=/\t\r\n ]+)  # base64-encoded data     \n\
                                                                          | ([^:]+?) \n\
                                                                          )    \n\
                                                                          %@                               # EMBEDDED_IMAGE_END \n\
                                                                          ", EMBEDDED_IMAGE_START, EMBEDDED_IMAGE_END]
                                                                 options:NSRegularExpressionAllowCommentsAndWhitespace error:NULL] retain];
        
        _linkRegex = [[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\n\
                                                                         %@   # EMBEDDED_LINK_START \n\
                                                                         (!?)       \n\
                                                                         (?:\\[([^]]+)])?       \n\
                                                                         <([^>]+)>       \n\
                                                                         \n\
                                                                         .*?    \n\
                                                                         %@                               # EMBEDDED_LINK_END \n\
                                                                         ", EMBEDDED_LINK_START, EMBEDDED_LINK_END]
                                                                options:NSRegularExpressionAllowCommentsAndWhitespace error:NULL] retain];
    }
	return self;
}

- (NSTextAttachment *)attachmentForImagedata:(NSData *)imagedata zoomX:(float)zoomX zoomY:(float)zoomY interpolate:(BOOL)interpolate needsAutoResize:(BOOL)needsAutoResize
{
    NSImage *attachment_image = nil;

    attachment_image = [[NSImage alloc] initWithData:imagedata];
    if (! attachment_image) {
        return nil;
    }
    if (needsAutoResize) {
        float dest_height = 42;
        float z1 = dest_height / attachment_image.size.height;
        zoomX = zoomY = z1;
    }
    BOOL must_zoom = zoomX != 1.0f || zoomY != 1.0f;

    if (must_zoom) {
        [attachment_image setSize:NSMakeSize(attachment_image.size.width * zoomX, attachment_image.size.height * zoomY)];
    }

    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithSerializedRepresentation:imagedata];
    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    [wrapper release];
    EnhancedAttachmentCell *cell = [[EnhancedAttachmentCell alloc] init];
    // Drawing an unscaled image needs no special treatment
    cell.interpolate = interpolate || ! must_zoom;

    [cell setImage:attachment_image];
    [attachment_image release];
    [attachment setAttachmentCell:cell];
    [cell release];
    return [attachment autorelease];
}

- (void)attachEmbeddedImages:(NSTextStorage *)textStorage textStorageRange:(NSRange)textStorageRange
{
    BOOL began_editing = NO;

    do {
        NSString *text_string = [textStorage string];
        NSTextCheckingResult *result = [_imageRegex firstMatchInString:text_string options:0 range:textStorageRange];
        if (! result) {
            break;
        }
        
        NSRange imageRange = [result range];

        NSData *imagedata = nil;
        float zoomx = 1.0, zoomy = 1.0;
        int interpolate = 1;
        BOOL needs_automatic_size = NO;
        NSRange range_imageparameters = [result rangeAtIndex:REGEX_IMAGEPARAMETERS_IDX];
        if (range_imageparameters.location != NSNotFound) {
            NSString *imageparameters = [text_string substringWithRange:range_imageparameters];
            NSScanner *scanner = [NSScanner scannerWithString:imageparameters];
            [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@", "]];
            if ([scanner scanFloat:&zoomx]) {
                if ([scanner scanFloat:&zoomy]) {
                    [scanner scanInt:&interpolate];
                } else {
                    zoomy = zoomx; // Only one number given, e.g. (4).
                }
            } else {
                // No valid zoom definition found.
                //break;
            }
        } else {
            needs_automatic_size = YES;
        }

        NSRange refrange = [result rangeAtIndex:REGEX_REF_IDX];
        NSRange base64range = [result rangeAtIndex:REGEX_BASE64_IDX];
        NSRange range_imagepath = [result rangeAtIndex:REGEX_IMAGEPATH_IDX];
        if (refrange.location != NSNotFound) {
            imagedata = [NSData dataWithContentsOfURL:[NSURL URLWithString:[text_string substringWithRange:refrange]]];
        } else if (base64range.location != NSNotFound) {
            imagedata = base64decode([text_string substringWithRange:base64range]);
        } else if (range_imagepath.location != NSNotFound) {
            NSString *filename1 = [text_string substringWithRange:range_imagepath];
            NSURL *url1 = [NSURL fileURLWithPath:filename1 isDirectory:NO];
            imagedata = [NSData dataWithContentsOfURL:url1];
        } else {
        }
 
        if (!imagedata || [imagedata length] == 0) {
            break;
        }
        
        NSTextAttachment *attachment = [self attachmentForImagedata:imagedata zoomX:zoomx zoomY:zoomy interpolate:interpolate needsAutoResize:needs_automatic_size];
        if (! attachment) {
            break;
        }
        
        NSDictionary *clearAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:0.001], NSFontAttributeName,
                                    [NSColor clearColor], NSForegroundColorAttributeName,
                                    nil];

        NSRange hiderange;
        switch ([result rangeAtIndex:REGEX_HIDE_IDX].length) {
            case 1:
                hiderange = [result rangeAtIndex:REGEX_IMAGEDATA_IDX];
                break;
            case 2:
                hiderange = imageRange;
                break;
            default:
                hiderange = NSMakeRange(NSNotFound, 0);
                break;
        }

        if (! began_editing) {
            [textStorage beginEditing];
            began_editing = YES;
        }

        if (hiderange.location != NSNotFound) {
            [textStorage addAttributes:clearAttrs range:hiderange];
        }
        [textStorage addAttribute:NSAttachmentAttributeName value:attachment range:NSMakeRange(imageRange.location + 1, 1)];
        [textStorage ensureAttributesAreFixedInRange:imageRange];

        textStorageRange = NSIntersectionRange(textStorageRange, NSMakeRange(NSMaxRange(imageRange), textStorageRange.length));
    } while(1);

    if (began_editing) {
        [textStorage endEditing];
    }
}

#define REGEX_LINKHIDE_IDX 1
#define REGEX_LINKTEXT_IDX 2
#define REGEX_LINKURL_IDX 3
- (void)attachEmbeddedLinks:(NSTextStorage *)textStorage textStorageRange:(NSRange)textStorageRange
{
    BOOL began_editing = NO;

    do {
        NSString *text_string = [textStorage string];
        NSTextCheckingResult *result = [_linkRegex firstMatchInString:text_string options:0 range:textStorageRange];
        if (! result) {
            break;
        }
        
        NSRange linkRange = [result range];
        NSRange linkurl_range = [result rangeAtIndex:REGEX_LINKURL_IDX];
        if (linkurl_range.location == NSNotFound) {
            break;
        }
        NSString *url = [text_string substringWithRange:linkurl_range];
        NSRange linktext_range = [result rangeAtIndex:REGEX_LINKTEXT_IDX];
        NSRange range1, range2;
        NSRange title_range;

        if (linktext_range.location == NSNotFound) {
            // Display the URL as is
            title_range = linkurl_range;
            range1 = NSMakeRange(linkRange.location, linkurl_range.location - linkRange.location);
            range2 = NSMakeRange(NSMaxRange(linkurl_range), NSMaxRange(linkRange) - NSMaxRange(linkurl_range));
        } else {
            title_range = linktext_range;
            range1 = NSMakeRange(linkRange.location, linktext_range.location - linkRange.location);
            range2 = NSMakeRange(NSMaxRange(linktext_range), NSMaxRange(linkRange) - NSMaxRange(linktext_range));
        }
        
        // These three range restrictions should be unnecessary but we leave them in for extra safety.
        range1 = NSIntersectionRange(range1, textStorageRange);
        range2 = NSIntersectionRange(range2, textStorageRange);
        title_range = NSIntersectionRange(title_range, textStorageRange);

        if (! began_editing) {
            [textStorage beginEditing];
            began_editing = YES;
        }
        
        NSRange hideindicator_range = [result rangeAtIndex:REGEX_LINKHIDE_IDX];
        if (hideindicator_range.length > 0) {
            NSDictionary *clearAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:0.001], NSFontAttributeName,
                                        [NSColor clearColor], NSForegroundColorAttributeName,
                                        nil];
            NSMutableArray *ranges_to_hide = [NSMutableArray arrayWithObjects:[NSValue valueWithRange:range1], [NSValue valueWithRange:range2], nil];
            for (NSValue *v in ranges_to_hide) {
                NSRange rangetohide = [v rangeValue];
                [textStorage addAttributes:clearAttrs range:rangetohide];
            }
        }
        [textStorage addAttribute:NSLinkAttributeName value:url range:title_range];

        NSString *linkbody = [text_string substringWithRange:title_range];
        NSCharacterSet *wcSet = [NSCharacterSet whitespaceCharacterSet];
        linkbody = [linkbody stringByTrimmingCharactersInSet:wcSet];
        [textStorage addAttribute:NSLinkAttributeName value:url range:title_range];
        if ([linkbody length] > 0) {
            if (!([linkbody hasPrefix:EMBEDDED_IMAGE_START] && [linkbody hasSuffix:EMBEDDED_IMAGE_END])) {
                // If there is non-whitespace text behind the link we use a white background color
                // to make the normally blue link text readable.
                // A purely whitespace text or no text could be an image which we don't want to have a white below itself.
                [textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor whiteColor] range:title_range];
            }
        }

        textStorageRange = NSIntersectionRange(textStorageRange, NSMakeRange(NSMaxRange(linkRange), textStorageRange.length));
    } while(1);
    
    if (began_editing) {
        [textStorage endEditing];
    }
}

- (void)dealloc
{
    [_imageRegex release];
    [_linkRegex release];
    [super dealloc];
}

@end

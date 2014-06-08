//
//  AppDelegate.m
//  AddedMarkupApp
//
//  Copyright (c) 2013 Michael Krause ( http://krause-software.com )
//

#import "AppDelegate.h"
#import "SimpleBase64.h"
#import "AttachEmbeddedImages.h"
#import "XcAM_XcodeColors.h"


#define COLSEQ_RED @"fg255,0,0;"
#define COLSEQ_GREEN @"fg0,255,0;"
#define COLSEQ_BLUE @"fg96,96,255;"
#define COLSEQ_CYAN @"fg96,255,255;"
#define COLSEQ_MAGENTA @"fg255,96,255;"
#define COLSEQ_YELLOW @"fg255,255,96;"
#define COLSEQ_BLACK @"fg0,0,0;"
#define COLSEQ_BLOCK @"bg255,255,0;" XCODE_COLORS_ESCAPE @"fg255,0,0;"
#define COLSEQ_RGB(r, g, b) [NSString stringWithFormat:@"fg%d,%d,%d;", r, g, b]

#define COLSEQ_R COLSEQ_RED
#define COLSEQ_G COLSEQ_GREEN
#define COLSEQ_B COLSEQ_BLUE
#define COLSEQ_C COLSEQ_CYAN
#define COLSEQ_M COLSEQ_MAGENTA
#define COLSEQ_Y COLSEQ_YELLOW
#define COLSEQ_K COLSEQ_BLACK

#define NSLogRED(s, ... ) NSLog(XCODE_COLORS_ESCAPE COLSEQ_RED s XCODE_COLORS_RESET, ##__VA_ARGS__)
#define NSLogGREEN(s, ... ) NSLog(XCODE_COLORS_ESCAPE COLSEQ_GREEN s XCODE_COLORS_RESET, ##__VA_ARGS__)
#define NSLogBLUE(s, ... ) NSLog(XCODE_COLORS_ESCAPE COLSEQ_BLUE s XCODE_COLORS_RESET, ##__VA_ARGS__)

#define DebugDecorateRED(s) [NSString stringWithFormat:@"%@%@%@%@", XCODE_COLORS_ESCAPE, COLSEQ_RED, s, XCODE_COLORS_RESET]
#define DebugDecorateGREEN(s) [NSString stringWithFormat:@"%@%@%@%@", XCODE_COLORS_ESCAPE, COLSEQ_GREEN, s, XCODE_COLORS_RESET]
#define DebugDecorateBLUE(s) [NSString stringWithFormat:@"%@%@%@%@", XCODE_COLORS_ESCAPE, COLSEQ_BLUE, s, XCODE_COLORS_RESET]

#define AMLink(u) [NSString stringWithFormat:@"%@%@%@%@%@", EMBEDDED_LINK_START, @"<", u, @">", EMBEDDED_LINK_END]
#define AMLinkWithTitle(u, t) [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@", EMBEDDED_LINK_START, @"![", t, @"]", @"<", u, @">", EMBEDDED_LINK_END]


@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    xec = XcEmbeddedControls.new;
    [xec applicationDidFinishLaunching:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editedEnded:) name:NSTextStorageDidProcessEditingNotification object:nil];
    [self.window setLevel: NSStatusWindowLevel];
    marker = [[AddedRangeMarker alloc] init];

    [self setTextContent];
}

- (NSString *)filenameForResource:(NSString *)resourceName { NSImage *nsimage;

  id filerep = [NSBundle.mainBundle pathForResource:resourceName ofType:nil];
  return filerep ?: (nsimage = [NSImage imageNamed:resourceName]) ?
    [nsimage.TIFFRepresentation writeToFile:
      filerep = [[[NSProcessInfo.processInfo.arguments[0] stringByDeletingLastPathComponent]
                                                stringByAppendingPathComponent:resourceName]
                                                     stringByAppendingPathExtension:@"tiff"]
                                                              atomically:YES], filerep : nil;
}

- (void)setTextContent
{
    NSString *filename1 =  @"/Applications/Safari.app/Contents/Resources/ExtensionDefaultIcon64.png";
    NSURL *url1 = [[NSURL alloc] initFileURLWithPath:filename1 isDirectory:NO];

    NSString *imagestring1 = [self imageRefDefinition:url1.absoluteString zoomX:4 zoomY:4 interpolate:NO];

    NSString *dotMac = [NSString stringWithFormat:@"∂i!!%@ƒi",[self filenameForResource:NSImageNameDotMac]];

    NSString *link1 = AMLinkWithTitle(@"http://apple.com", @"Apple");
    NSString *fn = filename1;
    NSString *text = [NSString stringWithFormat:@"∂i!!%@ƒi \n %@ %@ %@\n", fn, DebugDecorateGREEN(@"Apple"), link1, DebugDecorateBLUE(@"Apple")];
    text = [text stringByAppendingString:@"\n\n\n// RLOGetInt(@\"num_triangles\", 36);\n"];
    text = [text stringByAppendingString:@"// RLOGetFloat(@\"num_triangles\", 36);\n"];
    text = [text stringByAppendingFormat:@"\n\n%@", dotMac];

    NSString *text2 = [NSString stringWithFormat:@"Test zooming image: %@", imagestring1];
    NSLog(@"%@", text);
    NSLog(@"%@", text2);
    NSLog(@"%@", dotMac);
    NSLogGREEN(@"All is well!");
    [self.textView setString:text];
}

- (NSData *)dataForFilename:(NSString *)filename
{
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:filename];
    
    [image lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, image.size.width, image.size.height)];
    [image unlockFocus];
    NSData *imagedata = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
    return imagedata;
}

- (NSString *)base64dataForFilename:(NSString *)filename
{
    NSData *imagedata = [self dataForFilename:filename];
    NSString *base64_data = base64encode(imagedata, 0);
    base64_data = [[base64_data componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"]] componentsJoinedByString:@""];
    return base64_data;
}

- (NSString *)imageDefinition:(NSData *)data zoomX:(float)zoomX zoomY:(float)zoomY
{
    NSString *base64_data = base64encode(data, 0);
    return [NSString stringWithFormat:@"%@(%f,%f)%@%@", EMBEDDED_IMAGE_START, zoomX, zoomY, base64_data, EMBEDDED_IMAGE_END];
}

- (NSString *)imageDefinition:(NSData *)data zoom:(float)zoom
{
    NSString *base64_data = base64encode(data, 0);
    return [NSString stringWithFormat:@"%@(%f)%@%@", EMBEDDED_IMAGE_START, zoom, base64_data, EMBEDDED_IMAGE_END];
}

- (NSString *)imageDefinition:(NSData *)data
{
    return [self imageDefinition:data zoom:1];
}

- (NSString *)imageRefDefinition:(NSString *)url zoomX:(float)zoomX zoomY:(float)zoomY interpolate:(BOOL)interpolate
{
    return [NSString stringWithFormat:@"%@!!(%f,%f,%d)@ref=\"%@\"%@", EMBEDDED_IMAGE_START, zoomX, zoomY, interpolate, url, EMBEDDED_IMAGE_END];
}

- (void)editedEnded:(NSNotification *)aNotification
{
    NSTextStorage *textStorage = [aNotification object];
	NSRange range = [textStorage editedRange];
    XcAM_ApplyANSIColors(textStorage, range, XCODE_COLORS_ESCAPE);
    [marker attachEmbeddedImages:textStorage textStorageRange:range];
    [marker attachEmbeddedLinks:textStorage textStorageRange:range];
}

@end

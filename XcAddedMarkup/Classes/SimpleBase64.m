//=======================================================================
// Base64 coder by Michael Krause
//
// Lookup tables by Matt Gallagher
//
// Mapping from 6 bit pattern to ASCII character.
//
static unsigned char base64EncodeLookup[65] =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

//
// Definition for "masked-out" areas of the base64DecodeLookup mapping
//
#define xx 65

//
// Mapping from ASCII character to 6 bit pattern.
//
static unsigned char base64DecodeLookup[256] =
{
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 62, xx, xx, xx, 63, 
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, xx, xx, xx, xx, xx, xx, 
    xx,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, xx, xx, xx, xx, xx, 
    xx, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
};

#define ADD_LINEBREAK_IF_NEEDED(cond) do { if (linewidth && (cond) && (((ptr-buf) % (linewidth+2)) == linewidth)) { *ptr++ = '\r'; *ptr++ = '\n';}} while(0)

// Encode base64 data
// Use linewidth 0 for a single line of encoded data. Normal base64 linewidth is 64.
NSString *base64encode(NSData *data, unsigned int linewidth)
{
    NSUInteger length = [data length];
    unsigned char *bytes = (unsigned char *)[data bytes];
    unsigned char *bytesend = bytes + length;
    unsigned int numchars = (unsigned int)((length * 4 + 2) / 3);
    unsigned int numspacers = (3 - length % 3) % 3;
    int linespace = linewidth ? 2 * ((numchars + numspacers + linewidth - 1) / linewidth) : 0;
    char *buf = malloc(numchars + numspacers + linespace + 1);
    char *ptr = buf;
    int a = 0;  // number of available bits
    unsigned int N = 0;
    
    while (numchars-- > 0) {
        if (a < 6 && bytes < bytesend) {
            N = (N << 8) | *bytes++;
            a += 8;
        }
        a -= 6;
        *ptr++ = base64EncodeLookup[(a >= 0 ? N >> a : N << - a) & 63];
        ADD_LINEBREAK_IF_NEEDED(numchars);
    }
    while (numspacers--) {
        *ptr++ = '=';
        ADD_LINEBREAK_IF_NEEDED(numspacers > 0);
    }
    *ptr = '\0';
    return [[NSString alloc] initWithBytesNoCopy:buf length:ptr-buf encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

#define NO_BASE64_CHAR xx

NSData *base64decode(NSString *s)
{
    NSUInteger length = [s length];
    const char *bytes = [s cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned int maxbytes = (unsigned int)((length * 3 + 2) / 4);
    char *buf = malloc(maxbytes + 1);
    char *ptr = buf;
    int a = 0;  // number of available bits
    unsigned int N = 0;
    
    char c;
    while ((c = *bytes++)) {
        int v = base64DecodeLookup[c];
        if (v != NO_BASE64_CHAR) {
            N = N << 6 | v;
            a += 6;
        }
        if (a >= 8) {
            a -= 8;
            *ptr++ = (N >> a) & 255;
        }
    }
    
    return [[NSData alloc] initWithBytesNoCopy:buf length:ptr-buf freeWhenDone:YES];
}

//=======================================================================

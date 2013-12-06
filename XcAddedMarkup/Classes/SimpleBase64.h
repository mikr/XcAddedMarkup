//=======================================================================
// Base64 coder by Michael Krause
//
// Lookup tables by Matt Gallagher
//

NSString *base64encode(NSData *data, unsigned int linewidth);
NSData *base64decode(NSString *s);


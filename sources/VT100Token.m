//
//  VT100Token.m
//  iTerm
//
//  Created by George Nachman on 3/3/14.
//
//

#import "VT100Token.h"
#import "DebugLogging.h"
#include <stdlib.h>

static void VT100Token_preInitializeScreenChars(VT100Token* token) {
    // TODO: Expand this beyond just ascii characters.
    if (token->asciiData.length > kStaticScreenCharsCount) {
        token->screenChars.buffer = calloc(token->asciiData.length, sizeof(screen_char_t));
    } else {
        token->screenChars.buffer = token->screenChars.staticBuffer;
        memset(token->screenChars.buffer, 0, token->asciiData.length * sizeof(screen_char_t));
    }
    for (int i = 0; i < token->asciiData.length; i++) {
        token->screenChars.buffer[i].code = token->asciiData.buffer[i];
    }
    token->screenChars.length = token->asciiData.length;
    token->asciiData.screenChars = &token->screenChars;
}

void VT100Token_setAsciiBytes(VT100Token* token, char *bytes, int length) {
    assert(token->asciiData.buffer == NULL);
    
    token->asciiData.length = length;
    if (length > sizeof(token->asciiData.staticBuffer)) {
        token->asciiData.buffer = malloc(length);
    } else {
        token->asciiData.buffer = token->asciiData.staticBuffer;
    }
    memcpy(token->asciiData.buffer, bytes, length);
    
    VT100Token_preInitializeScreenChars(token);
}

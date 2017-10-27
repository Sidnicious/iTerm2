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
#include <pthread.h>

static VT100Token* gPool[1024] = {0};
static ssize_t gPoolLen = 0;

VT100Token* VT100Token_alloc() {
    VT100Token* ret = NULL;
    while (gPoolLen > 0) {
        ssize_t slot = __sync_sub_and_fetch(&gPoolLen, 1);
        if (slot >= 1000) continue;
        if (slot < 0) break;
        ret = gPool[slot];
        if (!ret || !__sync_bool_compare_and_swap(&gPool[slot], ret, NULL))
            continue;
        break;
    }
    if (!ret)
        ret = calloc(sizeof(VT100Token), 1);
    return ret;
}

void VT100Token_free(VT100Token* token) {
    free(token->_csi);
    token->_csi = NULL;

    [token->string release];
    token->string = nil;
    
    [token->kvpKey release];
    token->kvpKey = nil;
    
    [token->kvpValue release];
    token->kvpValue = nil;
    
    [token->savedData release];
    token->savedData = nil;
    
    if (token->asciiData.buffer != token->asciiData.staticBuffer) {
        free(token->asciiData.buffer);
    }
    if (token->asciiData.screenChars &&
        token->asciiData.screenChars->buffer != token->asciiData.screenChars->staticBuffer) {
        free(token->asciiData.screenChars->buffer);
    }
    token->asciiData.buffer = NULL;
    token->asciiData.length = 0;
    token->asciiData.screenChars = NULL;
    
    token->type = 0;
    token->code = 0;

    while (gPoolLen < 1000) {
        ssize_t slot = __sync_fetch_and_add(&gPoolLen, 1);
        if (slot < 0) continue;
        if (slot >= 1000) break;
        if (__sync_bool_compare_and_swap(&gPool[slot], NULL, token))
            return;
    }
    free(token);
}

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

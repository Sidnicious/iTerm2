//
//  iTermObjectPool.m
//  iTerm
//
//  Created by George Nachman on 3/3/14.
//
//

#import "iTermObjectPool.h"
#include <stdatomic.h>

@interface iTermObjectPool ()
- (void)recycleObject:(iTermPooledObject *)object;
@end

@interface iTermPooledObject ()

- (instancetype)initWithPool:(iTermObjectPool *)pool;

@end

@implementation iTermPooledObject {
    iTermObjectPool *_pool;  // Weak reference
}

- (instancetype)initWithPool:(iTermObjectPool *)pool {
    self = [super init];
    if (self) {
        _pool = pool;
    }
    return self;
}

- (void)destroyPooledObject {
}

- (void)recycleObject {
    [_pool recycleObject:self];
}

@end

#define kObjectPoolSize 2048

@implementation iTermObjectPool {
    iTermPooledObject* _Atomic _freeObjects[kObjectPoolSize];
    _Atomic int _freeObjectCount;
    int _allocated;
    int _freed;
    Class _class;
}

- (instancetype)initWithClass:(Class)theClass {
    self = [super init];
    if (self) {
        _class = theClass;
    }
    return self;
}

// This class is intended to have global scope and lifetime, so dealloc asserts.
- (void)dealloc {
    assert(false);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p class=%@ capacity=%d ever-allocated=%d currently-allocated=%d in-use=%d>",
            [self class], self, _class, kObjectPoolSize, _allocated, _allocated - _freed, _allocated - _freed - _freeObjectCount];
}

- (iTermPooledObject *)pooledObject {
    while (_freeObjectCount > 0) {
        int slot = atomic_fetch_sub(&_freeObjectCount, 1);
        if (slot > kObjectPoolSize) continue;
        if (slot <= 0) break;
        iTermPooledObject* ret = _freeObjects[slot-1];
        if (ret && atomic_compare_exchange_weak(&_freeObjects[slot-1], &ret, NULL))
            return ret;
    }
    _allocated++;
    // The analyzer complains here but it's actually correct because the pool implicitly owns the object.
    return [[_class alloc] initWithPool:self];
}

- (void)recycleObject:(iTermPooledObject *)obj {
    [obj destroyPooledObject];
    while (_freeObjectCount < kObjectPoolSize) {
        int slot = atomic_fetch_add(&_freeObjectCount, 1);
        if (slot < 0) continue;
        if (slot >= 1000) break;
        iTermPooledObject *nullval = NULL;
        if (atomic_compare_exchange_weak(&_freeObjects[slot], &nullval, obj)) {
            return;
        }
    }
    [obj release];
}

@end

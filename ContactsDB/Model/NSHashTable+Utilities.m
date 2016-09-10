//
//  NSHashTable+Utilities.m
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "NSHashTable+Utilities.h"

@implementation NSHashTable (Utilities)

- (void)addObjects:(id<NSFastEnumeration>)collection {
    for (id obj in collection) {
        [self addObject:obj];
    }
}

@end

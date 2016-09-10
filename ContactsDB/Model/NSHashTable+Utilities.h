//
//  NSHashTable+Utilities.h
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSHashTable (Utilities)

- (void)addObjects:(id<NSFastEnumeration>)collection;

@end

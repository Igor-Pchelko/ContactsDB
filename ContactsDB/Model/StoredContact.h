//
//  StoredContact.h
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreData;

// Core data contact
@interface StoredContact : NSManagedObject

@property (strong, nonatomic) NSString *identifier;
@property (strong, nonatomic) NSString *givenName;
@property (strong, nonatomic) NSString *familyName;

@end
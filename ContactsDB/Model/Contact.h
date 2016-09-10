//
//  Contact.h
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreData;
@import Contacts;
#import "StoredContact.h"

// Mediator contact model between "Stored Contacts" and "System Contacts"
@interface Contact : NSObject

@property (nonatomic, strong) NSManagedObjectID *objectID;

@property (copy, nonatomic) NSString *identifier;
@property (copy, nonatomic) NSString *givenName;
@property (copy, nonatomic) NSString *familyName;

+ (instancetype)contactWithStoredContact:(StoredContact*)storedContact;
+ (instancetype)contactWithCNContact:(CNContact*)aCNContact;

- (BOOL)isContentIdentical:(Contact*)contact;

@end
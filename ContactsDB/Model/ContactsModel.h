//
//  ContactsModel.h
//  ContactsDB
//
//  Created by Igor Pchelko on 08/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreData;
@import Contacts;
#import "Contact.h"

@protocol ContactsModelProtocol <NSObject>

- (void)contactsModelDidFailWithNoPermissions;
- (void)contactsModelDidLoad;

@end

@interface ContactsModel : NSObject

+ (instancetype) sharedInstance;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) id<ContactsModelProtocol> delegate;

- (void)update;

@end

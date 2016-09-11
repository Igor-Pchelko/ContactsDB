//
//  ContactsSynchronizer.m
//  ContactsDB
//
//  Created by Igor Pchelko on 11/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "ContactsSynchronizer.h"
#import "NSHashTable+Utilities.h"

@import Contacts;
@import UIKit;
#import "Contact.h"

@interface ContactsSynchronizer ()

@end

@implementation ContactsSynchronizer

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.isFinished = YES;
    }
    
    return self;
}



- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)syncWithStoredContacts:(NSArray *)allStoredContacts
                     withBlock:(void (^)(NSError *error,
                                         NSArray *contactsToAdd,
                                         NSArray *contactsToDelete,
                                         NSArray *contactsToUpdate)) completitionBlock {
    self.isFinished = NO;
    
    [self fetchContactListWithBlock:^(NSError *error, NSMutableArray *contacts) {

        self.isFinished = YES;
        
        [self performSyncWithSystemContacts:contacts
                         withStoredContacts:allStoredContacts
                                  withBlock:^(NSArray *contactsToAdd, NSArray *contactsToDelete, NSArray *allContactsToUpdate) {
                                      completitionBlock(nil, contactsToAdd, contactsToDelete, allContactsToUpdate);
                                  }];
    }];
}

- (void)fetchContactListWithBlock:(void (^)(NSError *error, NSMutableArray *contacts)) completitionBlock {
    
    dispatch_async(dispatch_get_global_queue( QOS_CLASS_DEFAULT, 0), ^(void) {
        
        // Create repository objects contacts
        CNContactStore *contactStore = [[CNContactStore alloc] init];
        
        // Specify requested fields
        NSArray *keys = @[CNContactIdentifierKey,
                          CNContactGivenNameKey,
                          CNContactFamilyNameKey,
                          ];
        
        // Create a request object
        CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
        request.predicate = nil;
        
        NSMutableArray *contacts = [NSMutableArray arrayWithCapacity:50];
        NSError *error;
        
        [contactStore enumerateContactsWithFetchRequest:request
                                                  error:&error
                                             usingBlock:^(CNContact* __nonnull contact, BOOL* __nonnull stop) {
                                                 Contact *contactObj = [Contact contactWithCNContact:contact];
                                                 [contacts addObject:contactObj];
                                             }];
        
        [self dumpCollection:contacts withTitle:[NSString stringWithFormat:@"contacts.count: %lu",contacts.count]];
        
        completitionBlock(error, contacts);
    });
}


- (void)performSyncWithSystemContacts:(NSArray *)allSystemContacts
                   withStoredContacts:(NSArray *)allStoredContacts
                            withBlock:(void (^)(NSArray *contactsToAdd, NSArray *contactsToDelete, NSArray *allContactsToUpdate)) completitionBlock {

    NSHashTable *allStoredContactsHashTable = [NSHashTable weakObjectsHashTable];
    [allStoredContactsHashTable addObjects:allStoredContacts];
    
    NSHashTable *allSystemContactsTable = [NSHashTable weakObjectsHashTable];
    [allSystemContactsTable addObjects:allSystemContacts];
    
    // Find contacts to add
    NSHashTable *contactsToAdd = [NSHashTable weakObjectsHashTable];
    [contactsToAdd unionHashTable:allSystemContactsTable];
    [contactsToAdd minusHashTable:allStoredContactsHashTable];
    
    // Find contacts to delete
    NSHashTable *contactsToDelete = [NSHashTable weakObjectsHashTable];
    [contactsToDelete unionHashTable:allStoredContactsHashTable];
    [contactsToDelete minusHashTable:allSystemContactsTable];
    
    // Find contacts to update
    NSHashTable *allContactsToUpdate = [NSHashTable weakObjectsHashTable];
    [allContactsToUpdate unionHashTable:allStoredContactsHashTable];
    [allContactsToUpdate intersectHashTable:allSystemContactsTable];
    
    NSHashTable *contactsToUpdate = [NSHashTable weakObjectsHashTable];
    
    for (Contact *storedContact in allContactsToUpdate) {
        Contact *systemContact = [allSystemContactsTable member:storedContact];
        
        if (![systemContact isContentIdentical:storedContact]) {
            NSLog(@"Contact to update systemContact: %@", systemContact);
            NSLog(@"Contact to update storedContact: %@", storedContact);
            storedContact.givenName = systemContact.givenName;
            storedContact.familyName = systemContact.familyName;
            
            [contactsToUpdate addObject:storedContact];
        } else {
            NSString *str = @"B8316FD5-136C-4968-8D50-46B52564806E";
            if ([systemContact.identifier isEqualToString:str])
            {
                NSLog(@"systemContact: %@", systemContact);
                NSLog(@"storedContact: %@", storedContact);
            }
            else
            {
//                NSLog(@"systemContact: %@", systemContact);
            }
        }
    }
    
    // Process
    completitionBlock(contactsToAdd.allObjects, contactsToDelete.allObjects, contactsToUpdate.allObjects);
}


#pragma mark - Debug

- (void)dumpCollection:(id<NSFastEnumeration>)collection withTitle:(NSString*)title {
    NSLog(@"%@", title);
//    for (id obj in collection) {
//        NSLog(@"%@", obj);
//    }
}
@end

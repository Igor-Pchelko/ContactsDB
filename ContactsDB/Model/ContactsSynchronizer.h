//
//  ContactsSynchronizer.h
//  ContactsDB
//
//  Created by Igor Pchelko on 11/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <Foundation/Foundation.h>

enum ContactsSynchronizerError {
    ContactsSynchronizerAuthorizationRequiredError = 1000
};

@interface ContactsSynchronizer : NSObject

@property (nonatomic, assign) BOOL isFinished;

- (void)syncWithStoredContacts:(NSArray *)allStoredContacts
                     withBlock:(void (^)(NSError *error,
                                         NSArray *contactsToAdd,
                                         NSArray *contactsToDelete,
                                         NSArray *allContactsToUpdate)) completitionBlock;

@end

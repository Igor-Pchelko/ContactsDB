//
//  Contact.m
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "Contact.h"

@implementation Contact

- (NSUInteger)hash {
    return [self.identifier hash];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[self class]])
        return NO;
    
    return [self.identifier isEqual:[object identifier]];
}

+ (instancetype)contactWithStoredContact:(StoredContact*)storedContact {
    Contact *contact = [Contact alloc];
    contact = [contact initWithStoredContact:storedContact];
    return contact;
}

- (instancetype)initWithStoredContact:(StoredContact*)storedContact {
    self = [super init];
    
    if (self == nil)
        return self;
    
    self.identifier = storedContact.identifier;
    self.givenName = storedContact.givenName;
    self.familyName = storedContact.familyName;
    self.objectID = storedContact.objectID;
    
    return self;
}

+ (instancetype)contactWithCNContact:(CNContact*)aCNContact {
    Contact *contact = [Contact alloc];
    contact = [contact initWithCNContact:aCNContact];
    return contact;
}

- (instancetype)initWithCNContact:(CNContact*)aCNContact {
    self = [super init];
    
    if (self == nil)
        return self;
    
    self.identifier = aCNContact.identifier;
    self.givenName = aCNContact.givenName;
    self.familyName = aCNContact.familyName;
    
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@;%@;%@", self.identifier, self.givenName, self.familyName];
}

- (BOOL)isContentIdentical:(Contact*)contact
{
    if (![self.givenName isEqual:contact.givenName])
        return NO;
    if (![self.familyName isEqual:contact.familyName])
        return NO;
    
    return YES;
}


@end


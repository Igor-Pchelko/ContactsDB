//
//  ContactsModel.m
//  ContactsDB
//
//  Created by Igor Pchelko on 08/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "ContactsModel.h"
#import "NSHashTable+Utilities.h"
#import "StoredContact.h"
#import "Contact.h"

@interface ContactsModel()
    @property (strong, nonatomic) NSManagedObjectContext *backgroundManagedObjectContext;
    @property (strong, nonatomic) NSMutableArray *allStoredContacts;
    @property (strong, nonatomic) NSMutableArray *allSystemContacts;
@end


@implementation ContactsModel

+ (instancetype)sharedInstance {
    static ContactsModel *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Subscribe for contacts changes
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(contactStoreDidChange:) name:CNContactStoreDidChangeNotification object:nil];
        
        // Start updates
        [self updateStoredContacts];
        [self updateContactList];
    }
    
    return self;
}

- (void)updateStoredContacts {
    NSLog(@"updateStoredContacts");
    self.allSystemContacts = nil;
    
    __weak typeof(self) weakSelf = self;
    
    [self initializeCoreDataWithBlock:^(BOOL succeeded, NSError *error) {
        NSAssert(succeeded, @"Failed to initialize CoreData with error: %@\n%@", [error localizedDescription], [error userInfo]);
        
        [self loadAllStoredContactsWithBlock:^(BOOL succeeded, NSError *error, NSMutableArray *contacts) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                strongSelf.allStoredContacts = contacts;
                NSString *title = [NSString stringWithFormat:@"allStoredContacts: %lu", strongSelf.allStoredContacts.count];
                [strongSelf dumpCollection:strongSelf.allStoredContacts withTitle:title];
                [strongSelf syncContacts];
            });
        }];
    }];
}

- (void)updateContactList {
    NSLog(@"updateContactList");
    __weak typeof(self) weakSelf = self;
    
    // Reset system contacts
    self.allSystemContacts = nil;

    [self loadContactListWithBlock:^(BOOL succeeded, NSError *error, NSMutableArray *contacts) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf.allSystemContacts = contacts;
            [strongSelf syncContacts];
        });
    }];
}

- (void)contactStoreDidChange: (NSNotification*) notification {
    NSLog(@"contactStoreDidChange: %@", notification);
    [self updateContactList];
}


- (void)syncContacts {
    // Skip sync if we don't have enough info yet to process it
    if (self.allStoredContacts == nil || self.allSystemContacts == nil)
        return;
    
    NSHashTable *allStoredContactsHashTable = [NSHashTable weakObjectsHashTable];
    [allStoredContactsHashTable addObjects:self.allStoredContacts];
    
    NSHashTable *allSystemContactsTable = [NSHashTable weakObjectsHashTable];
    [allSystemContactsTable addObjects:self.allSystemContacts];
    
    // Find contacts to add
    NSHashTable *contactsToAdd = [NSHashTable weakObjectsHashTable];
    [contactsToAdd unionHashTable:allSystemContactsTable];
    [contactsToAdd minusHashTable:allStoredContactsHashTable];
    
    NSString *title = [NSString stringWithFormat:@"contactsToAdd: %lu", contactsToAdd.count];
    [self dumpCollection:contactsToAdd withTitle:title];
    [self addContacts:contactsToAdd inManagedObjectContext:self.backgroundManagedObjectContext];
    
    // Find contacts to remove
    NSHashTable *contactsToRemove = [NSHashTable weakObjectsHashTable];
    [contactsToRemove unionHashTable:allStoredContactsHashTable];
    [contactsToRemove minusHashTable:allSystemContactsTable];
    title = [NSString stringWithFormat:@"contactsToRemove: %lu", contactsToRemove.count];
    [self dumpCollection:contactsToRemove withTitle:title];

    // Find contacts to update
    NSHashTable *allContactsToUpdate = [NSHashTable weakObjectsHashTable];
    [allContactsToUpdate unionHashTable:allStoredContactsHashTable];
    [allContactsToUpdate intersectHashTable:allSystemContactsTable];

    NSHashTable *contactsToUpdate = [NSHashTable weakObjectsHashTable];

    for (Contact *storedContact in allContactsToUpdate) {
        Contact *systemContact = [allSystemContactsTable member:storedContact];
        
        if (![systemContact isContentIdentical:storedContact]) {
            storedContact.givenName = systemContact.givenName;
            storedContact.familyName = systemContact.familyName;
            [contactsToUpdate addObject:storedContact];
        }
    }
    
    title = [NSString stringWithFormat:@"contactsToUpdate: %lu", contactsToUpdate.count];
    [self dumpCollection:contactsToUpdate withTitle:title];
    [self updateContacts:contactsToUpdate inManagedObjectContext:self.backgroundManagedObjectContext];
}

- (void)addContacts:(NSHashTable*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    [context performBlock:^{
        NSLog(@"addContacts: %lu", contacts.count);

        for (id contact in contacts) {
            [self addContact:contact inManagedObjectContext:context];
        }
    }];
}

- (void)deleteContacts:(NSHashTable*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    [context performBlock:^{
        NSLog(@"deleteContacts: %lu", contacts.count);
        
        for (id contact in contacts) {
            [self deleteContact:contact inManagedObjectContext:context];
        }
    }];
}

- (void)updateContacts:(NSHashTable*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    [context performBlock:^{
        NSLog(@"updateContacts: %lu", contacts.count);

        for (id contact in contacts) {
            [self updateContact:contact inManagedObjectContext:context];
        }
    }];
}

- (void)addContact:(Contact*)contact inManagedObjectContext:(NSManagedObjectContext *)context {
    StoredContact *storedContact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext:context];
    
    storedContact.identifier = contact.identifier;
    storedContact.givenName = contact.givenName;
    storedContact.familyName = contact.familyName;

    if ([context hasChanges]) {
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
    }
}

- (void)deleteContact:(Contact*)contact inManagedObjectContext:(NSManagedObjectContext *)context {
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Contact" inManagedObjectContext:context]];
    
    // Fetch Managed Object
    NSError *error = nil;
    StoredContact *storedContact = [context existingObjectWithID:contact.objectID error:&error];
    
    if (error) {
        NSLog(@"Unable to fetch managed object with object ID, %@.", contact.objectID);
        NSLog(@"%@, %@", error, error.localizedDescription);
        abort();
    }

    [context deleteObject:storedContact];
    
    if ([context hasChanges]) {
        if (![context save:&error]) {
            NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
    }
}

- (void)updateContact:(Contact*)contact inManagedObjectContext:(NSManagedObjectContext *)context {
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Contact" inManagedObjectContext:context]];
    
    // Fetch Managed Object
    NSError *error = nil;
    StoredContact *storedContact = [context existingObjectWithID:contact.objectID error:&error];
    
    if (error) {
        NSLog(@"Unable to fetch managed object with object ID, %@.", contact.objectID);
        NSLog(@"%@, %@", error, error.localizedDescription);
        abort();
    }

    storedContact.givenName = contact.givenName;
    storedContact.familyName = contact.familyName;
    
    if ([context hasChanges]) {
        if (![context save:&error]) {
            NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
    }
}

- (void)loadContactListWithBlock:(void (^)(BOOL succeeded, NSError *error, NSMutableArray *contacts)) completitionBlock {
    // TODO: load contacts in background thread
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    
    if (status == CNAuthorizationStatusDenied || status == CNAuthorizationStatusRestricted) {
        completitionBlock(NO, nil, nil);
        return;
    }
    
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
        
        [contactStore enumerateContactsWithFetchRequest:request
                                                  error:nil
                                             usingBlock:^(CNContact* __nonnull contact, BOOL* __nonnull stop)
         {
             Contact *contactObj = [Contact contactWithCNContact:contact];
             [contacts addObject:contactObj];
         }];
        
        completitionBlock(YES, nil, contacts);
    });
}

- (void)initializeCoreDataWithBlock:(void (^)(BOOL succeeded, NSError *error)) completitionBlock {
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"DataModel" withExtension:@"momd"];
    
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    if (mom == nil) {
        completitionBlock(NO, nil);
        return;
    }
    
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];

    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContext.persistentStoreCoordinator = psc;
    
    self.backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.backgroundManagedObjectContext.parentContext = self.managedObjectContext;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsURL URLByAppendingPathComponent:@"DataModel.sqlite"];
    NSLog(@"storeURL: %@", storeURL);
    
    dispatch_async(dispatch_get_global_queue( QOS_CLASS_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
        completitionBlock(store != nil, error);
    });
}


- (void)loadAllStoredContactsWithBlock:(void (^)(BOOL succeeded, NSError *error, NSMutableArray *contacts)) completitionBlock {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    
    [self.backgroundManagedObjectContext performBlock:^{
        NSError *error = nil;
        NSArray *results = [self.backgroundManagedObjectContext executeFetchRequest:request error:&error];
        
        if (!results) {
            completitionBlock(NO, error, nil);
            return;
        }
        
        NSMutableArray *contacts = [NSMutableArray arrayWithCapacity:50];
        
        for (StoredContact *storedContact  in results) {
            Contact *contact = [Contact contactWithStoredContact: storedContact];
            [contacts addObject:contact];
        }
        
        completitionBlock(YES, nil, contacts);
    }];
}


#pragma mark - Debug

- (void)dumpCollection:(id<NSFastEnumeration>)collection withTitle:(NSString*)title {
    NSLog(@"%@", title);
    for (id obj in collection) {
        NSLog(@"%@", obj);
    }
}

- (void)dumpAllStoredContacts {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    
    NSError *error = nil;
    NSArray *results = [self.backgroundManagedObjectContext executeFetchRequest:request error:&error];
    
    if (!results) {
        NSAssert(NO, @"Error fetching Employee objects: %@\n%@", [error localizedDescription], [error userInfo]);
    }
    
    NSLog(@"results.count: %lu", results.count);
    
    for (StoredContact *contact  in results) {
        NSLog(@"contact.identifier %@", contact.identifier);
        NSLog(@"contact.givenName %@", contact.givenName);
        NSLog(@"contact.familyName %@", contact.familyName);
    }
}

@end

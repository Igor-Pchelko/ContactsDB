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
#import "ContactsSynchronizer.h"
@import UIKit;

@interface ContactsModel()
    @property (strong, nonatomic) NSManagedObjectContext *backgroundManagedObjectContext;
    @property (strong, nonatomic) NSMutableArray *allStoredContacts;
    @property (strong, nonatomic) ContactsSynchronizer *contactsSynchronizer;
    @property (nonatomic) BOOL isResyncContactsRequired;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];

        self.contactsSynchronizer = [[ContactsSynchronizer alloc] init];

        // Subscribe for contacts changes
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(contactStoreDidChange:) name:CNContactStoreDidChangeNotification object:nil];
    }
    
    return self;
}

- (void)update {
    // Start updates
    [self updateStoredContactsWithBlock:^{
        if (self.delegate) {
            [self.delegate contactsModelDidLoad];
        }
        [self syncContacts];
    }];
}

- (void)applicationDidBecomeActive:(NSNotification*) notification {
    
    if (![self hasPermissions]) {
        NSLog(@"applicationDidBecomeActive: no permissions");
        if (self.delegate) {
            [self.delegate contactsModelDidFailWithNoPermissions];
        }
    }
}

- (BOOL)hasPermissions {
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    return (status == CNAuthorizationStatusAuthorized);
}

#pragma mark - Sync cotacts

- (void)syncContacts {
    
    NSLog(@"syncContacts");

    if (![self hasPermissions]) {
        NSLog(@"syncContacts: no permissions");
        if (self.delegate) {
            [self.delegate contactsModelDidFailWithNoPermissions];
        }
        return;
    }
    
    if (!self.contactsSynchronizer.isFinished)
    {
        NSLog(@"syncContacts not yet finished");
        self.isResyncContactsRequired = YES;
        return;
    }
    
    self.isResyncContactsRequired = NO;
    
    [self.contactsSynchronizer syncWithStoredContacts:self.allStoredContacts
                                            withBlock:^(NSError *error,
                                                        NSArray *contactsToAdd,
                                                        NSArray *contactsToDelete,
                                                        NSArray *contactsToUpdate) {
                                                
                                                NSLog(@"syncContacts complete");
                                                [self addContacts:contactsToAdd inManagedObjectContext:self.backgroundManagedObjectContext];
                                                [self deleteContacts:contactsToDelete inManagedObjectContext:self.backgroundManagedObjectContext];
                                                [self updateContacts:contactsToUpdate inManagedObjectContext:self.backgroundManagedObjectContext];
                                                
                                                if (self.isResyncContactsRequired) {
                                                    NSLog(@"re-syncContacts");
                                                    [self syncContacts];
                                                    return;
                                                }
                                            }];
}

- (void)contactStoreDidChange: (NSNotification*) notification {
    NSLog(@"contactStoreDidChange: %@", notification);
    [self syncContacts];
}

- (void)addContacts:(NSArray*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    
    [context performBlock:^{
        NSLog(@"addContacts: %lu", contacts.count);
        
        for (id contact in contacts) {
            [self addContact:contact inManagedObjectContext:context];
        }
    }];
}

- (void)addContact:(Contact*)contact inManagedObjectContext:(NSManagedObjectContext *)context {
    StoredContact *storedContact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext:context];
    
    storedContact.identifier = contact.identifier;
    storedContact.givenName = contact.givenName;
    storedContact.familyName = contact.familyName;
    
    NSError *error = nil;
    if (![context save:&error]) {
        NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
    
    // Save to all stored contacts
    dispatch_barrier_async(dispatch_get_global_queue( QOS_CLASS_DEFAULT, 0), ^{
        Contact *contact = [Contact contactWithStoredContact: storedContact];
        [self.allStoredContacts addObject:contact];
    });
}

- (void)deleteContacts:(NSArray*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    [context performBlock:^{
        NSLog(@"deleteContacts: %lu", contacts.count);
        
        for (id contact in contacts) {
            [self deleteContact:contact inManagedObjectContext:context];
        }
    }];
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
    
    if (![context save:&error]) {
        NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }

    // Delete from stored contacts
    dispatch_barrier_async(dispatch_get_global_queue( QOS_CLASS_DEFAULT, 0), ^{
        [self.allStoredContacts removeObject:contact];
    });
}

- (void)updateContacts:(NSArray*)contacts inManagedObjectContext:(NSManagedObjectContext *)context {
    [context performBlock:^{
        NSLog(@"updateContacts: %lu", contacts.count);
        
        for (id contact in contacts) {
            [self updateContact:contact inManagedObjectContext:context];
        }
    }];
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
    
    if (![context save:&error]) {
        NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
}


#pragma mark - Stored cotacts

- (void)updateStoredContactsWithBlock:(void (^)()) completitionBlock  {
    NSLog(@"updateStoredContacts");
    self.allStoredContacts = nil;
    
    __weak typeof(self) weakSelf = self;
    
    [self initializeCoreDataWithBlock:^(BOOL succeeded, NSError *error) {
        NSAssert(succeeded, @"Failed to initialize CoreData with error: %@\n%@", [error localizedDescription], [error userInfo]);
        
        [self loadAllStoredContactsWithBlock:^(BOOL succeeded, NSError *error, NSMutableArray *contacts) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                strongSelf.allStoredContacts = contacts;
                completitionBlock();
            });
        }];
    }];
}

- (void)managedObjectContextDidSave:(NSNotification *)notification {
    // Here we assume that this is a did-save notification from the parent.
    // Because parent is of private queue concurrency type, we are
    // on a background thread and can't use child (which is of main queue
    // concurrency type) directly.
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)initializeCoreDataWithBlock:(void (^)(BOOL succeeded, NSError *error)) completitionBlock {
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"DataModel" withExtension:@"momd"];
    
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    if (mom == nil) {
        completitionBlock(NO, nil);
        return;
    }
    
    __block NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];

    self.backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.backgroundManagedObjectContext.persistentStoreCoordinator = psc;

    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContext.parentContext = self.backgroundManagedObjectContext;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(managedObjectContextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.backgroundManagedObjectContext];

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

//
//  ContactsListViewController.m
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "ContactsListViewController.h"
@import CoreData;
#import "ContactsModel.h"
#import "ContactTableViewCell.h"

@interface ContactsListViewController () <NSFetchedResultsControllerDelegate, ContactsModelProtocol>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation ContactsListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [ContactsModel sharedInstance].delegate = self;
    [[ContactsModel sharedInstance] update];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - ContactsModelProtocol

- (void)contactsModelDidFailWithNoPermissions {
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Contact permissions is required"
                                                                   message:@"Please enable contact permission to allow syncronize contacts in app."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Go to settings"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                              [[UIApplication sharedApplication] openURL:url];
                                                          }];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)contactsModelDidLoad {
    NSLog(@"contactsModelDidLoad: reload");
    [self initFetchedResultsController];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (self.fetchedResultsController == nil)
        return 0;
    
    NSInteger numberOfRows = 0;
    
    if ([[self.fetchedResultsController sections] count] > 0) {
        id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
        numberOfRows = [sectionInfo numberOfObjects];
    }
    
    return numberOfRows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    if (self.fetchedResultsController == nil)
        return 0;

    return self.fetchedResultsController.sections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.fetchedResultsController == nil)
        return nil;

    static NSString *kContactCellID = @"ContactCellID";
    ContactTableViewCell *cell = (ContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:kContactCellID];
    
    // Get the specific earthquake for this row.
    StoredContact *contact = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    [cell configureWithContact:contact];
    
    return cell;
}

#pragma mark - NSFetchedResultsController

// called after fetched results controller received a content change notification
- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {

    [self.tableView reloadData];
}

- (void)initFetchedResultsController {
    
    // Set up the fetched results controller
    self.fetchedResultsController = nil;
    
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact"
                                              inManagedObjectContext:[[ContactsModel sharedInstance] managedObjectContext]];
    [fetchRequest setEntity:entity];
    
    // sort by date
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"familyName" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[[ContactsModel sharedInstance] managedObjectContext]
                                          sectionNameKeyPath:nil
                                                   cacheName:nil];
    self.fetchedResultsController = aFetchedResultsController;
    self.fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    
    if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate.
        // You should not use this function in a shipping application, although it may be useful
        // during development. If it is not possible to recover from the error, display an alert
        // panel that instructs the user to quit the application by pressing the Home button.
        //
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

@end

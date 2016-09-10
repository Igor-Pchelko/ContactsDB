//
//  ContactTableViewCell.h
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"

@interface ContactTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *label;
- (void)configureWithContact:(Contact*)contact;

@end

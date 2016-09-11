//
//  ContactTableViewCell.m
//  ContactsDB
//
//  Created by Igor Pchelko on 10/09/16.
//  Copyright © 2016 Igor Pchelko. All rights reserved.
//

#import "ContactTableViewCell.h"

@implementation ContactTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (NSString *)displayNameWithContact:(StoredContact*)contact {
    if ([contact.familyName length] == 0 && [contact.givenName length] == 0)
        return @"<Unknown>";
    
    return [NSString stringWithFormat:@"%@ %@", contact.familyName, contact.givenName];
}

- (void)configureWithContact:(StoredContact*)contact {
    
    self.label.text = [self displayNameWithContact:contact];
}

@end

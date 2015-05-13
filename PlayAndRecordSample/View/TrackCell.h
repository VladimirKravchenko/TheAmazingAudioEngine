//
//  TrackCell.h
//  TheEngineSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TrackCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *muteButton;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) void (^muteBlock)(TrackCell *aCell);
@end

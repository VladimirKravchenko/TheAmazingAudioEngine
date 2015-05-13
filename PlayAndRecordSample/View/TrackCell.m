//
//  TrackCell.m
//  TheEngineSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import "TrackCell.h"

@implementation TrackCell

- (IBAction)muteButtonPressed:(id)sender {
    if (self.muteBlock)
        self.muteBlock(self);
}

@end

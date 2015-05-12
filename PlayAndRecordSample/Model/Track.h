//
//  Track.h
//  TheEngineSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Track : NSObject
@property (copy, nonatomic) NSString *urlString;
@property (copy, nonatomic) NSString *name;
- (instancetype)initWithName:(NSString *)name urlString:(NSString *)urlString NS_DESIGNATED_INITIALIZER;
+ (instancetype)trackWithName:(NSString *)name urlString:(NSString *)urlString;

@end

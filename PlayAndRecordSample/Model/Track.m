//
//  Track.m
//  TheEngineSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import "Track.h"

@implementation Track

- (instancetype)initWithName:(NSString *)name urlString:(NSString *)urlString {
    self = [super init];
    if (self) {
        _urlString = [urlString copy];
        _name = [name copy];
    }
    return self;
}

+ (instancetype)trackWithName:(NSString *)name urlString:(NSString *)urlString {
    return [[self alloc] initWithName:name urlString:urlString];
}

@end

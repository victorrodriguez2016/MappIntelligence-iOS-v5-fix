//
//  AdvertisementProperties.m
//  MappIntelligenceSDK
//
//  Created by Miroljub Stoilkovic on 28/10/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import "AdvertisementProperties.h"

@implementation AdvertisementProperties

- (instancetype)initWith: (NSString *) campaignId {
    self = [super init];
    _campaignId = campaignId;
    return self;
}

- (NSMutableArray<NSURLQueryItem *> *)asQueryItems {
    NSMutableArray<NSURLQueryItem*>* items = [[NSMutableArray alloc] init];
    
    NSString *mediaCode = _mediaCode ? _mediaCode : @"wt_mc";
    if (_campaignId) {
        [items addObject:[[NSURLQueryItem alloc] initWithName:@"mc" value: [NSString stringWithFormat:@"%@%@%@",mediaCode, @"%3D",_campaignId] ]];
    } else {
        [items addObject:[[NSURLQueryItem alloc] initWithName:@"mc" value:mediaCode]];
    }
    
    if (_action) {
        NSString *actionString = [NSString stringWithFormat:@"%@", _action == 0 ? @"c": @"v"];
        [items addObject:[[NSURLQueryItem alloc] initWithName:@"mca" value: actionString]];
    } else {
        [items addObject:[[NSURLQueryItem alloc] initWithName:@"mca" value:@"c"]];

    }
    if (_customProperties) {
        for(NSNumber* key in _customProperties) {
            [items addObject:[[NSURLQueryItem alloc] initWithName:[NSString stringWithFormat:@"cc%@",key] value: [_customProperties[key] componentsJoinedByString:@";"]]];
        }
    }
    return items;
}

- (id)copyWithZone:(NSZone *)zone {
    AdvertisementProperties *adCopy = [[AdvertisementProperties alloc] init];
    [adCopy setCampaignId:_campaignId];
    [adCopy setMediaCode:_mediaCode];
    [adCopy setAction:_action];
    [adCopy setCustomProperties:_customProperties];
    [adCopy setOncePerSession:_oncePerSession];
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:adCopy requiringSecureCoding:YES error:&error];
    adCopy = [NSKeyedUnarchiver unarchivedObjectOfClass:AdvertisementProperties.class fromData:data error:&error];
    return adCopy;
}
- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.campaignId forKey:@"Campaign_ID"];
    [coder encodeObject:self.mediaCode forKey:@"Media_code"];
    [coder encodeInteger: self.action forKey:@"Action"];
    [coder encodeObject:self.customProperties forKey:@"Custom_properties"];
    [coder encodeBool:self.oncePerSession forKey:@"Once_per_session"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if (self = [super init]) {
        self.campaignId = [coder decodeObjectForKey:@"Campaign_ID"];
        self.mediaCode = [coder decodeObjectForKey:@"Media_code"];
        self.action = [coder decodeIntegerForKey: @"Action"];
        NSSet *classes = [NSSet setWithObjects:NSArray.class, NSDictionary.class, NSNumber.class, NSString.class, nil];
        self.customProperties = [coder decodeObjectOfClasses:classes forKey:@"Custom_properties"];
        self.oncePerSession = [coder decodeBoolForKey:@"Once_per_session"];
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    AdvertisementProperties *otherObj = (AdvertisementProperties *)other;
    if(self.action == otherObj.action &&
       self.oncePerSession == otherObj.oncePerSession &&
       [self.campaignId isEqual:otherObj.campaignId] &&
       [self.customProperties isEqual: otherObj.customProperties] &&
       [self.mediaCode isEqual: otherObj.mediaCode]) {
        return YES;
    }
    return NO;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}
@end
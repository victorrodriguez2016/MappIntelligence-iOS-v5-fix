//
//  AdvertisementProperties.h
//  MappIntelligenceSDK
//
//  Created by Miroljub Stoilkovic on 28/10/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, CampaignAction) {
    click,
    view
};

NS_ASSUME_NONNULL_BEGIN

@interface AdvertisementProperties : NSObject <NSCopying, NSSecureCoding>
@property (nullable) NSString *campaignId;
@property CampaignAction action;
@property (nullable) NSString *mediaCode;
@property BOOL oncePerSession;
@property (nullable) NSDictionary<NSNumber* ,NSArray<NSString*>*>* customProperties;

- (instancetype)initWith: (NSString *) campaignId;
- (NSMutableArray<NSURLQueryItem*>*)asQueryItems;

@end

NS_ASSUME_NONNULL_END

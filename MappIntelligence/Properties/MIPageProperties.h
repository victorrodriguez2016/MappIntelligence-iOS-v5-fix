//
//  MIPageProperties.h
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 17/07/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MITrackerRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIPageProperties : NSObject

@property (nullable) NSString* internalSearch;
@property (nullable) NSDictionary<NSNumber* ,NSArray<NSString*>*> *details;
@property (nullable) NSMutableDictionary* groups;

-(instancetype)initWithPageParams: (NSDictionary<NSNumber* ,NSArray<NSString*>*>* _Nullable) parameters andWithPageCategory: (NSMutableDictionary* _Nullable) category andWithSearch: (NSString* _Nullable)internalSearch;

-(NSMutableArray<NSURLQueryItem*>*)asQueryItems;

@end

NS_ASSUME_NONNULL_END
//
//  MIPageProperties.m
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 17/07/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import "MIPageProperties.h"

@implementation MIPageProperties

-(instancetype)initWithPageParams: (NSDictionary<NSNumber* ,NSArray<NSString*>*>* _Nullable) parameters andWithPageCategory: (NSMutableDictionary* _Nullable) category andWithSearch: (NSString* _Nullable)internalSearch {
    self = [self init];
    if (self) {
        _details = parameters;
        _groups = category;
        _internalSearch = internalSearch;
    }
    return  self;
}

- (NSMutableArray<NSURLQueryItem*>*)asQueryItems {
    NSMutableArray<NSURLQueryItem*>* items = [[NSMutableArray alloc] init];
    if (_details) {
        _details = [self filterCustomDict:_details];
        for(NSNumber* key in _details) {
            [items addObject:[[NSURLQueryItem alloc] initWithName:[NSString stringWithFormat:@"cp%@",key] value: [_details[key] componentsJoinedByString:@";"]]];
        }
    }
    if (_groups) {
        for(NSString* key in _groups) {
            [items addObject:[[NSURLQueryItem alloc] initWithName:[NSString stringWithFormat:@"cg%@",key] value: [_groups[key] componentsJoinedByString:@";"]]];
        }
    }
    if (_internalSearch) {
        [items addObject:[[NSURLQueryItem alloc] initWithName:@"is" value:_internalSearch]];
    }
    return items;
}

- (NSDictionary<NSNumber* ,NSArray<NSString*>*> *) filterCustomDict: (NSDictionary<NSNumber* ,NSArray<NSString*>*> *) dict{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (NSNumber *idx in dict) {
        if (idx.intValue > 0) {
            [result setObject:dict[idx] forKey:idx];
        }
    }
    return result;
}
@end

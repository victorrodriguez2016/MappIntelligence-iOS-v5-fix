//
//  UserProperties.m
//  MappIntelligenceTests
//
//  Created by Miroljub Stoilkovic on 22/10/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "UserProperties.h"

@interface UserPropertiesTests : XCTestCase
@property UserProperties* userProperties;
@property NSMutableDictionary* parameters;
@end

@implementation UserPropertiesTests

- (void)setUp {
    _parameters = [@{@20: @[@"1 element"]} copy];
    _userProperties = [[UserProperties alloc] initWithCustomProperties:_parameters];
}

- (void)tearDown {
    _parameters = nil;
    _userProperties = nil;
}

- (void)testInitWIthCustomParameters {
    XCTAssertTrue([_userProperties.customProperties isEqualToDictionary:_parameters], @"The details from action properties is not same as it is used for creation!");
}

- (void)testAsQueryItemsForRequest {
    //1. create expected query items
    NSMutableArray<NSURLQueryItem*>* expectedItems = [[NSMutableArray alloc] init];
    if (_parameters) {
        for(NSString* key in _parameters) {
            [expectedItems addObject:[[NSURLQueryItem alloc] initWithName:[NSString stringWithFormat:@"uc%@",key] value: [_parameters[key] componentsJoinedByString:@";"]]];
        }
    }

     //3.get resulted list of query items
     NSMutableArray<NSURLQueryItem*>* result = [_userProperties asQueryItems];
     
     XCTAssertTrue([expectedItems isEqualToArray:result], @"The expected query is not the same as ones from result!");
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
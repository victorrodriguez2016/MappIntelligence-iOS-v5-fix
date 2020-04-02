//
//  UIFlowObserver.m
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 3/11/20.
//  Copyright © 2020 Stefan Stevanovic. All rights reserved.
//

#import "UIFlowObserver.h"
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#else
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#endif

@interface UIFlowObserver ()

@property DefaultTracker *tracker;
#if !TARGET_OS_WATCH
@property UIApplication *application;
#endif
@property NSObject *applicationDidBecomeActiveObserver;
@property NSObject *applicationWillEnterForegroundObserver;
@property NSObject *applicationWillResignActiveObserver;
@property NSUserDefaults *sharedDefaults;

@end

@implementation UIFlowObserver

- (instancetype)initWith:(DefaultTracker *)tracker {
    self = [super init];
    _tracker = tracker;
#if !TARGET_OS_WATCH
    _sharedDefaults = [NSUserDefaults standardUserDefaults];
#endif
    return self;
}

- (BOOL)setup {
  NSNotificationCenter *notificationCenter =
      [NSNotificationCenter defaultCenter];
#if !TARGET_OS_WATCH
    //Posted when the app becomes active.
    _applicationDidBecomeActiveObserver = [notificationCenter addObserverForName: UIApplicationDidBecomeActiveNotification object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self didBecomeActive];
    }];
    //Posted shortly before an app leaves the background state on its way to becoming the active app.
    _applicationWillEnterForegroundObserver = [notificationCenter addObserverForName:UIApplicationWillEnterForegroundNotification object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self willEnterForeground];
    }];
    //Posted when the app is no longer active and loses focus.
    _applicationWillResignActiveObserver = [notificationCenter addObserverForName:UIApplicationWillResignActiveNotification object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self willResignActive];
    }];
    //terminate, not called always
    [notificationCenter addObserverForName:UIApplicationWillTerminateNotification object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        //[self willResignActive];
    }];
#else
    _applicationWillEnterForegroundObserver = [notificationCenter addObserverForName:@"UIApplicationWillEnterForegroundNotification" object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self willEnterForeground];
    }];
    _applicationDidBecomeActiveObserver = [notificationCenter addObserverForName: @"UIApplicationDidBecomeActiveNotification" object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self didBecomeActive];
    }];
    [notificationCenter addObserverForName:@"UIApplicationWillTerminateNotification" object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self willTerminate];
    }];
    _applicationWillResignActiveObserver = [notificationCenter addObserverForName:@"UIApplicationWillResignActiveNotification" object:NULL queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        [self willResignActive];
    }];
#endif
  return YES;
}

-(void)didBecomeActive {
#if TARGET_OS_WATCH
//    [_tracker updateFirstSessionWith:[[WKExtension sharedExtension] applicationState]];
#endif
}

-(void)willEnterForeground {
    //[_tracker updateFirstSession];
    //NSLog(@"%ld",(long)[[UIApplication sharedApplication] applicationState] );
// application status if came relaunch app is INACTIVE
#if !TARGET_OS_WATCH
  [_tracker updateFirstSessionWith:[[UIApplication sharedApplication]
                                       applicationState]];
#else
  [_tracker updateFirstSessionWith:[[WKExtension sharedExtension] applicationState]];
    NSLog(@"%ld session state: %ld", (long)[[WKExtension sharedExtension] applicationState], (long)[[WKExtendedRuntimeSession session] state]);
#endif
}

-(void)willResignActive {
#if TARGET_OS_WATCH
    NSLog(@"%ld session state: %ld", (long)[[WKExtension sharedExtension] applicationState], (long)[[WKExtendedRuntimeSession session] state]);
#endif  
  [_tracker initHibernate];
}

-(void)willTerminate {
#if TARGET_OS_WATCH
    NSLog(@"Watch OS will be terminate");
#endif
}

@end


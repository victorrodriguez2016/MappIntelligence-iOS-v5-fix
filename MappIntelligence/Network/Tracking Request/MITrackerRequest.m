//
//  TrackerRequest.m
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 2/12/20.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import "MITrackerRequest.h"
#import "MappIntelligenceLogger.h"

@interface MITrackerRequest ()

@property MappIntelligenceLogger *loger;
@property NSURLSession *urlSession;
@property NSURLSession *backgroundUrlSession;

@end

@implementation MITrackerRequest

- (instancetype)init {
  self = [super init];
  if (self) {
    _loger = [MappIntelligenceLogger shared];
#if TARGET_OS_IOS
    _urlSession = [[NSURLSession alloc] init];
#endif
  }
  return self;
}

- (instancetype)initWithEvent:(MITrackingEvent *)event
            andWithProperties:(MIProperties *)properties {
  self = [self init];
  [self setEvent:event];
  [self setProperties:properties];
  return self;
}

- (void)sendRequestWith:(NSURL *)url andCompletition:(nonnull void (^)(NSError * _Nonnull))handler {
  [_loger logObj:[[NSString alloc]
                     initWithFormat:@"Tracking Request: %@", [url absoluteURL]]
      forDescription:kMappIntelligenceLogLevelDescriptionInfo];

  [self createUrlSession];

  [[_urlSession
        dataTaskWithURL:url
      completionHandler:^(NSData *_Nullable data,
                          NSURLResponse *_Nullable response,
                          NSError *_Nullable error) {
        if (!error) {
          [self->_loger logObj:[[NSString alloc]
                                   initWithFormat:
                                       @"Response from tracking server: %@",
                                       [response description]]
                forDescription:kMappIntelligenceLogLevelDescriptionDebug];
        }
        handler(error);
      }] resume];
}

- (void)sendRequestWith:(NSURL *)url andBody:(NSString*)body andCompletition:(nonnull void (^)(NSError * _Nonnull))handler {
    
    [self createUrlSession];
    NSURLRequest* request = [self createRequest:url andBody:body];
    
    [[_urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            [self->_loger logObj:[[NSString alloc]
                                  initWithFormat:
                                  @"Response from tracking server for sended batch support: %@",
                                  [response description]]
                  forDescription:kMappIntelligenceLogLevelDescriptionDebug];
        }
        handler(error);
        [self->_urlSession invalidateAndCancel];
    }] resume];
}


- (void)sendBackgroundRequestWith:(NSURL *)url andBody:(NSString*)body {
    [self createBackgroundUrlSession];
    NSURLRequest* request = [self createRequest:url andBody:body];
    
    [[_backgroundUrlSession dataTaskWithRequest:request] resume];
}

- (NSURLRequest*) createRequest:(NSURL *)url andBody:(NSString*)body {
    [_loger logObj:[[NSString alloc]
                       initWithFormat:@"Tracking Request: %@ with body: %@", [url absoluteURL], body]
        forDescription:kMappIntelligenceLogLevelDescriptionInfo];

      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
          cachePolicy:NSURLRequestUseProtocolCachePolicy
      timeoutInterval:60.0];
      [request addValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
      [request addValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Accept"];

      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO]];
    return request;
}


- (void)createUrlSession {
  NSURLSessionConfiguration *urlSessionConfiguration =
      [NSURLSessionConfiguration ephemeralSessionConfiguration];
  [urlSessionConfiguration
      setHTTPCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
  [urlSessionConfiguration setHTTPShouldSetCookies:NO];
  [urlSessionConfiguration setURLCache:NULL];
  [urlSessionConfiguration setURLCredentialStorage:NULL];
  [urlSessionConfiguration
      setRequestCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
  [urlSessionConfiguration setShouldUseExtendedBackgroundIdleMode:YES];

  _urlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration];
  [_urlSession setSessionDescription:@"Mapp Intelligence Tracking"];
}

- (void)createBackgroundUrlSession {
  NSURLSessionConfiguration *urlSessionConfiguration =
      [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.mapp.background"];
  [urlSessionConfiguration
      setHTTPCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
  [urlSessionConfiguration setHTTPShouldSetCookies:NO];
  [urlSessionConfiguration setURLCache:NULL];
  [urlSessionConfiguration setURLCredentialStorage:NULL];
  [urlSessionConfiguration
      setRequestCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
  [urlSessionConfiguration setShouldUseExtendedBackgroundIdleMode:YES];
    [urlSessionConfiguration setAllowsCellularAccess:YES];
    [urlSessionConfiguration setDiscretionary:YES];
    [urlSessionConfiguration setSessionSendsLaunchEvents:YES];

    _backgroundUrlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration delegate:self delegateQueue:nil];
  [_backgroundUrlSession setSessionDescription:@"Mapp Intelligence Tracking in Background"];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    //NSLog(@"%@", data);
#if !TARGET_OS_WATCH
    UIBackgroundTaskIdentifier backgroundIdentifier = (unsigned long)[[NSUserDefaults standardUserDefaults] integerForKey:@"backgroundIdentifier"];
    [[UIApplication sharedApplication] endBackgroundTask: backgroundIdentifier];
#endif
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    NSLog(@"error: %@", error);
#if !TARGET_OS_WATCH
    UIBackgroundTaskIdentifier backgroundIdentifier = (unsigned long)[[NSUserDefaults standardUserDefaults] integerForKey:@"backgroundIdentifier"];
    [[UIApplication sharedApplication] endBackgroundTask: backgroundIdentifier];
#endif
}

@end

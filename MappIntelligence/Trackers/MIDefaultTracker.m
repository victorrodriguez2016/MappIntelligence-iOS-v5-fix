//
//  MIDefaultTracker.m
//  MappIntelligenceSDK
//
//  Created by Vladan Randjelovic on 11/02/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

#import "MIDefaultTracker.h"
#import "MappIntelligenceLogger.h"
#import "MappIntelligence.h"
#import "MIProperties.h"
#import "MIEnvironment.h"
#import "MIConfiguration.h"
#import "MIRequestTrackerBuilder.h"
#import "MITrackerRequest.h"
#import "MIRequestUrlBuilder.h"
#import "MIUIFlowObserver.h"
#import "MIDatabaseManager.h"
#import "MIRequestData.h"
#import "MIRequestBatchSupportUrlBuilder.h"



#import <objc/runtime.h>

@implementation NSThread(isLocking)

static int waiting_condition_key;

-(BOOL) isWaitingOnCondition {
    // here, we sleep for a microsecond (1 millionth of a second) so that the
    // other thread can catch up,  and actually call 'wait'. This time
    // interval is so small that you will never notice it in an actual
    // application, it's just here because of how multithreaded
    // applications work.
    usleep(1);

    BOOL val = [objc_getAssociatedObject(self, &waiting_condition_key) boolValue];

    // sleep before and after so it works on both edges
    usleep(1);

    return val;
}

-(void) setIsWaitingOnCondition:(BOOL) value {
        objc_setAssociatedObject(self, &waiting_condition_key, @(value), OBJC_ASSOCIATION_RETAIN);
}

@end

@implementation NSCondition(isLocking)

+(void) load {
    Method old = class_getInstanceMethod(self, @selector(wait));
    Method new = class_getInstanceMethod(self, @selector(_wait));

    method_exchangeImplementations(old, new);
}

-(void) _wait {
    // this is the replacement for the original wait method
    [[NSThread currentThread] setIsWaitingOnCondition:YES];

    // call  the original implementation, which now resides in the same name as this method
    [self _wait];

    [[NSThread currentThread] setIsWaitingOnCondition:NO];
}

@end


#define appHibernationDate @"appHibernationDate"
#define appVersion @"appVersion"
#define configuration @"configuration"
#define everId @"everId"
#define legacyEverId @"webtrekk.everId"
#define isFirstEventOfApp @"isFirstEventOfApp"
#define legacyIsFirstEventOfApp @"webtrekk.isFirstEventOfApp"

@interface MIDefaultTracker ()

@property MIConfiguration *config;
@property MappIntelligenceLogger *logger;
@property MITrackingEvent *event;
@property MIRequestUrlBuilder *requestUrlBuilder;
@property MIRequestBatchSupportUrlBuilder* requestBatchSupportUrlBuilder;
@property NSUserDefaults* defaults;
@property BOOL isFirstEventOpen;
@property BOOL isFirstEventOfSession;
@property MIUIFlowObserver *flowObserver;
@property NSCondition *conditionUntilGetFNS;
@property dispatch_queue_t queue;

- (void)enqueueRequestForEvent:(MITrackingEvent *)event;
- (MIProperties *)generateRequestProperties;

@end

@implementation MIDefaultTracker : NSObject

static MIDefaultTracker *sharedTracker = nil;
static NSString *everID;
static NSString *userAgent;

+ (nullable instancetype)sharedInstance {

  static MIDefaultTracker *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[MIDefaultTracker alloc] init];
  });
  return shared;
}

- (instancetype)init {
  if (!sharedTracker) {
    sharedTracker = [super init];
    everID = [sharedTracker generateEverId];
    _config = [[MIConfiguration alloc] init];
    _logger = [MappIntelligenceLogger shared];
    _defaults = [NSUserDefaults standardUserDefaults];
    _flowObserver = [[MIUIFlowObserver alloc] initWith:self];
    [_flowObserver setup];
    _conditionUntilGetFNS = [[NSCondition alloc] init];
    _isReady = NO;
    [self generateUserAgent];
    [self initializeTracking];
      _queue = dispatch_queue_create("Inserting Requests", NULL);
#if TARGET_OS_TV
      [self checkIfAppUpdated];
#endif
  }
  return sharedTracker;
}

- (NSString*)generateUserAgent {
  NSString *properties = [MIEnvironment.operatingSystemName
      stringByAppendingFormat:@" %@; %@; %@", MIEnvironment.operatingSystemVersionString,
                            MIEnvironment.deviceModelString,
                          [[NSLocale currentLocale]     localeIdentifier]];
  userAgent =
      [[NSString alloc] initWithFormat:@"Tracking Library %@ (%@))",
       MappIntelligence.version, properties];
    return userAgent;
}

- (void)initializeTracking {
  _config.serverUrl = [[NSURL alloc] initWithString:[MappIntelligence getUrl]];
  _config.MappIntelligenceId = [MappIntelligence getId];
  _config.requestInterval = [[MappIntelligence shared] requestInterval];
    _config.requestPerQueue = ([[MappIntelligence shared] batchSupportEnabled]) ? [[MappIntelligence shared] batchSupportSize] : [[MappIntelligence shared] requestPerQueue];
  _requestUrlBuilder =
      [[MIRequestUrlBuilder alloc] initWithUrl:_config.serverUrl
                                   andWithId:_config.MappIntelligenceId];
}

- (BOOL)isBackgroundSendoutEnabled {
    return [[MappIntelligence shared] enableBackgroundSendout];
}

- (void)sendRequestFromDatabaseWithCompletionHandler:(void (^)(NSError * _Nullable))handler {
    [[MIDatabaseManager shared] fetchAllRequestsFromInterval: _config.requestPerQueue andWithCompletionHandler:^(NSError * _Nonnull error, id  _Nullable data) {
        if (!error) {
            MIRequestData* dt = (MIRequestData*)data;
            [dt sendAllRequestsWithCompletitionHandler:^(NSError * _Nullable error) {
                if(error) {
                    [self->_logger logObj:[[NSString alloc] initWithFormat:@"An error occurred while sending track requests to Mapp Intelligence: %@!", [error description]] forDescription:kMappIntelligenceLogLevelDescriptionDebug];
                }
                handler(error);
            }];
        }
    }];
}

- (void)removeAllRequestsFromDBWithCompletionHandler:(void (^)(NSError * _Nullable))handler {
    [[MIDatabaseManager shared] deleteAllRequest];
    //TODO: handle deletation error
    handler(nil);
}
- (void)sendBatchForRequestInBackground: (BOOL)background withCompletionHandler:(void (^)(NSError * _Nullable))handler {
        _requestBatchSupportUrlBuilder = [[MIRequestBatchSupportUrlBuilder alloc] init];
    [_requestBatchSupportUrlBuilder sendBatchForRequestsInBackground:background withCompletition:^(NSError * _Nonnull error) {
        if (error) {
            [self->_logger logObj:@"An error occurred while sending batch requests to Mapp Intelligence." forDescription:kMappIntelligenceLogLevelDescriptionDebug];
            
        }
        handler(error);
    }];
}

- (NSString *)generateEverId {


  NSString *tmpEverId = [[MIDefaultTracker sharedDefaults] stringForKey:everId];
  // https://nshipster.com/nil/ read for more explanation
  if (tmpEverId != nil) {
    return tmpEverId;
  } else {
    return [self getNewEverID];
  }

  return @"";
}

- (void)setEverIDFromString:(NSString *_Nonnull)everIDString {
    everID = everIDString;
    [[MIDefaultTracker sharedDefaults] setValue:everIDString forKey:everId];
    [[MIDefaultTracker sharedDefaults] synchronize];
}

- (NSString *)getNewEverID {
  NSString *tmpEverId = [[NSString alloc]
      initWithFormat:@"6%010.0f%08u",
                     [[[NSDate alloc] init] timeIntervalSince1970],
                     arc4random_uniform(99999999) + 1];
  [[MIDefaultTracker sharedDefaults] setValue:tmpEverId forKey:everId];

  if ([everId isEqual:[[NSNull alloc] init]]) {
    @throw @"Cannot generate everID";
  }
  return tmpEverId;
}
#if !TARGET_OS_WATCH
- (NSError *_Nullable)track:(UIViewController *)controller {
  NSString *CurrentSelectedCViewController =
      NSStringFromClass([controller class]);
  return [self trackWith:CurrentSelectedCViewController];
}
#endif
- (NSError *)trackWithEvent:(MITrackingEvent *)event {
      if (![_defaults stringForKey:isFirstEventOfApp]) {
        [_defaults setBool:YES forKey:isFirstEventOfApp];
        [_defaults synchronize];
        _isFirstEventOpen = YES;
        _isFirstEventOfSession = YES;
      } else {
        _isFirstEventOpen = NO;
      }
    #ifdef TARGET_OS_WATCH
        _isReady = YES;
    #endif
      dispatch_async(_queue,
                     ^(void) {
                       // Background Thread
                       [self->_conditionUntilGetFNS lock];
                       while (!self->_isReady)
                         [self->_conditionUntilGetFNS wait];
                         [self enqueueRequestForEvent:event];
                         [self->_conditionUntilGetFNS signal];
                         [self->_conditionUntilGetFNS unlock];
                     });
        
        return NULL;
}

- (NSError *)trackWithCustomEvent:(MITrackingEvent *)event {
      if (![_defaults stringForKey:isFirstEventOfApp]) {
        [_defaults setBool:YES forKey:isFirstEventOfApp];
        [_defaults synchronize];
        _isFirstEventOpen = YES;
        _isFirstEventOfSession = YES;
      } else {
        _isFirstEventOpen = NO;
      }
    #ifdef TARGET_OS_WATCH
        _isReady = YES;
    #endif
      dispatch_async(_queue,
                     ^(void) {
                       // Background Thread
                       [self->_conditionUntilGetFNS lock];
                       while (!self->_isReady)
                         [self->_conditionUntilGetFNS wait];
                         [self enqueueRequestForCustomEvent:event];
                         [self->_conditionUntilGetFNS signal];
                         [self->_conditionUntilGetFNS unlock];
                     });
        
        return NULL;
}

- (NSError *_Nullable)trackWith:(NSString *)name {
  if ([_config.MappIntelligenceId isEqual:@""] ||
      [_config.serverUrl.absoluteString isEqual:@""]) {
    NSString *msg =
        @"Request cannot be sent without a track domain and trackID.";
    [_logger logObj:msg
        forDescription:kMappIntelligenceLogLevelDescriptionError];
    NSString *domain = @"com.mapp.mappIntelligenceSDK.ErrorDomain";
    NSString *desc = NSLocalizedString(msg, @"");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    NSError *error =
        [NSError errorWithDomain:domain code:-101 userInfo:userInfo];
    return error;
  }
  if ([name length] > 255) {
      NSString *msg =
      @"ContentID contains more than 255 characters, characters will be removed automatically.";
    [_logger logObj:msg
        forDescription:kMappIntelligenceLogLevelDescriptionWarning];
      NSRange range = NSMakeRange(0, 254);
      name =  [name substringWithRange:range];
  }
  if (![_defaults stringForKey:isFirstEventOfApp]) {
    [_defaults setBool:YES forKey:isFirstEventOfApp];
    [_defaults synchronize];
    _isFirstEventOpen = YES;
    _isFirstEventOfSession = YES;
  } else {
    _isFirstEventOpen = NO;
  }

  [_logger logObj:[[NSString alloc] initWithFormat:@"Content ID is: %@", name]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];

  // create request with page event
    MITrackingEvent *event = [[MITrackingEvent alloc] init];
  [event setPageName:name];
#ifdef TARGET_OS_WATCH
    _isReady = YES;
#endif
  dispatch_async(_queue,
                 ^(void) {
                   // Background Thread
                   [self->_conditionUntilGetFNS lock];
                   while (!self->_isReady)
                     [self->_conditionUntilGetFNS wait];
                   //dispatch_async(dispatch_get_main_queue(), ^(void) {
                     // Run UI Updates
                     [self enqueueRequestForEvent:event];
                     [self->_conditionUntilGetFNS signal];
                     [self->_conditionUntilGetFNS unlock];
                   //});
                 });
    
    return NULL;
}

- (void)enqueueRequestForEvent:(MITrackingEvent *)event {
  MIProperties *requestProperties = [self generateRequestProperties];
  requestProperties.locale = [NSLocale currentLocale];

  [requestProperties setIsFirstEventOfApp:_isFirstEventOpen];
  [requestProperties setIsFirstEventOfSession:_isFirstEventOfSession];
  [requestProperties setIsFirstEventAfterAppUpdate:NO];

  MIRequestTrackerBuilder *builder =
      [[MIRequestTrackerBuilder alloc] initWithConfoguration:self.config];

    MITrackerRequest *request =
      [builder createRequestWith:event andWith:requestProperties];
   [_requestUrlBuilder urlForRequest:request withCustomData:NO];
    MIRequest *r = [self->_requestUrlBuilder dbRequest];
    [r setStatus:ACTIVE];
    BOOL status = [[MIDatabaseManager shared] insertRequest:r];
    [_logger logObj:[NSString stringWithFormat: @"request written with success: %d", status] forDescription:kMappIntelligenceLogLevelDescriptionDebug];
  _isFirstEventOfSession = NO;
  _isFirstEventOpen = NO;
}

- (MIProperties *)generateRequestProperties {
  return [[MIProperties alloc] initWithEverID:everID
                            andSamplingRate:0
                               withTimeZone:[NSTimeZone localTimeZone]
                              withTimestamp:[NSDate date]
                              withUserAgent:userAgent];
}

+ (NSUserDefaults *)sharedDefaults {
  return [NSUserDefaults standardUserDefaults];
}

- (void)initHibernate {
  NSDate *date = [[NSDate alloc] init];
  [_logger logObj:[[NSString alloc] initWithFormat:@"save current date for "
                                                   @"session detection %@ "
                                                   @"with defaults %d",
                                                   date, _defaults == NULL]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];
  [_defaults setObject:date forKey:appHibernationDate];
  _isReady = NO;
}
#if !TARGET_OS_WATCH
- (void)updateFirstSessionWith:(UIApplicationState)state {
  if (state == UIApplicationStateInactive) {
    _isFirstEventOfSession = YES;
     [self checkIfAppUpdated];
  } else {
    _isFirstEventOfSession = NO;
  }
  [self fireSignal];
//  [self checkIfAppUpdated];
}
#else
- (void)updateFirstSessionWith:(WKApplicationState)state {
  NSDate *date = [[NSDate alloc] init];
  [_logger logObj:[[NSString alloc]
                      initWithFormat:
                          @" interval since last close of app:  %f",
                          [date
                              timeIntervalSinceDate:
                                  [_defaults objectForKey:appHibernationDate]]]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];
  if ([date timeIntervalSinceDate:[_defaults objectForKey:appHibernationDate]] >
      30 * 60) {
    _isFirstEventOfSession = YES;
  } else {
    _isFirstEventOfSession = NO;
  }
  [self checkIfAppUpdated];
  [self fireSignal];
}
#endif

- (void)fireSignal {
  _isReady = YES;
  [_conditionUntilGetFNS signal];
  [_conditionUntilGetFNS unlock];
}

- (void)reset {
  sharedTracker = NULL;
  sharedTracker = [self init];
  _isReady = YES;
  [_defaults removeObjectForKey:isFirstEventOfApp];
  [_defaults synchronize];
  everID = [self getNewEverID];
}

- (void) checkIfAppUpdated {
    if (!_queue) {
        return;
    }
    if (MIEnvironment.appUpdated) {
        _isFirstEventOfSession = YES;
        MIActionEvent *updateEvent = [[MIActionEvent alloc] initWithName:@"webtrekk_ignore"];
        updateEvent.sessionParameters = [[MISessionParameters alloc] initWithParameters: @{@815:@"1"}];
        [self trackWithEvent: updateEvent];
    }
}

- (void)enqueueRequestForCustomEvent:(MITrackingEvent *)event {
    MIProperties *requestProperties = [self generateRequestProperties];
    requestProperties.locale = [NSLocale currentLocale];

    [requestProperties setIsFirstEventOfApp:_isFirstEventOpen];
    [requestProperties setIsFirstEventOfSession:_isFirstEventOfSession];
    [requestProperties setIsFirstEventAfterAppUpdate:NO];

    MIRequestTrackerBuilder *builder =
        [[MIRequestTrackerBuilder alloc] initWithConfoguration:self.config];

      MITrackerRequest *request =
        [builder createRequestWith:event andWith:requestProperties];
     [_requestUrlBuilder urlForRequest:request withCustomData:YES];
      MIRequest *r = [self->_requestUrlBuilder dbRequest];
      [r setStatus:ACTIVE];
      BOOL status = [[MIDatabaseManager shared] insertRequest:r];
      [_logger logObj:[NSString stringWithFormat: @"request written with success: %d", status] forDescription:kMappIntelligenceLogLevelDescriptionDebug];
    _isFirstEventOfSession = NO;
    _isFirstEventOpen = NO;
}

-(void) migrateData {
    NSString *legacyEID = [[MIDefaultTracker sharedDefaults] stringForKey:legacyEverId];
    if (legacyEID != nil) {
        [[MIDefaultTracker sharedDefaults] setValue:legacyEID forKey:everId];
    }
    if ([[MIDefaultTracker sharedDefaults] stringForKey:legacyIsFirstEventOfApp]) {
        [[MIDefaultTracker sharedDefaults] setBool:NO forKey:isFirstEventOfApp];
    }
}

@end

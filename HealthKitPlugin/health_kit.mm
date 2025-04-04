#import "health_kit.h"
#include <Foundation/NSDate.h>
#include <HealthKit/HealthKit.h>

HealthKit *HealthKit::instance = NULL;
std::map<String, int> period_steps;

int today_steps = 0;
int total_steps = 0;

void HealthKit::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_today_steps_query"), &HealthKit::run_today_steps_walked_query);
    ClassDB::bind_method(D_METHOD("run_total_steps_query"), &HealthKit::run_total_steps_walked_query);
    ClassDB::bind_method(D_METHOD("run_period_steps_query", "days"), &HealthKit::run_period_steps_query);
    ClassDB::bind_method(D_METHOD("get_today_steps"), &HealthKit::get_today_steps);
    ClassDB::bind_method(D_METHOD("get_total_steps"), &HealthKit::get_total_steps);
    ClassDB::bind_method(D_METHOD("get_period_steps_dict"), &HealthKit::get_period_steps_dict);
}

HealthKit *HealthKit::get_singleton() {
    NSLog(@"Getting HealthKit Singleton");
    return instance;
}

HealthKit::HealthKit() {
    NSLog(@"In HealthKit constructor");
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    
    if (![HKHealthStore isHealthDataAvailable]) {
        NSLog(@"Health data is not available on this device");
        return;
    }
    
    HKHealthStore* store = [[HKHealthStore alloc] init];
    health_store = (void*)CFBridgingRetain(store);
    
    NSSet<HKSampleType*> *read_types = [NSSet setWithObject:
                                        [HKQuantityType quantityTypeForIdentifier: HKQuantityTypeIdentifierStepCount]];
    
    [store requestAuthorizationToShareTypes:NULL readTypes:read_types
                                completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"Health data authorization failed: %@", error);
            return;
        }
        NSLog(@"Health data authorization success");
        run_today_steps_walked_query();
        run_total_steps_walked_query();
    }];
}

int HealthKit::get_today_steps() {
    NSLog(@"In HealthKit get today walked");
    return today_steps;
}

int HealthKit::get_total_steps() {
    NSLog(@"In HealthKit get total steps walked");
    return total_steps;
}

void HealthKit::run_today_steps_walked_query() {
    if (!health_store) return;
    HKHealthStore* store = (__bridge HKHealthStore*)health_store;

    HKQuantityType *type = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    NSDate *today = [NSDate date];
    
    NSDate *startOfDay = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] startOfDayForDate:[NSDate date]];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startOfDay endDate:today options:HKQueryOptionStrictStartDate];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc]
                                initWithQuantityType:type quantitySamplePredicate:predicate
                                options:HKStatisticsOptionCumulativeSum
                                completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
        
        if (error != nil) {
            NSLog(@"Error with today's steps: %@", error);
        } else {
            double steps = [[result sumQuantity] doubleValueForUnit:[HKUnit countUnit]];
            NSLog(@"Today's steps: %f", steps);
            today_steps = steps;
        }
    }];
    
    [store executeQuery:query];
}

void HealthKit::run_total_steps_walked_query() {
    if (!health_store) return;
    HKHealthStore* store = (__bridge HKHealthStore*)health_store;

    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setDay:1]; // Monday
    [components setMonth:1]; // May
    [components setYear:2024];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    [components setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    
    NSDate *start = [calendar dateFromComponents:components];
    NSDate *end = [NSDate date];
    
    HKQuantityType *type = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:start endDate:end options:HKQueryOptionStrictStartDate];

    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:type quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
        
        if (error != nil) {
            NSLog(@"Error with total steps: %@", error);
        } else {
            double steps = [[result sumQuantity] doubleValueForUnit:[HKUnit countUnit]];
            NSLog(@"Total steps since epoch %f", steps);
            total_steps = steps;
        }
    }];
    
    [store executeQuery:query];
}

void HealthKit::run_period_steps_query(int days) {
    if (!health_store) return;
    HKHealthStore* store = (__bridge HKHealthStore*)health_store;

    HKQuantityType *type = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];

    NSDate *startDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-days toDate:now options:0];
    startDate = [calendar startOfDayForDate:startDate];

    NSDate *anchorDate = [calendar startOfDayForDate:now];

    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:now options:HKQueryOptionStrictStartDate];

    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;

    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc]
                                          initWithQuantityType:type
                                          quantitySamplePredicate:predicate
                                          options:HKStatisticsOptionCumulativeSum
                                          anchorDate:anchorDate
                                          intervalComponents:interval];

    query.initialResultsHandler = ^(HKStatisticsCollectionQuery * _Nonnull query, HKStatisticsCollection * _Nullable results, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error fetching steps for past %d days: %@", days, error);
            return;
        }

        period_steps.clear();

        [results enumerateStatisticsFromDate:startDate toDate:now withBlock:^(HKStatistics * _Nonnull statistics, BOOL * _Nonnull stop) {
            if (statistics.sumQuantity) {
                double steps = [statistics.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyy-MM-dd"];
                NSString *dateStr = [formatter stringFromDate:statistics.startDate];
                period_steps[dateStr.UTF8String] = (int)steps;
            }
        }];

        for (const auto& entry : period_steps) {
            NSString *key = [NSString stringWithUTF8String:entry.first.utf8().get_data()];
            NSLog(@"Period steps entry: %@ -> %d", key, entry.second);
        }
    };

    [store executeQuery:query];
}

Dictionary HealthKit::get_period_steps_dict() {
    Dictionary steps_data;
    for (const auto& entry : period_steps) {
        steps_data[entry.first] = entry.second;
    }
    return steps_data;
}

HealthKit::~HealthKit() {
    if (health_store) {
        CFBridgingRelease(health_store);
        health_store = nullptr;
    }
    if (instance == this) {
        instance = nullptr;
    }
}

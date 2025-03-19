
#import "health_kit.h"
#include <Foundation/NSDate.h>
#include <HealthKit/HealthKit.h>

HealthKit *HealthKit::instance = NULL;
HKHealthStore *health_store = NULL;
std::map<String, int> monthly_steps;

int today_steps_walked = 0;
int total_steps_walked = 0;

void HealthKit::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_today_steps_query"), &HealthKit::run_today_steps_walked_query);
    ClassDB::bind_method(D_METHOD("run_total_steps_query"), &HealthKit::run_total_steps_walked_query);
    ClassDB::bind_method(D_METHOD("run_monthly_steps_query"), &HealthKit::run_monthly_steps_walked_query); // NEW
    ClassDB::bind_method(D_METHOD("get_today_steps_walked"), &HealthKit::get_today_steps_walked);
    ClassDB::bind_method(D_METHOD("get_total_steps_walked"), &HealthKit::get_total_steps_walked);
    ClassDB::bind_method(D_METHOD("get_monthly_steps_walked_dict"), &HealthKit::get_monthly_steps_walked_dict); // NEW
    ClassDB::bind_method(D_METHOD("get_monthly_steps_walked_array"), &HealthKit::get_monthly_steps_walked_array); // NEW
}

HealthKit *HealthKit::get_singleton() {
    NSLog(@"Getting HealthKit Singleton");
    return instance;
}

HealthKit::HealthKit() {
    NSLog(@"In HealthKit constructor");
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    health_store = [[HKHealthStore alloc] init];
    
    NSLog(@"Is health data available: %i", [HKHealthStore isHealthDataAvailable]);
    
    [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    // we read, but never update (share).
    NSSet<HKSampleType*> *read_types = [NSSet setWithObject:
                                        [HKQuantityType quantityTypeForIdentifier: HKQuantityTypeIdentifierStepCount]];
    
    
    [health_store requestAuthorizationToShareTypes:NULL readTypes:read_types
                                        completion:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"Is health data completion success: %i", success);
        run_today_steps_walked_query();
        run_total_steps_walked_query();
        run_monthly_steps_walked_query();
    }];
}

int HealthKit::get_today_steps_walked() {
    NSLog(@"In HealthKit get today walked");
    return today_steps_walked;
}

int HealthKit::get_total_steps_walked() {
    NSLog(@"In HealthKit get total steps walked");
    return total_steps_walked;
}


void HealthKit::run_today_steps_walked_query() {
    
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
            today_steps_walked = steps;
        }
    }];
    
    
    [health_store executeQuery:query];
}


// There's a Garden epoch - say 1/1/2024. All total steps are relative to that.
// Gardens and flowers are started at the step count since that epoch.
void HealthKit::run_total_steps_walked_query() {
    
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
            total_steps_walked = steps;
        }
    }];
    
    [health_store executeQuery:query];
}

void HealthKit::run_monthly_steps_walked_query() {
    HKQuantityType *type = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];

    NSDate *startDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-30 toDate:now options:0];
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
            NSLog(@"Error fetching monthly steps: %@", error);
            return;
        }

        monthly_steps.clear();

        [results enumerateStatisticsFromDate:startDate toDate:now withBlock:^(HKStatistics * _Nonnull statistics, BOOL * _Nonnull stop) {
            if (statistics.sumQuantity) {
                double steps = [statistics.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyy-MM-dd"];
                String dateStr = [NSString stringWithString:[formatter stringFromDate:statistics.startDate]].UTF8String;
                monthly_steps[dateStr] = (int)steps;
                NSLog(@"Steps on %@: %d", [formatter stringFromDate:statistics.startDate], (int)steps);
            }
        }];
    };

    [health_store executeQuery:query];
}

Dictionary HealthKit::get_monthly_steps_walked_dict() {
    Dictionary steps_data;
    for (const auto& entry : monthly_steps) {
        steps_data[entry.first] = entry.second;
    }
    return steps_data;
}

Array HealthKit::get_monthly_steps_walked_array() {
    Array steps_list;
    for (const auto& entry : monthly_steps) {
        steps_list.append(entry.second);
    }
    return steps_list;
}

HealthKit::~HealthKit() {
}

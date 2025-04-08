#ifndef IN_APP_STORE_H
#define IN_APP_STORE_H

#include "core/version.h"
#include "core/object/class_db.h"
#include <map>

class HealthKit : public Object {

    GDCLASS(HealthKit, Object);

    static HealthKit *instance;
    static void _bind_methods();

public:

    int get_today_steps();
    int get_total_steps();
    Dictionary get_period_steps_dict();

    void run_today_steps_walked_query();
    void run_total_steps_walked_query();
    void run_period_steps_query(int days);
    
    static HealthKit *get_singleton();

    HealthKit();
    ~HealthKit();
    
private:
    std::map<String, int> period_steps;
    void* health_store;
};

#endif

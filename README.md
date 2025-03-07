# A Godot plugin for health kit.

This only has the functionality that we need for one of Bodeville's upcoming
games. It's not a general HealthKit plugin. But we hope this will help somebody,
somewhere!

## Other useful reading:

Godot instructions on creating ios plugins:
- https://docs.godotengine.org/en/stable/tutorials/platform/ios/ios_plugin.html

The godot-ios-plugins repository, which has a lot of plugins but not health kit.
- https://github.com/godotengine/godot-ios-plugins

## Background

The Godot source is included as a submodule because we need to include the Godot
headers in the plugin. 

## How to build

1. Drop into the godot/ directory and build the thing either for debug or release.
   - cd godot
   - scons p=ios target=[template_debug,template_release]


2. Open HealthKitPlugin.xcodeproject.


3. Build the HealthKitPlugin in xcode for "any arm64 device". This will produce
   a file at Build/Products/Debug-iphoneos/libHealthKitPlugin.a or similar, depending
   on your build configuration.

   - NOTE: I've seen an error like this: `godot/core/typedefs.h:41:10 'platform_config.h' file not found`
     To fix it (and this is probably an awful hack) i've edited `core/typedefs.h` and changed this line:

     `- #include "platform_config.h"`

     `+ #include "platform/ios/platform_config.h"`


4. Copy libHealthKitPlugin.a into your godot project under res://ios/plugins


5. Also copy HealthKitPlugin.gdip (from the root of this repository) to res://ios/plugins


6. Now in godot, when you export to ios via Project -> Export, you should see an option
   for HealthKitPlugin in the Plugins section. Enabled that checkbox.


7. Write some godot code to use the plugin:


```
var health_kit;

func _ready():
	if Engine.has_singleton("HealthKit"):
		health_kit = Engine.get_singleton("HealthKit")
		check_steps_coroutine();
	
	else:
		print("iOS HealthKit plugin is not available on this platform.")
		

func check_steps_coroutine():
	while true:
		health_kit.run_today_steps_query();
		health_kit.run_total_steps_query();		
		await get_tree().create_timer(2).timeout
		var today:int = health_kit.get_today_steps_walked()
		print("Steps walked today: %d" % today)
		var total:int = health_kit.get_total_steps_walked()
		print("Total steps walked: %d" % total)
		await get_tree().create_timer(15).timeout
```

## Troubleshooting

- __`clang++: error: linker command failed with exit code 1`__

	When exporting a Godot project for iOS with the `HealthKitPlugin`, the linker command can fail with an `Undefined symbols for architecture arm64` error related to `ClassDB::bind_methodfi` and `Object::get_argument_options`. To bypass this error, try unchecking the "Export with Debug" option when choosing a folder to export your project.

	> __NOTE:__
	> The reason for the error is that plugin doesn't have separate versions for debug/release. Feel free to fork and submit a PR with improvements.


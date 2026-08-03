#import <UIKit/UIKit.h>

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"[ProfileCustomTweak] Loaded successfully");

    return %orig(application, launchOptions);
}

%end

%ctor {
    NSLog(@"[ProfileCustomTweak] Injected");
}

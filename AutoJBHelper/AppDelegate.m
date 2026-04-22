#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

// ============================================================
// Kiem tra phone co dang JB hay khong
// ============================================================
- (BOOL)isJailbroken {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:@"/var/jb/usr/bin/sh"]) return YES;
    if ([fm fileExistsAtPath:@"/var/jb/usr/bin/launchctl"]) return YES;
    if ([fm fileExistsAtPath:@"/var/jb/basebin"]) return YES;
    if ([fm fileExistsAtPath:@"/var/jb/Library/LaunchDaemons"]) return YES;
    
    FILE *f = fopen("/var/jb/usr/bin/sh", "r");
    if (f) {
        fclose(f);
        return YES;
    }
    
    return NO;
}

// ============================================================
// Mo app Dopamine qua URL scheme
// ============================================================
- (void)openDopamine {
    NSLog(@"[AutoJBHelper] Phone mat JB, dang mo Dopamine...");
    
    NSURL *url = [NSURL URLWithString:@"dopamine://"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"[AutoJBHelper] Mo Dopamine: %@", success ? @"OK" : @"FAIL");
    }];
}

// ============================================================
// Check va mo Dopamine neu mat JB
// ============================================================
- (void)checkAndOpenDopamine {
    if (![self isJailbroken]) {
        NSLog(@"[AutoJBHelper] Khong phat hien JB");
        [self openDopamine];
    } else {
        NSLog(@"[AutoJBHelper] Phone dang JB, khong can mo Dopamine");
    }
}

// ============================================================
// Background Task
// ============================================================
- (void)registerBackgroundTask {
    [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:@"com.atfarm.autojb.check"
                                                          usingQueue:nil
                                                       launchHandler:^(BGTask *task) {
        [self handleBackgroundTask:(BGAppRefreshTask *)task];
    }];
}

- (void)scheduleBackgroundTask {
    BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:@"com.atfarm.autojb.check"];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60];
    
    NSError *error = nil;
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
    if (error) {
        NSLog(@"[AutoJBHelper] Loi dang ky background task: %@", error);
    } else {
        NSLog(@"[AutoJBHelper] Da dang ky background task");
    }
}

- (void)handleBackgroundTask:(BGAppRefreshTask *)task {
    [self scheduleBackgroundTask];
    [self checkAndOpenDopamine];
    [task setTaskCompletedWithSuccess:YES];
}

// ============================================================
// App Lifecycle
// ============================================================
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AutoJBHelper] App launched");
    
    [self registerBackgroundTask];
    [self scheduleBackgroundTask];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self checkAndOpenDopamine];
    });
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor blackColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = @"AutoJB Helper";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:24];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.text = [self isJailbroken] ? @"Dang JB" : @"Khong JB";
    statusLabel.textColor = [self isJailbroken] ? [UIColor greenColor] : [UIColor redColor];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:18];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor constant:-30],
        [statusLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [statusLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:20],
    ]];
    
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"[AutoJBHelper] App became active");
    [self checkAndOpenDopamine];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self scheduleBackgroundTask];
}

@end

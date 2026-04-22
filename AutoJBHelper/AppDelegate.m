#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

// ============================================================
// Kiem tra phone co dang JB hay khong
// Cach kiem tra: check xem /var/jb/ co ton tai va co noi dung khong
// - Dang JB: /var/jb/ co mount, co bootstrap files
// - Mat JB: /var/jb/ khong ton tai hoac rong
// ============================================================
- (BOOL)isJailbroken {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Cach 1: Check /var/jb/usr/bin/ exist
    if ([fm fileExistsAtPath:@"/var/jb/usr/bin/sh"]) return YES;
    if ([fm fileExistsAtPath:@"/var/jb/usr/bin/launchctl"]) return YES;
    
    // Cach 2: Check bootstrap path
    if ([fm fileExistsAtPath:@"/var/jb/basebin"]) return YES;
    if ([fm fileExistsAtPath:@"/var/jb/Library/LaunchDaemons"]) return YES;
    
    // Cach 3: Dung fopen de check access
    FILE *f = fopen("/var/jb/usr/bin/sh", "r");
    if (f) {
        fclose(f);
        return YES;
    }
    
    return NO;
}

// ============================================================
// Mo app Dopamine
// URL scheme cua Dopamine: "dopamine://" (can verify)
// Hoac dung bundle identifier: com.opa334.Dopamine
// ============================================================
- (void)openDopamine {
    NSLog(@"[AutoJBHelper] Phone mat JB, dang mo Dopamine...");
    
    // Cach 1: URL scheme
    NSURL *url = [NSURL URLWithString:@"dopamine://"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            NSLog(@"[AutoJBHelper] Mo Dopamine: %@", success ? @"OK" : @"FAIL");
        }];
        return;
    }
    
    // Cach 2: Dung LSApplicationWorkspace (private API, TrollStore cho phep)
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if ([workspace respondsToSelector:openSelector]) {
            [workspace performSelector:openSelector withObject:@"com.opa334.Dopamine"];
            NSLog(@"[AutoJBHelper] Da mo Dopamine qua LSApplicationWorkspace");
        }
    }
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
// Dang ky Background Task
// iOS se goi background task moi 15+ phut (iOS quyet dinh)
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
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60]; // 15 phut
    
    NSError *error = nil;
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
    if (error) {
        NSLog(@"[AutoJBHelper] Loi dang ky background task: %@", error);
    } else {
        NSLog(@"[AutoJBHelper] Da dang ky background task");
    }
}

- (void)handleBackgroundTask:(BGAppRefreshTask *)task {
    // Schedule lan tiep theo
    [self scheduleBackgroundTask];
    
    // Check JB
    [self checkAndOpenDopamine];
    
    [task setTaskCompletedWithSuccess:YES];
}

// ============================================================
// App Lifecycle
// ============================================================
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AutoJBHelper] App launched");
    
    // Dang ky background task
    [self registerBackgroundTask];
    [self scheduleBackgroundTask];
    
    // Check ngay khi app mo
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self checkAndOpenDopamine];
    });
    
    // Setup UI toi gian
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
    statusLabel.text = [self isJailbroken] ? @"✓ Dang JB" : @"✗ Khong JB";
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

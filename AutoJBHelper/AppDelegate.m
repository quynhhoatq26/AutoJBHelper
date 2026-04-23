#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <sys/stat.h>
#import <spawn.h>
#import <sys/wait.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

// ============================================================
// Kiem tra JB bang posix_spawn
// ============================================================
- (BOOL)isJailbroken {
    pid_t pid;
    const char *args[] = {"/var/jb/usr/bin/uname", NULL};
    
    struct stat st;
    if (stat("/var/jb/usr/bin/uname", &st) != 0) {
        return NO;
    }
    
    int result = posix_spawn(&pid, "/var/jb/usr/bin/uname", NULL, NULL, 
                             (char * const *)args, NULL);
    
    if (result != 0) {
        return NO;
    }
    
    int status;
    waitpid(pid, &status, 0);
    
    return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

// ============================================================
// Mo Dopamine bang LSApplicationWorkspace (private API)
// ============================================================
- (void)openDopamine {
    NSLog(@"[AutoJBHelper] Phone mat JB, dang mo Dopamine...");
    
    Class LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
    if (!LSApplicationWorkspace) {
        NSLog(@"[AutoJBHelper] LSApplicationWorkspace khong ton tai");
        return;
    }
    
    // Lay defaultWorkspace
    id workspace = ((id(*)(Class, SEL))objc_msgSend)(LSApplicationWorkspace, 
                                                     @selector(defaultWorkspace));
    if (!workspace) {
        NSLog(@"[AutoJBHelper] Khong lay duoc defaultWorkspace");
        return;
    }
    
    // Goi openApplicationWithBundleID:
    SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if ([workspace respondsToSelector:selector]) {
        BOOL success = ((BOOL(*)(id, SEL, id))objc_msgSend)(workspace, selector, 
                                                             @"com.opa334.Dopamine");
        NSLog(@"[AutoJBHelper] Mo Dopamine qua LSApplicationWorkspace: %@", 
              success ? @"OK" : @"FAIL");
        
        if (success) return;
    }
    
    // Fallback: thu URL scheme
    NSURL *url = [NSURL URLWithString:@"dopamine://"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"[AutoJBHelper] Fallback URL scheme: %@", success ? @"OK" : @"FAIL");
    }];
}

// ============================================================
// Check va mo Dopamine neu mat JB
// ============================================================
- (void)checkAndOpenDopamine {
    if (![self isJailbroken]) {
        NSLog(@"[AutoJBHelper] Khong phat hien JB -> mo Dopamine");
        [self openDopamine];
    } else {
        NSLog(@"[AutoJBHelper] Phone dang JB, exit app");
        // Dang JB -> exit app sau 0.3s de AutoTouch tiep tuc
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            exit(0);
        });
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
    
    // Setup UI (chi hien vai giay roi exit)
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor blackColor];
    
    BOOL jb = [self isJailbroken];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = @"AutoJB Helper";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:24];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.text = jb ? @"Dang JB - Exit..." : @"Khong JB - Mo Dopamine...";
    statusLabel.textColor = jb ? [UIColor greenColor] : [UIColor redColor];
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
    
    // Check va xu ly sau 0.5s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self checkAndOpenDopamine];
    });
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"[AutoJBHelper] App became active");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self checkAndOpenDopamine];
    });
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self scheduleBackgroundTask];
}

@end

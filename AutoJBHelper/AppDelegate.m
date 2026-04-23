#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <sys/stat.h>
#import <spawn.h>
#import <sys/wait.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

// ============================================================
// Kiem tra phone co dang JB hay khong bang posix_spawn
// Chi khi JB, posix_spawn moi co the chay binary trong /var/jb/
// Khi mat JB, syscall se fail hoac binh thuong nhung khong co quyen thuc thi
// ============================================================
- (BOOL)isJailbroken {
    pid_t pid;
    // Chay /var/jb/usr/bin/uname - binary toi gian, exit ngay
    const char *args[] = {"/var/jb/usr/bin/uname", NULL};
    
    // File phai ton tai truoc
    struct stat st;
    if (stat("/var/jb/usr/bin/uname", &st) != 0) {
        return NO;  // File khong ton tai = mat JB chac chan
    }
    
    // Thu spawn binary
    int result = posix_spawn(&pid, "/var/jb/usr/bin/uname", NULL, NULL, 
                             (char * const *)args, NULL);
    
    if (result != 0) {
        // posix_spawn fail = khong chay duoc = mat JB
        return NO;
    }
    
    // Cho process exit
    int status;
    waitpid(pid, &status, 0);
    
    // Neu exit code = 0, process chay thanh cong = JB con hoat dong
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
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
    
    BOOL jb = [self isJailbroken];
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.text = jb ? @"Dang JB" : @"Khong JB";
    statusLabel.textColor = jb ? [UIColor greenColor] : [UIColor redColor];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:18];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:statusLabel];
    
    // Debug info
    UILabel *debugLabel = [[UILabel alloc] init];
    NSMutableString *debug = [NSMutableString string];
    
    // Test multiple binaries
    const char *binaries[] = {
        "/var/jb/usr/bin/uname",
        "/var/jb/bin/sh",
        "/var/jb/usr/bin/sh",
        "/var/jb/basebin/jbctl",
    };
    
    for (int i = 0; i < 4; i++) {
        struct stat st;
        int statResult = stat(binaries[i], &st);
        [debug appendFormat:@"stat %s: %d\n", binaries[i], statResult];
        
        if (statResult == 0) {
            pid_t pid;
            const char *args[] = {binaries[i], NULL};
            int spawn_result = posix_spawn(&pid, binaries[i], NULL, NULL, 
                                           (char * const *)args, NULL);
            [debug appendFormat:@" spawn: %d", spawn_result];
            if (spawn_result == 0) {
                int status;
                waitpid(pid, &status, 0);
                [debug appendFormat:@" exit: %d\n", WEXITSTATUS(status)];
            } else {
                [debug appendString:@"\n"];
            }
        }
    }
    
    debugLabel.text = debug;
    debugLabel.textColor = [UIColor whiteColor];
    debugLabel.textAlignment = NSTextAlignmentLeft;
    debugLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    debugLabel.numberOfLines = 0;
    debugLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:debugLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor constant:-100],
        [statusLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [statusLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:20],
        [debugLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [debugLabel.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:30],
        [debugLabel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:10],
        [debugLabel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-10],
    ]];
    
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self checkAndOpenDopamine];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self scheduleBackgroundTask];
}

@end

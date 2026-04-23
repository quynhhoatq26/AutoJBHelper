#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <sys/stat.h>
#import <sys/sysctl.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

// ============================================================
// Kiem tra phone co dang JB hay khong
// Cach moi: check process launchd_1 cua Dopamine co chay khong
// Khi JB: co process /var/jb/basebin/jbctl + launchd_1
// Khi mat JB: khong co process nay (du /var/jb/ folder van ton tai)
// ============================================================
- (BOOL)isJailbroken {
    // Cach 1: Check symlink /var/jb co mount point thuc khong
    // /var/jb/basebin la folder cua Dopamine, chi ton tai KHI mount active
    struct stat st;
    if (stat("/var/jb/basebin/jbctl", &st) == 0 && S_ISREG(st.st_mode)) {
        // File la regular file va accessible
        // Kiem tra them: file co the doc duoc khong
        FILE *f = fopen("/var/jb/basebin/jbctl", "r");
        if (f) {
            // Doc 4 bytes dau (magic number cua Mach-O)
            unsigned char magic[4];
            size_t n = fread(magic, 1, 4, f);
            fclose(f);
            if (n == 4 && magic[0] == 0xcf && magic[1] == 0xfa) {
                // Mach-O binary, phone dang JB that
                return YES;
            }
        }
    }
    
    // Cach 2: Check qua system call fork() - JB cho phep fork, mat JB thi fail
    // Can chu y: fork trong iOS app sandbox luon fail, khong dung
    
    // Cach 3: Check co process mobile_obliterator / launchd_1 khong
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    if (sysctl(mib, 3, NULL, &size, NULL, 0) == 0) {
        struct kinfo_proc *procs = malloc(size);
        if (sysctl(mib, 3, procs, &size, NULL, 0) == 0) {
            int count = size / sizeof(struct kinfo_proc);
            for (int i = 0; i < count; i++) {
                const char *name = procs[i].kp_proc.p_comm;
                if (strcmp(name, "launchd_1") == 0 || 
                    strcmp(name, "jbctl") == 0 ||
                    strcmp(name, "dopamined") == 0) {
                    free(procs);
                    return YES;
                }
            }
        }
        free(procs);
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
    
    BOOL jb = [self isJailbroken];
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.text = jb ? @"Dang JB" : @"Khong JB";
    statusLabel.textColor = jb ? [UIColor greenColor] : [UIColor redColor];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:18];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:statusLabel];
    
    // Debug: hien thi chi tiet
    UILabel *debugLabel = [[UILabel alloc] init];
    NSMutableString *debug = [NSMutableString string];
    
    // Check /var/jb/basebin/jbctl
    struct stat st;
    int statResult = stat("/var/jb/basebin/jbctl", &st);
    [debug appendFormat:@"stat jbctl: %d\n", statResult];
    
    if (statResult == 0) {
        FILE *f = fopen("/var/jb/basebin/jbctl", "r");
        if (f) {
            unsigned char magic[4];
            size_t n = fread(magic, 1, 4, f);
            fclose(f);
            [debug appendFormat:@"magic: %02x %02x %02x %02x (%zu bytes)\n", magic[0], magic[1], magic[2], magic[3], n];
        } else {
            [debug appendString:@"fopen FAIL\n"];
        }
    }
    
    // Count processes matching JB
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    int jbProcCount = 0;
    if (sysctl(mib, 3, NULL, &size, NULL, 0) == 0) {
        struct kinfo_proc *procs = malloc(size);
        if (sysctl(mib, 3, procs, &size, NULL, 0) == 0) {
            int count = size / sizeof(struct kinfo_proc);
            for (int i = 0; i < count; i++) {
                const char *name = procs[i].kp_proc.p_comm;
                if (strcmp(name, "launchd_1") == 0 || 
                    strcmp(name, "jbctl") == 0 ||
                    strcmp(name, "dopamined") == 0) {
                    jbProcCount++;
                }
            }
        }
        free(procs);
    }
    [debug appendFormat:@"JB procs: %d\n", jbProcCount];
    
    debugLabel.text = debug;
    debugLabel.textColor = [UIColor whiteColor];
    debugLabel.textAlignment = NSTextAlignmentCenter;
    debugLabel.font = [UIFont systemFontOfSize:12];
    debugLabel.numberOfLines = 0;
    debugLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:debugLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor constant:-60],
        [statusLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [statusLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:20],
        [debugLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [debugLabel.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:30],
        [debugLabel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [debugLabel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
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

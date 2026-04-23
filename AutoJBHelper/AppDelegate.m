#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <sys/stat.h>
#import <spawn.h>
#import <sys/wait.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

@interface AppDelegate ()
@property (strong, nonatomic) AVAudioPlayer *silentPlayer;
@property (strong, nonatomic) NSTimer *checkTimer;
@property (strong, nonatomic) NSMutableDictionary *lastForegroundTimes;
@end

@implementation AppDelegate

// ============================================================
// Target apps - 3 apps user thuong chay scripts tren
// ============================================================
- (NSArray<NSString *> *)targetApps {
    return @[
        @"com.facebook.Facebook",
        @"com.apple.mobilesafari",
        @"com.oecoway.friendlyLite"
    ];
}

// ============================================================
// Kiem tra JB bang posix_spawn (da verify 100% chinh xac)
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
// Lay app dang foreground (qua private API SpringBoardServices)
// Tra ve bundle ID hoac nil
// ============================================================
typedef NSString* (*SBSCopyFrontmostFunc)(void);

- (NSString *)frontmostAppBundleID {
    static SBSCopyFrontmostFunc SBSCopyFrontmost = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (handle) {
            SBSCopyFrontmost = (SBSCopyFrontmostFunc)dlsym(handle, "SBSCopyFrontmostApplicationDisplayIdentifier");
        }
    });
    
    if (SBSCopyFrontmost) {
        NSString *bundle = SBSCopyFrontmost();
        if (bundle) {
            return [bundle copy];
        }
    }
    
    return nil;
}

// ============================================================
// Cap nhat thoi gian foreground cua target apps
// ============================================================
- (void)updateForegroundTimes {
    if (!self.lastForegroundTimes) {
        self.lastForegroundTimes = [NSMutableDictionary dictionary];
    }
    
    NSString *front = [self frontmostAppBundleID];
    if (front && [[self targetApps] containsObject:front]) {
        self.lastForegroundTimes[front] = @([[NSDate date] timeIntervalSince1970]);
    }
}

// ============================================================
// Check: target app co dang foreground HOAC foreground trong 5 phut qua khong
// ============================================================
- (BOOL)targetAppActiveRecently {
    NSString *front = [self frontmostAppBundleID];
    
    if (front && [[self targetApps] containsObject:front]) {
        return YES;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSString *bundle in [self targetApps]) {
        NSNumber *lastTime = self.lastForegroundTimes[bundle];
        if (lastTime) {
            NSTimeInterval age = now - [lastTime doubleValue];
            if (age < 300) {
                return YES;
            }
        }
    }
    
    return NO;
}

// ============================================================
// Mo Dopamine bang LSApplicationWorkspace (private API)
// ============================================================
- (void)openDopamine {
    NSLog(@"[AutoJBHelper] *** MO DOPAMINE ***");
    
    Class LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
    if (!LSApplicationWorkspace) {
        return;
    }
    
    id workspace = ((id(*)(Class, SEL))objc_msgSend)(LSApplicationWorkspace, 
                                                     @selector(defaultWorkspace));
    if (!workspace) {
        return;
    }
    
    SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if ([workspace respondsToSelector:selector]) {
        ((BOOL(*)(id, SEL, id))objc_msgSend)(workspace, selector, 
                                             @"com.opa334.Dopamine");
    }
}

// ============================================================
// Main check - goi moi 30 giay
// ============================================================
- (void)periodicCheck {
    [self updateForegroundTimes];
    
    BOOL jb = [self isJailbroken];
    
    if (jb) {
        NSLog(@"[AutoJBHelper] Dang JB, skip");
        return;
    }
    
    BOOL targetActive = [self targetAppActiveRecently];
    
    if (targetActive) {
        NSLog(@"[AutoJBHelper] Mat JB NHUNG target app con active -> cho");
        return;
    }
    
    NSLog(@"[AutoJBHelper] Mat JB + target app khong active > 5 phut -> mo Dopamine");
    [self openDopamine];
}

// ============================================================
// Silent audio trick
// ============================================================
- (void)startSilentAudio {
    NSError *error = nil;
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&error];
    [session setActive:YES error:&error];
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"silent.wav"];
    [self generateSilentWav:path];
    
    NSURL *url = [NSURL fileURLWithPath:path];
    self.silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (self.silentPlayer) {
        self.silentPlayer.numberOfLoops = -1;
        self.silentPlayer.volume = 0.0;
        [self.silentPlayer play];
        NSLog(@"[AutoJBHelper] Silent audio started");
    } else {
        NSLog(@"[AutoJBHelper] Silent audio error: %@", error);
    }
}

- (void)generateSilentWav:(NSString *)path {
    uint32_t sampleRate = 44100;
    uint32_t numSamples = sampleRate;
    uint32_t dataSize = numSamples * 2;
    uint32_t fileSize = 36 + dataSize;
    
    NSMutableData *data = [NSMutableData data];
    
    [data appendBytes:"RIFF" length:4];
    [data appendBytes:&fileSize length:4];
    [data appendBytes:"WAVE" length:4];
    
    [data appendBytes:"fmt " length:4];
    uint32_t fmtSize = 16;
    uint16_t audioFormat = 1;
    uint16_t numChannels = 1;
    uint32_t byteRate = sampleRate * 2;
    uint16_t blockAlign = 2;
    uint16_t bitsPerSample = 16;
    [data appendBytes:&fmtSize length:4];
    [data appendBytes:&audioFormat length:2];
    [data appendBytes:&numChannels length:2];
    [data appendBytes:&sampleRate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bitsPerSample length:2];
    
    [data appendBytes:"data" length:4];
    [data appendBytes:&dataSize length:4];
    
    char silence[1024] = {0};
    for (uint32_t i = 0; i < dataSize; i += 1024) {
        uint32_t chunk = MIN(1024, dataSize - i);
        [data appendBytes:silence length:chunk];
    }
    
    [data writeToFile:path atomically:YES];
}

// ============================================================
// Tra ve app truoc do
// ============================================================
- (void)returnToPreviousApp {
    UIApplication *app = [UIApplication sharedApplication];
    SEL suspendSel = NSSelectorFromString(@"suspend");
    if ([app respondsToSelector:suspendSel]) {
        ((void(*)(id, SEL))objc_msgSend)(app, suspendSel);
    }
}

// ============================================================
// Background Task backup
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
    [self periodicCheck];
    [task setTaskCompletedWithSuccess:YES];
}

// ============================================================
// App Lifecycle
// ============================================================
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AutoJBHelper] App launched");
    
    self.lastForegroundTimes = [NSMutableDictionary dictionary];
    
    [self registerBackgroundTask];
    [self scheduleBackgroundTask];
    
    [self startSilentAudio];
    
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
    statusLabel.text = @"Chay ngam - Co the back";
    statusLabel.textColor = [UIColor greenColor];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:16];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:statusLabel];
    
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"App se chay ngam va check moi 30s.\nKhi dang JB: khong lam gi.\nKhi mat JB + 3 target app\nkhong active >5 phut: mo Dopamine.";
    hintLabel.textColor = [UIColor lightGrayColor];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.numberOfLines = 0;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:hintLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor constant:-50],
        [statusLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [statusLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:15],
        [hintLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [hintLabel.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:30],
        [hintLabel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [hintLabel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
    ]];
    
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                       target:self
                                                     selector:@selector(periodicCheck)
                                                     userInfo:nil
                                                      repeats:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self periodicCheck];
    });
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"[AutoJBHelper] App became active");
    
    BOOL jb = [self isJailbroken];
    if (jb) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self returnToPreviousApp];
        });
    } else {
        [self openDopamine];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self scheduleBackgroundTask];
}

@end

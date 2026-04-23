#import "AppDelegate.h"
#import <UIKit/UIKit.h>
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
// Mo Dopamine bang LSApplicationWorkspace
// ============================================================
- (void)openDopamine {
    NSLog(@"[AutoJBHelper] Mat JB -> mo Dopamine");
    
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
// App Lifecycle
// ============================================================
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AutoJBHelper] App launched");
    
    // UI don gian
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
    statusLabel.text = jb ? @"Dang JB" : @"Mat JB - Mo Dopamine...";
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
    
    // Neu mat JB -> mo Dopamine sau 0.5s
    if (!jb) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self openDopamine];
        });
    }
    // Neu dang JB -> khong lam gi, giu nguyen UI (user tu tat hoac phim tat khong mo)
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Khi app reactivate, check lai
    BOOL jb = [self isJailbroken];
    if (!jb) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self openDopamine];
        });
    }
}

@end

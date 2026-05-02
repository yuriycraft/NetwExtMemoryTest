#import "PacketTunnelProvider.h"
#import "MemoryMonitor.h"

@interface PacketTunnelProvider ()
@property (nonatomic, strong) NSTimer *memoryReportTimer;
@property (nonatomic, assign) BOOL isStressTesting;
@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    NSLog(@"🚀 PacketTunnelExtension STARTING");
    
    // Проверка entitlements
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *bundleId = bundle.bundleIdentifier;
    NSLog(@"📦 Extension Bundle ID: %@", bundleId);
    
    __weak typeof(self) weakSelf = self;
    [MemoryMonitor shared].onPressureChange = ^(MemoryPressureLevel level) {
        switch (level) {
            case MemoryPressureLevelWarning:
                NSLog(@"⚠️ [EXTENSION] WARNING - Memory pressure!");
                [weakSelf handleMemoryWarning];
                break;
            case MemoryPressureLevelCritical:
                NSLog(@"💀 [EXTENSION] CRITICAL - Emergency cleanup!");
                [weakSelf handleMemoryCritical];
                break;
            default:
                break;
        }
    };
    
    [[MemoryMonitor shared] startMonitoringWithIdentifier:@"🔌 EXTENSION"];
    
    // Базовые сетевые настройки
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.0.0.1"]
                                                                subnetMasks:@[@"255.255.255.0"]];
    NEIPv4Route *defaultRoute = [NEIPv4Route defaultRoute];
    ipv4Settings.includedRoutes = @[defaultRoute];
    
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"10.0.0.2"];
    settings.IPv4Settings = ipv4Settings;
    
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"❌ Failed to set network settings: %@", error);
            completionHandler(error);
        } else {
            NSLog(@"✅ Network settings configured successfully");
            completionHandler(nil);
            [weakSelf startMemoryReporting];
        }
    }];
}

- (void)handleMemoryWarning {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    if (self.isStressTesting) {
        NSLog(@"🧹 Cleaning up extension memory...");
        [[MemoryMonitor shared] releaseAllMemory];
        self.isStressTesting = NO;
    }
}

- (void)handleMemoryCritical {
//    [[MemoryMonitor shared] releaseAllMemory];
// к   self.isStressTesting = NO;
}

- (void)startMemoryReporting {
    self.memoryReportTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                              target:self
                                                            selector:@selector(reportMemoryUsage)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)reportMemoryUsage {
    uint64_t usage = [[MemoryMonitor shared] getCurrentMemoryUsage];
    float usageMB = usage / 1024.0 / 1024.0;
    NSLog(@"📊 [EXTENSION] Current memory: %.2f MB / 50 MB limit", usageMB);
    
    if (usageMB > 45) {
        NSLog(@"⚠️ [EXTENSION] Above 45 MB! Cleanup needed.");
    }
}

- (void)startStressTest {
    self.isStressTesting = YES;
    NSLog(@"🔥 [EXTENSION] Starting STRESS TEST - allocating 5 MB chunks");
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 1; i <= 15; i++) {
            if (!weakSelf.isStressTesting) break;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[MemoryMonitor shared]  allocateMemoryWithRandomImages:1 ofSize: 5];
            });
            
            sleep(1);
        }
    });
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    NSLog(@"🛑 PacketTunnelExtension STOPPING. Reason: %ld", (long)reason);
    
    [self.memoryReportTimer invalidate];
    self.memoryReportTimer = nil;
    
    [[MemoryMonitor shared] stopMonitoring];
    completionHandler();
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *message = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    NSLog(@"📨 Received app message: %@", message);
    
    if ([message isEqualToString:@"START_STRESS"]) {
        [self startStressTest];
        NSData *response = [@"STRESS_STARTED" dataUsingEncoding:NSUTF8StringEncoding];
        completionHandler(response);
    } else if ([message isEqualToString:@"STOP_STRESS"]) {
        self.isStressTesting = NO;
        [[MemoryMonitor shared] releaseAllMemory];
        NSData *response = [@"STRESS_STOPPED" dataUsingEncoding:NSUTF8StringEncoding];
        completionHandler(response);
    } else if ([message isEqualToString:@"GET_MEMORY"]) {
        uint64_t usage = [[MemoryMonitor shared] getCurrentMemoryUsage];
        NSString *responseStr = [NSString stringWithFormat:@"MEMORY:%.2f MB", usage / 1024.0 / 1024.0];
        NSData *response = [responseStr dataUsingEncoding:NSUTF8StringEncoding];
        completionHandler(response);
    } else {
        completionHandler(nil);
    }
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    NSLog(@"😴 Extension going to sleep");
    completionHandler();
}

- (void)wake {
    NSLog(@"⏰ Extension waking up");
}

@end

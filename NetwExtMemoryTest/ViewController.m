#import "ViewController.h"
#import "MemoryMonitor.h"
#import <NetworkExtension/NetworkExtension.h>

@interface ViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UIProgressView *memoryProgress;
@property (nonatomic, strong) UIStepper *stepper;
@property (nonatomic, strong) UILabel *stepperLabel;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, assign) NSUInteger allocSize;
@property (nonatomic, strong) NSMutableString *logBuffer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Memory Stress Test";
    self.allocSize = 10;
    self.logBuffer = [NSMutableString string];
    
    [self setupUI];
    [self setupMemoryMonitor];
    [self startMemoryUpdates];
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 20;
    self.stackView.layoutMargins = UIEdgeInsetsMake(20, 20, 20, 20);
    self.stackView.layoutMarginsRelativeArrangement = YES;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];
    
    // Status Label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"✅ Normal";
    self.statusLabel.textColor = [UIColor systemGreenColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:24];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.stackView addArrangedSubview:self.statusLabel];
    
    // Memory Label
    self.memoryLabel = [[UILabel alloc] init];
    self.memoryLabel.text = @"Memory: 0.00 MB";
    self.memoryLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightMedium];
    self.memoryLabel.textAlignment = NSTextAlignmentCenter;
    [self.stackView addArrangedSubview:self.memoryLabel];
    
    // Memory Progress
    self.memoryProgress = [[UIProgressView alloc] init];
    self.memoryProgress.progressTintColor = [UIColor systemBlueColor];
    self.memoryProgress.trackTintColor = [UIColor systemGray5Color];
    self.memoryProgress.progress = 0;
    [self.stackView addArrangedSubview:self.memoryProgress];
    
    // Separator
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor systemGray4Color];
    [separator.heightAnchor constraintEqualToConstant:1].active = YES;
    [self.stackView addArrangedSubview:separator];
    
    // Stepper Control
    UILabel *stepperTitle = [[UILabel alloc] init];
    stepperTitle.text = @"Allocation Size:";
    stepperTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [self.stackView addArrangedSubview:stepperTitle];
    
    UIStackView *stepperRow = [[UIStackView alloc] init];
    stepperRow.axis = UILayoutConstraintAxisHorizontal;
    stepperRow.spacing = 20;
    stepperRow.distribution = UIStackViewDistributionFillEqually;
    
    self.stepperLabel = [[UILabel alloc] init];
    self.stepperLabel.text = @"10 MB";
    self.stepperLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightMedium];
    self.stepperLabel.textAlignment = NSTextAlignmentCenter;
    
    self.stepper = [[UIStepper alloc] init];
    self.stepper.minimumValue = 1;
    self.stepper.maximumValue = 50;
    self.stepper.value = 10;
    self.stepper.stepValue = 1;
    [self.stepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
    
    [stepperRow addArrangedSubview:self.stepperLabel];
    [stepperRow addArrangedSubview:self.stepper];
    [self.stackView addArrangedSubview:stepperRow];
    
    // Action Buttons
    NSArray *buttons = @[
//        @{@"title": @"🚀 Allocate", @"color": UIColor.systemBlueColor, @"action": @"allocateButtonTapped"},
//        @{@"title": @"🧹 Release All", @"color": UIColor.systemOrangeColor, @"action": @"releaseButtonTapped"},
//        @{@"title": @"🔥 Stress Test (APP)", @"color": UIColor.systemRedColor, @"action": @"stressTestTapped"},
        @{@"title": @"🔧 Create VPN", @"color": UIColor.systemTealColor, @"action": @"createVPNConfiguration"},
        @{@"title": @"🔌 Connect VPN", @"color": UIColor.systemIndigoColor, @"action": @"connectVPN"},
        @{@"title": @"🗑 Delete VPN", @"color": UIColor.systemGrayColor, @"action": @"deleteVPNConfiguration"},
        @{@"title": @"📡 Query Extension", @"color": UIColor.systemGreenColor, @"action": @"queryExtensionTapped"},
        @{@"title": @"🔥 Stress Extension", @"color": UIColor.systemPurpleColor, @"action": @"stressExtensionTapped"}
    ];
    
    for (NSDictionary *btnInfo in buttons) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:btnInfo[@"title"] forState:UIControlStateNormal];
        button.backgroundColor = btnInfo[@"color"];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        button.layer.cornerRadius = 8;
        button.contentEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
        [button addTarget:self action:NSSelectorFromString(btnInfo[@"action"]) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:button];
    }
    
    // Log TextView
    UILabel *logTitle = [[UILabel alloc] init];
    logTitle.text = @"📋 Event Log:";
    logTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [self.stackView addArrangedSubview:logTitle];
    
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logTextView.backgroundColor = [UIColor systemGray6Color];
    self.logTextView.layer.cornerRadius = 8;
    self.logTextView.editable = NO;
    self.logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [self.stackView addArrangedSubview:self.logTextView];
    [self.logTextView.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
}

- (void)setupMemoryMonitor {
    __weak typeof(self) weakSelf = self;
    [MemoryMonitor shared].onPressureChange = ^(MemoryPressureLevel level) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (level) {
                case MemoryPressureLevelWarning:
                    weakSelf.statusLabel.text = @"⚠️ WARNING - Clean up!";
                    weakSelf.statusLabel.textColor = [UIColor systemOrangeColor];
                    [weakSelf addLog:@"⚠️ APP received WARNING pressure"];
                    break;
                case MemoryPressureLevelCritical:
                    weakSelf.statusLabel.text = @"💀 CRITICAL - Emergency cleanup!";
                    weakSelf.statusLabel.textColor = [UIColor systemRedColor];
                    [weakSelf addLog:@"💀 APP received CRITICAL pressure"];
                    break;
                default:
                    weakSelf.statusLabel.text = @"✅ Normal";
                    weakSelf.statusLabel.textColor = [UIColor systemGreenColor];
                    break;
            }
        });
    };
    
    [[MemoryMonitor shared] startMonitoringWithIdentifier:@"📱 APP"];
    [self addLog:@"✅ APP memory monitor started"];
}

- (void)startMemoryUpdates {
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateMemoryDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateMemoryDisplay {
    uint64_t usage = [[MemoryMonitor shared] getCurrentMemoryUsage];
    float usageMB = usage / 1024.0 / 1024.0;
    
    self.memoryLabel.text = [NSString stringWithFormat:@"Memory: %.2f MB", usageMB];
    
    float progress = MIN(usageMB / 500.0, 1.0);
    [self.memoryProgress setProgress:progress animated:YES];
    
    if (usageMB > 300) {
        self.memoryProgress.progressTintColor = [UIColor systemOrangeColor];
    } else if (usageMB > 500) {
        self.memoryProgress.progressTintColor = [UIColor systemRedColor];
    } else {
        self.memoryProgress.progressTintColor = [UIColor systemBlueColor];
    }
}

- (void)addLog:(NSString *)message {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logBuffer appendFormat:@"[%@] %@\n", timestamp, message];
        self.logTextView.text = self.logBuffer;
        
        NSRange range = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:range];
    });
}

- (void)allocateButtonTapped {
    [self addLog:[NSString stringWithFormat:@"🚀 Allocating %lu MB in APP", (unsigned long)self.allocSize]];
    [MemoryMonitor shared].isUnderStress = YES;
    [[MemoryMonitor shared] allocateMemory:self.allocSize];
}

- (void)releaseButtonTapped {
    [self addLog:@"🧹 Manually releasing memory in APP"];
    [[MemoryMonitor shared] releaseAllMemory];
}

- (void)stepperChanged:(UIStepper *)sender {
    self.allocSize = (NSUInteger)sender.value;
    self.stepperLabel.text = [NSString stringWithFormat:@"%lu MB", (unsigned long)self.allocSize];
}

- (void)stressTestTapped {
    [self addLog:@"🔥 Starting STRESS TEST in APP - will allocate until killed"];
    [MemoryMonitor shared].isUnderStress = YES;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 1; i <= 20; i++) {
            NSUInteger size = i * 10;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf addLog:[NSString stringWithFormat:@"📊 Allocating %lu MB (total: %d MB)", (unsigned long)size, i * 10]];
            });
            
            [[MemoryMonitor shared] allocateMemory:size];
            sleep(1);
        }
    });
}

#pragma mark - VPN Management

- (void)createVPNConfiguration {
    [self addLog:@"🔧 Creating VPN configuration..."];
    
    NETunnelProviderManager *manager = [[NETunnelProviderManager alloc] init];
    
    NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
    protocol.providerBundleIdentifier = @"YC.NetwExtMemoryTest.PacketTunnelOBJ-C";
    protocol.serverAddress = @"127.0.0.1";
    protocol.username = @"test";
    
    manager.protocolConfiguration = protocol;
    manager.localizedDescription = @"Memory Stress Test VPN";
    manager.enabled = YES;  // Важно: включаем конфигурацию
    
    [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self addLog:[NSString stringWithFormat:@"❌ Failed to save config: %@", error.localizedDescription]];
            } else {
                [self addLog:@"✅ VPN configuration created successfully!"];
                [self addLog:@"💡 Tap 'Connect VPN' to start"];
                
                // Дополнительная загрузка для активации
                [manager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
                    if (!loadError) {
                        [self addLog:@"✅ Configuration loaded and ready"];
                    }
                }];
            }
        });
    }];
}

- (void)connectVPN {
    [self addLog:@"🔌 Connecting to VPN..."];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:[NSString stringWithFormat:@"❌ Load error: %@", error.localizedDescription]];
            });
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject;
        if (!manager) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"❌ No configuration found. Create it first with 'Create VPN' button!"];
            });
            return;
        }
        
        // Важно: Дважды загружаем конфигурацию
        [manager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
            if (loadError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self addLog:[NSString stringWithFormat:@"❌ First load error: %@", loadError.localizedDescription]];
                });
                return;
            }
            
            // Вторая загрузка - workaround для ошибки NEVPNErrorDomain error 2
            [manager loadFromPreferencesWithCompletionHandler:^(NSError *secondLoadError) {
                if (secondLoadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addLog:[NSString stringWithFormat:@"❌ Second load error: %@", secondLoadError.localizedDescription]];
                    });
                    return;
                }
                
                // Убеждаемся, что конфигурация включена
                manager.enabled = YES;
                
                [manager saveToPreferencesWithCompletionHandler:^(NSError *saveError) {
                    if (saveError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self addLog:[NSString stringWithFormat:@"❌ Save error: %@", saveError.localizedDescription]];
                        });
                        return;
                    }
                    
                    NETunnelProviderSession *session = (NETunnelProviderSession *)manager.connection;
                    NSError *startError;
                    [session startTunnelWithOptions:nil andReturnError:&startError];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (startError) {
                            [self addLog:[NSString stringWithFormat:@"❌ Start error: %@", startError.localizedDescription]];
                        } else {
                            [self addLog:@"✅ VPN connecting... Check extension logs for memory events"];
                        }
                    });
                }];
            }];
        }];
    }];
}

- (void)deleteVPNConfiguration {
    [self addLog:@"🗑 Deleting VPN configuration..."];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error || !managers.firstObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"❌ No configuration to delete"];
            });
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject;
        [manager removeFromPreferencesWithCompletionHandler:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self addLog:[NSString stringWithFormat:@"❌ Delete error: %@", error.localizedDescription]];
                } else {
                    [self addLog:@"✅ VPN configuration deleted"];
                }
            });
        }];
    }];
}

#pragma mark - Extension Communication

- (void)queryExtensionTapped {
    [self addLog:@"📡 Querying extension for memory usage..."];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:[NSString stringWithFormat:@"❌ Load error: %@", error.localizedDescription]];
            });
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject;
        if (!manager) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"❌ No VPN configuration found. Tap 'Create VPN' first!"];
            });
            return;
        }
        
        // Важно: Дважды загружаем конфигурацию перед использованием
        [manager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
            if (loadError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self addLog:[NSString stringWithFormat:@"❌ Load error: %@", loadError.localizedDescription]];
                });
                return;
            }
            
            NETunnelProviderSession *session = (NETunnelProviderSession *)manager.connection;
            
            if (session.status != NEVPNStatusConnected) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self addLog:@"⚠️ VPN not connected. Tap 'Connect VPN' first"];
                });
                return;
            }
            
            [self sendGetMemoryMessage:session];
        }];
    }];
}

- (void)sendGetMemoryMessage:(NETunnelProviderSession *)session {
    NSData *message = [@"GET_MEMORY" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *sendError = nil;
    
    BOOL success = [session sendProviderMessage:message
                                    returnError:&sendError
                                responseHandler:^(NSData * _Nullable responseData) {
        if (responseData) {
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:[NSString stringWithFormat:@"📨 Extension: %@", response]];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"⚠️ No response from extension (timeout)"];
            });
        }
    }];
    
    if (!success || sendError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addLog:[NSString stringWithFormat:@"❌ Send error: %@", sendError.localizedDescription]];
        });
    }
}

- (void)stressExtensionTapped {
    [self addLog:@"🔥 Sending stress command to extension..."];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error || !managers.firstObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"❌ No VPN configuration found. Tap 'Create VPN' first!"];
            });
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject;
        
        // Двойная загрузка конфигурации (важно!)
        [manager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
            if (loadError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self addLog:[NSString stringWithFormat:@"❌ Load error: %@", loadError.localizedDescription]];
                });
                return;
            }
            
            // Вторая загрузка - это известный workaround для iOS
            [manager loadFromPreferencesWithCompletionHandler:^(NSError *secondLoadError) {
                if (secondLoadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addLog:[NSString stringWithFormat:@"❌ Second load error: %@", secondLoadError.localizedDescription]];
                    });
                    return;
                }
                
                NETunnelProviderSession *session = (NETunnelProviderSession *)manager.connection;
                
                if (session.status != NEVPNStatusConnected) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addLog:@"⚠️ VPN not connected. Tap 'Connect VPN' first"];
                    });
                    return;
                }
                
                [self sendStressCommand:session];
            }];
        }];
    }];
}

- (void)sendStressCommand:(NETunnelProviderSession *)session {
    NSData *message = [@"START_STRESS" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *sendError = nil;
    
    BOOL success = [session sendProviderMessage:message
                                    returnError:&sendError
                                responseHandler:^(NSData * _Nullable responseData) {
        if (responseData) {
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:[NSString stringWithFormat:@"📨 Extension: %@", response]];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addLog:@"⚠️ No response from extension"];
            });
        }
    }];
    
    if (!success || sendError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addLog:[NSString stringWithFormat:@"❌ Send error: %@", sendError.localizedDescription]];
        });
    }
}

- (void)dealloc {
    [self.updateTimer invalidate];
    [[MemoryMonitor shared] stopMonitoring];
}

@end

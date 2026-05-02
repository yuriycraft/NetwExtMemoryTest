#import "MemoryMonitor.h"
#import <mach/mach.h>
#import <dispatch/dispatch.h>

@interface MemoryMonitor ()
@property (nonatomic, assign) dispatch_source_t memorySource;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) NSMutableArray<NSData *> *memoryBlocks;      // Для FF-данных
@property (nonatomic, strong) NSMutableArray<UIImage *> *imageBlocks;     // Для реальных изображений
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDataBlocks;  // Для сырых данных изображений
@property (nonatomic, strong) NSString *monitorIdentifier;
@end

@implementation MemoryMonitor

+ (instancetype)shared {
    static MemoryMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.memoryBlocks = [NSMutableArray array];
        instance.imageBlocks = [NSMutableArray array];
        instance.imageDataBlocks = [NSMutableArray array];
        instance.isMonitoring = NO;
    });
    return instance;
}

- (void)startMonitoringWithIdentifier:(NSString *)identifier {
    if (self.isMonitoring) {
        NSLog(@"📊 [%@] Already monitoring", identifier);
        return;
    }
    
    self.monitorIdentifier = identifier;
    
    dispatch_source_t source = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_MEMORYPRESSURE,
        0,
        DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );
    
    if (!source) {
        NSLog(@"❌ [%@] Failed to create memory pressure source", identifier);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(source, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        dispatch_source_memorypressure_flags_t flags = dispatch_source_get_data(source);
        MemoryPressureLevel level;
        NSString *levelStr;
        
        switch (flags) {
            case DISPATCH_MEMORYPRESSURE_WARN:
                level = MemoryPressureLevelWarning;
                levelStr = @"⚠️ WARNING";
                break;
            case DISPATCH_MEMORYPRESSURE_CRITICAL:
                level = MemoryPressureLevelCritical;
                levelStr = @"💀 CRITICAL";
                break;
            case DISPATCH_MEMORYPRESSURE_NORMAL:
                level = MemoryPressureLevelNormal;
                levelStr = @"✅ NORMAL";
                break;
            default:
                level = MemoryPressureLevelUnknown;
                levelStr = @"❓ UNKNOWN";
                break;
        }
        
        uint64_t memoryUsage = [strongSelf getCurrentMemoryUsage];
        float memoryMB = memoryUsage / 1024.0 / 1024.0;
        
        NSLog(@"🔔 [%@] %@ - Memory usage: %.2f MB",
              strongSelf.monitorIdentifier, levelStr, memoryMB);
        
        if (strongSelf.onPressureChange) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.onPressureChange(level);
            });
        }
        
        if (level == MemoryPressureLevelCritical && strongSelf.isUnderStress) {
            NSLog(@"💀 [%@] CRITICAL - Auto releasing memory!", strongSelf.monitorIdentifier);
            [strongSelf releaseAllMemory];
        }
    });
    
    dispatch_source_set_cancel_handler(source, ^{
        NSLog(@"🛑 [%@] Memory monitoring stopped", identifier);
    });
    
    self.memorySource = source;
    dispatch_resume(source);
    self.isMonitoring = YES;
    
    uint64_t initialMemory = [self getCurrentMemoryUsage];
    NSLog(@"✅ [%@] Memory monitoring started. Initial usage: %.2f MB",
          identifier, initialMemory / 1024.0 / 1024.0);
}

- (void)stopMonitoring {
    if (self.memorySource) {
        dispatch_source_cancel(self.memorySource);
        self.memorySource = nil;
    }
    self.isMonitoring = NO;
    [self releaseAllMemory];
}

- (uint64_t)getCurrentMemoryUsage {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    }
    return 0;
}

#pragma mark - Старый метод (заполнение 0xFF)

- (void)allocateMemory:(NSUInteger)megabytes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger chunkSize = 1024 * 1024;
        
        for (NSUInteger i = 0; i < megabytes; i++) {
            @autoreleasepool {
                NSMutableData *data = [NSMutableData dataWithLength:chunkSize];
                memset((void *)[data mutableBytes], 0xFF, chunkSize);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.memoryBlocks addObject:data];
                    
                    uint64_t currentUsage = [self getCurrentMemoryUsage];
                    float currentMB = currentUsage / 1024.0 / 1024.0;
                    
                    NSLog(@"📈 [%@] [FF] Allocated %lu MB. Total FF blocks: %lu. Current usage: %.2f MB",
                          self.monitorIdentifier, (unsigned long)megabytes,
                          (unsigned long)self.memoryBlocks.count, currentMB);
                });
                
                usleep(5000);
            }
        }
    });
}

#pragma mark - Новые методы с реальными изображениями

- (UIImage *)generateTestImageOfSize:(NSUInteger)megabytes {
    // Рассчитываем размеры для получения нужного объёма в памяти
    // Для RGB изображения: ширина * высота * 4 байта (RGBA) ≈ размер в байтах
    NSUInteger targetBytes = megabytes * 1024 * 1024;
    NSUInteger pixelsCount = targetBytes / 4; // 4 байта на пиксель
    NSUInteger size = (NSUInteger)sqrt(pixelsCount);
    
    CGSize imageSize = CGSizeMake(size, size);
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1.0);
    
    // Рисуем градиент или случайные цвета
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Заливаем случайным цветом
    CGFloat red = (CGFloat)(arc4random_uniform(256)) / 255.0;
    CGFloat green = (CGFloat)(arc4random_uniform(256)) / 255.0;
    CGFloat blue = (CGFloat)(arc4random_uniform(256)) / 255.0;
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:red green:green blue:blue alpha:1.0].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    
    // Рисуем случайные круги
    for (int i = 0; i < 100; i++) {
        CGFloat x = (CGFloat)(arc4random_uniform((uint32_t)imageSize.width));
        CGFloat y = (CGFloat)(arc4random_uniform((uint32_t)imageSize.height));
        CGFloat radius = (CGFloat)(arc4random_uniform(50)) + 10;
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(x - radius, y - radius, radius * 2, radius * 2));
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)allocateMemoryWithRealImages:(NSUInteger)megabytes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            UIImage *image = [self generateTestImageOfSize:megabytes];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.imageBlocks addObject:image];
                
                uint64_t currentUsage = [self getCurrentMemoryUsage];
                float currentMB = currentUsage / 1024.0 / 1024.0;
                
                NSLog(@"🎨 [%@] [IMAGE] Allocated image ~%lu MB. Total images: %lu. Current usage: %.2f MB",
                      self.monitorIdentifier, (unsigned long)megabytes,
                      (unsigned long)self.imageBlocks.count, currentMB);
            });
        }
    });
}

- (void)allocateMemoryWithRandomImages:(NSUInteger)count ofSize:(NSUInteger)megabytesEach {
    NSLog(@"🎨 [%@] Generating %lu images of ~%lu MB each...",
          self.monitorIdentifier, (unsigned long)count, (unsigned long)megabytesEach);
    
    for (NSUInteger i = 0; i < count; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                UIImage *image = [self generateTestImageOfSize:megabytesEach];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.imageBlocks addObject:image];
                    
                    uint64_t currentUsage = [self getCurrentMemoryUsage];
                    float currentMB = currentUsage / 1024.0 / 1024.0;
                    
                    NSLog(@"🎨 [%@] [IMAGE %lu/%lu] Current usage: %.2f MB",
                          self.monitorIdentifier, (unsigned long)(i + 1), (unsigned long)count, currentMB);
                });
                
                usleep(100000); // 0.1 sec delay
            }
        });
    }
}

#pragma mark - Очистка памяти

- (void)releaseAllMemory {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger ffCount = self.memoryBlocks.count;
        NSUInteger imageCount = self.imageBlocks.count;
        
        [self.memoryBlocks removeAllObjects];
        [self.imageBlocks removeAllObjects];
        [self.imageDataBlocks removeAllObjects];
        
        uint64_t currentUsage = [self getCurrentMemoryUsage];
        float currentMB = currentUsage / 1024.0 / 1024.0;
        
        NSLog(@"🗑 [%@] Released %lu FF blocks and %lu images. Current usage: %.2f MB",
              self.monitorIdentifier, (unsigned long)ffCount, (unsigned long)imageCount, currentMB);
        
        self.isUnderStress = NO;
    });
}

- (void)releaseImagesOnly {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger imageCount = self.imageBlocks.count;
        [self.imageBlocks removeAllObjects];
        [self.imageDataBlocks removeAllObjects];
        
        uint64_t currentUsage = [self getCurrentMemoryUsage];
        float currentMB = currentUsage / 1024.0 / 1024.0;
        
        NSLog(@"🎨 [%@] Released %lu images only. Current usage: %.2f MB (FF data preserved)",
              self.monitorIdentifier, (unsigned long)imageCount, currentMB);
    });
}

@end

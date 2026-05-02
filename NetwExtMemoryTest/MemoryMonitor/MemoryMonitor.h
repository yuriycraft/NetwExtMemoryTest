#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MemoryPressureLevel) {
    MemoryPressureLevelUnknown = 0,
    MemoryPressureLevelNormal,
    MemoryPressureLevelWarning,
    MemoryPressureLevelCritical
};

@interface MemoryMonitor : NSObject

+ (instancetype)shared;

- (void)startMonitoringWithIdentifier:(NSString *)identifier;
- (void)stopMonitoring;
- (uint64_t)getCurrentMemoryUsage;

// Старый метод - просто заполняет память 0xFF
- (void)allocateMemory:(NSUInteger)megabytes;

// Новый метод - загружает реальные изображения
- (void)allocateMemoryWithRealImages:(NSUInteger)megabytes;
- (void)allocateMemoryWithRandomImages:(NSUInteger)count ofSize:(NSUInteger)megabytesEach;

// Очистка
- (void)releaseAllMemory;
- (void)releaseImagesOnly; // Очистить только изображения, оставив FF-данные

@property (nonatomic, copy, nullable) void (^onPressureChange)(MemoryPressureLevel level);
@property (nonatomic, assign) BOOL isUnderStress;

@end

NS_ASSUME_NONNULL_END

//
//  VideoCompress.h
//  VideoDemo
//
//  Created by karos li on 2020/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoCompress : NSObject

+ (void)deleteOutputUrlIfNeed:(NSURL *)outputUrl;

- (void)compressVideo1:(NSURL *)videoUrl withOutputUrl:(NSURL *)outputUrl;
- (void)compressVideo2:(NSURL *)videoUrl withOutputUrl:(NSURL *)outputUrl;

@end

NS_ASSUME_NONNULL_END

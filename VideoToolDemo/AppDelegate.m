//
//  AppDelegate.m
//  VideoToolDemo
//
//  Created by karos li on 2020/12/23.
//

#import "AppDelegate.h"
#import "VideoCompress.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Insert code here to initialize your application
//    NSString *originUrl = [[NSBundle mainBundle] pathForResource:@"zoo_origin_3200kb" ofType:@"MOV"];
//    NSString *outputUrl = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"zoo1.mp4"];
    
//    NSString *originUrl = [[NSBundle mainBundle] pathForResource:@"office_origin_8000kb" ofType:@"MOV"];
//    NSString *outputUrl = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"office.mp4"];
    
    NSString *originUrl = [[NSBundle mainBundle] pathForResource:@"code_origin_22000kb" ofType:@"mp4"];
    NSString *outputUrl = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"code.mp4"];
    
    NSLog(@"The original video at %@", originUrl);
    NSLog(@"The output video at %@", outputUrl);
    
    [VideoCompress deleteOutputUrlIfNeed:[NSURL fileURLWithPath:outputUrl]];
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:originUrl]) {
        
//        [[VideoCompress new] compressVideo1:[NSURL fileURLWithPath:originUrl] withOutputUrl:[NSURL fileURLWithPath:outputUrl]];
        
        [[VideoCompress new] compressVideo2:[NSURL fileURLWithPath:originUrl] withOutputUrl:[NSURL fileURLWithPath:outputUrl]];
        
    }
    
    return YES;
}

- (void)copyVideo:(NSString *)fromUrl ToUrl:(NSString *)toUrl {
    //将视频文件copy到沙盒目录中
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    [manager copyItemAtURL:[NSURL URLWithString:fromUrl] toURL:[NSURL URLWithString:toUrl] error:&error];
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end

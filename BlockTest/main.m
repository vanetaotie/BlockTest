//
//  main.m
//  BlockTest
//
//  Created by vane on 10/05/2018.
//  Copyright © 2018 vane. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        
        ^{ printf("Hello, World!\n"); } ();
        
        __block int val = 0;
        void (^blk)(void) = ^{val = 1;};
        blk();
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

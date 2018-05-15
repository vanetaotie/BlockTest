//
//  BlockTestCycle.h
//  BlockTest
//
//  Created by vane on 11/05/2018.
//  Copyright © 2018 vane. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^TestBlock)(NSError *error);

@interface BlockTestCycle : NSObject

@property (nonatomic, copy) TestBlock testBlock;

- (void)testWithBlock:(TestBlock)completion;

@end

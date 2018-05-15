//
//  BlockTestCycle.m
//  BlockTest
//
//  Created by vane on 11/05/2018.
//  Copyright © 2018 vane. All rights reserved.
//

#import "BlockTestCycle.h"

@implementation BlockTestCycle

- (void)testWithBlock:(TestBlock)completion {
    
    //1.强行制造retain cycle，
    //反之，如果不在内部进行赋值操作，虽然外部看起来也很有疑问，但不会发生循环引用
    _testBlock = completion;
    _testBlock(nil);
    
    //2.completion在别处被使用...
    
    //3.因此，如果发生这种使用开发者应该在抛出Block方法的内部自⾏找到一个适当的时机解除retain cycle，比如:
//    _testBlock = nil;
}

@end

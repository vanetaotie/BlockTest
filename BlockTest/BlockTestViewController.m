//
//  BlockTestViewController.m
//  BlockTest
//
//  Created by vane on 10/05/2018.
//  Copyright © 2018 vane. All rights reserved.
//

#import "BlockTestViewController.h"
#import "BlockTestCycle.h"

@interface BlockTestViewController ()

@property (nonatomic, strong) BlockTestCycle *testCycle;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSOperation *operation;

@end

@implementation BlockTestViewController
{
    id _observer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor redColor];
    
    //1.正常栈上的block引用self不会发生retain cycle
    void (^blkk)(void) =  ^{
        NSLog(@"self==%@",self);
        [self showLog];
    };
    blkk();
    
    //2.UIView的动画block不会造成循环引用的原因就是，这是个类方法，当前控制器不可能强引用一个类，所以循环无法形成
    [UIView animateWithDuration:0.5 animations:^{
        NSLog(@"self==%@",self);
        [self showLog];
    }];
    
    //demo
//    [self retainCycle];
//    [self retainCycle2];
//    [self weakStrongDance];
//    [self unretainCycle];
    
    UIButton *popBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 80)];
    popBtn.backgroundColor = [UIColor greenColor];
    popBtn.center = self.view.center;
    [popBtn addTarget:self action:@selector(pop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:popBtn];
}

//retain cycle 范例
- (void)retainCycle {
    //范例1
    _observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"TestNotificationKey"
                                                                  object:nil queue:nil
                                                              usingBlock:^(NSNotification *n){
                                                                  NSLog(@"%@",self);
                                                              }];
}

- (void)retainCycle2 {
    _testCycle = [[BlockTestCycle alloc] init];
    [_testCycle testWithBlock:^(NSError *error) {
        NSLog(@"%@",self);
    }];
}

//weakStrongDance
- (void)weakStrongDance {
    __weak __typeof__(self) weakSelf = self;
    _testCycle = [[BlockTestCycle alloc] init];
    [_testCycle testWithBlock:^(NSError *error) {
        NSLog(@"weakSelf==%@",weakSelf);
        
        //为何用strongSelf搭配weakSelf使用
        //1.只使用weakSelf，在部分情况下会造成Crash问题
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            NSMutableArray *array = [NSMutableArray array];
//            [array addObject:weakSelf];
//            NSLog(@"测试weakSelf");
//        });
        
        //2.搭配strongSelf，避免产生额外问题
//        __strong __typeof__(weakSelf) strongSelf = weakSelf;
//        NSLog(@"strongSelf==%@",strongSelf);
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            NSMutableArray *array = [NSMutableArray array];
//            [array addObject:strongSelf];
//            NSLog(@"%@",array);
//            NSLog(@"测试StrongSelf");
//        });
    }];
}

//weakStrongDance注意事项
- (void)pop {
    [self lateExcute];
//    [self lateExcute2];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)lateExcute {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"延迟3s执行,%@",self);
    });
}

- (void)lateExcute2 {
    __weak __typeof__(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //执行方法后直接pop返回，strongSelf在赋值前，weakSelf已经为空
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        NSLog(@"延迟3s执行,%@",strongSelf);
        
        //因此需要做strongSelf的nil判空处理，不进行判空处理，依旧可能出现问题，比如：
//        NSArray *array = @[strongSelf];
//        NSLog(@"%@",array);
    });
}

//打破retain cycle 范例
- (void)unretainCycle {
    
    //范例1 NSOperation内部处理,见文档
    self.queue = [[NSOperationQueue alloc] init];
    self.operation = [[NSOperation alloc] init];
    self.operation.completionBlock = ^{
        NSLog(@"self==%@",self);
        [self finishedOperation];
    };
    [self.queue addOperation:self.operation];
    
    //范例2 AFN...内部解决
    
    //范例3 个人设计类，自行手动打破————见BlockTestCycle 3.
}

- (void)dealloc {
    if (_observer) {
        [[NSNotificationCenter defaultCenter] removeObserver:_observer];
    }
    
    NSLog(@"BlockTestVC页面销毁");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showLog {
    
}

- (void)finishedOperation {
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

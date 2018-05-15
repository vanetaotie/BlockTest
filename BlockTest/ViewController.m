//
//  ViewController.m
//  BlockTest
//
//  Created by vane on 10/05/2018.
//  Copyright © 2018 vane. All rights reserved.
//

#import "ViewController.h"
#import "BlockTestViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    __block int val = 0;
//    void (^blkk)(void) =  ^{
//        NSLog(@"~~~~~~~%d", val);
//    };
//    val++;
//    blkk();
    
    UIButton *pushBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 80)];
    pushBtn.backgroundColor = [UIColor redColor];
    pushBtn.center = self.view.center;
    [pushBtn addTarget:self action:@selector(push) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pushBtn];
}

- (void)push {
    BlockTestViewController *vc = [[BlockTestViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

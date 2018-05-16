# Block使用杂记

## 1.Block的特性和使用场景

Block 是一种闭包语法，将代码像对象一样传递，最重要的特性是，Block 可以访问定义范围内的全部变量。
Block 可以在多种场合使用，常见的场合包括但不限于通知回调、动画、多线程等。

## 2.Block的结构和类型研究

对 Block 稍微了解的话，就会知道 Block 会在编译过程中，会被当作结构体进行处理。
其大致的结构如下：
```c++
struct Block_descriptor {
    unsigned long int reserved;
    unsigned long int size;
    void (*copy)(void *dst, void *src);
    void (*dispose)(void *);
};

struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor *descriptor;
    /* Imported variables. */
};
```
其中`isa`指针就指向表明 Block 类型的类。

根据 Block 在内存中的位置，一般可分为三种类型：

`_NSConcreteGlobalBlock`：全局的静态 block ，不会访问任何外部变量，不会涉及到任何拷贝，比如一个空的 block。这个类型的 block 要么是空 block ，要么是不访问任何外部变量的 block 。它既不在栈中，也不在堆中，我理解为它可能在内存的全局区。

`_NSConcreteStackBlock`：保存在栈中的 block，当函数返回时被销毁。该类型的 block 有闭包行为，也就是有访问外部变量，并且该 block 只且只有有一次执行，因为栈中的空间是可重复使用的，所以当栈中的 block 执行一次之后就被清除出栈了，所以无法多次使用。

`_NSConcreteMallocBlock`：保存在堆中的 block，当引用计数为0时被销毁。该类型的 block 都是由 _NSConcreteStackBlock 类型的 block 从栈中复制到堆中形成的。该类型的 block 有闭包行为，并且该 block 需要被多次执行。当需要多次执行时，就会把该 block 从栈中复制到堆中，供以多次执行。

以上内容引用自 [Objective-C中的Block](http://www.devtalking.com/articles/you-should-know-block/)。

为了验证以上结论，这里写了两个 block ，然后通过 clang 将其翻译成 C 语言。

A：
```objc
^{ printf("Hello, World!\n"); } ();
```
这是个空 block ，不涉及外部变量的拷贝。
通过 clang 翻译后，得到如下关键区域代码：
```c++
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
 printf("Hello, World!\n"); }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
```
从C代码中可以看到，`isa` 指针指向的是 _NSConcreteStackBlock ，按照之前的理论，应该是指向 _NSConcreteGlobalBlock 。
这里通过查阅相关资料可知：
> 由于 clang 改写的具体实现方式和 LLVM 不太一样，并且这里没有开启 ARC 。所以这里我们看到 isa 指向的还是 _NSConcreteStackBlock。但在 LLVM 的实现中，开启 ARC 时，block 应该是 _NSConcreteGlobalBlock 类型。

关于是否开启 ARC 对于 block 类型的影响的问题，在 ARC 开启的情况下，将只会有 _NSConcreteGlobalBlock 和 _NSConcreteMallocBlock 类型的 block。
比如我们将第二段代码中的 blk() 进行打印，可以得到以下信息：
```c++
2018-05-16 11:29:57.405094+0800 BlockTest[7696:7587452] <__NSMallocBlock__: 0x60000004d1a0>
```
证明以上结论正确。

B:
```objc
 __block int val = 0;
 void (^blk)(void) = ^{val = 1;};
 blk();
```
第二个例子是一个有外部变量访问的 block 。 
通过clang 翻译之后，得到如下C代码：
```c++
struct __main_block_impl_1 {
  struct __block_impl impl;
  struct __main_block_desc_1* Desc;
  __Block_byref_val_0 *val; // by ref
  __main_block_impl_1(void *fp, struct __main_block_desc_1 *desc, __Block_byref_val_0 *_val, int flags=0) : val(_val->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_1(struct __main_block_impl_1 *__cself) {
  __Block_byref_val_0 *val = __cself->val; // bound by ref
(val->__forwarding->val) = 1;}
static void __main_block_copy_1(struct __main_block_impl_1*dst, struct __main_block_impl_1*src) {_Block_object_assign((void*)&dst->val, (void*)src->val, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_1(struct __main_block_impl_1*src) {_Block_object_dispose((void*)src->val, 8/*BLOCK_FIELD_IS_BYREF*/);}
```
`isa` 指向 _NSConcreteStackBlock，说明这是一个分配在栈上的实例。

NSConcreteMallocBlock 类型的 block 通常不会在源码中直接出现，因为默认它是当一个 block 被 copy 的时候，才会将这个 block 复制到堆中。

## 3.常见的非Retain Cycle的Block类型

正常情况下，当 block 不是 self 的属性时，self 不持有 block ，不会发生循环引用，如：
```objc
void (^blkk)(void) =  ^{
    NSLog(@"self==%@",self);
};
blkk();
```
另外，调用系统类方法时，也不会发生循环引用，比如使用 UIView 动画：
```objc
[UIView animateWithDuration:0.5 animations:^{
    NSLog(@"self==%@",self);
}];
```

还有一种情况，比如使用了系统的 NSOperation 对象，如下面这段示例代码：
```objc
self.queue = [[NSOperationQueue alloc] init];
self.operation = [[NSOperation alloc] init];
self.operation.completionBlock = ^{
    NSLog(@"self==%@",self);
};
[self.queue addOperation:self.operation];
```
这时，在 completionBlock 中，编译器甚至已经给了我们 retain cycle 的警告，但是实际运行后可以得知，这里并不会发生循环引用，具体的原因在查阅苹果[关于 NSOperation 的文档](https://developer.apple.com/documentation/foundation/nsoperation/1408085-completionblock?preferredLanguage=occ)后，得到以下这段解释：

`In iOS 8 and later and macOS 10.10 and later, this property is set to nil after the completion block begins executing.`

由此得知 Apple 在内部做了置空处理，所以这里可以放心使用。

## 4.Block的循环引用问题(retain cycle)

只要 Block 的内部引用了 self 或 self 的变量、属性，就会对 self 带来直接或间接的强引用，如果 self 又通过某种方式直接或间接的对 Block 进行了强引用，则造成循环引用(retain cycle)，带来内存泄漏问题。

Demo A：
```objc
@implementation TestViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    Tester *tester = [[Tester alloc] init];
    [tester run];

    _observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"TestNotificationKey" 
                                                            object:nil queue:nil 
                                                        usingBlock:^(NSNotification *n){
                                                            NSLog(@"%@",self);
                                                        }];
}

- (void)dealloc {
    if (_observer) {
        [[NSNotificationCenter defaultCenter] removeObserver:_observer];
    }
}
@end
```
向通知中心注册一个观察者，在 dealloc 方法中解除。
在注册通知的时候，block 中使用了 self，因此，self 被 block retain，在解除通知之前，block 一直被通知中心持有，则 _observer 持有了 block 的一份拷贝，而 _observer 始终被 self 持有，所以 self 同时持有了 block。
至此，形成循环引用，self 不会被释放，dealloc 方法也不会走，通知也就不会被解除。

Demo B：
```objc
#import "TestB.h"
@interface TestA:NSObject
@property (nonatomic, strong) TestB *testB;
@end

@implementation TestA
- (void)test {
    //retain cycle demo
    _testB = [[TestB allock] init];
    [_testB testWithBlock:^(NSError *error){
        NSLog(@"%@",self);
    }];
}

- (void)dealloc {
    NSLog(@"dealloc");
}
@end
```
```objc
typedef void (^TestBlock)(NSError *error);
@interface TestB:NSObject
@property (nonatomic, copy) TestBlock testBlock;
@end

@implementation TestB
- (void)testWithBlock:(TestBlock)completion {
    _testBlock = completion;
}
@end
```
在 TestA 中，TestA 持有了 _testB，_testB 持有其属性 testBlock，而在 testWithBlock 方法中，TestA 中的 block 又通过参数 completion 赋给了 testBlock，因此，间接造成在 TestA 中 self 对 block 的强引用。而在 block 内部，又对 self 进行了强引用，所以形成循环引用。
上例是故意制造的 retain cycle，在这个简单的 demo 中，这么做可能毫无意义，但是在实际开发中，TestB 中的 _testBlock 很可能在其他地方被使用，造成容易被疏忽的循环引用问题。

**总结：
循环引用的形成，根本原因只有一条，就是 self 和 block 之间直接或者间接的互相持有了对方，分析问题的时候，只需要抓住这个宗旨，循序渐进，找到变量之间的持有关系，就会发现隐藏的问题。**

## 5. weak-strong dance

对于在使用block过程中产生的循环引用问题，苹果官方给出了一种解决方案，weak-strong dance。
以Demo A为例，解决此处的循环引用可以采用如下方式：
```objc
__weak TestViewController *weakSelf = self;
_observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"TestNotificationKey" 
                                                        object:nil queue:nil 
                                                    usingBlock:^(NSNotification *n){
                                                      TestViewController *strongSelf = weakSelf;
                                                      if (strongSelf) {
                                                        NSLog(@"%@",strongSelf);
                                                      }
                                                    }];
```
首先定义对 self 的弱引用 weakSelf，当 self 被释放时，weakSelf 会变为 nil。
然后在 block 中使用 weakSelf，考虑到多线程情况，这里使用强引用 strongSelf 来持有 weakSelf，此时如果 self 不为 nil 即 retain self，以防止在后面使用的时候被释放。使用 strongSelf 的时候需要进行 nil 判断，在多线程的情况下，可能在对 strongSelf 赋值的时候，weakSelf 已经 nil 了。
通过这种手法，block 就不会持有 self，从而打破循环引用。
此外，strongSelf 的作用会保持到 block 执行完成，清理 block 栈的时候，strongSelf 会被 release，所以在 block 内定义的 strongSelf 是被 block 持有的，帮助 block 持有 self，相当于 self 的引用计数+1，并跟随 block 的执行完毕而销毁。

## 6.使用 weak-strong dance 的注意事项

在使用 weak-strong dance 的时候，需要注意一些情况。
比如异步网络请求，使用 GCD 延迟执行一段代码：
```objc
@implementation TestViewController
- (void)test {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"%@", self);
    });
}

- (void)dealloc {
    NSLog(@"dealloc");
}
@end
```
假设 TestViewController 被 push 进来之后立即执⾏ test ⽅法，然后立即 pop 回去，这里不会立即执⾏ dealloc ⽅法，而是先等待5s执行 block，之后再⾛ dealloc ⽅法。

使用 weak-strong dance 后：
```objc
@implementation TestViewController
- (void)test {
    __weak TestViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      TestViewController *strongSelf = weakSelf;
      NSLog(@"%@", self);
    });
}

- (void)dealloc {
    NSLog(@"dealloc");
}
@end
```
pop的时候，会立即执行dealloc，5s后又会执行block，不过此时self已经为nil了。如果此时在block中又进行了其它操作，并且使用到了strongSelf的话，必然会造成crash。
因此，如上一条所述，在block中使用weak-strong dance时，要做好nil判断。

**总结：
在使⽤ weak-strong dance 时，首先需要清楚的是，使⽤的场合是什么，目的⼜是什么，多线程环境下，使用了 weak-strong dance 后，如果在给 block ⾥面的 strongSelf 赋值的时候，weakSelf 已经 nil 了，代码就不执⾏了。也就是说，如果需要 block 中的代码⽆论何时都必须执行，就不该使⽤ weak-strong dance，⽽如果 block 中不是必须执⾏的代码，那么即使 weakSelf 为 nil 了，也⽆所谓了，正如⻚面都销毁了，是否执⾏加载数据的代码，就变的毫⽆意义了，此时只需要做好判断，不让程序崩溃，该 return 就 return 吧。**

## 7.其它应对retain cycle的做法

优秀的开发者，不会把循环引用的问题抛给使⽤者，也不应该把责任推给API的调⽤者。所以在产生循环引用的情况下，开发者应该自⾏找到一个适当的时机解除retain cycle。
以Demo B为例，在 TestB 中，testBlock 在使⽤后，需要及时将其置空，比如在回调结束后执⾏_testBlock = nil，这样，只要 block 运⾏完毕，retain cycle就解除了，这⼀切都在内部实现，不需要也不应该暴露给调用者。
再⽐如，AFNetworking(3.x以下版本)中，在做网络请求的时候会使用这个方法：
```objc
- (void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                              failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    ...
    self.completionBlock = ^{
            ...
               if (success) {
                   dispatch_group_async(self.completionGroup ?: http_request_operation_completion_group(), self.completionQueue ?: dispatch_get_main_queue(), ^{
                       success(self, responseObject);
                   });
               }
            ...
          }
    ...
}
```
success 这个 block 被 AFHTTPRequestOperation 对象持有。其实循环引⽤在一开始的时候被建立了，只不过在 block 执⾏完成之后，循环引⽤又被⼿动打破了。如何打破？因为AFN的作者封装了一个completionBlock，使用了一个dispatch_group，无论传进来的是什么，最终都会在回调之后主动打破循环引用。
```objc
- (void)setCompletionBlock:(void (^)(void))block {
    [self.lock lock];
    if (!block) {
        [super setCompletionBlock:nil];
    } else {
        __weak __typeof(self)weakSelf = self;
        [super setCompletionBlock:^ {
            __strong __typeof(weakSelf)strongSelf = weakSelf;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_group_t group = strongSelf.completionGroup ?: url_request_operation_completion_group();
            dispatch_queue_t queue = strongSelf.completionQueue ?: dispatch_get_main_queue();
#pragma clang diagnostic pop

            dispatch_group_async(group, queue, ^{
                block();
            });

            dispatch_group_notify(group, url_request_operation_completion_queue(), ^{
                [strongSelf setCompletionBlock:nil];
            });
        }];
    }
    [self.lock unlock];
}
```

**总结：
retain cycle本身并不一定是糟糕的，他可以延迟self的销毁，最关键的依旧是，在合适的时候手动打破它。**

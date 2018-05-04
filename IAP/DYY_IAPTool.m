//
//  DYY_IAPTool.m
//  IAP
//
//  Created by dzc on 2018/5/2.
//  Copyright © 2018年 dyy. All rights reserved.
//

#import "DYY_IAPTool.h"

#ifdef DEBUG
#define checkURL @"https://sandbox.itunes.apple.com/verifyReceipt"
#else
#define checkURL @"https://buy.itunes.apple.com/verifyReceipt"
#endif

#define checkSandboxURL @"https://sandbox.itunes.apple.com/verifyReceipt"

//匿名的扩展
@interface DYY_IAPTool ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

//商品字典
@property(nonatomic,strong)NSMutableDictionary *productDict;

@end

@implementation DYY_IAPTool
+ (DYY_IAPTool *)dyy_defaultTool
{
    static DYY_IAPTool * iapTool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iapTool = [[DYY_IAPTool alloc]init];
        [iapTool setUp];
    });
    return iapTool;
}
#pragma mark 初始化
- (void)setUp
{
    self.CheckAfterPay = YES;
    //设置购买队列的监听器
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}
#pragma mark 请求苹果服务器可购买的商品
- (void)dyy_requestProductsWithProductArray:(NSArray *)products
{
    NSLog(@"开始请求可购买的商品");
    // 能够销售的商品
    NSSet *set = [[NSSet alloc]initWithArray:products];
    //请求是否能毛
    SKProductsRequest *request = [[SKProductsRequest alloc]initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
}
#pragma mark 请求回来结果 把商品加入dict
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (self.productDict == nil) {
        self.productDict = [NSMutableDictionary dictionaryWithCapacity:response.products.count];//response.products.count可购买的数量
    }
    NSMutableArray *productArray = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        NSLog(@"product.productIdentifier==%@", product.productIdentifier);
        [self.productDict setObject:product forKey:product.productIdentifier];//添加字典
        [productArray addObject:product];//添加数组
    }
    //告知vc获取到的商品 用于更新数据
    [self.iapDelegate DYY_IAPToolGetProductsWith:productArray];
}
#pragma mark - 用户决定购买商品
- (void)dyy_buyProduct:(NSString *)productID
{
    SKProduct *product = self.productDict[productID];
    // 要购买产品(店员给用户开了个小票)
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    // 去收银台排队，准备购买(异步网络)
    [[SKPaymentQueue defaultQueue] addPayment:payment];

}
#pragma mark - SKPaymentTransaction Observer
#pragma mark 购买队列状态变化,,判断购买状态是否成功
/**
 检测买队列的变化
 @param queue 队列
 @param transactions 交易
 */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    // 处理结果
    for (SKPaymentTransaction *transaction in transactions) {
        NSLog(@"队列状态变化 %@", transaction);
        // 如果小票状态是购买完成
        if (SKPaymentTransactionStatePurchased == transaction.transactionState) {
            NSLog(@"购买完成 %@", transaction.payment.productIdentifier);
            
            if(self.CheckAfterPay){
                //需要向苹果服务器验证一下
                //通知代理
                [self.iapDelegate DYY_IAPToolBeginChekingWithProductID:transaction.payment.productIdentifier];
                // 验证购买凭据
                [self verifyPruchaseWithID:transaction.payment.productIdentifier];
            }else{
                //不需要向苹果服务器验证
                //通知代理
                [self.iapDelegate DYY_IAPToolBuyProductSuccessWithProductID:transaction.payment.productIdentifier
                                                                    andInfo:nil];
            }
            // 将交易从交易队列中删除
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            
        } else if (SKPaymentTransactionStateRestored == transaction.transactionState) {
            NSLog(@"恢复成功 :%@", transaction.payment.productIdentifier);
            
            // 通知代理
            [self.iapDelegate DYY_IAPToolRestoredProductID:transaction.payment.productIdentifier];
            
            // 将交易从交易队列中删除
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        } else if (SKPaymentTransactionStateFailed == transaction.transactionState){
            
            // 将交易从交易队列中删除
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            NSLog(@"交易失败");
            //取消
            [self.iapDelegate DYY_IAPToolCancelBuyProductWithProductID:transaction.payment.productIdentifier];
        }else if(SKPaymentTransactionStatePurchasing == transaction.transactionState){
            NSLog(@"正在购买");
        }else{
            NSLog(@"state:%ld",(long)transaction.transactionState);
            NSLog(@"已经购买");
            // 将交易从交易队列中删除
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }

}
#pragma mark 恢复商品
- (void)dyy_restorePurchase
{
    // 恢复已经完成的所有交易.（仅限永久有效商品）
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}
#pragma mark 验证购买凭据
/**
 *  验证购买凭据
 *
 *  @param ProductID 商品ID
 */
- (void)verifyPruchaseWithID:(NSString *)ProductID
{
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    // 发送网络POST请求，对购买凭据进行验证
    NSURL *url = [NSURL URLWithString:checkURL];
    NSLog(@"checkURL:%@",checkURL);
    
    // 国内访问苹果服务器比较慢，timeoutInterval需要长一点
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0f];
    request.HTTPMethod = @"POST";
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = payloadData;
    NSLog(@"encodeStrencodeStr==%@",encodeStr);
    // 提交验证请求，并获得官方的验证JSON结果
    NSURLSession *sesss = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [sesss dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // 官方验证结果为空
        if (data == nil) {
            //NSLog(@"验证失败");
            //验证失败,通知代理
            [self.iapDelegate DYY_IAPToolCheckFailedWithProductID:ProductID
                                                          andInfo:data];
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingAllowFragments
                                                               error:nil];
        
//        NSLog(@"RecivedVerifyPruchaseDict：%@", dict);
        NSLog(@"RecivedVerifyPruchaseDict_sratus：%@", dict[@"status"]);
#pragma mark 21007
        if ([dict[@"status"] integerValue] == 21007) {
            //审核的时候发送到正式服务器上了 这里需要再次区测试服务器验证
            [self verifySecondPruchaseWithID:ProductID];
        }else if ([dict[@"status"] integerValue] == 0){
            if (dict != nil) {
                // 验证成功,通知代理
                // bundle_id&application_version&product_id&transaction_id
                [self.iapDelegate DYY_IAPToolBuyProductSuccessWithProductID:ProductID
                                                                    andInfo:dict];
            }else{
                //验证失败,通知代理
                [self.iapDelegate DYY_IAPToolCheckFailedWithProductID:ProductID
                                                              andInfo:data];
            }
        }
    }];
    [dataTask resume];
}
- (void)verifySecondPruchaseWithID:(NSString *)ProductID
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    // 发送网络POST请求，对购买凭据进行验证
    NSURL *url = [NSURL URLWithString:checkSandboxURL];
    NSLog(@"checkSandboxURL:%@",checkSandboxURL);
    
    // 国内访问苹果服务器比较慢，timeoutInterval需要长一点
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0f];
    request.HTTPMethod = @"POST";
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = payloadData;

    // 提交验证请求，并获得官方的验证JSON结果
    NSURLSession *sesss = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [sesss dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // 官方验证结果为空
        if (data == nil) {
            //NSLog(@"验证失败");
            //验证失败,通知代理
            [self.iapDelegate DYY_IAPToolCheckFailedWithProductID:ProductID
                                                          andInfo:data];
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingAllowFragments
                                                               error:nil];
        
        //        NSLog(@"RecivedVerifyPruchaseDict：%@", dict);
        NSLog(@"second_RecivedVerifyPruchaseDict_sratus：%@", dict[@"status"]);
        
        if (dict != nil) {
            // 验证成功,通知代理
            // bundle_id&application_version&product_id&transaction_id
            [self.iapDelegate DYY_IAPToolBuyProductSuccessWithProductID:ProductID
                                                                andInfo:dict];
        }else{
            //验证失败,通知代理
            [self.iapDelegate DYY_IAPToolCheckFailedWithProductID:ProductID
                                                          andInfo:data];
        }
    }];
    [dataTask resume];
}
@end

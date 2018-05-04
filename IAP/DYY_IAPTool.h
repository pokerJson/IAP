//
//  DYY_IAPTool.h
//  IAP
//
//  Created by dzc on 2018/5/2.
//  Copyright © 2018年 dyy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

//代理
@protocol DYY_IAPTollDelegate <NSObject>

- (void)DYY_IAPToolSystemWrong;                                                 //系统错误
- (void)DYY_IAPToolGetProductsWith:(NSMutableArray *)products;                 //获取内购商品
- (void)DYY_IAPToolBuyProductSuccessWithProductID:(NSString *)productID
                                          andInfo:(NSDictionary *)info;         //购买成功success
- (void)DYY_IAPToolCancelBuyProductWithProductID:(NSString *)productID;         //取消购买cancel
- (void)DYY_IAPToolBeginChekingWithProductID:(NSString *)productID;             //开始验证购买
- (void)DYY_IAPToolChekRepeatedWithProductID:(NSString *)productID;             //重复的验证
- (void)DYY_IAPToolCheckFailedWithProductID:(NSString *)productID
                                    andInfo:(NSData *)infoData;                 //验证失败
- (void)DYY_IAPToolRestoredProductID:(NSString *)productID;                     //恢复了已购买的商品（永久性商品）

@end


@interface DYY_IAPTool : NSObject
//上面的代理
@property (nonatomic,weak) id<DYY_IAPTollDelegate> iapDelegate;
/*购买完后是否在iOS端向服务器验证一次,默认为YES*/
@property(nonatomic)BOOL CheckAfterPay;

/*单例*/
+(DYY_IAPTool *)dyy_defaultTool;

/*请求苹果服务器商品*/
- (void)dyy_requestProductsWithProductArray:(NSArray *)products;

/*购买哪个商品*/
- (void)dyy_buyProduct:(NSString *)productID;

/*恢复商品（仅限永久有效商品）*/
- (void)dyy_restorePurchase;

@end

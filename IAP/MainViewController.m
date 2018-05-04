//
//  ViewController.m
//  IAP
//
//  Created by dzc on 2018/5/2.
//  Copyright © 2018年 dyy. All rights reserved.
//

#import "MainViewController.h"
#import "DYY_IAPTool.h"
#import "SVProgressHUD.h"

@interface MainViewController ()<DYY_IAPTollDelegate,UITableViewDelegate,UITableViewDataSource>

@property (nonatomic,strong)UITableView *tabView;
@property (nonatomic,strong)NSMutableArray *productArray;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self creatView];
    
    DYY_IAPTool *iapTool = [DYY_IAPTool dyy_defaultTool];
    iapTool.iapDelegate = self;
    [SVProgressHUD showWithStatus:@"向苹果询问哪些商品能够购买"];
    [iapTool dyy_requestProductsWithProductArray:@[@"com.iap.rmb06",
                                                   @"com.iap.rmb12",
                                                   @"com.iap.rmb18",
                                                   @"com.iap.rmb30"]];

}
#pragma mark DYY_IAPTool 代理
//IAP工具已获得可购买的商品
- (void)DYY_IAPToolGetProductsWith:(NSMutableArray *)products
{
    for (SKProduct *product in products){
        NSLog(@"localizedDescription:%@\nlocalizedTitle:%@\nprice:%@\npriceLocale:%@\nproductID:%@",
              product.localizedDescription,
              product.localizedTitle,
              product.price,
              product.priceLocale,
              product.productIdentifier);
        NSLog(@"--------------------------");
    }

    self.productArray = products;
    [self.tabView reloadData];
    [SVProgressHUD showSuccessWithStatus:@"成功获取到可购买的商品"];
}
//支付成功了，并开始向苹果服务器进行验证（若CheckAfterPay为NO，则不会经过此步骤）
-(void)DYY_IAPToolBeginChekingWithProductID:(NSString *)productID {
    NSLog(@"BeginChecking:%@",productID);
    
    [SVProgressHUD showWithStatus:@"购买成功，正在验证购买"];
}
//支付失败/取消
-(void)DYY_IAPToolCancelBuyProductWithProductID:(NSString *)productID {
    NSLog(@"支付失败/取消canceld:%@",productID);
    [SVProgressHUD showInfoWithStatus:@"购买失败"];
}
//商品被重复验证了
-(void)DYY_IAPToolChekRepeatedWithProductID:(NSString *)productID {
    NSLog(@"CheckRepeated:%@",productID);
    
    [SVProgressHUD showInfoWithStatus:@"重复验证了"];
}
//商品完全购买成功且验证成功了。（若CheckAfterPay为NO，则会在购买成功后直接触发此方法）
-(void)DYY_IAPToolBuyProductSuccessWithProductID :(NSString *)productID
                                          andInfo:(NSDictionary *)infoDic {
    NSLog(@"BoughtSuccessed:%@",productID);
    NSLog(@"successedInfo:%@",infoDic);
    NSLog(@"successedInfo:%@",infoDic[@"status"]);
    
    [SVProgressHUD showSuccessWithStatus:@"购买成功！(相关信息已打印)"];
    NSString *status = infoDic[@"status"];
    if (status.integerValue == 0) {
        //线上或者沙河
    }else if(status.integerValue == 21007){
        //
    }
}
//商品购买成功了，但向苹果服务器验证失败了
//2种可能：
//1，设备越狱了，使用了插件，在虚假购买。
//2，验证的时候网络突然中断了。（一般极少出现，因为购买的时候是需要网络的）
-(void)DYY_IAPToolCheckFailedWithProductID:(NSString *)productID
                                   andInfo:(NSData *)infoData {
    NSLog(@"CheckFailed:%@",productID);
    
    [SVProgressHUD showErrorWithStatus:@"验证失败了"];
}
//恢复了已购买的商品（仅限永久有效商品）
-(void)DYY_IAPToolRestoredProductID:(NSString *)productID {
    NSLog(@"Restored:%@",productID);
    
    [SVProgressHUD showSuccessWithStatus:@"成功恢复了商品（已打印）"];
}
//内购系统错误了
-(void)DYY_IAPToolSystemWrong {
    NSLog(@"SysWrong");
    [SVProgressHUD showErrorWithStatus:@"内购系统出错"];
}
#pragma mark BuyProduct
//购买商品
-(void)BuyProduct:(SKProduct *)product{
    
    [SVProgressHUD showWithStatus:@"正在购买商品"];
    
    [[DYY_IAPTool dyy_defaultTool] dyy_buyProduct:product.productIdentifier];
}

#pragma mark --------UITableViewDataSource,UITableViewDelegate
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.productArray.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 200;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MyCell" forIndexPath:indexPath];
    SKProduct *product = self.productArray[indexPath.row];
    //cell的设置
    cell.textLabel.text = [NSString stringWithFormat:@"本地化商品描述:%@\n\n本地化商品标题:%@\n\n价格:%@\n\n商品ID:%@",
                           product.localizedDescription,
                           product.localizedTitle,
                           product.price,
                           product.productIdentifier];
    
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self.tabView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self BuyProduct:self.productArray[indexPath.row]];
}

- (void)creatView
{
    self.tabView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tabView.delegate = self;
    self.tabView.dataSource = self;
    
    [self.view addSubview:self.tabView];
    
    //注册重用单元格
    [self.tabView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"MyCell"];
}
- (NSMutableArray *)productArray
{
    if (!_productArray) {
        _productArray = [NSMutableArray array];
    }
    return _productArray;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

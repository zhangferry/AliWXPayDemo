//
//  ViewController.m
//  AliWXPayDemo
//
//  Created by zhangferry on 16/5/20.
//  Copyright © 2016年 com.jiuwei. All rights reserved.
//

#import "ViewController.h"
#import <AlipaySDK/AlipaySDK.h>
#import "WXApi.h"
#import "DataSigner.h"
#import "Order.h"
#import "GDataXMLNode.h"
#import "CommonUtil.h"

//支付宝参数
static NSString *kAliPay_partner = @"2088xxxx";//商户号

static NSString *kAliPay_seller = @"xxxx@qq.com";//支付宝帐号

static NSString *kAliPay_privateKey = @"pkcs8格式";//私钥
//微信参数
static NSString *kWeiXin_AppId = @"wxb4ba3c02aa476ea1";//appid

static NSString *kWeiXin_MchId = @"13xxxxxxx";//商户号

static NSString *kWeiXin_APIKEY = @"xxxxx";//由微信端生成

static NSString *const getPrePayIdUrl = @"https://api.mch.weixin.qq.com/pay/unifiedorder";/** 获取prePayId的url, 这是官方给的接口 */

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)aliPay:(id)sender {
    //商户ID
    NSString *partner = kAliPay_partner;
    //商户支付宝帐号
    NSString *seller = kAliPay_seller;
    
    NSString *privateKey = kAliPay_privateKey;//公钥是用来解密的（因为App之间的跳转有空隙，有可能被截取数据，不安全）
    //partner和seller获取失败,提示
    if ([partner length] == 0 ||
        [seller length] == 0 ||
        [privateKey length] == 0){
        NSLog(@"缺少partner或者seller或者私钥。");
        return;
    }
    
    /*
     *生成订单信息及签名
     */
    //将商品信息赋予AlixPayOrder的成员变量
    Order *order = [[Order alloc] init];
    order.partner = partner;
    order.sellerID = seller;
    order.outTradeNO = [self generateTradeNO]; //订单ID（由商家自行制定）
    order.subject = @"商品标题"; //商品标题
    order.body = @"商品描述"; //商品描述
    order.totalFee = @"0.01"; //商品价格
    //********
    order.notifyURL =  @"http://app.alip.com/wash/unionpay/mobilentify"; //回调URL，告诉后台一些支付的结果信息，跟后台的服务器进行连接的
    
    //以下的信息是支付的基本的配置信息（固定不变）
    order.service = @"mobile.securitypay.pay";
    order.paymentType = @"1";
    order.inputCharset = @"utf-8";
    order.itBPay = @"30m";
    order.showURL = @"m.alipay.com";
    
    //应用注册scheme,在AlixPayDemo-Info.plist定义URL types
    NSString *appScheme = @"carinsurance";
    
    //将商品信息拼接成字符串
    NSString *orderSpec = [order description];
    NSLog(@"orderSpec = %@",orderSpec);
    
    //获取私钥并将商户信息签名,外部商户可以根据情况存放私钥和签名,只需要遵循RSA签名规范,并将签名字符串base64编码和UrlEncode
    id<DataSigner> signer = CreateRSADataSigner(privateKey);
    NSString *signedString = [signer signString:orderSpec];
    
    //将签名成功字符串格式化为订单字符串,请严格按照该格式
    NSString *orderString = nil;
    if (signedString != nil) {
        orderString = [NSString stringWithFormat:@"%@&sign=\"%@\"&sign_type=\"%@\"",
                       orderSpec, signedString, @"RSA"];
        
        [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic) {
            NSLog(@"reslut = %@",resultDic);
            //            9000 订单支付成功
            //            8000 正在处理中
            //            4000 订单支付失败
            //            6001 用户中途取消
            //            6002 网络连接出错
            
            
        }];
    }

}

- (IBAction)WeixinPay:(id)sender {
    
    [self getWeChatPayWithOrderName:@"商品名称" price:@"1"];
}

// 调起微信支付，传进来商品名称和价格
- (void)getWeChatPayWithOrderName:(NSString *)name
                            price:(NSString*)price{
    
    //----------------------------获取prePayId配置------------------------------
    // 订单标题，展示给用户
    NSString* orderName = name;
    // 订单金额,单位（分）, 1是0.01元
    NSString* orderPrice = price;
    // 支付类型，固定为APP
    NSString* orderType = @"APP";
    // 随机数串
    NSString *noncestr  = [self genNonceStr];
    // 商户订单号
    NSString *orderNO   = [self genOutTradNo];
    
    //================================
    //预付单参数订单设置
    //================================
    NSMutableDictionary *packageParams = [NSMutableDictionary dictionary];
    
    [packageParams setObject: kWeiXin_AppId      forKey:@"appid"];       //开放平台appid
    [packageParams setObject: kWeiXin_MchId  forKey:@"mch_id"];      //商户号
    [packageParams setObject: noncestr     forKey:@"nonce_str"];   //随机串
    [packageParams setObject: orderType    forKey:@"trade_type"];  //支付类型，固定为APP
    [packageParams setObject: orderName    forKey:@"body"];        //订单描述，展示给用户
    [packageParams setObject: orderNO      forKey:@"out_trade_no"];//商户订单号
    [packageParams setObject: orderPrice   forKey:@"total_fee"];   //订单金额，单位为分
    [packageParams setObject: [CommonUtil getIPAddress:YES] forKey:@"spbill_create_ip"];//发器支付的机器ip
    [packageParams setObject: @"http://weixin.qq.com"  forKey:@"notify_url"];  //支付结果异步通知
    NSString *prePayid;
    prePayid = [self sendPrepay:packageParams];
    //--------------获取prePayId结束，利用参数生成sign签名-------------------
    
    if(prePayid){
        NSString *timeStamp = [self genTimeStamp];
        // 调起微信支付
        PayReq *request = [[PayReq alloc] init];
        request.partnerId = kWeiXin_MchId;
        request.prepayId = prePayid;
        request.package = @"Sign=WXPay";
        request.nonceStr = noncestr;
        request.timeStamp = [timeStamp intValue];
        
        // 这里要注意key里的值一定要填对， 微信官方给的参数名是错误的，不是第二个字母大写
        NSMutableDictionary *signParams = [NSMutableDictionary dictionary];
        [signParams setObject: kWeiXin_AppId               forKey:@"appid"];
        [signParams setObject: kWeiXin_MchId           forKey:@"partnerid"];
        [signParams setObject: request.nonceStr      forKey:@"noncestr"];
        [signParams setObject: request.package       forKey:@"package"];
        [signParams setObject: timeStamp             forKey:@"timestamp"];
        [signParams setObject: request.prepayId      forKey:@"prepayid"];
        
        //生成签名
        NSString *sign  = [self genSign:signParams];
        
        //添加签名
        request.sign = sign;
        
        [WXApi sendReq:request];
        
        
    } else{
        NSLog(@"获取prePayId失败！");
    }
    
}

// 发送给微信的XML格式数据
- (NSString *)genPackage:(NSMutableDictionary*)packageParams
{
    NSString *sign;
    NSMutableString *reqPars = [NSMutableString string];
    
    // 生成签名
    sign = [self genSign:packageParams];
    
    // 生成xml格式的数据, 作为post给微信的数据
    NSArray *keys = [packageParams allKeys];
    [reqPars appendString:@"<xml>"];
    for (NSString *categoryId in keys) {
        [reqPars appendFormat:@"<%@>%@</%@>"
         , categoryId, [packageParams objectForKey:categoryId],categoryId];
    }
    [reqPars appendFormat:@"<sign>%@</sign></xml>", sign];
    
    return [NSString stringWithString:reqPars];
}

// 获取prePayId
- (NSString *)sendPrepay:(NSMutableDictionary *)prePayParams
{
    
    // 获取提交预支付的xml格式数据
    NSString *send = [self genPackage:prePayParams];
    // 打印检查， 格式应该是xml格式的字符串
    NSLog(@"%@", send);
    
    // 转换成NSData
    NSData *data_send = [send dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:getPrePayIdUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data_send];
    
    NSError *error = nil;
    // 拿到data后, 用xml解析， 这里随便用什么方法解析
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    if (!error) {
        // 1.根据data初始化一个GDataXMLDocument对象
        GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithData:data options:0 error:nil];
        // 2.拿出根节点
        GDataXMLElement *rootElement = [document rootElement];
        GDataXMLElement *return_code = [[rootElement elementsForName:@"return_code"] lastObject];
        GDataXMLElement *return_msg = [[rootElement elementsForName:@"return_msg"] lastObject];
        GDataXMLElement *result_code = [[rootElement elementsForName:@"result_code"] lastObject];
        GDataXMLElement *prepay_id = [[rootElement elementsForName:@"prepay_id"] lastObject];
        // 如果return_code和result_code都为SUCCESS, 则说明成功
        NSLog(@"return_code---%@", [return_code stringValue]);
        // 返回信息，通常返回一些错误信息
        NSLog(@"return_msg---%@", [return_msg stringValue]);
        NSLog(@"result_code---%@", [result_code stringValue]);
        // 拿到这个就成功一大半啦
        NSLog(@"prepay_id---%@", [prepay_id stringValue]);
        
        return [prepay_id stringValue];
    } else {
        return nil;
    }
}

#pragma mark - 生成各种参数

- (NSString *)genTimeStamp
{
    return [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
}

/**
 * 注意：商户系统内部的订单号,32个字符内、可包含字母,确保在商户系统唯一
 */
- (NSString *)genNonceStr
{
    return [CommonUtil md5:[NSString stringWithFormat:@"%d", arc4random() % 10000]];
}

/**
 * 建议 traceid 字段包含用户信息及订单信息，方便后续对订单状态的查询和跟踪
 */
- (NSString *)genTraceId
{
    return [NSString stringWithFormat:@"myt_%@", [self genTimeStamp]];
}

- (NSString *)genOutTradNo
{
    return [CommonUtil md5:[NSString stringWithFormat:@"%d", arc4random() % 10000]];
}


#pragma mark - 签名
/** 签名 */
- (NSString *)genSign:(NSDictionary *)signParams
{
    // 排序, 因为微信规定 ---> 参数名ASCII码从小到大排序
    NSArray *keys = [signParams allKeys];
    NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    
    //生成 ---> 微信规定的签名格式
    NSMutableString *sign = [NSMutableString string];
    for (NSString *key in sortedKeys) {
        [sign appendString:key];
        [sign appendString:@"="];
        [sign appendString:[signParams objectForKey:key]];
        [sign appendString:@"&"];
    }
    NSString *signString = [[sign copy] substringWithRange:NSMakeRange(0, sign.length - 1)];
    
    // 拼接API密钥
    NSString *result = [NSString stringWithFormat:@"%@&key=%@", signString, kWeiXin_APIKEY];
    // 打印检查
    NSLog(@"result = %@", result);
    // md5加密
    NSString *signMD5 = [CommonUtil md5:result];
    // 微信规定签名英文大写
    signMD5 = signMD5.uppercaseString;
    // 打印检查
    NSLog(@"signMD5 = %@", signMD5);
    return signMD5;
}



#pragma mark -
#pragma mark   ==============产生随机订单号==============


- (NSString *)generateTradeNO
{
    static int kNumber = 15;
    
    NSString *sourceStr = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSMutableString *resultStr = [[NSMutableString alloc] init];
    srand((unsigned)time(0));
    for (int i = 0; i < kNumber; i++)
    {
        unsigned index = rand() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }
    return resultStr;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

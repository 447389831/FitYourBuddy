//
//  HttpTask.m
//  FitYourBuddy
//
//  Created by 陈文琦 on 15/8/12.
//  Copyright (c) 2015年 xpz. All rights reserved.
//

#import "HttpTask.h"
#import "HttpHelper.h"
#import "AppCore.h"

@interface HttpTask ()

@property (nonatomic, strong) NSMutableDictionary   *fieldsToBePosted;
@property (nonatomic, strong) NSMutableArray        *filesToBePosted;
@property (nonatomic, strong) NSMutableArray        *dataToBePosted;

@end

@implementation HttpTask

#pragma mark -
#pragma mark 生命周期

/** 初始化一个HTTP请求 */
- (instancetype)initWithURLString:(NSString *)aURLString
                       httpMethod:(NSString *)method
                         received:(TaskOnReceived)receivedBlock
                            error:(TaskOnError)errorBlock {
    self = [super init];
    if (self) {
        self.httpTaskState = HttpTaskStateReady;
        
        self.aURLString = aURLString;
        self.httpMethod = method;
        self.receivedBlock = receivedBlock;
        self.errorBlock = errorBlock;
        
        self.gzip = YES;
        
        self.timeout = APPCONFIG_CONN_TIMEOUT;
        
        self.recieveData = [NSMutableData new];
        
        self.filesToBePosted = [NSMutableArray array];
        self.dataToBePosted = [NSMutableArray array];
        NSDictionary *params = [aURLString httpGetMethodParams];
        self.fieldsToBePosted = [NSMutableDictionary dictionaryWithDictionary:params];
        
        [[AppCore sharedAppCore].appCoreQueue addOperation:self];
    }
    return self;
}

//释放资源
- (void)dealloc {
    [self stopLoading];
    self.urlRequest = nil;
}

- (void)start {
    if (self.isCancelled) {
        self.httpTaskState = HttpTaskStateFinished;
        return;
    }
    
    [HttpHelper showNetworkIndicator];
    
    //开启网络
    [self doStartRequest];
    
    self.httpTaskState = HttpTaskStateExecuting;
}

- (void)doStartRequest {
    if ([NSThread currentThread] != [NSThread mainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self doStartRequest];
        });
    } else {//保证主线程执行
        NSURL *aURL = nil;
        if ([self.httpMethod isEqualToString:@"POST"]) {
            NSString *domainURL = [self.aURLString httpGetMethodDomain];
            aURL = [NSURL URLWithString:domainURL];
        } else {
            aURL = [NSURL URLWithString:self.aURLString];
            //使用get方法传入code有xxx|xxx这种带“|”的会使url初始化失败。
            if (aURL == nil) {
                NSString *newUrlString = [self.aURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                aURL = [NSURL URLWithString:newUrlString];
            }
        }
        
        self.urlRequest = [NSMutableURLRequest requestWithURL:aURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeout];
        
        [self.urlRequest setHTTPMethod:self.httpMethod];
        
        if ([self.httpMethod isEqualToString:@"POST"]) {
            [self.urlRequest setHTTPBody:[self bodyData]];
        }
        
        /** 不支持cookies */
        [self.urlRequest setHTTPShouldHandleCookies:NO];
        
        /** 固定代理 */
        [self.urlRequest setValue:@"IOS_Version" forHTTPHeaderField:@"User-Agent"];
        
        //gzip
        if (self.gzip) {
            [self.urlRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        }
        
        //网络请求
        self.urlConnection = [[NSURLConnection alloc] initWithRequest:self.urlRequest
                                                             delegate:self
                                                     startImmediately:NO];
        
        [self.urlConnection scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                      forMode:NSRunLoopCommonModes];
        
        [self.urlConnection start];
    }
}

- (void)cancel {
    if (self.isFinished) {
        return;
    }
    
    self.receivedBlock = nil;
    self.errorBlock = nil;
    [self.urlConnection cancel];
    
    [super cancel];
}

- (BOOL)isReady {
    return (_httpTaskState == HttpTaskStateReady && [super isReady]);
}

- (BOOL)isFinished {
    return (_httpTaskState == HttpTaskStateFinished);
}

- (BOOL)isExecuting {
    return (_httpTaskState == HttpTaskStateExecuting);
}

//设置状态
- (void)setHttpTaskState:(HttpTaskState)networkOperationState {
    @synchronized(self){
        switch (networkOperationState) {
            case HttpTaskStateReady:
                [self willChangeValueForKey:@"isReady"];
                break;
            case HttpTaskStateExecuting:
                [self willChangeValueForKey:@"isReady"];
                [self willChangeValueForKey:@"isExecuting"];
                break;
            case HttpTaskStateFinished:
                [self willChangeValueForKey:@"isExecuting"];
                [self willChangeValueForKey:@"isFinished"];
                break;
        }
        
        _httpTaskState = networkOperationState;
        
        switch (networkOperationState) {
            case HttpTaskStateReady:
                [self didChangeValueForKey:@"isReady"];
                break;
            case HttpTaskStateExecuting:
                [self didChangeValueForKey:@"isReady"];
                [self didChangeValueForKey:@"isExecuting"];
                break;
            case HttpTaskStateFinished:
                [self didChangeValueForKey:@"isExecuting"];
                [self didChangeValueForKey:@"isFinished"];
                break;
        }
    }
}

#pragma mark -
#pragma mark 网络方法
//终止数据加载
- (void)stopLoading {
    [self onFinished:nil];
    
    if(self.httpTaskState == HttpTaskStateExecuting) {
        self.httpTaskState = HttpTaskStateFinished;
    }
}

//请求结束时调用的事件，只调用一次
- (void)onFinished:(NSError *)error {
    if (self.completed) {
        return;
    }
    
    if ([NSThread currentThread] != [NSThread mainThread]) {
        dispatch_sync(dispatch_get_main_queue(),^{
            [self onFinished:error];
        });
    } else {
        [HttpHelper hiddenNetworkIndicator];
        
        //加载完毕
        self.completed = YES;
        
        //错误
        self.httpError = error;
        
        if (error) {
            if (self.errorBlock) {
                self.errorBlock(self, error);
            }
        } else {
            if (self.receivedBlock) {
                self.receivedBlock(self, self.recieveData);
            }
        }
        
        [self cancel];
    }
}

#pragma mark -
#pragma mark 网络回调

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    return request;
}

//如果连接需要验证信息，则直接忽略
- (void)connection:(NSURLConnection *)conn didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

//收到HTTP请求头后触发的回调函数
- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response {
    //用setLength 这是个方法，不是属性
    [self.recieveData setLength:0];
    
    /** Get response code **/
    self.statusCode = [(NSHTTPURLResponse *)response statusCode];
    self.expectedContentLength = response.expectedContentLength;
    
    //>400都是错误码，在客户端中不需要对其有个别性的处理
    if (self.statusCode >= 400) {
        [self onHttpStatusCodeError:[response description]];
    }
}

//接收到一个数据报后的回调函数
- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data {
    if(!self.recieveData){
        return;
    }
    [self.recieveData appendData:data];
}

//当出现错误后的回调函数
- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error{
    self.httpError = error;
    if (nil != error) {
        [self onFinished:error];
    } else {
        [self onHttpStatusCodeError:nil];
    }
    
    self.httpTaskState = HttpTaskStateFinished;
}

//连接结束后的回调函数
- (void)connectionDidFinishLoading:(NSURLConnection *)conn{
    [self onFinished:nil];
    
    self.httpTaskState = HttpTaskStateFinished;
}

#pragma mark -
#pragma mark 私有方法

-(void) addFile:(NSString*) filePath forKey:(NSString*) key {
    [self addFile:filePath forKey:key mimeType:@"application/octet-stream"];
}

-(void) addFile:(NSString*) filePath forKey:(NSString*) key mimeType:(NSString*) mimeType {
    
    if ([self.urlRequest.HTTPMethod isEqualToString:@"GET"]) {
        [self.urlRequest setHTTPMethod:@"POST"];
    }
    
    NSDictionary *dict = @{@"filepath": filePath,
                           @"name": key,
                           @"mimetype": mimeType};
    
    [self.filesToBePosted addObject:dict];
}

-(void) addData:(NSData*) data forKey:(NSString*) key {
    
    [self addData:data forKey:key mimeType:@"application/octet-stream" fileName:@"file"];
}

-(void) addData:(NSData*) data forKey:(NSString*) key mimeType:(NSString*) mimeType fileName:(NSString*) fileName {
    
    if ([self.urlRequest.HTTPMethod isEqualToString:@"GET"]) {
        [self.urlRequest setHTTPMethod:@"POST"];
    }
    
    NSDictionary *dict = @{@"data": data,
                           @"name": key,
                           @"mimetype": mimeType,
                           @"filename": fileName};
    
    [self.dataToBePosted addObject:dict];
}

-(NSData*)bodyData {
    NSString *boundary = @"0xKhTmLbOuNdArY";
    NSMutableData *body = [NSMutableData data];
    //    __block NSUInteger postLength = 0;
    
    [self.fieldsToBePosted enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        
        NSString *thisFieldString = [NSString stringWithFormat:
                                     @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@",
                                     boundary, key, obj];
        
        [body appendData:[thisFieldString dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    [self.filesToBePosted enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSDictionary *thisFile = (NSDictionary*) obj;
        NSString *thisFieldString = [NSString stringWithFormat:
                                     @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\nContent-Transfer-Encoding: binary\r\n\r\n",
                                     boundary,
                                     thisFile[@"name"],
                                     [thisFile[@"filepath"] lastPathComponent],
                                     thisFile[@"mimetype"]];
        
        [body appendData:[thisFieldString dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData: [NSData dataWithContentsOfFile:thisFile[@"filepath"]]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    [self.dataToBePosted enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSDictionary *thisDataObject = (NSDictionary*) obj;
        NSString *thisFieldString = [NSString stringWithFormat:
                                     @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\nContent-Transfer-Encoding: binary\r\n\r\n",
                                     boundary,
                                     thisDataObject[@"name"],
                                     thisDataObject[@"filename"],
                                     thisDataObject[@"mimetype"]];
        
        [body appendData:[thisFieldString dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:thisDataObject[@"data"]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    //    if (postLength >= 1)
    //        [self.urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long) postLength] forHTTPHeaderField:@"Content-Length"];
    
    [body appendData: [[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    
    //    if(([self.filesToBePosted count] > 0) || ([self.dataToBePosted count] > 0)) {
    
    //Content type
    [self.urlRequest setValue:[NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", charset, boundary] forHTTPHeaderField:@"Content-Type"];
    
    [self.urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long) [body length]] forHTTPHeaderField:@"Content-Length"];
    //    }
    return body;
}

//设置 HTTP 请求头报错时的错误信息
- (void)onHttpStatusCodeError:(NSString *)errorDomain {
    if (errorDomain.length == 0) {
        errorDomain = [HttpHelper httpStatusErrorStr:self.statusCode];
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:0];
    userInfo[APPCONFIG_CONN_ERROR_MSG_DOMAIN] = errorDomain;
    
    NSError *statusError = [NSError errorWithDomain:APPCONFIG_CONN_ERROR_MSG_DOMAIN code:self.statusCode userInfo:userInfo];
    [self onFinished:statusError];
}

@end

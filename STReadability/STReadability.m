// 
// Copyright (c) 2011, Shun Takebayashi
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// 

#import "STReadability.h"

@interface STReadability ()

@property (copy) NSString *authorizationToken;

- (void)authorizeWithCompletionHandler:(void (^)(NSError *))handler;

@end

@implementation STReadability

- (void)getRequestForURL:(NSURL *)url
       completionHandler:(void (^)(NSURLRequest *, NSError *))handler {
    if (!self.authorizationToken) {
        [self authorizeWithCompletionHandler:^(NSError *error) {
            if (error) {
                handler(nil, error);
            }
            else {
                [self getRequestForURL:url
                     completionHandler:handler];
            }
        }];
    }
    else {
        NSURL *shortenUrl = [NSURL URLWithString:@"http://www.readability.com/~/"];
        NSMutableURLRequest *shortenRequest = [NSMutableURLRequest requestWithURL:shortenUrl];
        shortenRequest.HTTPMethod = @"POST";
        shortenRequest.HTTPBody = [[NSString stringWithFormat:
                                    @"url=%@",
                                    [url.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
                                   dataUsingEncoding:NSUTF8StringEncoding];
        [shortenRequest setValue:[NSString stringWithFormat:@"csrftoken=%@", self.authorizationToken]
              forHTTPHeaderField:@"Cookie"];
        [shortenRequest setValue:self.authorizationToken
              forHTTPHeaderField:@"X-CSRFToken"];
        [NSURLConnection sendAsynchronousRequest:shortenRequest
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *shortenResponse, NSData *shortenData, NSError *shortenError) {
                                   if (shortenError) {
                                       handler(nil, shortenError);
                                   }
                                   else {
                                       NSString *sessionToken;
                                       NSDictionary *headers = ((NSHTTPURLResponse *)shortenResponse).allHeaderFields;
                                       NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:headers
                                                                                                 forURL:shortenResponse.URL];
                                       for (NSHTTPCookie *cookie in cookies) {
                                           if ([cookie.name isEqualToString:@"sessionid"]) {
                                               sessionToken = cookie.value;
                                           }
                                       }
                                       NSDictionary *shortenJson = [NSJSONSerialization JSONObjectWithData:shortenData
                                                                                                   options:0
                                                                                                     error:NULL];
                                       NSString *articleIdentifier = [shortenJson objectForKey:@"shortened_id"];
                                       if (articleIdentifier) {
                                           NSURL *articleUrl = [NSURL URLWithString:
                                                                [@"http://www.readability.com/articles/" stringByAppendingString:articleIdentifier]];
                                           NSMutableURLRequest *articleRequest = [NSMutableURLRequest requestWithURL:articleUrl];
                                           [articleRequest setValue:[NSString stringWithFormat:@"sessionid=%@", sessionToken]
                                                 forHTTPHeaderField:@"Cookie"];
                                           handler(articleRequest, nil);
                                       }
                                       else {
                                           handler(nil, nil);
                                       }
                                   }
                               }];
    }
}

// MARK: Authorization

@synthesize authorizationToken;

- (void)authorizeWithCompletionHandler:(void (^)(NSError *))handler {
    NSURL *url = [NSURL URLWithString:@"http://www.readability.com/shorten"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPShouldHandleCookies:NO];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if (error) {
                                   self.authorizationToken = nil;
                                   handler(error);
                               }
                               else {
                                   NSDictionary *headers = ((NSHTTPURLResponse *)response).allHeaderFields;
                                   NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:headers
                                                                                             forURL:response.URL];
                                   for (NSHTTPCookie *cookie in cookies) {
                                       if ([cookie.name isEqualToString:@"csrftoken"]) {
                                           self.authorizationToken = cookie.value;
                                       }
                                   }
                                   handler(nil);
                               }
                           }];
}

@end

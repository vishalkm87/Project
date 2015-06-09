#import "FTPDownload.h"

#import <Cordova/CDV.h>

@interface FTPDownload ()<NSStreamDelegate,NSURLConnectionDataDelegate>

@property (nonatomic, strong, readwrite) NSInputStream *   networkStream;
@property (nonatomic, copy,   readwrite) NSString *        filePath;
@property (nonatomic, strong, readwrite) NSOutputStream *  fileStream;
@property (nonatomic, strong, readwrite) NSURLConnection * connection;
@end

@implementation FTPDownload
NSString*           callbackId;


-(void)getFile:(CDVInvokedUrlCommand*)command{
    NSLog(@"Inside the getFile :"); 
    CFUUIDRef   uuid;
    CFStringRef uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
  
    CFRelease(uuidStr);
    CFRelease(uuid); 
    
    NSURL *     url;
    NSString *  trimmedStr;
    NSRange     schemeMarkerRange;
    NSString *  scheme; 
    NSString *username = @"test";
    NSString *password = @"Google123!";
    NSString *filename = @"cdv_photo_008.jpg";
    NSString *server = @"ip/folder";
    NSString *str = [NSString stringWithFormat:@"ftp://%@:%@@%@/%@",
                     username, password, server, filename]; 
    
    self.filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Get-%@",filename]];
    assert( self.filePath != nil);
    
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && ([trimmedStr length] != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"ftp"  options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                url = [NSURL URLWithString:trimmedStr];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
     
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_filePath];
    if (callbackId) {
        //[self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId]; 
    
    self.fileStream = [NSOutputStream outputStreamToFileAtPath: self.filePath append:NO];
    assert(self.fileStream != nil);
    
    [self.fileStream open];
    
    // Open a CFFTPStream for the URL.
    //url = CFBridgingRelease( CFURLCreateCopyAppendingPathComponent(NULL, ( CFURLRef) url, ( CFStringRef) imageString , false));
    
    self.networkStream = CFBridgingRelease(
                                           CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                           );
    assert(self.networkStream != nil);
    
    self.networkStream.delegate = self;
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.networkStream open];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    
}
 
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
#pragma unused(aStream)
    assert(aStream == self.networkStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            NSLog(@"Opened connection");
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];
            
            NSLog(@"Receiving");
            
            // Pull some data off the network.
            
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                NSLog(@"Network read error");
            } else if (bytesRead == 0) {
                NSLog(@"Network read success");
                //self.getImageView.image = [UIImage imageWithContentsOfFile:self.filePath];
                
                return;
                //NSLog(@"16 %@",pluginResult);
                
            } else {
                NSInteger   bytesWritten;
                NSInteger   bytesWrittenSoFar;
                
                // Write to the file.
                
                bytesWrittenSoFar = 0;
                do {
                    bytesWritten = [self.fileStream write:&buffer[bytesWrittenSoFar] maxLength:(NSUInteger) (bytesRead - bytesWrittenSoFar)];
                    assert(bytesWritten != 0);
                    if (bytesWritten == -1) {
                        NSLog(@"File write error");
                        break;
                    } else {
                        bytesWrittenSoFar += bytesWritten;
                    }
                } while (bytesWrittenSoFar != bytesRead);
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            NSLog(@".....Stream open error");
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
// A delegate method called by the NSURLConnection as data arrives.  We just
// write the data to the file.
{
#pragma unused(theConnection)
    NSUInteger      dataLength;
    const uint8_t * dataBytes;
    NSInteger       bytesWritten;
    NSUInteger      bytesWrittenSoFar;
    
    assert(theConnection == self.connection);
    
    dataLength = [data length];
    dataBytes  = [data bytes];
    
    bytesWrittenSoFar = 0;
    do {
        bytesWritten = [self.fileStream write:&dataBytes[bytesWrittenSoFar] maxLength:dataLength - bytesWrittenSoFar];
        assert(bytesWritten != 0);
        if (bytesWritten <= 0) {
            NSLog(@".......File write error");
            // [self stopReceiveWithStatus:@"File write error"];
            break;
        } else {
            bytesWrittenSoFar += (NSUInteger) bytesWritten;
        }
    } while (bytesWrittenSoFar != dataLength);
}

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
// A delegate method called by the NSURLConnection when the request/response
// exchange is complete.
//
// For an HTTP request you would check [response statusCode] and [response MIMEType] to
// verify that this is acceptable data, but for an FTP request there is no status code
// and the type value is derived from the extension so you might as well pre-flight that.
//
// You could, use this opportunity to get [response expectedContentLength] and
// [response suggestedFilename], but I don't need either of these values for
// this sample.
{
#pragma unused(theConnection)
#pragma unused(response)
    
    assert(theConnection == self.connection);
    assert(response != nil);
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
// A delegate method called by the NSURLConnection if the connection fails.
// We shut down the connection and display the failure.  Production quality code
// would either display or log the actual error.
{
#pragma unused(theConnection)
#pragma unused(error)
    //  assert(theConnection == self.connection);
    NSLog(@".....Connection failed");
    NSLog(@"%@",error.localizedDescription);
    // [self stopReceiveWithStatus:@"Connection failed"];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
// A delegate method called by the NSURLConnection when the connection has been
// done successfully.  We shut down the connection with a nil status, which
// causes the image to be displayed.
{
#pragma unused(theConnection)
    assert(theConnection == self.connection); 
}

@end

#import "FtpUpload.h"
#import <Cordova/CDV.h>
#import "ListController.h"
#import "CreateDirController.h"


@class CreateDirController;

enum {
    kSendBufferSize = 32768
};

NSString*           callbackId;
NSError             *error;
CDVInvokedUrlCommand *command;
CDVPlugin *handler;


@implementation FtpUpload
{
    uint8_t                     _buffer[kSendBufferSize];
}


- (void)sendFile:(CDVInvokedUrlCommand*)command {
     
    methodStart = [NSDate date]; 
    NSDictionary *args = command.arguments[0];
    NSString *add = [NSString stringWithFormat:@"%@", [args objectForKey:@"address"]];
    NSString *userNAme = [args objectForKey:@"username"];
    NSString *pass = [args objectForKey:@"password"];
    NSString *rtId = [args objectForKey:@"routeId"]; 
    NSString *filepth = [args objectForKey:@"file"]; 
    
    callbackId = command.callbackId;
    self.callbackId = command.callbackId; 
    handler = self;
    
    if ([add isEqualToString:@""] || add == NULL || [userNAme isEqualToString:@""] || userNAme == NULL || [pass isEqualToString:@""] || pass == NULL || [filepth isEqualToString:@""] || filepth == NULL || [rtId isEqualToString:@""] || rtId == NULL) {
        
        [self returnError:@"Values are null"];
        
    }else{
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults] ;
        [defaults setObject:add forKey:@"address"];
        [defaults setObject:userNAme forKey:@"username"];
        [defaults setObject:pass forKey:@"password"];
        [defaults setObject:rtId forKey:@"routeId"];
        [defaults setObject:filepth forKey:@"filePath"];  
        address = add;
        usernames = userNAme;
        passwords = pass;
        filePaths = filepth;
        ListController *listController = [[ListController alloc]init];
        [listController startReceive:[self smartURLForString:address] withUsername:usernames andPassword:passwords];
    }
}

-(void) startUploadingFile{
    
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"hh:mm:ss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]]; 
    NSString *time = [dateFormatter stringFromDate:now]; 
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults] ;
    address = [defaults valueForKey:@"address"];
    usernames = [defaults valueForKey:@"username"];
    passwords = [defaults valueForKey:@"password"];
    filePaths = [defaults valueForKey:@"filePath"];
     
    NSDictionary *attributes = [[NSFileManager defaultManager]
                                attributesOfItemAtPath:filePaths error:&error];
    
    if (!error) {
        NSNumber *size = [attributes objectForKey:NSFileSize]; 
    }
    else { 
        NSLog(@"error.localizedDescription ==>>  %@",error.localizedDescription);
    }
    
    
    
    NSString *rtId = [defaults valueForKey:@"routeId"];  
    address = [address stringByAppendingString:[NSString stringWithFormat:@"%@/",rtId]]; 
    if (! self.isSending ) {
        [self startSend:filePaths toUrl:address withUsername:usernames andPassword:passwords];
    }
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart]; 
} 

- (void)startSend:(NSString *)filePath toUrl:(NSString *)urlText withUsername:(NSString *)username andPassword:(NSString *)password
{
    BOOL success;
    NSURL * url;
    
    assert(filePath != nil);
    assert([[NSFileManager defaultManager] fileExistsAtPath:filePath]); 
    assert(self.networkStream == nil); // don't tap send twice in a row!
    assert(self.fileStream == nil); // ditto
     
    
    url = [self smartURLForString:urlText];
    success = (url != nil);
    
    if (success) {
        // Add the last part of the file name to the end of the URL to form the final
        // URL that we're going to put to.
        
        url = CFBridgingRelease(
                                CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) [filePath lastPathComponent], false)
                                );
        success = (url != nil);
    }
    
    // If the URL is bogus, let the user know. Otherwise kick off the connection.
    
    if ( ! success) {
        NSLog(@"Invalid URL");
        [self returnError:@"Invalid URL"];
    } else {
        
        // Open a stream for the file we're going to send. We do not open this stream;
        // NSURLConnection will do it for us.
        
        self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
        assert(self.fileStream != nil);
        
        [self.fileStream open];
        
        // Open a CFFTPStream for the URL.
        
        self.networkStream = CFBridgingRelease(
                                               CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                               );
        assert(self.networkStream != nil);
        
        success = [self.networkStream setProperty:username forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        
        //Following line is causing trouble
        //[self.networkStream setProperty:(id)kCFBooleanFalse forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream open];
        
        [self sendDidStart];
    }
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
            assert(NO); // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            NSLog(@"Sending");
            
            // If we don't have any data buffered, go read the next chunk of data.
            
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger bytesRead;
                
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {
                    [self stopSendWithStatus:nil];
                    [self returnSuccess];
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
            [self returnSuccess];
        } break;
        default: {
            assert(NO);
        } break;
    }
}

- (void)stopSendWithStatus:(NSString *)statusString
{
    
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"hh:mm:ss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]]; 
    NSString *time = [dateFormatter stringFromDate:now]; 
    
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    
    // [self sendDidStopWithStatus:statusString];
    [self returnSuccess];
}

- (uint8_t *)buffer
{
    return self->_buffer;
}

- (BOOL)isSending
{
    return (self.networkStream != nil);
}


- (void)dealloc
{
    [self stopSendWithStatus:@"Stopped"];
};


#pragma mark Network manager utility functions

-(void)sendDidStart {
    
}

- (void)sendDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"Succeeded";
        NSLog(@"Upload Success");
        [self returnSuccess];
    } else {
        [self returnError:statusString];
    }
    
    
}

- (NSURL *)smartURLForString:(NSString *)str
{
    NSURL * result;
    NSString * trimmedStr;
    NSRange schemeMarkerRange;
    NSString * scheme;
    
    assert(str != nil);
    
    result = nil;
    
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && ([trimmedStr length] != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            result = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"ftp" options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedStr];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
    
    return result;
}


- (void) returnSuccess {
    
    NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
    [posError setObject: [NSNumber numberWithInt: CDVCommandStatus_OK] forKey:@"code"];
    [posError setObject: @"Success" forKey: @"message"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:posError];  
    [handler.commandDelegate sendPluginResult:result callbackId:callbackId];  
    
}


- (void)returnError:(NSString*)message
{
    NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
    [posError setObject: [NSNumber numberWithInt: CDVCommandStatus_ERROR] forKey:@"code"];
    [posError setObject: message ? message : @"" forKey: @"message"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError]; 
    [handler.commandDelegate sendPluginResult:result callbackId:callbackId]; 
}

@end
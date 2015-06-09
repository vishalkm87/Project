//
//  FtpUpload.h

//  FTPUploadnDirectoryUploadandDirectoryIpad
//
//  Created by Admin on 20/08/14.
//
//

#import <Cordova/CDV.h>

@interface FtpUpload : CDVPlugin <NSStreamDelegate>

{
    
    NSDate *methodStart;
    
    NSString *address;
    NSString *usernames;
    NSString *passwords;
    NSString *file;
    NSString *filePaths;
}

- (void)sendFile:(CDVInvokedUrlCommand*)command;

-(void)startUploadingFile ; 

@property (nonatomic, assign, readwrite ) BOOL              isSending;
@property (nonatomic, strong, readwrite) NSOutputStream *  networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *   fileStream;
@property (nonatomic, assign, readonly ) uint8_t *         buffer;
@property (nonatomic, assign, readwrite) size_t            bufferOffset;
@property (nonatomic, assign, readwrite) size_t            bufferLimit;
@property (nonatomic, strong) NSString* callbackId;
@end
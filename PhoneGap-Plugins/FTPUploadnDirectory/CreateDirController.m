/*
 File: CreateDirController.m
 Abstract: Manages the Create Dir tab.
 Version: 1.4
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "CreateDirController.h"
#import "FtpUpload.h"

#include <CFNetwork/CFNetwork.h>

@class FtpUpload;

@interface CreateDirController () <UITextFieldDelegate, NSStreamDelegate>

// Properties that don't need to be seen by the outside world.

@property (nonatomic, assign, readonly ) BOOL              isCreating;
@property (nonatomic, strong, readwrite) NSOutputStream *  networkStream;
@property (nonatomic,strong) FtpUpload *ftpUpload;
@end

@implementation CreateDirController

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.

- (void)createDidStart
{
    NSLog(@"createDidStart ==>> Folder Creating");
}

- (void)updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    NSLog(@"updateStatus ==>> status is %@",statusString);
}

- (void)createDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"Create succeeded";
    }   NSLog(@"createDidStopWithStatus ==>> status is %@",statusString);
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

- (BOOL)isCreating
{
    return (self.networkStream != nil);
}

- (void)startCreate :(NSURL *)url withUsername:(NSString *)username andPassword:(NSString *)password;

{
    BOOL                    success;
    success = (url != nil);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *rtId = [defaults valueForKey:@"routeId"];  
    
    if (success) {
        // Add the directory name to the end of the URL to form the final URL
        // that we're going to create.  CFURLCreateCopyAppendingPathComponent will
        // percent encode (as UTF-8) any wacking characters, which is the right thing
        // to do in the absence of application-specific knowledge about the encoding
        // expected by the server.
       
        url = CFBridgingRelease(
                                CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) rtId, true)
                                );
        success = (url != nil);
    }
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        // self.statusLabel.text = @"Invalid URL";
        NSLog(@"Invalid URL ==>> Invalid URL");
    } else {
        
        // Open a CFFTPStream for the URL.
        
        self.networkStream = CFBridgingRelease(
                                               CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                               );
        assert(self.networkStream != nil);
        
        // if ([self.usernameText.text length] != 0) {
        success = [self.networkStream setProperty:username forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        // }
        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream open];
        
        // Tell the UI we're creating.
        
        [self createDidStart];
    }
}

- (void)stopCreateWithStatus:(NSString *)statusString
{
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    self.ftpUpload = [[FtpUpload alloc]init];
    [self.ftpUpload startUploadingFile];
    [self createDidStopWithStatus:statusString];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
#pragma unused(aStream)
    assert(aStream == self.networkStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self updateStatus:@"Opened connection"];
            NSLog(@"stream open ==>> Opened connection");
            // Despite what it says in the documentation <rdar://problem/7163693>,
            // you should wait for the NSStreamEventEndEncountered event to see
            // if the directory was created successfully.  If you shut the stream
            // down now, you miss any errors coming back from the server in response
            // to the MKD command.
            //
            // [self stopCreateWithStatus:nil];
        } break;
        case NSStreamEventHasBytesAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);
        } break;
        case NSStreamEventErrorOccurred: {
            CFStreamError   err;
            
            // -streamError does not return a useful error domain value, so we
            // get the old school CFStreamError and check it.
            
            err = CFWriteStreamGetError( (__bridge CFWriteStreamRef) self.networkStream );
            if (err.domain == kCFStreamErrorDomainFTP) {
                [self stopCreateWithStatus:[NSString stringWithFormat:@"FTP errors ==>> FTP errors %d", (int) err.error]];
            } else {
                [self stopCreateWithStatus:@"Stream open error"];
            }
        } break;
        case NSStreamEventEndEncountered: {
            [self stopCreateWithStatus:nil];
        } break;
        default: {
            assert(NO);
        } break;
    }
}

- (void)dealloc
{
    [self stopCreateWithStatus:@"Stopped"];
};

@end

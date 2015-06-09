/*
     File: ListController.m
 Abstract: Manages the List tab.
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

#import "ListController.h"
#import "CreateDirController.h"
#import "FtpUpload.h"

//#import "NetworkManager.h"

#include <sys/socket.h>
#include <sys/dirent.h>

#include <CFNetwork/CFNetwork.h>

#pragma mark * ListController

@interface ListController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, NSStreamDelegate> {
    
    NSMutableArray *directoriesList;
}

- (IBAction)listOrCancelAction:(id)sender;

// Properties that don't need to be seen by the outside world.

@property (nonatomic, assign, readonly ) BOOL              isReceiving;
@property (nonatomic, strong, readwrite) NSInputStream *   networkStream;
@property (nonatomic, strong, readwrite) NSMutableData *   listData;
@property (nonatomic, strong, readwrite) NSMutableArray *  listEntries;
@property (nonatomic, copy,   readwrite) NSString *        status;

- (void)updateStatus:(NSString *)statusString;

@end

@implementation ListController

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.

- (void)receiveDidStart
{
    // Clear the current image so that we get a nice visual cue if the receive fails.
    [self.listEntries removeAllObjects];
    NSLog(@" receiveDidStart ==>> status is %@", self.status);
    [self updateStatus:@"Receiving"];
  
}

- (void)updateStatus:(NSString *)statusString
{
    int j = 0;
    assert(statusString != nil);
    self.status = statusString;
    
    if ([self.status isEqualToString:@"List succeeded"]) {
        
    NSDictionary * listEntry;
    for (int i = 0; i < [self.listEntries count]; i++) {
        listEntry = [self.listEntries objectAtIndex:i];
        assert([listEntry isKindOfClass:[NSDictionary class]]);
        [directoriesList addObject:[listEntry objectForKey:(id) kCFFTPResourceName]];
        
        NSLog( @" updateStatusresource list is ==>> %@",[listEntry objectForKey:(id) kCFFTPResourceName]);
        
        NSString *folderList =[listEntry objectForKey:(id) kCFFTPResourceName];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        NSString *rtId = [defaults valueForKey:@"routeId"];

        if([folderList isEqualToString:rtId]){
            
            NSLog(@" folderList ==>> Got file name ");
            
            j = 1;
        }
       
    }
        if (j==1){
            FtpUpload *ftpUpload = [[FtpUpload alloc]init];
            [ftpUpload startUploadingFile];
            
        }else{
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *address = [defaults valueForKey:@"address"];
            NSString *usernames = [defaults valueForKey:@"username"];
            NSString *passwords = [defaults valueForKey:@"password"]; 
            CreateDirController *createDirController = [[CreateDirController alloc]init];
            [createDirController startCreate:[self smartURLForString:address] withUsername:usernames andPassword:passwords];
        }

    }
    
    NSLog(@"updateStatus status is ==>> %@", self.status);
    
    }

- (void)addListEntries:(NSArray *)newEntries
{
    assert(self.listEntries != nil);
    
    [self.listEntries addObjectsFromArray:newEntries];
     NSLog(@"addListEntries ==>> status is %@", self.status);
    
}

- (void)receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"List succeeded";
    }
    [self updateStatus:statusString];
   
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

- (BOOL)isReceiving
{
    return (self.networkStream != nil);
}

- (void)startReceive :(NSURL *)url withUsername:(NSString *)username andPassword:(NSString *)password;
    // Starts a connection to download the current URL.
{
    
    if (self.listEntries == nil) {
                self.listEntries = [NSMutableArray array];
                assert(self.listEntries != nil);
            }
        
    BOOL                success;
  
    assert(self.networkStream == nil);      // don't tap receive twice in a row!

    // First get and check the URL.
    success = (url != nil);

    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        [self updateStatus:@"Invalid URL"];
    } else {

        // Create the mutable data into which we will receive the listing.

        self.listData = [NSMutableData data];
        assert(self.listData != nil);
        // Open a CFFTPStream for the URL.

        self.networkStream = CFBridgingRelease(
            CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
        );
        assert(self.networkStream != nil);
        
        success = [self.networkStream setProperty:username forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);

        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream open];
        
        // Tell the UI we're receiving.
        
        [self receiveDidStart];
    }
    
   
}

- (void)stopReceiveWithStatus:(NSString *)statusString
    // Shuts down the connection and displays the result (statusString == nil) 
    // or the error status (otherwise).
{
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    [self receiveDidStopWithStatus:statusString];
    self.listData = nil;
}

- (NSDictionary *)entryByReencodingNameInEntry:(NSDictionary *)entry encoding:(NSStringEncoding)newEncoding
    // CFFTPCreateParsedResourceListing always interprets the file name as MacRoman, 
    // which is clearly bogus <rdar://problem/7420589>.  This code attempts to fix 
    // that by converting the Unicode name back to MacRoman (to get the original bytes; 
    // this works because there's a lossless round trip between MacRoman and Unicode) 
    // and then reconverting those bytes to Unicode using the encoding provided. 
{
    NSDictionary *  result;
    NSString *      name;
    NSData *        nameData;
    NSString *      newName;
    
    newName = nil;
    
    // Try to get the name, convert it back to MacRoman, and then reconvert it 
    // with the preferred encoding.
    
    name = [entry objectForKey:(id) kCFFTPResourceName];
    if (name != nil) {
        assert([name isKindOfClass:[NSString class]]);
        
        nameData = [name dataUsingEncoding:NSMacOSRomanStringEncoding];
        if (nameData != nil) {
            newName = [[NSString alloc] initWithData:nameData encoding:newEncoding];
        }
    }
    
    // If the above failed, just return the entry unmodified.  If it succeeded, 
    // make a copy of the entry and replace the name with the new name that we 
    // calculated.
    
    if (newName == nil) {
        assert(NO);                 // in the debug builds, if this fails, we should investigate why
        result = (NSDictionary *) entry;
    } else {
        NSMutableDictionary *   newEntry;
        
        newEntry = [entry mutableCopy];
        assert(newEntry != nil);
        
        [newEntry setObject:newName forKey:(id) kCFFTPResourceName];
        
        result = newEntry;
    }
    
    return result;
}

- (void)parseListData
{
    NSMutableArray *    newEntries;
    NSUInteger          offset;
    
    // We accumulate the new entries into an array to avoid a) adding items to the 
    // table one-by-one, and b) repeatedly shuffling the listData buffer around.
    
    newEntries = [NSMutableArray array];
    assert(newEntries != nil);
    
    offset = 0;
    do {
        CFIndex         bytesConsumed;
        CFDictionaryRef thisEntry;
        
        thisEntry = NULL;
        
        assert(offset <= [self.listData length]);
        bytesConsumed = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *) self.listData.bytes)[offset], (CFIndex) ([self.listData length] - offset), &thisEntry);
        if (bytesConsumed > 0) {

            // It is possible for CFFTPCreateParsedResourceListing to return a 
            // positive number but not create a parse dictionary.  For example, 
            // if the end of the listing text contains stuff that can't be parsed, 
            // CFFTPCreateParsedResourceListing returns a positive number (to tell 
            // the caller that it has consumed the data), but doesn't create a parse 
            // dictionary (because it couldn't make sense of the data).  So, it's 
            // important that we check for NULL.

            if (thisEntry != NULL) {
                NSDictionary *  entryToAdd;
                
                // Try to interpret the name as UTF-8, which makes things work properly 
                // with many UNIX-like systems, including the Mac OS X built-in FTP 
                // server.  If you have some idea what type of text your target system 
                // is going to return, you could tweak this encoding.  For example, 
                // if you know that the target system is running Windows, then 
                // NSWindowsCP1252StringEncoding would be a good choice here.
                // 
                // Alternatively you could let the user choose the encoding up 
                // front, or reencode the listing after they've seen it and decided 
                // it's wrong.
                //
                // Ain't FTP a wonderful protocol!

                entryToAdd = [self entryByReencodingNameInEntry:(__bridge NSDictionary *) thisEntry encoding:NSUTF8StringEncoding];
                
                [newEntries addObject:entryToAdd];
            }
            
            // We consume the bytes regardless of whether we get an entry.
            
            offset += (NSUInteger) bytesConsumed;
        }
        
        if (thisEntry != NULL) {
            CFRelease(thisEntry);
        }
        
        if (bytesConsumed == 0) {
            // We haven't yet got enough data to parse an entry.  Wait for more data 
            // to arrive.
            break;
        } else if (bytesConsumed < 0) {
            // We totally failed to parse the listing.  Fail.
            [self stopReceiveWithStatus:@"Listing parse failed"];
            break;
        }
    } while (YES);

    if ([newEntries count] != 0) {
        [self addListEntries:newEntries];
    }
    if (offset != 0) {
        [self.listData replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
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
            [self updateStatus:@"Opened connection"];
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];

            [self updateStatus:@"Receiving"];
            
            // Pull some data off the network.
            
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead < 0) {
                [self stopReceiveWithStatus:@"Network read error"];
            } else if (bytesRead == 0) {
                [self stopReceiveWithStatus:nil];
            } else {
                assert(self.listData != nil);
                
                // Append the data to our listing buffer.
                
                [self.listData appendBytes:buffer length:(NSUInteger) bytesRead];
                
                // Check the listing buffer for any complete entries and update 
                // the UI if we find any.
                
                [self parseListData];
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopReceiveWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
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



 - (void)dealloc
{
    [self stopReceiveWithStatus:@"Stopped"];
};

@end

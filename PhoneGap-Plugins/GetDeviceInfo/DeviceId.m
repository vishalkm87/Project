#import "DeviceId.h"

@implementation DeviceId

-(void) getId:(CDVInvokedUrlCommand *)command{
    
    NSLog(@"getId function in IOS");
    NSLog(@"uniqueIdentifier: %@", [[UIDevice currentDevice] uniqueIdentifier]);
    NSLog(@"name: %@", [[UIDevice currentDevice] name]);
    NSLog(@"systemName: %@", [[UIDevice currentDevice] systemName]);
    NSLog(@"systemVersion: %@", [[UIDevice currentDevice] systemVersion]);
    NSLog(@"model: %@", [[UIDevice currentDevice] model]);
    NSLog(@"localizedModel: %@", [[UIDevice currentDevice] localizedModel]); 
    NSString *vendorId; 
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        
        vendorId =  [[[UIDevice currentDevice] identifierForVendor] UUIDString]; 
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:vendorId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"not supported"] callbackId:command.callbackId];
        
    }
    
    NSString *versionString = [[UIDevice currentDevice] systemVersion];  
   
}

@end
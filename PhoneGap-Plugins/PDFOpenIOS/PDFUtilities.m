#import "PDFUtilities.h"


@interface PDFUtilities()

@property (strong, nonatomic) UIDocumentInteractionController *documentInteractionController;

@end


@implementation PDFUtilities

- (void)viewPdf:(CDVInvokedUrlCommand*)command
{   
    if (command.arguments[0] == (id)[NSNull null])
    {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
        return;
    }

    NSString *url = command.arguments[0];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,(unsigned long)NULL), ^(void)
    {
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *file = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"PDF.pdf"]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];

        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
        {
           NSLog(@"pdf downloaded, opening...");

           NSData *pdf = data;

           CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pdf);
           CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);

           if (document == nil) {
               // error
           }
           else 
           {
               NSURL *localURL = [NSURL fileURLWithPath:file];

               [pdf writeToFile:file options:NSDataWritingAtomic error:&error];

                self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:localURL];
               [self.documentInteractionController setDelegate:self];
               [self.documentInteractionController presentPreviewAnimated:NO];

           }

           CGDataProviderRelease(provider);
           CGPDFDocumentRelease(document);
        }]; 
    });

    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

- (UIViewController*) documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
    return  [[[[UIApplication sharedApplication] delegate] window] rootViewController];
}
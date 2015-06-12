#import <Cordova/CDVPlugin.h>

@interface PDFUtilities : CDVPlugin <UIDocumentInteractionControllerDelegate>

- (void)viewPdf:(CDVInvokedUrlCommand*)command;

@end
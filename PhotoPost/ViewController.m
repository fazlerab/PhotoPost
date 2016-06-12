//
//  ViewController.m
//  PhotoPost
//
//  Created by Imran on 2/11/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>
#import "ViewController.h"

@interface ViewController ()  <FBSDKLoginButtonDelegate, FBSDKSharingDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet FBSDKProfilePictureView *profilePicture;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *email;
@property (weak, nonatomic) IBOutlet UIImageView *pickedImageView;
@property (weak, nonatomic) IBOutlet UITextField *photoDescriptionTextField;
@property (weak, nonatomic) IBOutlet UIButton *postButton;
@property (weak, nonatomic) IBOutlet FBSDKLoginButton *loginButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.profilePicture.layer.borderWidth = 1.0f;
    self.profilePicture.layer.borderColor = [UIColor grayColor].CGColor;
    
    self.pickedImageView.layer.borderWidth = 1.0f;
    self.pickedImageView.layer.borderColor = [UIColor grayColor].CGColor;
    
    self.photoDescriptionTextField.layer.borderWidth = 1.0f;
    self.photoDescriptionTextField.layer.borderColor = [UIColor grayColor].CGColor;
    
    self.postButton.layer.cornerRadius = 3.0f;
    [self.postButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    self.postButton.enabled = NO;

    self.status.text = @"You are logged out.";
    [self doHideUserInfo:YES];
    [self setupLogin];
}

- (void)setupLogin {
    self.loginButton.delegate = self;
    self.loginButton.readPermissions = @[@"public_profile", @"email"];

    NSLog(@"currentAccessToken=%@", [FBSDKAccessToken currentAccessToken]);
    if ([FBSDKAccessToken currentAccessToken]) {
        self.status.text = @"You are logged in.";
        [self fetchNameAndEmail];
    }
}

- (BOOL)loginButtonWillLogin:(FBSDKLoginButton *)loginButton {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.status.text = @"Logging in...";
    return YES;
}

- (void) loginButton:(FBSDKLoginButton *)loginButton didCompleteWithResult:(FBSDKLoginManagerLoginResult *)result error:(NSError *)error {
    NSLog(@"%@ result=%@\terror=%@", NSStringFromSelector(_cmd), result, error);
    
    if (error) {
        NSLog(@"Login Error: %@", error.localizedDescription);
        return;
    }
    
    if (!result.isCancelled) {
        self.status.text = @"You are logged in.";
        [self fetchNameAndEmail];
    }
    else {
        self.status.text = @"You are logged out.";
        self.postButton.enabled = NO;
    }
}

- (void) loginButtonDidLogOut:(FBSDKLoginButton *)loginButton {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.status.text = @"You are logged out.";
    [self doHideUserInfo:YES];
}

- (void)fetchNameAndEmail{
    if([FBSDKAccessToken currentAccessToken]) {
        NSDictionary *parameters = @{@"fields": @"name,email"};
        
        [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:parameters]
         startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
             if (!error) {
                 if ([result isKindOfClass:[NSDictionary class]]) {
                     NSDictionary *resultDict = (NSDictionary *)result;
                     
                     self.name.text = resultDict[@"name"];
                     self.email.text = resultDict[@"email"];
                     
                     [self doHideUserInfo:NO];
                 }
             }
             else {
                 NSLog(@"Fetch Error: %@", error.localizedDescription);
             }
        }];
    }
}

- (void)doHideUserInfo:(BOOL)hide {
    self.postButton.enabled = !hide;

    self.name.hidden = hide;
    self.email.hidden = hide;
    
    if (hide) {
        self.name.text = @"";
        self.email.text = @"";
    }
}

// MARK: ImagePicker methods
- (IBAction)showMediaBrowser {
    [self startMediaBrowserFromViewController:self
                                usingDelegate:self];
}

- (BOOL)startMediaBrowserFromViewController:(UIViewController *)controller
                              usingDelegate:(id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)delegate {
    if (([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] == NO) || (delegate == nil) || (controller == nil)) {
        return NO;
    }
    
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    mediaUI.mediaTypes = @[(NSString *)kUTTypeImage];
    mediaUI.allowsEditing = YES;
    mediaUI.delegate = delegate;
    
    [controller presentViewController:mediaUI animated:YES completion:nil];
    
    return YES;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToUse;
    
    if (CFStringCompare((CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        editedImage = info[UIImagePickerControllerEditedImage];
        originalImage = info[UIImagePickerControllerOriginalImage];
        
        if (editedImage) {
            imageToUse = editedImage;
        }
        else {
            imageToUse = originalImage ;
        }
        
        [self.pickedImageView setContentMode:UIViewContentModeScaleAspectFit];
        [self.pickedImageView setImage:imageToUse];
        
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// MARK: Post to timeline methods
- (IBAction)handlePost:(UIButton *)sender {
    UIImage *image = self.pickedImageView.image;
    
    if (image) {
        [self requestPermission:@"publish_actions" onSuccessPost:^{ [self post]; }];
        //[self requestPermission:@"publish_actions" onSuccessPost:^{ [self postPhoto]; }];
    }
}

- (void) requestPermission:(NSString *)permission onSuccessPost:(void(^)(void))post {
    if ([[FBSDKAccessToken currentAccessToken] hasGranted:permission]) {
        post();
    }
    else {
        FBSDKLoginManager *loginManager = [[FBSDKLoginManager alloc] init];
        [loginManager logInWithPublishPermissions:@[permission] fromViewController:self handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            }
            else if ([result.grantedPermissions containsObject:permission]) {
                post();
            }
        }];
    }
}

- (void)post {
    UIImage *image = self.pickedImageView.image;
    
    NSString *caption = self.photoDescriptionTextField.text;
    caption = [caption stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"source"] = image;
    
    if (![caption isEqualToString:@""]) {
        parameters[@"caption"] = caption;
    }
    
    FBSDKGraphRequest *graphRequest = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/photos"
                                                                        parameters:parameters
                                                                        HTTPMethod:@"POST"];
    [graphRequest startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            [self showAlertWithTitle:@"Fail" andMessage:[NSString stringWithFormat:@"%@", error.localizedDescription]];
        }
        else {
            NSLog(@"result=%@", result);
            [self showAlertWithTitle:@"Success" andMessage:@"Posted to your timeline."];
        }
    }];
}

- (void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message {
    UIAlertController *alertUI = [UIAlertController alertControllerWithTitle:title
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    
    [alertUI addAction:okAction];
    [self presentViewController:alertUI animated:YES completion:nil];
}

// MARK: FBSDKSharing methods
- (void)postPhoto {
    UIImage *imageToPost = self.pickedImageView.image;
    
    FBSDKSharePhoto *sharePhoto = [FBSDKSharePhoto photoWithImage:imageToPost userGenerated:YES];
    sharePhoto.caption = self.photoDescriptionTextField.text;
    
    FBSDKSharePhotoContent *photoContent = [[FBSDKSharePhotoContent alloc] init];
    photoContent.photos = @[sharePhoto];
    
    [FBSDKShareAPI shareWithContent:photoContent delegate:self];
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results {
    NSLog(@"%@\tresult=%@", NSStringFromSelector(_cmd), results);
    [self showAlertWithTitle:@"Success" andMessage:@"Photo posted to your timeline."];
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer {
    NSLog(@"%@", NSStringFromSelector(_cmd));   
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    [self showAlertWithTitle:@"Fail" andMessage:[NSString stringWithFormat:@"%@", error.localizedDescription]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

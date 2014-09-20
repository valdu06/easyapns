/***
 ** WARNING:
 **  1/ Remember to add the "AudioToolbox.framework" framework for your project.
 **  2/ Add this follow line (#import <AudioToolbox/AudioToolbox.h>)
 **/
#import <AudioToolbox/AudioToolbox.h>


/**
 * Add these global variables after the @implementation AppDelegate
 */
// !!! CHANGE "www.mywebsite.com" TO YOUR WEBSITE. Leave out the http://
// !!! SAMPLE: "secure.awesomeapp.com"
#define HOST @"www.mywebsite.com"
// !!! CHANGE "/path/of/install" TO THE PATH TO WHERE apns.php IS INSTALLED. Leave blank if it's at root.
// !!! ( MUST START WITH "/" character BUT MUST NOT END WITH "/" character ).
// !!! SAMPLE: "/path/to/install"
#define PATH_HOST @"/path/of/install"


/**
 * This is what you need to add to your applicationDidBecomeActive
 */
- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Add registration for remote notifications
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
    
    // Clear application badge when app launches
    application.applicationIconBadgeNumber = 0;
    [self resetBadgeServer];
}


/*
 * --------------------------------------------------------------------------------------------------------------
 *  BEGIN APNS CODE
 * --------------------------------------------------------------------------------------------------------------
 */

/**
 * Fetch and Format Device Token and Register Important Information to Remote Server
 */
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    
#if !TARGET_IPHONE_SIMULATOR
    
    // Get Bundle Info for Remote Registration (handy if you have more than one app)
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    NSUInteger rntypes;
    if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        rntypes = [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
    } else {
        rntypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    }
    
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = (rntypes & UIRemoteNotificationTypeBadge) ? @"enabled" : @"disabled";
    NSString *pushAlert = (rntypes & UIRemoteNotificationTypeAlert) ? @"enabled" : @"disabled";
    NSString *pushSound = (rntypes & UIRemoteNotificationTypeSound) ? @"enabled" : @"disabled";
    
    // Get the users Device Model, Display Name, Unique ID, Token & Version Number
    UIDevice *dev = [UIDevice currentDevice];
    NSString *deviceUuid;
    if ([dev respondsToSelector:@selector(identifierForVendor)])
        deviceUuid = dev.identifierForVendor.UUIDString;
        else {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            id uuid = [defaults objectForKey:@"deviceUuid"];
            if (uuid)
                deviceUuid = (NSString *)uuid;
            else {
                CFStringRef cfUuid = CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
                deviceUuid = (__bridge NSString *)cfUuid;
                CFRelease(cfUuid);
                [defaults setObject:deviceUuid forKey:@"deviceUuid"];
            }
        }
    NSString *deviceName = dev.name;
    NSString *deviceModel = dev.model;
    NSString *deviceSystemVersion = dev.systemVersion;
    
    // Prepare the Device Token for Registration (remove spaces and < >)
    NSString *deviceToken = [[[[devToken description]
                               stringByReplacingOccurrencesOfString:@"<"withString:@""]
                              stringByReplacingOccurrencesOfString:@">" withString:@""]
                             stringByReplacingOccurrencesOfString: @" " withString: @""];
    
    
    // Store deviceToken value in locals preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:deviceToken forKey:@"deviceToken"];
    [defaults synchronize];
    
    
    // Build URL String for Registration
    
    NSString *urlString = [NSString stringWithFormat:@"%@/apns.php?task=%@&appname=%@&appversion=%@&deviceuid=%@&devicetoken=%@&devicename=%@&devicemodel=%@&deviceversion=%@&pushbadge=%@&pushalert=%@&pushsound=%@", PATH_HOST, @"register", appName, appVersion, deviceUuid, deviceToken, deviceName, deviceModel, deviceSystemVersion, pushBadge, pushAlert, pushSound];
    
    // Register the Device Data
    // !!! CHANGE "http" TO "https" IF YOU ARE USING HTTPS PROTOCOL
    NSURL *url = [[NSURL alloc] initWithScheme:@"http" host:HOST path:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *urlReponse, NSData *returnData, NSError *error) {
                               NSLog(@"Return Data: %@", returnData);
                           }];
    NSLog(@"Register URL: %@", url);
    
#endif
}

/**
 * Failed to Register for Remote Notifications
 */
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
#if !TARGET_IPHONE_SIMULATOR
    
    NSLog(@"Error in registration. Error: %@", error);
    
#endif
}

/**
 * Remote Notification Received while application was open.
 */
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
#if !TARGET_IPHONE_SIMULATOR
    
    NSLog(@"remote notification: %@",[userInfo description]);
    NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
    
    NSString *alert = [apsInfo objectForKey:@"alert"];
    NSLog(@"Received Push Alert: %@", alert);
    
    NSString *sound = [apsInfo objectForKey:@"sound"];
    NSLog(@"Received Push Sound: %@", sound);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    NSString *badge = [apsInfo objectForKey:@"badge"];
    NSLog(@"Received Push Badge: %@", badge);
    application.applicationIconBadgeNumber = [[apsInfo objectForKey:@"badge"] integerValue];
    
    // Display an visual alert notification when application is running.
    UIAlertView *notificationAlert = [[UIAlertView alloc] initWithTitle:@"New notification" message:alert delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [notificationAlert show];
    
#endif
}

/**
 * Reset Badge number into database
 */
- (void)resetBadgeServer {
    // Reset the Device Badge on database
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *deviceToken = [defaults objectForKey:@"deviceToken"];
    
    NSString *urlResetBadgeString = [NSString stringWithFormat:@"%@/apns.php?task=%@&devicetoken=%@", PATH_HOST, @"reset", deviceToken];
    NSURL *urlResetBadge = [[NSURL alloc] initWithScheme:@"http" host:HOST path:urlResetBadgeString];
    NSURLRequest *requestResetBadge = [[NSURLRequest alloc] initWithURL:urlResetBadge];
    [NSURLConnection sendAsynchronousRequest:requestResetBadge queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *urlReponseResetBadge, NSData *returnDataResetBadge, NSError *errorResetBadge) {
        NSLog(@"Return Data: %@", returnDataResetBadge);
    }];
    NSLog(@"Reset URL: %@", urlResetBadge);
}

/*
 * --------------------------------------------------------------------------------------------------------------
 *  END APNS CODE
 * --------------------------------------------------------------------------------------------------------------
 */

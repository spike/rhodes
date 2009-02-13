//
//  AppManager.h
//  rhorunner
//
//  Created by vlad on 9/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface AppManager : NSObject {

	
}

+ (AppManager *)instance;
+ (NSString *) getApplicationsRootPath;
+ (NSString *) getApplicationsRosterUrl;
+ (bool) installApplication:(NSString*)appName data:(NSData*)appData;

- (void) copyFromMainBundle:(NSString *)item replace:(bool)replaceFiles;
- (void) configure;

@end

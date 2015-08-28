//
//  SNPHAssetPickerController.h
//  SNPHAssetPickerController
//
//  Created by Brian Gerfort on 27/08/15.
//  Copyright © 2015 2ndNature. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface SNPHAssetPickerController : UINavigationController

@property (nonatomic, assign) BOOL onlyImages;
@property (nonatomic, assign) NSInteger maximumPickableAssets;

- (instancetype)initWithDismissHandler:(void (^)(NSArray<PHAsset *> *pickedAssets, BOOL wasCancelled))dismissHandler;
- (void)cancelPicker:(id)sender;

@end

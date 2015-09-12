# SNPHAssetPickerController
Simple PHAsset picker for the Photos.framework

Example usage:

	SNPHAssetPickerController *picker = [[SNPHAssetPickerController alloc] initWithDismissHandler:^(NSArray<PHAsset *> *pickedAssets, BOOL includeRAW, BOOL wasCancelled) {
        
        if (wasCancelled == NO)
        {
            NSLog(@"Picked %@%@", pickedAssets, (includeRAW) ? @" (User wants RAW files too)" : @"");
        }
        
    }];
    [picker setOnlyImages:YES];
    [picker setAskToIncludeRAW:YES];
    [self presentViewController:picker animated:YES completion:nil];

To use it in your own project add the Photos.framework and the SNPHAssetPickerController.m/h files. That's it.

License Schmicense. Give me a shout-out in your app if you use it. Or don't. Up to you. :)

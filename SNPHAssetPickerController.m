//
//  SNPHAssetPickerController.m
//
//  Created by Brian Gerfort on 27/08/15.
//  Copyright © 2015 2ndNature. All rights reserved.
//

#import "SNPHAssetPickerController.h"

#define MAXIMUM_ITEM_SIZE   100.0

NSString * const SNPHAssetPickerAssetCellIdentifier = @"SNPHAssetPickerAssetCell";
NSString * const SNPHAssetPickerCollectionCellIdentifier = @"SNPHAssetPickerCollectionCell";

@interface SNPHAssetPickerController ()

@property (nonatomic, copy) void (^dismissHandler)(NSArray<PHAsset *> *pickedPhotos, BOOL includeRAW, BOOL wasCancelled);

- (void)pickedAssets:(NSArray *)assets includeRAW:(BOOL)includeRAW;

@end

#pragma mark - SNPHAssetPickerAssetCell

@interface SNPHAssetPickerAssetCell : UICollectionViewCell

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, assign) BOOL picked;

@end

@interface SNPHAssetPickerAssetCell ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *selectionImageView;
@property (nonatomic, strong) UIView *selectionOverlay;

@end

@implementation SNPHAssetPickerAssetCell

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        CGRect myRect = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
        self.imageView = [[UIImageView alloc] initWithFrame:myRect];
        [_imageView setContentMode:UIViewContentModeScaleAspectFill];
        [_imageView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
        [_imageView setClipsToBounds:YES];
        [self.contentView addSubview:_imageView];
        
        self.selectionOverlay = [[UIView alloc] initWithFrame:myRect];
        [_selectionOverlay setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
        [_selectionOverlay setBackgroundColor:[UIColor colorWithWhite:1.0 alpha:0.5]];
        [_selectionOverlay setHidden:YES];
        [self.contentView addSubview:_selectionOverlay];
        
        self.selectionImageView = [[UIImageView alloc] initWithFrame:CGRectMake(myRect.size.width - 30.0 - 3.0, myRect.size.height - 30.0 - 3.0, 30.0, 30.0)];
        [_selectionImageView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin)];
        [self.contentView addSubview:_selectionImageView];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [_imageView setImage:nil];
    [self setPicked:NO];
}

- (void)setPicked:(BOOL)picked
{
    if (_picked == picked) return;
    
    _picked = picked;
    
    if (_picked && _selectionImageView.image == nil)
    {
        [_selectionImageView setImage:[[self class] checkmarkImage]];
    }
    
    [_selectionOverlay setHidden:(!picked)];
    [_selectionImageView setHidden:(!picked)];
}

+ (UIImage *)checkmarkImage
{
    static dispatch_once_t pred;
    static UIImage *image = nil;
    
    dispatch_once(&pred, ^{
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(30.0, 30.0), NO, [UIScreen mainScreen].scale);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        UIColor *shadow = [UIColor colorWithWhite:0.0 alpha:0.2];
        CGSize shadowOffset = CGSizeMake(0.1, -0.1);
        CGFloat shadowBlurRadius = 5;
        
        UIBezierPath *badgeOutline = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 25, 25)];
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
        [[UIColor whiteColor] setFill];
        [badgeOutline fill];
        CGContextRestoreGState(context);
        
        UIBezierPath *badgeBackground = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(4, 4, 23, 23)];
        [[UIColor colorWithRed:0.0/255.0 green:102.0/255.0 blue:204.0/255.0 alpha:1.0] setFill];
        [badgeBackground fill];
        
        UIBezierPath *checkmarkPath = [UIBezierPath bezierPath];
        [checkmarkPath moveToPoint:CGPointMake(8.5, 16.5)];
        [checkmarkPath addLineToPoint:CGPointMake(12.5, 20.5)];
        [checkmarkPath addLineToPoint:CGPointMake(21.5, 11.5)];
        [checkmarkPath addLineToPoint:CGPointMake(20.5, 10.5)];
        [checkmarkPath addLineToPoint:CGPointMake(12.5, 18.5)];
        [checkmarkPath addLineToPoint:CGPointMake(9.5, 15.5)];
        [checkmarkPath addLineToPoint:CGPointMake(8.5, 16.5)];
        [checkmarkPath closePath];
        [[UIColor whiteColor] setFill];
        [checkmarkPath fill];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    });
    
    return image;
}

@end

#pragma mark - SNPHAssetPickerAssetsViewController

@interface SNPHAssetPickerAssetsViewController : UICollectionViewController

@property (nonatomic, strong) PHAssetCollection *collection;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, strong) NSMutableArray *picks;

@end

@implementation SNPHAssetPickerAssetsViewController

- (instancetype)initWithCollection:(PHAssetCollection *)collection
{
    if ((self = [super initWithCollectionViewLayout:[[UICollectionViewFlowLayout alloc] init]]))
    {
        [self setCollection:collection];
        [self setPicks:[NSMutableArray array]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:[self.collection localizedTitle]];
    [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", NULL) style:UIBarButtonItemStyleDone target:self action:@selector(pickAssets:)]];

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [self setToolbarItems:@[
                            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select All", NULL) style:UIBarButtonItemStylePlain target:self action:@selector(selectAll:)],
                            flexibleSpace,
                            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Invert", NULL) style:UIBarButtonItemStylePlain target:self action:@selector(invertSelection:)],
                            flexibleSpace,
                            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select None", NULL) style:UIBarButtonItemStylePlain target:self action:@selector(selectNone:)]
                            ]];
    
    [self.collectionView registerClass:[SNPHAssetPickerAssetCell class] forCellWithReuseIdentifier:SNPHAssetPickerAssetCellIdentifier];
    [self.collectionView setBackgroundColor:[UIColor whiteColor]];
    [self updateCollectionViewLayoutAnimated:NO];

    [self reloadAssets:self];

    [self updateNavigationItem];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([(SNPHAssetPickerController *)self.navigationController maximumPickableAssets] == NSIntegerMax)
    {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if ([(SNPHAssetPickerController *)self.navigationController maximumPickableAssets] == NSIntegerMax)
    {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        [self updateCollectionViewLayoutAnimated:YES];
        
    } completion:nil];
}

- (void)updateCollectionViewLayoutAnimated:(BOOL)animated
{
    NSUInteger minimumItemsPerRow = ceil(self.navigationController.view.frame.size.width / (float)MAXIMUM_ITEM_SIZE);
    CGFloat minimumSpacing = 1.0;
    CGFloat length = (self.navigationController.view.frame.size.width - ((minimumItemsPerRow - 1) * minimumSpacing)) / (float)minimumItemsPerRow;
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [layout setMinimumInteritemSpacing:minimumSpacing];
    [layout setMinimumLineSpacing:minimumSpacing];
    [layout setItemSize:CGSizeMake(length, length)];
    [self.collectionView setCollectionViewLayout:layout animated:animated];
}

- (void)reloadAssets:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSMutableArray *assets = [NSMutableArray array];
        NSMutableArray *tempArray = [NSMutableArray array];

        PHFetchOptions *fetchOptions = nil;
        if ([(SNPHAssetPickerController *)self.navigationController onlyImages])
        {
            fetchOptions = [PHFetchOptions new];
            fetchOptions.predicate = [NSPredicate predicateWithFormat:@"(mediaType = %d)", PHAssetMediaTypeImage];
        }
        
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:self.collection options:fetchOptions];
        [fetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [tempArray addObject:asset];
            
        }];
        [assets addObjectsFromArray:[tempArray sortedArrayUsingComparator:^NSComparisonResult(PHAsset *asset1, PHAsset *asset2) {
            
            return [[asset1 creationDate] compare:[asset2 creationDate]];
            
        }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.assets = assets;
            [self.collectionView reloadData];
            
            if ([assets count] > 0)
            {
                [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:[assets count] - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
            }
            
        });
    });
}

- (void)selectAll:(id)sender
{
    if ([self.picks count] == [self.assets count]) return;
    
    [self setPicks:[self.assets mutableCopy]];
    [self refreshPicksOnVisibleCells];
    [self updateNavigationItem];
}

- (void)invertSelection:(id)sender
{
    if ([self.picks count] == 0)
    {
        [self selectAll:sender];
    }
    else if ([self.picks count] == [self.assets count])
    {
        [self selectNone:sender];
    }
    else
    {
        NSMutableArray *picks = [NSMutableArray arrayWithCapacity:[self.assets count]];
        [self.assets enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if ([self.picks containsObject:asset] == NO)
            {
                [picks addObject:asset];
            }
            
        }];
        [self setPicks:picks];
        [self refreshPicksOnVisibleCells];
        [self updateNavigationItem];
    }
}

- (void)selectNone:(id)sender
{
    if ([self.picks count] == 0) return;
    
    [self setPicks:[NSMutableArray arrayWithCapacity:0]];
    [self refreshPicksOnVisibleCells];
    [self updateNavigationItem];
}

- (void)refreshPicksOnVisibleCells
{
    [[self.collectionView indexPathsForVisibleItems] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
        
        [(SNPHAssetPickerAssetCell *)[self.collectionView cellForItemAtIndexPath:indexPath] setPicked:[self.picks containsObject:[self.assets objectAtIndex:indexPath.row]]];
        
    }];
}

- (void)updateNavigationItem
{
    [self.navigationItem.rightBarButtonItem setEnabled:([self.picks count] > 0)];
    [self setTitle:([self.picks count] > 0) ? [NSString stringWithFormat:NSLocalizedString(@"%lu selected", NULL), [self.picks count]] : [self.collection localizedTitle]];
}

- (void)pickAssets:(id)sender
{
    NSArray *sortedAssets = [self.picks sortedArrayUsingComparator:^NSComparisonResult(PHAsset *asset1, PHAsset *asset2) {
        
        return [[asset1 creationDate] compare:[asset2 creationDate]];
        
    }];
    
    __block BOOL hasRAW = NO;
    if ([(SNPHAssetPickerController *)self.navigationController askToIncludeRAW])
    {
        [self.picks enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [[PHAssetResource assetResourcesForAsset:asset] enumerateObjectsUsingBlock:^(PHAssetResource *assetResource, NSUInteger idx, BOOL * _Nonnull stop) {

                if (assetResource.type == PHAssetResourceTypeAlternatePhoto)
                {
                    hasRAW = YES;
                    *stop = YES;
                }
                
            }];
            if (hasRAW)
            {
                *stop = YES;
            }
            
        }];
    }
    
    if (hasRAW)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Include RAW files", NULL) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            [(SNPHAssetPickerController *)self.navigationController pickedAssets:sortedAssets includeRAW:YES];
            
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Don't import RAW files", NULL) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            [(SNPHAssetPickerController *)self.navigationController pickedAssets:sortedAssets includeRAW:NO];
            
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", NULL) style:UIAlertActionStyleCancel handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [(SNPHAssetPickerController *)self.navigationController pickedAssets:sortedAssets includeRAW:NO];
    }
}

#pragma mark UICollectionView Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.assets count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat mainScreenScale = [UIScreen mainScreen].scale;
    SNPHAssetPickerAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:SNPHAssetPickerAssetCellIdentifier forIndexPath:indexPath];
    PHAsset *asset = [self.assets objectAtIndex:indexPath.row];
    [cell setPicked:[self.picks containsObject:asset]];
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(MAXIMUM_ITEM_SIZE * mainScreenScale, MAXIMUM_ITEM_SIZE * mainScreenScale) contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        
        [[(SNPHAssetPickerAssetCell *)[collectionView cellForItemAtIndexPath:indexPath] imageView] setImage:result];
        
    }];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self.assets objectAtIndex:indexPath.row];
    if ([self.picks containsObject:asset])
    {
        [self.picks removeObject:asset];
    }
    else
    {
        NSInteger maximumPickableAssets = [(SNPHAssetPickerController *)self.navigationController maximumPickableAssets];
        if ([self.picks count] < maximumPickableAssets)
        {
            [self.picks addObject:asset];
        }
        else
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:NSLocalizedString(@"You can only select %lu %@ at a time.", nil), maximumPickableAssets, (maximumPickableAssets == 1) ? NSLocalizedString(@"photo", NULL) : NSLocalizedString(@"photos", NULL)] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", NULL) style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
    
    [(SNPHAssetPickerAssetCell *)[collectionView cellForItemAtIndexPath:indexPath] setPicked:[self.picks containsObject:asset]];
    
    [self updateNavigationItem];
}

@end

#pragma mark - SNPHAssetPickerCollectionItem

@interface SNPHAssetPickerCollectionItem : NSObject

@property (nonatomic, strong) PHAssetCollection *collection;
@property (nonatomic, strong) NSArray<PHAsset *> *thumbnailAssets;
@property (nonatomic, assign) NSUInteger assetCount;

+ (SNPHAssetPickerCollectionItem *)collectionItemWithCollection:(PHAssetCollection *)assetCollection onlyImages:(BOOL)onlyImages;

@end

@implementation SNPHAssetPickerCollectionItem

+ (SNPHAssetPickerCollectionItem *)collectionItemWithCollection:(PHAssetCollection *)assetCollection onlyImages:(BOOL)onlyImages
{
    SNPHAssetPickerCollectionItem *collection = [SNPHAssetPickerCollectionItem new];
    collection.collection = assetCollection;

    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    if (onlyImages) fetchOptions.predicate = [NSPredicate predicateWithFormat:@"(mediaType = %d)", PHAssetMediaTypeImage];

    PHFetchResult *thumbnailFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:fetchOptions];
    
    collection.assetCount = [thumbnailFetchResult count];
    collection.thumbnailAssets = [thumbnailFetchResult objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, (collection.assetCount < 3) ? collection.assetCount : 3)]];
    
    return collection;
}

@end

#pragma mark - SNPHAssetPickerCollectionCell

@interface SNPHAssetPickerCollectionCell : UITableViewCell

@property (nonatomic, strong) SNPHAssetPickerCollectionItem *collectionItem;

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@end

@interface SNPHAssetPickerCollectionCell ()

@property (nonatomic, strong) UIImageView *imageView1;
@property (nonatomic, strong) UIImageView *imageView2;
@property (nonatomic, strong) UIImageView *imageView3;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;

@end

@implementation SNPHAssetPickerCollectionCell

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]))
    {
        self.imageView1 = [self newImageView];
        [self.contentView addSubview:_imageView1];
        
        self.imageView2 = [self newImageView];
        [self.contentView insertSubview:_imageView2 belowSubview:_imageView1];
        
        self.imageView3 = [self newImageView];
        [self.contentView insertSubview:_imageView3 belowSubview:_imageView2];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_titleLabel setFont:[UIFont systemFontOfSize:17.0]];
        [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.contentView addSubview:_titleLabel];
        
        self.countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_countLabel setFont:[UIFont systemFontOfSize:12.0]];
        [_countLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.contentView addSubview:_countLabel];
        
        [self.contentView addConstraints:@[
                                           [NSLayoutConstraint constraintWithItem:_imageView1 attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeTop multiplier:1.0 constant:10.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView1 attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:8.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView1 attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-10.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView1 attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0.0],
                                           
                                           [NSLayoutConstraint constraintWithItem:_imageView2 attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeTop multiplier:1.0 constant:-2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView2 attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeLeft multiplier:1.0 constant:2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView2 attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeRight multiplier:1.0 constant:-2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView2 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:_imageView2 attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.0],
                                           
                                           [NSLayoutConstraint constraintWithItem:_imageView3 attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_imageView2 attribute:NSLayoutAttributeTop multiplier:1.0 constant:-2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView3 attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_imageView2 attribute:NSLayoutAttributeLeft multiplier:1.0 constant:2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView3 attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_imageView2 attribute:NSLayoutAttributeRight multiplier:1.0 constant:-2.0],
                                           [NSLayoutConstraint constraintWithItem:_imageView3 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:_imageView3 attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.0],
                                           
                                           [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0],
                                           [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeRight multiplier:1.0 constant:17.0],
                                           
                                           [NSLayoutConstraint constraintWithItem:_countLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:5.0],
                                           [NSLayoutConstraint constraintWithItem:_countLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_imageView1 attribute:NSLayoutAttributeRight multiplier:1.0 constant:17.0]
                                           ]];
        
        [self setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    return self;
}

- (UIImageView *)newImageView
{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    [imageView setClipsToBounds:YES];
    [imageView setBackgroundColor:[UIColor colorWithRed:239.0/255.0 green:239.0/255.0 blue:244.0/255.0 alpha:1.0]];
    [imageView.layer setBorderWidth:0.5];
    [imageView.layer setBorderColor:[UIColor whiteColor].CGColor];
    [imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    return imageView;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.collectionItem = nil;
}

- (void)setCollectionItem:(SNPHAssetPickerCollectionItem *)collectionItem
{
    if (_collectionItem == collectionItem) return;
    
    _collectionItem = collectionItem;
    
    if ([_collectionItem isKindOfClass:[SNPHAssetPickerCollectionItem class]])
    {
        NSInteger thumbnailCount = [_collectionItem.thumbnailAssets count];
        
        [_titleLabel setText:[_collectionItem.collection localizedTitle]];
        [_countLabel setText:[NSString stringWithFormat:@"%lu", (unsigned long)_collectionItem.assetCount]];
        
        PHImageManager *imageManager = [PHImageManager defaultManager];
        CGFloat cellHeight = self.contentView.bounds.size.height;
        CGFloat mainScreenScale = [UIScreen mainScreen].scale;
        CGSize targetSize = (cellHeight > MAXIMUM_ITEM_SIZE * mainScreenScale) ? CGSizeMake(cellHeight, cellHeight) : CGSizeMake(MAXIMUM_ITEM_SIZE * mainScreenScale, MAXIMUM_ITEM_SIZE * mainScreenScale);
        if (thumbnailCount > 0)
        {
            [imageManager requestImageForAsset:[_collectionItem.thumbnailAssets objectAtIndex:0] targetSize:targetSize contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                
                [self.imageView1 setImage:result];
                
            }];
        }
        if (thumbnailCount > 1)
        {
            [imageManager requestImageForAsset:[_collectionItem.thumbnailAssets objectAtIndex:1] targetSize:targetSize contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                
                [self.imageView2 setImage:result];
                
            }];
        }
        if (thumbnailCount > 2)
        {
            [imageManager requestImageForAsset:[_collectionItem.thumbnailAssets objectAtIndex:2] targetSize:targetSize contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                
                [self.imageView3 setImage:result];
                
            }];
        }
    }
    else
    {
        [_titleLabel setText:@""];
        [_countLabel setText:@""];
        [_imageView1 setImage:nil];
        [_imageView2 setImage:nil];
        [_imageView3 setImage:nil];
    }
}

@end

#pragma mark - SNPHAssetPickerCollectionsViewController

@interface SNPHAssetPickerCollectionsViewController : UITableViewController

@property (nonatomic, strong) NSMutableArray<SNPHAssetPickerCollectionItem *> *assetCollections;

@end

@implementation SNPHAssetPickerCollectionsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"Albums", NULL)];
    
    [self.tableView setRowHeight:89.0];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [self setClearsSelectionOnViewWillAppear:YES];

    [self verifyAuthorizationStatus];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.navigationItem setLeftBarButtonItem:(self.presentingViewController.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassRegular) ? [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:(SNPHAssetPickerController *)self.navigationController action:@selector(cancelPicker:)] : nil];
}

- (void)verifyAuthorizationStatus
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined)
    {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
            [self verifyAuthorizationStatus];
            
        }];
    }
    else
    {
        switch (status)
        {
            case PHAuthorizationStatusRestricted:
            {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"The device settings does not allow access to the Photo Library.", NULL) message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", NULL) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

                    [(SNPHAssetPickerController *)self.navigationController cancelPicker:self];

                }]];
                [self presentViewController:alert animated:YES completion:nil];
                break;
            }
            default:
            case PHAuthorizationStatusDenied:
            {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please turn on access to the Photo Library from the settings.", NULL) message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", NULL) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    
                    [(SNPHAssetPickerController *)self.navigationController cancelPicker:self];
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];

                }]];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", NULL) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    
                    [(SNPHAssetPickerController *)self.navigationController cancelPicker:self];

                }]];
                [self presentViewController:alert animated:YES completion:nil];
                break;
            }
            case PHAuthorizationStatusAuthorized:
            {
                [self reloadCollections:self];
                break;
            }
        }
    }
}

- (void)reloadCollections:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

        BOOL onlyImages = [(SNPHAssetPickerController *)self.navigationController onlyImages];
        NSMutableArray *collections = [NSMutableArray array];
        NSMutableArray *tempArray = [NSMutableArray array];

        PHFetchOptions *fetchOptions = [PHFetchOptions new];
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:YES]]; // Huh. Doesn't work. That's why we're going with the tempArray sorting instead.
        fetchOptions.includeHiddenAssets = NO;

        // Smart albums
        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:fetchOptions];
        [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger idx, BOOL * _Nonnull stop) {
            
            SNPHAssetPickerCollectionItem *collectionItem = [SNPHAssetPickerCollectionItem collectionItemWithCollection:assetCollection onlyImages:onlyImages];
            if (collectionItem.assetCount > 0)
            {
                [tempArray addObject:collectionItem];
            }
            
        }];
        [collections addObjectsFromArray:[tempArray sortedArrayUsingComparator:^NSComparisonResult(SNPHAssetPickerCollectionItem *collItem1, SNPHAssetPickerCollectionItem *collItem2) {
            
            return [[collItem1.collection localizedTitle] caseInsensitiveCompare:[collItem2.collection localizedTitle]];
            
        }]];
        
        // Custom albums
        fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:fetchOptions];
        [tempArray removeAllObjects];
        [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger idx, BOOL * _Nonnull stop) {
            
            SNPHAssetPickerCollectionItem *collectionItem = [SNPHAssetPickerCollectionItem collectionItemWithCollection:assetCollection onlyImages:onlyImages];
            if (collectionItem.assetCount > 0)
            {
                [tempArray addObject:collectionItem];
            }
            
        }];
        [collections addObjectsFromArray:[tempArray sortedArrayUsingComparator:^NSComparisonResult(SNPHAssetPickerCollectionItem *collItem1, SNPHAssetPickerCollectionItem *collItem2) {
            
            return [[collItem1.collection localizedTitle] caseInsensitiveCompare:[collItem2.collection localizedTitle]];
            
        }]];

        dispatch_async(dispatch_get_main_queue(), ^{

            self.assetCollections = collections;
            [self.tableView reloadData];

        });
    });
}

#pragma mark UITableView Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.assetCollections count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (self.assetCollections == nil) ? 44.0 : [super tableView:tableView heightForFooterInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (self.assetCollections == nil)
    {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [spinner startAnimating];
        return spinner;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SNPHAssetPickerCollectionCell *cell = [tableView dequeueReusableCellWithIdentifier:SNPHAssetPickerCollectionCellIdentifier];
    if (cell == nil)
    {
        cell = [[SNPHAssetPickerCollectionCell alloc] initWithReuseIdentifier:SNPHAssetPickerCollectionCellIdentifier];
    }
    cell.collectionItem = [self.assetCollections objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SNPHAssetPickerAssetsViewController *assetPicker = [[SNPHAssetPickerAssetsViewController alloc] initWithCollection:[[self.assetCollections objectAtIndex:indexPath.row] collection]];
    [self.navigationController pushViewController:assetPicker animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

#pragma mark - SNPHAssetPickerController

@implementation SNPHAssetPickerController

- (instancetype)initWithDismissHandler:(void (^)(NSArray<PHAsset *> *pickedAssets, BOOL includeRAW, BOOL wasCancelled))dismissHandler
{
    if ((self = [super initWithRootViewController:[[SNPHAssetPickerCollectionsViewController alloc] initWithStyle:UITableViewStylePlain]]))
    {
        [self setModalPresentationStyle:UIModalPresentationFormSheet];
        [self setMaximumPickableAssets:NSIntegerMax];
        [self setDismissHandler:dismissHandler];
    }
    return self;
}

- (void)pickedAssets:(NSArray *)assets includeRAW:(BOOL)includeRAW
{
    [self dismissViewControllerAnimated:YES completion:^{
        
        if (self.dismissHandler != nil)
        {
            self.dismissHandler(assets, includeRAW, NO);
        }
        
    }];
}

- (void)cancelPicker:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        
        if (self.dismissHandler != nil)
        {
            self.dismissHandler(nil, NO, YES);
        }
        
    }];
}

@end

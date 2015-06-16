//
//  CollectionViewCell.h
//  MoltinSDK iOS Example
//
//  Created by Gasper Rebernak on 15/06/15.
//  Copyright (c) 2015 Gasper Rebernak. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CollectionListCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *lbTitle;

- (void)configureWithCollectionDict:(NSDictionary *) dictionary;

@end

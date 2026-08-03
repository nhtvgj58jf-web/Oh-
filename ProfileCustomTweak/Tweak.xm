#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// ============================================================
// MARK: - Configuration helpers
// ============================================================

static NSDictionary *PCTLoadConfig(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths firstObject];
    NSString *configPath = [documentsPath stringByAppendingPathComponent:@"PCTConfig.plist"];
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (!config) {
        config = @{
            @"backgroundImagePath": @"",
            @"backgroundVideoPath": @""
        };
    }
    return config;
}

static UIFont *PCTLoadCustomFont(CGFloat size) {
    UIFont *customFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
    if (!customFont) {
        customFont = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
    }
    return customFont;
}

// ============================================================
// MARK: - Background layer
// ============================================================

@interface PCTBackgroundView : UIView
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation PCTBackgroundView

- (void)configureWithConfig:(NSDictionary *)config {
    for (UIView *sub in self.subviews) [sub removeFromSuperview];
    self.player = nil;
    if (self.playerLayer) { [self.playerLayer removeFromSuperlayer]; self.playerLayer = nil; }

    NSString *videoPath = config[@"backgroundVideoPath"];
    NSString *imagePath = config[@"backgroundImagePath"];

    if (videoPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        NSURL *url = [NSURL fileURLWithPath:videoPath];
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        self.player = [AVPlayer playerWithPlayerItem:item];
        self.player.muted = YES;
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.playerLayer.frame = self.bounds;
        [self.layer insertSublayer:self.playerLayer atIndex:0];

        [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                           object:item
                                                            queue:nil
                                                       usingBlock:^(NSNotification * _Nonnull note) {
            [self.player seekToTime:kCMTimeZero];
            [self.player play];
        }];
        [self.player play];
    } else if (imagePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:self.bounds];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.image = [UIImage imageWithContentsOfFile:imagePath];
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:iv];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;
    for (UIView *sub in self.subviews) sub.frame = self.bounds;
}

@end

// ============================================================
// MARK: - Hooks
// ============================================================

%hook PeerInfoHeaderNode

- (void)layoutSubviews {
    %orig;

    static void *kPCTBackgroundKey = &kPCTBackgroundKey;
    PCTBackgroundView *bg = objc_getAssociatedObject(self, kPCTBackgroundKey);
    if (!bg) {
        bg = [[PCTBackgroundView alloc] initWithFrame:self.bounds];
        bg.userInteractionEnabled = NO;
        [self insertSubview:bg atIndex:0];
        objc_setAssociatedObject(self, kPCTBackgroundKey, bg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    bg.frame = self.bounds;
    [bg configureWithConfig:PCTLoadConfig()];
}

%end

%hook PeerInfoTitleNode

- (void)setTitleFont:(UIFont *)font {
    UIFont *custom = PCTLoadCustomFont(font.pointSize);
    %orig(custom ?: font);
}

%end

%ctor {
    %init;
}

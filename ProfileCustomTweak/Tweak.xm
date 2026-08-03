// ProfileCustomTweak
//
// Concept/starting-point Logos tweak for Telegram-iOS (open source client).
// Adds:
//   1. A custom background (photo or looping video) behind the profile header,
//      instead of Telegram's default gradient/wallpaper.
//   2. A custom font for the displayed name in the profile header.
//
// IMPORTANT — read before building:
// Telegram-iOS is a large, frequently-changing Swift codebase (TelegramUI module).
// The private class/method names below (PeerInfoHeaderNode, AvatarListContainerNode,
// PeerInfoTitleNode, etc.) reflect the general architecture of the *open source*
// Telegram-iOS project, but exact symbol names/signatures shift between versions
// and get name-mangled differently depending on how a given build (e.g. your
// TgExtra fork) was compiled. This file will very likely need adjustment — dumping
// the actual class-dump / runtime headers of the specific binary you're targeting
// (via `class-dump` or Hopper on your own build) and matching method selectors is
// a required next step, not optional. Treat this as the skeleton/logic, not a
// drop-in binary patch.
//
// Build: normal Theos tweak (`make package`), then install the .deb / load via
// TrollStore-style injection into your own IPA — same as any other tweak.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreText/CoreText.h>

// ---------------------------------------------------------------------------
// MARK: - Shared config (reads user-selected assets from a shared plist so you
// can wire up a simple settings UI later, e.g. via TgExtra's own settings hook)
// ---------------------------------------------------------------------------

static NSString * const kConfigPath = @"/var/mobile/Library/Preferences/com.profilecustomtweak.plist";

static NSDictionary *PCTLoadConfig(void) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    return dict ?: @{};
}

// Expected keys in the plist:
//   "backgroundImagePath"  -> NSString, path to a .jpg/.png
//   "backgroundVideoPath"  -> NSString, path to a .mp4/.mov (looping)
//   "nameFontPath"         -> NSString, path to a .ttf/.otf bundled with the tweak
//   "nameFontSize"         -> NSNumber (points)

// ---------------------------------------------------------------------------
// MARK: - Custom font registration
// ---------------------------------------------------------------------------

static UIFont *PCTLoadCustomFont(CGFloat size) {
    NSDictionary *config = PCTLoadConfig();
    NSString *fontPath = config[@"nameFontPath"];
    if (!fontPath) return nil;

    static NSMutableSet *registeredPaths;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ registeredPaths = [NSMutableSet set]; });

    if (![registeredPaths containsObject:fontPath]) {
        NSData *fontData = [NSData dataWithContentsOfFile:fontPath];
        if (fontData) {
            CFErrorRef error = NULL;
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)fontData);
            CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
            if (cgFont) {
                CTFontManagerRegisterGraphicsFont(cgFont, &error);
                CFRelease(cgFont);
            }
            CGDataProviderRelease(provider);
            [registeredPaths addObject:fontPath];
        }
    }

    NSString *psName = config[@"nameFontPostscriptName"];
    if (!psName) return nil; // must match the font's actual PostScript name
    return [UIFont fontWithName:psName size:size];
}

// ---------------------------------------------------------------------------
// MARK: - Background layer (photo or looping video) inserted behind the
// profile header content.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// MARK: - Hooks into the profile header
//
// The class/selector names below are placeholders matching the general shape
// of PeerInfoHeaderNode in Telegram-iOS's TelegramUI module. You MUST verify
// these against the actual binary (class-dump) before this will link/hook
// correctly — Swift name mangling means the real symbol is something like
// `_TtC10TelegramUI19PeerInfoHeaderNode` or similar, and %hook needs the
// de-mangled Objective-C-visible name if the class is exposed to the runtime
// at all (many Swift-only classes are NOT visible to Logos hooks without
// extra tooling, e.g. Swift class dump / runtime introspection via `dsdump`).
// ---------------------------------------------------------------------------

#import <objc/runtime.h>

@interface PeerInfoHeaderNode : UIView
@end
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

// Custom font applied to the title/name label. Real class is likely
// something like PeerInfoTitleNode / ImmediateTextNode used inside the
// header — adjust the target class/property to match what class-dump shows.

%hook PeerInfoTitleNode

- (void)setTitleFont:(UIFont *)font {
    UIFont *custom = PCTLoadCustomFont(font.pointSize);
    %orig(custom ?: font);
}

%end

%ctor {
    %init;
}

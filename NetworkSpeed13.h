@interface _UIStatusBarForegroundView: UIView
@property(nonatomic, retain) UILabel *speedLabel;
@end

@interface SBCoverSheetPresentationManager: NSObject
+ (id)sharedInstance;
- (BOOL)isPresented;
@end

#import <Cephei/HBPreferences.h>
#import <ifaddrs.h>
#import <net/if.h>

static const long KILOBYTES = 1 << 10;
static const long MEGABYTES = 1 << 20;

static BOOL shouldUpdateSpeedLabel;

static long oldUpSpeed = 0, oldDownSpeed = 0;

static NSString *_Nullable cachedString;

typedef struct
{
    uint32_t inputBytes;
    uint32_t outputBytes;
} UpDownBytes;

HBPreferences *_Nullable pref;

BOOL enabled;

double locationX;
double locationY;

double width;
double height;

long fontSize;

long alignment;

@interface _UIStatusBarForegroundView: UIView
@property(nonatomic, retain) UILabel *_Nullable speedLabel;
@end

@interface SBCoverSheetPresentationManager: NSObject
+ (id _Nullable )sharedInstance;
- (BOOL)isPresented;
@end

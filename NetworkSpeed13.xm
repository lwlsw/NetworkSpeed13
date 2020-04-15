#import "NetworkSpeed13.h"

#import "SparkColourPickerUtils.h"
#import <Cephei/HBPreferences.h>
#import <ifaddrs.h>
#import <net/if.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

static const long KILOBITS = 1000;
static const long MEGABITS = 1000000;
static const long KILOBYTES = 1 << 10;
static const long MEGABYTES = 1 << 20;

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id networkSpeedObject;

static BOOL shouldUpdateSpeedLabel;
static long oldUpSpeed = 0, oldDownSpeed = 0;
typedef struct
{
    uint32_t inputBytes;
    uint32_t outputBytes;
} UpDownBytes;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL showDownloadSpeedFirst;
static BOOL showSecondSpeedInNewLine;
static BOOL showUploadSpeed;
static NSString *uploadPrefix;
static BOOL showDownloadSpeed;
static NSString *downloadPrefix;
static NSString *separator;
static long dataUnit;
static BOOL backgroundColorEnabled;
static float backgroundCornerRadius;
static BOOL customBackgroundColorEnabled;
static UIColor *customBackgroundColor;
static BOOL showAlways;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;
static double width;
static double height;
static long fontSize;
static BOOL boldFont;
static BOOL customTextColorEnabled;
static UIColor *customTextColor;
static long alignment;
static double updateInterval;

// Got some help from similar network speed tweaks by julioverne & n3d1117

NSString* formatSpeed(long bytes)
{
	if(dataUnit == 0) // BYTES
	{
		if (bytes < KILOBYTES) return @"0KB/s";
		else if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.0fKB/s", (double)bytes / KILOBYTES];
		else return [NSString stringWithFormat:@"%.2fMB/s", (double)bytes / MEGABYTES];
	}
	else // BITS
	{
		if (bytes < KILOBITS) return @"0Kb/s";
		else if (bytes < MEGABITS) return [NSString stringWithFormat:@"%.0fKb/s", (double)bytes / KILOBITS];
		else return [NSString stringWithFormat:@"%.2fMb/s", (double)bytes / MEGABITS];
	}
}

UpDownBytes getUpDownBytes()
{
	@autoreleasepool
	{
		struct ifaddrs *ifa_list = 0, *ifa;
		UpDownBytes upDownBytes;
		upDownBytes.inputBytes = 0;
		upDownBytes.outputBytes = 0;
		
		if (getifaddrs(&ifa_list) == -1) return upDownBytes;

		for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
		{
			if (AF_LINK != ifa->ifa_addr->sa_family || 
				(!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) || 
				ifa->ifa_data == 0) continue;
			
			struct if_data *if_data = (struct if_data *)ifa->ifa_data;

			upDownBytes.inputBytes += if_data->ifi_ibytes;
			upDownBytes.outputBytes += if_data->ifi_obytes;
		}
		
		freeifaddrs(ifa_list);
		return upDownBytes;
	}
}

static NSMutableString* formattedString()
{
	@autoreleasepool
	{
		NSMutableString* mutableString = [[NSMutableString alloc] init];
		
		UpDownBytes upDownBytes = getUpDownBytes();
		long upDiff = (upDownBytes.outputBytes - oldUpSpeed) / updateInterval;
		long downDiff = (upDownBytes.inputBytes - oldDownSpeed) / updateInterval;
		oldUpSpeed = upDownBytes.outputBytes;
		oldDownSpeed = upDownBytes.inputBytes;

		if(!showAlways && (upDiff < 2 * KILOBYTES && downDiff < 2 * KILOBYTES) || upDiff > 500 * MEGABYTES && downDiff > 500 * MEGABYTES)
		{
			shouldUpdateSpeedLabel = NO;
			return nil;
		}
		else shouldUpdateSpeedLabel = YES;

		if(dataUnit == 1) // BITS
		{
			upDiff *= 8;
			downDiff *= 8;
		}

		if(showDownloadSpeedFirst)
		{
			if(showDownloadSpeed) [mutableString appendString: [NSString stringWithFormat: @"%@%@", downloadPrefix, formatSpeed(downDiff)]];
			if(showUploadSpeed)
			{
				if([mutableString length] > 0)
				{
					if(showSecondSpeedInNewLine) [mutableString appendString: @"\n"];
					else [mutableString appendString: separator];
				}
				[mutableString appendString: [NSString stringWithFormat: @"%@%@", uploadPrefix, formatSpeed(upDiff)]];
			}
		}
		else
		{
			if(showUploadSpeed) [mutableString appendString: [NSString stringWithFormat: @"%@%@", uploadPrefix, formatSpeed(upDiff)]];
			if(showDownloadSpeed)
			{
				if([mutableString length] > 0)
				{
					if(showSecondSpeedInNewLine) [mutableString appendString: @"\n"];
					else [mutableString appendString: separator];
				}
				[mutableString appendString: [NSString stringWithFormat: @"%@%@", downloadPrefix, formatSpeed(downDiff)]];
			}
		}
		
		return [mutableString copy];
	}
}

static void orientationChanged()
{
	if(followDeviceOrientation && networkSpeedObject) 
		[networkSpeedObject updateOrientation];
}

static void loadDeviceScreenDimensions()
{
	UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.height;
		screenHeight = [[UIScreen mainScreen] bounds].size.width;
	}
	else
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.width;
		screenHeight = [[UIScreen mainScreen] bounds].size.height;
	}
}

@implementation UILabelWithInsets

- (void)drawTextInRect: (CGRect)rect
{
    UIEdgeInsets insets = {0, 5, 0, 5};
    [super drawTextInRect: UIEdgeInsetsInsetRect(rect, insets)];
}

@end

@implementation NetworkSpeed

	- (id)init
	{
		self = [super init];
		if(self)
		{
			@try
			{
				networkSpeedWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[networkSpeedWindow setHidden: NO];
				[networkSpeedWindow setAlpha: 1];
				[networkSpeedWindow _setSecure: YES];
				[networkSpeedWindow setUserInteractionEnabled: NO];
				[[networkSpeedWindow layer] setAnchorPoint: CGPointZero];
				
				networkSpeedLabel = [[UILabelWithInsets alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[[networkSpeedLabel layer] setMasksToBounds: YES];
				[(UIView *)networkSpeedWindow addSubview: networkSpeedLabel];

				[self updateFrame];

				[NSTimer scheduledTimerWithTimeInterval: updateInterval target: self selector: @selector(updateText) userInfo: nil repeats: YES];

				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
				CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			}
			@catch (NSException *e) {}
		}
		return self;
	}

	- (void)updateFrame
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_updateFrame) object: nil];
		[self performSelector: @selector(_updateFrame) withObject: nil afterDelay: 0.3];
	}

	- (void)_updateFrame
	{
		if(showOnLockScreen) [networkSpeedWindow setWindowLevel: 1050];
		else [networkSpeedWindow setWindowLevel: 1000];

		[self updateNetworkSpeedLabelProperties];
		[self updateNetworkSpeedSize];

		orientationOld = nil;
		[self updateOrientation];
	}

	- (void)updateNetworkSpeedLabelProperties
	{
		if(boldFont) [networkSpeedLabel setFont: [UIFont boldSystemFontOfSize: fontSize]];
		else [networkSpeedLabel setFont: [UIFont systemFontOfSize: fontSize]];

		[networkSpeedLabel setNumberOfLines: showSecondSpeedInNewLine ? 2 : 1];

		[networkSpeedLabel setTextAlignment: alignment];

		if(customTextColorEnabled)
			[networkSpeedLabel setTextColor: customTextColor];
		
		if(!backgroundColorEnabled)
			[networkSpeedLabel setBackgroundColor: [UIColor clearColor]];
		else
		{
			[[networkSpeedLabel layer] setCornerRadius: backgroundCornerRadius];
			[[networkSpeedLabel layer] setContinuousCorners: YES];
			
			if(customBackgroundColorEnabled)
				[networkSpeedLabel setBackgroundColor: customBackgroundColor];
		}
	}

	- (void)updateNetworkSpeedSize
	{
		CGRect frame = [networkSpeedLabel frame];
		frame.size.width = width;
		frame.size.height = height;
		[networkSpeedLabel setFrame: frame];

		frame = [networkSpeedWindow frame];
		frame.size.width = width;
		frame.size.height = height;
		[networkSpeedWindow setFrame: frame];
	}

	- (void)updateOrientation
	{
		if(!followDeviceOrientation)
		{
			CGRect frame = [networkSpeedWindow frame];
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			[networkSpeedWindow setFrame: frame];
		}
		else
		{
			UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
			if(orientation == orientationOld)
				return;
			
			CGAffineTransform newTransform;
			CGRect frame = [networkSpeedWindow frame];

			switch (orientation)
			{
				case UIDeviceOrientationLandscapeRight:
				{
					frame.origin.x = landscapeY;
					frame.origin.y = screenHeight - landscapeX;
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationLandscapeLeft:
				{
					frame.origin.x = screenWidth - landscapeY;
					frame.origin.y = landscapeX;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationPortraitUpsideDown:
				{
					frame.origin.x = screenWidth - portraitX;
					frame.origin.y = screenHeight - portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
					break;
				}
				case UIDeviceOrientationPortrait:
				default:
				{
					frame.origin.x = portraitX;
					frame.origin.y = portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
					break;
				}
			}

			[UIView animateWithDuration: 0.3f animations:
			^{
				[networkSpeedWindow setTransform: newTransform];
				[networkSpeedWindow setFrame: frame];
				orientationOld = orientation;
			} completion: nil];
		}
	}

	- (void)updateText
	{
		if(networkSpeedWindow && networkSpeedLabel)
		{
			if(![[%c(SBCoverSheetPresentationManager) sharedInstance] _isEffectivelyLocked])
			{
				NSString *speed = formattedString();
				if(shouldUpdateSpeedLabel)
				{
					[networkSpeedWindow setHidden: NO];
					[networkSpeedLabel setText: speed];
				}
				else [networkSpeedWindow setHidden: YES];
			}
			else [networkSpeedWindow setHidden: YES];
		}
	}

	- (void)updateTextColor: (UIColor*)color
	{
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if(!customTextColorEnabled) [networkSpeedLabel setTextColor: color];
			if(backgroundColorEnabled && !customBackgroundColorEnabled) 
			{
				if(r == 0) [networkSpeedLabel setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent: 0.5]];
				else [networkSpeedLabel setBackgroundColor: [[UIColor blackColor] colorWithAlphaComponent: 0.5]];
			}	

		}
	}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching: (id)application
{
	%orig;

	loadDeviceScreenDimensions();
	if(!networkSpeedObject) 
		networkSpeedObject = [[NetworkSpeed alloc] init];
}

%end

%hook _UIStatusBar

-(void)setForegroundColor: (UIColor*)color
{
	%orig;
	
	if(networkSpeedObject && [self styleAttributes] && [[self styleAttributes] imageTintColor]) 
		[networkSpeedObject updateTextColor: [[self styleAttributes] imageTintColor]];
}

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(!pref) pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.networkspeed13prefs"];
	enabled = [pref boolForKey: @"enabled"];
	showOnLockScreen = [pref boolForKey: @"showOnLockScreen"];
	showDownloadSpeedFirst = [pref boolForKey: @"showDownloadSpeedFirst"];
	showSecondSpeedInNewLine = [pref boolForKey: @"showSecondSpeedInNewLine"];
	showUploadSpeed = [pref boolForKey: @"showUploadSpeed"];
	uploadPrefix = [pref objectForKey: @"uploadPrefix"];
	showDownloadSpeed = [pref boolForKey: @"showDownloadSpeed"];
	downloadPrefix = [pref objectForKey: @"downloadPrefix"];
	separator = [pref objectForKey: @"separator"];
	dataUnit = [pref integerForKey: @"dataUnit"];
	backgroundColorEnabled = [pref boolForKey: @"backgroundColorEnabled"];
	backgroundCornerRadius = [pref floatForKey: @"backgroundCornerRadius"];
	customBackgroundColorEnabled = [pref boolForKey: @"customBackgroundColorEnabled"];
	portraitX = [pref floatForKey: @"portraitX"];
	portraitY = [pref floatForKey: @"portraitY"];
	landscapeX = [pref floatForKey: @"landscapeX"];
	landscapeY = [pref floatForKey: @"landscapeY"];
	followDeviceOrientation = [pref boolForKey: @"followDeviceOrientation"];
	width = [pref floatForKey: @"width"];
	height = [pref floatForKey: @"height"];
	fontSize = [pref integerForKey: @"fontSize"];
	boldFont = [pref boolForKey: @"boldFont"];
	customTextColorEnabled = [pref boolForKey: @"customTextColorEnabled"];
	alignment = [pref integerForKey: @"alignment"];
	showAlways = [pref boolForKey: @"showAlways"];
	updateInterval = [pref doubleForKey: @"updateInterval"];

	if(backgroundColorEnabled && customBackgroundColorEnabled || customTextColorEnabled)
	{
		NSDictionary *preferencesDictionary = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.johnzaro.networkspeed13prefs.colors.plist"];
		customBackgroundColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customBackgroundColor"] withFallback: @"#000000:0.50"];
		customTextColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customTextColor"] withFallback: @"#FF9400"];
	}

	if(networkSpeedObject)
	{
		[networkSpeedObject updateFrame];
		[networkSpeedObject updateText];
	}
}

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.networkspeed13prefs"];
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"showOnLockScreen": @NO,
			@"showAlways": @NO,
			@"showDownloadSpeedFirst": @NO,
			@"showSecondSpeedInNewLine": @NO,
			@"showUploadSpeed": @NO,
			@"uploadPrefix": @"↑",
			@"showDownloadSpeed": @NO,
			@"downloadPrefix": @"↓",
			@"separator": @" ",
			@"dataUnit": @0,
			@"backgroundColorEnabled": @NO,
			@"backgroundCornerRadius": @6,
			@"customBackgroundColorEnabled": @NO,
			@"portraitX": @280,
			@"portraitY": @32,
			@"landscapeX": @735,
			@"landscapeY": @32,
			@"followDeviceOrientation": @NO,
			@"width": @95,
			@"height": @12,
			@"fontSize": @8,
			@"boldFont": @NO,
			@"customTextColorEnabled": @NO,
			@"alignment": @1,
			@"updateInterval": @1.0
    	}];

		settingsChanged(NULL, NULL, NULL, NULL, NULL);

		if(enabled)
		{
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.networkspeed13prefs/reloadprefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			%init;
		}
	}
}
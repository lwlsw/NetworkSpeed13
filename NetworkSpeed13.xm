#import "NetworkSpeed13.h"

// Got some help from similar network speed tweaks by julioverne & n3d1117

NSString* formatSpeed(long bytes)
{
	if (bytes < KILOBYTES) return @"0K/s";
	else if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.0fK/s", (double)bytes / KILOBYTES];
	else return [NSString stringWithFormat:@"%.2fM/s", (double)bytes / MEGABYTES];
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
		NSMutableString* string = [[NSMutableString alloc] init];
		
		UpDownBytes upDownBytes = getUpDownBytes();
		long upDiff = upDownBytes.outputBytes - oldUpSpeed;
		long downDiff = upDownBytes.inputBytes - oldDownSpeed;
		oldUpSpeed = upDownBytes.outputBytes;
		oldDownSpeed = upDownBytes.inputBytes;

		if(upDiff < 2 * KILOBYTES && downDiff < 2 * KILOBYTES)
		{
			shouldUpdateSpeedLabel = NO;
			return nil;
		}
		else shouldUpdateSpeedLabel = YES;

		// [string appendString: @"↑99.99M/s ↓99.99M/s"]; (this is for debugging)
		[string appendString: @"↑"];
		[string appendString: formatSpeed(upDiff)];
		[string appendString: @" ↓"];
		[string appendString: formatSpeed(downDiff)];
		
		return string;
	}
}

%hook _UIStatusBarForegroundView

%property(nonatomic, retain) UILabel *speedLabel;

-(id)initWithFrame: (CGRect)arg1
{
	@autoreleasepool
	{
		self = %orig;

		if(!self.speedLabel)
		{
			self.speedLabel = [[UILabel alloc] initWithFrame: CGRectMake(locationX, locationY, width, height)];
			self.speedLabel.font = [UIFont systemFontOfSize: fontSize];
			self.speedLabel.textAlignment = alignment;
			
			self.speedLabel.adjustsFontSizeToFitWidth = NO;

			[NSTimer scheduledTimerWithTimeInterval: 1.1 repeats: YES block: ^(NSTimer *timer)
			{
				if(![[%c(SBCoverSheetPresentationManager) sharedInstance] isPresented] && self && self.speedLabel)
				{
					if(!shouldUpdateSpeedLabel || [self.superview.superview.superview isKindOfClass: %c(CCUIStatusBar)])
					{
						if(!self.speedLabel.hidden) self.speedLabel.hidden = YES;
					}
					else
					{
						self.speedLabel.hidden = NO;
						self.speedLabel.text = cachedString;
					}
				}
				else if(!self.speedLabel.hidden) self.speedLabel.hidden = YES;
			}];
			[self addSubview: self.speedLabel];
		}
		return self;
	}
}

%end

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.networkspeed13prefs"];
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"locationX": @292,
			@"locationY": @32,
			@"width": @82,
			@"height": @12,
			@"fontSize": @8,
			@"alignment": @1
    	}];

		enabled = [pref boolForKey: @"enabled"];
		
		if(enabled)
		{
			locationX = [pref floatForKey: @"locationX"];
			locationY = [pref floatForKey: @"locationY"];
			
			width = [pref floatForKey: @"width"];
			height = [pref floatForKey: @"height"];

			fontSize = [pref integerForKey: @"fontSize"];
			
			alignment = [pref integerForKey: @"alignment"];

			[NSTimer scheduledTimerWithTimeInterval: 1.0 repeats: YES block: ^(NSTimer *timer)
			{
				if(![[%c(SBCoverSheetPresentationManager) sharedInstance] isPresented]) cachedString = formattedString();
			}];

			%init;
		}
	}
}
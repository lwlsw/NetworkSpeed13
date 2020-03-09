#include "NSPRootListController.h"
#import "spawn.h"

@implementation NSPRootListController

- (instancetype)init
{
    self = [super init];

    if (self)
	{
        NSPAppearanceSettings *appearanceSettings = [[NSPAppearanceSettings alloc] init];
        self.hb_appearanceSettings = appearanceSettings;
        self.respringButton = [[UIBarButtonItem alloc] initWithTitle: @"Respring" style: UIBarButtonItemStylePlain target: self action: @selector(respring)];
        self.respringButton.tintColor = [UIColor blackColor];
        self.navigationItem.rightBarButtonItem = self.respringButton;

        self.navigationItem.titleView = [UIView new];
        self.titleLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 10, 10)];
        self.titleLabel.font = [UIFont boldSystemFontOfSize: 17];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.text = @"NetworkSpeed13";
		self.titleLabel.alpha = 0.0;
        self.titleLabel.textColor = [UIColor blackColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.navigationItem.titleView addSubview: self.titleLabel];

        [NSLayoutConstraint activateConstraints:
		@[
            [self.titleLabel.topAnchor constraintEqualToAnchor: self.navigationItem.titleView.topAnchor],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor: self.navigationItem.titleView.leadingAnchor],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor: self.navigationItem.titleView.trailingAnchor],
            [self.titleLabel.bottomAnchor constraintEqualToAnchor: self.navigationItem.titleView.bottomAnchor],
        ]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.headerImageView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"NSPHeader" inBundle: [NSBundle bundleForClass: [self class]] compatibleWithTraitCollection:nil]];
    self.headerImageView.contentMode = UIViewContentModeTop;
    self.headerImageView.translatesAutoresizingMaskIntoConstraints = NO;
    
	self.headerWidth = [UIScreen mainScreen].bounds.size.width;
	self.headerAspectRatio = self.headerImageView.image.size.height / self.headerImageView.image.size.width;
	self.headerHeight = self.headerWidth * self.headerAspectRatio;

	self.headerView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.headerWidth, self.headerHeight + 15)];
    [self.headerView addSubview:self.headerImageView];

    [NSLayoutConstraint activateConstraints:
	@[
        [self.headerImageView.topAnchor constraintEqualToAnchor: self.headerView.topAnchor],
        [self.headerImageView.leadingAnchor constraintEqualToAnchor: self.headerView.leadingAnchor],
        [self.headerImageView.trailingAnchor constraintEqualToAnchor: self.headerView.trailingAnchor],
        [self.headerImageView.bottomAnchor constraintEqualToAnchor: self.headerView.bottomAnchor],
    ]];
    _table.tableHeaderView = self.headerView;
}

- (UITableViewCell*)tableView: (UITableView*)tableView cellForRowAtIndexPath: (NSIndexPath*)indexPath
{
    tableView.tableHeaderView = self.headerView;
    return [super tableView:tableView cellForRowAtIndexPath: indexPath];
}

- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    CGRect frame = self.table.bounds;
    frame.origin.y = -frame.size.height;

    self.navigationController.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:1.00 green:0.58 blue:0.00 alpha:1.0];
    [self.navigationController.navigationController.navigationBar setShadowImage: [UIImage new]];
    self.navigationController.navigationController.navigationBar.tintColor = [UIColor blackColor];
    self.navigationController.navigationController.navigationBar.translucent = NO;
}

- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];
    [self.navigationController.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName : [UIColor blackColor]}];
}

- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];
    [self.navigationController.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName : [UIColor blackColor]}];
}

- (void)scrollViewDidScroll: (UIScrollView*)scrollView
{
    CGFloat offsetY = scrollView.contentOffset.y;

    if (offsetY > self.headerHeight / 2.0) [UIView animateWithDuration: 0.2 animations: ^{ self.titleLabel.alpha = 1.0; }];
	else [UIView animateWithDuration:0.2 animations: ^{ self.titleLabel.alpha = 0.0; }];

    if (offsetY > 0) offsetY = 0;
    self.headerImageView.frame = CGRectMake(0, offsetY, self.headerView.frame.size.width, self.headerHeight - offsetY);
}

- (NSArray*)specifiers
{
	if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName: @"Root" target: self];
	return _specifiers;
}

- (void)respring
{
	pid_t pid;
	const char *args[] = {"sbreload", NULL, NULL, NULL};
	posix_spawn(&pid, "usr/bin/sbreload", NULL, NULL, (char *const *)args, NULL);
}

- (void)email
{
	if([%c(MFMailComposeViewController) canSendMail])
	{
		MFMailComposeViewController *mailCont = [[%c(MFMailComposeViewController) alloc] init];
		mailCont.mailComposeDelegate = self;

		[mailCont setToRecipients: [NSArray arrayWithObject: @"johnzrgnns@gmail.com"]];
		[self presentViewController: mailCont animated: YES completion: nil];
	}
}

- (void)reddit
{
	if([[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString: @"reddit://"]])
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"reddit://www.reddit.com/user/johnzaro"]];
	else
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/user/johnzaro"]];
}

-(void)mailComposeController:(id)arg1 didFinishWithResult:(long long)arg2 error:(id)arg3
{
    [self dismissViewControllerAnimated: YES completion: nil];
}

@end

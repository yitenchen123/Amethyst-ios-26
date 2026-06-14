//  OptiFineInstallViewController.m
//  Amethyst

#import "OptiFineInstallViewController.h"
#import "AFNetworking.h"
#import "LauncherNavigationController.h"
#import "WFWorkflowProgressView.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import <dlfcn.h>

#pragma mark - Custom Cell & Header (reused from ForgeInstallViewController)

@interface OptiFineVersionCell : UITableViewCell
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@implementation OptiFineVersionCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.versionLabel = [[UILabel alloc] init];
        self.versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.versionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:self.versionLabel];
        
        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.subtitleLabel.numberOfLines = 1;
        self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:self.subtitleLabel];
        
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.versionLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [self.versionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:2],
            [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
        ]];
    }
    return self;
}
@end

@interface OptiFineHeaderView : UITableViewHeaderFooterView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronImageView;
@property (nonatomic, strong) UIButton *expandCollapseButton;
@property (nonatomic, assign) BOOL isExpanded;
@end

@implementation OptiFineHeaderView
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        UIView *containerView = [[UIView alloc] init];
        containerView.backgroundColor = [UIColor systemGroupedBackgroundColor];
        containerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:containerView];
        
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:self.titleLabel];
        
        self.chevronImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        self.chevronImageView.tintColor = [UIColor systemGrayColor];
        self.chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
        [containerView addSubview:self.chevronImageView];
        
        self.expandCollapseButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.expandCollapseButton.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:self.expandCollapseButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
            [self.titleLabel.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronImageView.leadingAnchor constant:-16],
            [self.chevronImageView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
            [self.chevronImageView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [self.chevronImageView.widthAnchor constraintEqualToConstant:20],
            [self.chevronImageView.heightAnchor constraintEqualToConstant:20],
            [self.expandCollapseButton.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
            [self.expandCollapseButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
            [self.expandCollapseButton.topAnchor constraintEqualToAnchor:containerView.topAnchor],
            [self.expandCollapseButton.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
        ]];
    }
    return self;
}
- (void)setIsExpanded:(BOOL)isExpanded {
    _isExpanded = isExpanded;
    [UIView animateWithDuration:0.3 animations:^{
        self.chevronImageView.transform = isExpanded ? CGAffineTransformMakeRotation(M_PI_2) : CGAffineTransformIdentity;
    }];
}
@end

#pragma mark - OptiFineInstallViewController

@interface OptiFineInstallViewController ()
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) AFURLSessionManager *afManager;
@property (nonatomic, strong) WFWorkflowProgressView *progressView;
@property (atomic, assign) BOOL isDataLoading;
@property (nonatomic, strong) NSLock *dataLock;

@property (nonatomic, strong) NSMutableArray<NSString *> *mcVersionList;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSDictionary *> *> *optifineList;
@property (nonatomic, strong) NSMutableArray<NSMutableArray *> *filteredOptifineList;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *visibilityList;

@property (nonatomic, strong) NSIndexPath *currentDownloadIndexPath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *displayNameCache;
@property (nonatomic, strong) NSTimer *searchDebounceTimer;
@property (nonatomic, strong) dispatch_queue_t searchQueue;
@end

@implementation OptiFineInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Navigation bar
    self.title = @"OptiFine";
    if (self.navigationController) {
        self.navigationController.navigationBar.translucent = NO;
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    // Table view settings
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.tableView registerClass:[OptiFineVersionCell class] forCellReuseIdentifier:@"OptiFineVersionCell"];
    [self.tableView registerClass:[OptiFineHeaderView class] forHeaderFooterViewReuseIdentifier:@"OptiFineHeader"];
    
    // Search controller
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = (id<UISearchResultsUpdating>)self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search OptiFine versions";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    
    // Refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshVersions) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    // Progress view
    dlopen("/System/Library/PrivateFrameworks/WorkflowUIServices.framework/WorkflowUIServices", RTLD_GLOBAL);
    self.progressView = [[NSClassFromString(@"WFWorkflowProgressView") alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    self.progressView.resolvedTintColor = self.view.tintColor;
    [self.progressView addTarget:self action:@selector(actionCancelDownload) forControlEvents:UIControlEventTouchUpInside];
    
    // Data containers
    self.dataLock = [[NSLock alloc] init];
    self.mcVersionList = [NSMutableArray new];
    self.optifineList = [NSMutableArray new];
    self.filteredOptifineList = [NSMutableArray new];
    self.visibilityList = [NSMutableArray new];
    self.displayNameCache = [NSMutableDictionary new];
    self.searchQueue = dispatch_queue_create("com.amethyst.optifine.search", DISPATCH_QUEUE_SERIAL);
    self.isDataLoading = NO;
    
    [self loadOptiFineVersions];
}

- (void)dealloc {
    [self.searchDebounceTimer invalidate];
}

- (void)actionCancelDownload {
    if (self.currentDownloadIndexPath) {
        [self resetCellAppearance:self.currentDownloadIndexPath];
        self.currentDownloadIndexPath = nil;
    }
    [self.afManager invalidateSessionCancelingTasks:YES resetSession:NO];
    showDialog(@"Download Cancelled", @"The download has been cancelled.");
}

- (void)resetCellAppearance:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (!cell) return;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)actionClose {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)refreshVersions {
    [self loadOptiFineVersions];
}

- (void)loadOptiFineVersions {
    [self switchToLoadingState];
    self.isDataLoading = YES;
    
    [self.dataLock lock];
    [self.mcVersionList removeAllObjects];
    [self.optifineList removeAllObjects];
    [self.filteredOptifineList removeAllObjects];
    [self.visibilityList removeAllObjects];
    [self.displayNameCache removeAllObjects];
    [self.dataLock unlock];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
    
    NSString *urlString = @"https://bmclapi2.bangbang93.com/optifine/versionlist";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isDataLoading = NO;
                [self switchToReadyState];
                [self.refreshControl endRefreshing];
                showDialog(@"Error", error.localizedDescription);
                [self actionClose];
            });
            return;
        }
        
        NSError *jsonError;
        NSArray *rawList = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![rawList isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isDataLoading = NO;
                [self switchToReadyState];
                showDialog(@"Error", @"Failed to parse OptiFine version list");
                [self actionClose];
            });
            return;
        }
        
        // Group by Minecraft version
        NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *groupDict = [NSMutableDictionary dictionary];
        for (NSDictionary *item in rawList) {
            NSString *mcVersion = item[@"mcversion"];
            if (!mcVersion || mcVersion.length == 0) continue;
            
            NSMutableDictionary *ofItem = [@{@"version": item[@"version"] ?: @"",
                                            @"type": item[@"type"] ?: @"",
                                            @"mcversion": mcVersion,
                                            @"patch": item[@"patch"] ?: @""} mutableCopy];
            NSString *downloadUrl = [NSString stringWithFormat:@"https://bmclapi2.bangbang93.com/optifine/download?mcversion=%@&version=%@&type=%@",
                                     mcVersion, ofItem[@"version"], ofItem[@"type"]];
            ofItem[@"downloadUrl"] = downloadUrl;
            
            if (!groupDict[mcVersion]) {
                groupDict[mcVersion] = [NSMutableArray array];
            }
            [groupDict[mcVersion] addObject:ofItem];
        }
        
        // Sort Minecraft versions descending
        NSArray *sortedMCVersions = [groupDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *v1, NSString *v2) {
            return [self compareMinecraftVersion:v2 with:v1];
        }];
        
        [self.dataLock lock];
        for (NSString *mcVer in sortedMCVersions) {
            [self.mcVersionList addObject:mcVer];
            NSArray *versions = groupDict[mcVer];
            // Sort by patch number descending
            NSArray *sortedVersions = [versions sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                NSInteger patch1 = [obj1[@"patch"] integerValue];
                NSInteger patch2 = [obj2[@"patch"] integerValue];
                if (patch1 == patch2) return NSOrderedSame;
                return patch1 > patch2 ? NSOrderedAscending : NSOrderedDescending;
            }];
            [self.optifineList addObject:[sortedVersions mutableCopy]];
            [self.visibilityList addObject:@NO];
        }
        [self.filteredOptifineList removeAllObjects];
        for (NSMutableArray *section in self.optifineList) {
            [self.filteredOptifineList addObject:[section mutableCopy]];
        }
        [self.dataLock unlock];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isDataLoading = NO;
            [self switchToReadyState];
            [self.tableView reloadData];
            if (self.mcVersionList.count > 0) {
                [self.tableView setContentOffset:CGPointZero animated:YES];
            }
        });
    }];
    [task resume];
}

- (NSComparisonResult)compareMinecraftVersion:(NSString *)v1 with:(NSString *)v2 {
    NSArray *parts1 = [v1 componentsSeparatedByString:@"."];
    NSArray *parts2 = [v2 componentsSeparatedByString:@"."];
    NSInteger major1 = parts1.count > 0 ? [parts1[0] integerValue] : 0;
    NSInteger major2 = parts2.count > 0 ? [parts2[0] integerValue] : 0;
    if (major1 != major2) return major1 < major2 ? NSOrderedAscending : NSOrderedDescending;
    NSInteger minor1 = parts1.count > 1 ? [parts1[1] integerValue] : 0;
    NSInteger minor2 = parts2.count > 1 ? [parts2[1] integerValue] : 0;
    if (minor1 != minor2) return minor1 < minor2 ? NSOrderedAscending : NSOrderedDescending;
    NSInteger patch1 = parts1.count > 2 ? [parts1[2] integerValue] : 0;
    NSInteger patch2 = parts2.count > 2 ? [parts2[2] integerValue] : 0;
    if (patch1 != patch2) return patch1 < patch2 ? NSOrderedAscending : NSOrderedDescending;
    return NSOrderedSame;
}

- (void)switchToLoadingState {
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:indicator];
    [indicator startAnimating];
    self.navigationController.modalInPresentation = YES;
}

- (void)switchToReadyState {
    UIActivityIndicatorView *indicator = (id)self.navigationItem.rightBarButtonItem.customView;
    [indicator stopAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(actionClose)];
    self.navigationController.modalInPresentation = NO;
    [self.refreshControl endRefreshing];
}

#pragma mark - Search
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if (self.isDataLoading) return;
    NSString *searchText = searchController.searchBar.text;
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(performSearch:) userInfo:searchText repeats:NO];
}

- (void)performSearch:(NSTimer *)timer {
    NSString *searchText = timer.userInfo;
    self.searchText = searchText;
    if (searchText.length == 0) {
        [self.dataLock lock];
        [self.filteredOptifineList removeAllObjects];
        for (NSMutableArray *section in self.optifineList) {
            [self.filteredOptifineList addObject:[section mutableCopy]];
        }
        [self.dataLock unlock];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
        return;
    }
    dispatch_async(self.searchQueue, ^{
        [self.dataLock lock];
        NSArray *snapshot = [self.optifineList copy];
        [self.dataLock unlock];
        NSMutableArray *newFiltered = [NSMutableArray new];
        for (NSArray *section in snapshot) {
            NSMutableArray *filteredSection = [NSMutableArray new];
            for (NSDictionary *item in section) {
                NSString *displayName = [self getDisplayNameForItem:item];
                if ([displayName localizedCaseInsensitiveContainsString:searchText]) {
                    [filteredSection addObject:item];
                }
            }
            [newFiltered addObject:filteredSection];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dataLock lock];
            [self.filteredOptifineList removeAllObjects];
            [self.filteredOptifineList addObjectsFromArray:newFiltered];
            [self.dataLock unlock];
            [self.tableView reloadData];
        });
    });
}

- (NSString *)getDisplayNameForItem:(NSDictionary *)item {
    NSString *version = item[@"version"];
    NSString *type = item[@"type"];
    if (type.length > 0 && ![type isEqualToString:@"(none)"]) {
        return [NSString stringWithFormat:@"OptiFine %@ %@", version, type];
    } else {
        return [NSString stringWithFormat:@"OptiFine %@", version];
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.isDataLoading) return 0;
    [self.dataLock lock];
    NSInteger count = self.mcVersionList.count;
    [self.dataLock unlock];
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isDataLoading) return 0;
    [self.dataLock lock];
    if (section >= self.visibilityList.count) {
        [self.dataLock unlock];
        return 0;
    }
    NSInteger rows = 0;
    if (self.visibilityList[section].boolValue) {
        if (self.searchController.isActive) {
            if (section < self.filteredOptifineList.count) rows = self.filteredOptifineList[section].count;
        } else {
            if (section < self.optifineList.count) rows = self.optifineList[section].count;
        }
    }
    [self.dataLock unlock];
    return rows;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    OptiFineHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"OptiFineHeader"];
    if (self.isDataLoading) {
        header.titleLabel.text = @"Loading...";
        header.isExpanded = NO;
        return header;
    }
    [self.dataLock lock];
    NSString *mcVersion = self.mcVersionList[section];
    header.titleLabel.text = [NSString stringWithFormat:@"Minecraft %@", mcVersion];
    if (section < self.visibilityList.count) {
        header.isExpanded = self.visibilityList[section].boolValue;
    } else {
        header.isExpanded = NO;
    }
    [self.dataLock unlock];
    header.expandCollapseButton.tag = section;
    [header.expandCollapseButton addTarget:self action:@selector(toggleSection:) forControlEvents:UIControlEventTouchUpInside];
    return header;
}

- (void)toggleSection:(UIButton *)sender {
    if (self.isDataLoading) return;
    NSInteger section = sender.tag;
    [self.dataLock lock];
    if (section >= 0 && section < self.visibilityList.count) {
        self.visibilityList[section] = @(!self.visibilityList[section].boolValue);
        [self.dataLock unlock];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.dataLock unlock];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 60.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 56.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OptiFineVersionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OptiFineVersionCell" forIndexPath:indexPath];
    if (self.isDataLoading) {
        cell.versionLabel.text = @"Loading...";
        cell.subtitleLabel.text = @"";
        return cell;
    }
    [self.dataLock lock];
    NSDictionary *item = nil;
    if (self.searchController.isActive) {
        if (indexPath.section < self.filteredOptifineList.count && indexPath.row < self.filteredOptifineList[indexPath.section].count)
            item = self.filteredOptifineList[indexPath.section][indexPath.row];
    } else {
        if (indexPath.section < self.optifineList.count && indexPath.row < self.optifineList[indexPath.section].count)
            item = self.optifineList[indexPath.section][indexPath.row];
    }
    [self.dataLock unlock];
    if (!item) {
        cell.versionLabel.text = @"Unknown";
        cell.subtitleLabel.text = @"";
        return cell;
    }
    cell.versionLabel.text = [self getDisplayNameForItem:item];
    NSString *type = item[@"type"];
    if (type.length > 0 && ![type isEqualToString:@"(none)"]) {
        cell.subtitleLabel.text = [type capitalizedString];
        if ([type isEqualToString:@"pre"]) {
            cell.subtitleLabel.textColor = [UIColor systemOrangeColor];
        } else {
            cell.subtitleLabel.textColor = [UIColor systemGreenColor];
        }
    } else {
        cell.subtitleLabel.text = @"Release";
        cell.subtitleLabel.textColor = [UIColor systemBlueColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.isDataLoading) return;
    
    [self.dataLock lock];
    NSDictionary *item = nil;
    if (self.searchController.isActive) {
        if (indexPath.section < self.filteredOptifineList.count && indexPath.row < self.filteredOptifineList[indexPath.section].count)
            item = self.filteredOptifineList[indexPath.section][indexPath.row];
    } else {
        if (indexPath.section < self.optifineList.count && indexPath.row < self.optifineList[indexPath.section].count)
            item = self.optifineList[indexPath.section][indexPath.row];
    }
    [self.dataLock unlock];
    if (!item) return;
    
    NSString *downloadUrl = item[@"downloadUrl"];
    if (!downloadUrl) {
        showDialog(@"Error", @"Download URL not available");
        return;
    }
    
    self.currentDownloadIndexPath = indexPath;
    tableView.allowsSelection = NO;
    [self switchToLoadingState];
    self.progressView.fractionCompleted = 0;
    
    OptiFineVersionCell *cell = (OptiFineVersionCell *)[tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryView = self.progressView;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"OptiFineInstaller.jar"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadUrl]];
    self.afManager = [AFURLSessionManager new];
    NSURLSessionDownloadTask *downloadTask = [self.afManager downloadTaskWithRequest:request progress:^(NSProgress *progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.fractionCompleted = progress.fractionCompleted;
        });
    } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        [NSFileManager.defaultManager removeItemAtPath:outPath error:nil];
        return [NSURL fileURLWithPath:outPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            tableView.allowsSelection = YES;
            [self resetCellAppearance:indexPath];
            self.currentDownloadIndexPath = nil;
            if (error) {
                if (error.code != NSURLErrorCancelled) {
                    showDialog(@"Download Error", error.localizedDescription);
                }
                [self switchToReadyState];
                return;
            }
            showDialog(@"Download Complete", @"OptiFine installer downloaded. The installer will now run.");
            LauncherNavigationController *navVC = (id)((UISplitViewController *)self.presentingViewController).viewControllers[1];
            [self dismissViewControllerAnimated:YES completion:^{
                [navVC enterModInstallerWithPath:outPath hitEnterAfterWindowShown:YES];
            }];
        });
    }];
    [downloadTask resume];
}

@end
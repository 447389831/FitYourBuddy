//
//  IndexViewController.m
//  FitYourBuddy
//
//  Created by 陈文琦 on 15/2/15.
//  Copyright (c) 2015年 xpz. All rights reserved.
//

#import "IndexViewController.h"
#import "WQProgressBar.h"
#import "WQCalendar.h"

#import "ExerciseViewController.h"

static CGFloat const LevelViewHeight = 80.0f;
static CGFloat const TitleLabelWidth = 40.0f;
static CGFloat const FatGuyHeightRatio = 0.8f;
//static CGFloat const FatGuyWidthToHeightRatio = 631.0f / 822.0f;
static CGFloat const StartButtonWidth = 200.0f;
static CGFloat const DayLabelHeight = 25.0f;

static const UIEdgeInsets CalendarImageMargin = (UIEdgeInsets){0,25,-5,25};

@interface IndexViewController ()<UIScrollViewDelegate, UIGestureRecognizerDelegate>
{
    UIView              *scrollBlock;
    
    NSDictionary        *accountDict;
}

@end

@implementation IndexViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"小胖砸";
    self.view.backgroundColor = indexBackgroundColor;
    
    //统一返回键
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] init];
    [backItem setBackButtonBackgroundImage:[[UIImage imageNamed:@"NavBackIcon"] resizableImageWithCapInsets:UIEdgeInsetsMake(0,15,0,0)] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [backItem setTitle:@""];
    self.navigationItem.backBarButtonItem = backItem;
    
    //获取姓名和性别
    NSError *error;
    accountDict = [AccountCoreDataHelper getAccountDictionaryWithError:&error];
    NSString *fatGuyName = [NSString stringWithFormat:@"早上好，%@", accountDict[@"name"]];
    NSString *fatGuyCount = [NSString stringWithFormat:@"%@天", accountDict[@"count"]];
    NSString *fatGuyLevel = [NSString stringWithFormat:@"等级Lv.%@", accountDict[@"level"]];
    float fullExp = [CommonUtil getExpFromLevel:accountDict[@"level"]];
    float exp = [accountDict[@"exp"] floatValue];
    exp = exp / fullExp;
    
    //添加小胖砸界面
    CGFloat fatGuyViewHeight = APPCONFIG_UI_SCREEN_VHEIGHT - LevelViewHeight - TitleLabelWidth - APPCONFIG_UI_VIEW_BETWEEN_PADDING * 3;
    UIView* fatGuyView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, APPCONFIG_UI_SCREEN_FWIDTH, fatGuyViewHeight)];
    [fatGuyView setBackgroundColor:themeBlueColor];
    [self.view addSubview:fatGuyView];
    
    UILabel* fatGuyNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 20)];
    [fatGuyNameLabel setText:fatGuyName];
    [fatGuyNameLabel setTextColor:[UIColor whiteColor]];
    [fatGuyNameLabel setFont:[UIFont boldSystemFontOfSize:16]];
    [fatGuyNameLabel setBackgroundColor:[UIColor clearColor]];
    [fatGuyView addSubview:fatGuyNameLabel];
    
    //加两个云，这里frame就写死了
    UIImageView *cloudImage = [[UIImageView alloc] init];
    cloudImage.frame = CGRectMake(210, 5, 60, 60);
    cloudImage.image = [UIImage imageNamed:@"CloudIcon"];
    [fatGuyView addSubview:cloudImage];
    
    cloudImage = [[UIImageView alloc] init];
    cloudImage.frame = CGRectMake(260, 45, 60, 60);
    cloudImage.image = [UIImage imageNamed:@"CloudIcon"];
    [fatGuyView addSubview:cloudImage];
    
    //临时小胖砸图
    UIImage *fatGuyImage = [UIImage imageNamed:@"LittleFatGuy"];
    //CGFloat tmpHeight = fatGuyViewHeight * FatGuyHeightRatio * FatGuyHeightRatio;
    //fatGuyImage = [fatGuyImage transformToSize:CGSizeMake(tmpHeight * FatGuyWidthToHeightRatio, tmpHeight)];
    
    UIImageView* littleFatGuy = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, fatGuyViewHeight * FatGuyHeightRatio, fatGuyViewHeight * FatGuyHeightRatio)];
    [littleFatGuy setBackgroundColor:[UIColor whiteColor]];
    [littleFatGuy setContentMode:UIViewContentModeCenter];//UIViewContentModeScaleAspectFit
    //[littleFatGuy setContentMode:UIViewContentModeScaleAspectFit];
    [littleFatGuy setImage:fatGuyImage];
    [littleFatGuy setCenter:CGPointMake(fatGuyView.center.x, fatGuyView.center.y + APPCONFIG_UI_VIEW_BETWEEN_PADDING)];
    littleFatGuy.layer.cornerRadius = fatGuyViewHeight * FatGuyHeightRatio / 2.0f;
    littleFatGuy.layer.shadowColor = themeDeepBlueColor.CGColor;
    littleFatGuy.layer.shadowOffset = CGSizeMake(5, 5);
    littleFatGuy.layer.shadowOpacity = 1;
    littleFatGuy.layer.shadowRadius = 0;
    [fatGuyView addSubview:littleFatGuy];
    
    //UIImageView *fatGuyImageView = [[UIImageView alloc] initWithImage:fatGuyImage];
    //fatGuyImageView.center = littleFatGuy.center;
    //[littleFatGuy addSubview:fatGuyImageView];
    
    //开始锻炼按钮
    UIButton* startTrainBtn = [[UIButton alloc] initWithFrame:CGRectMake((APPCONFIG_UI_SCREEN_FWIDTH - StartButtonWidth) / 2, APPCONFIG_UI_SCREEN_VHEIGHT - APPCONFIG_UI_VIEW_BETWEEN_PADDING  - TitleLabelWidth, StartButtonWidth, TitleLabelWidth)];
    [startTrainBtn setBackgroundColor:themeRedColor];
    [[startTrainBtn layer] setCornerRadius:15];
    [startTrainBtn addTarget:self action:@selector(tappedStartTrainBtn) forControlEvents:UIControlEventTouchUpInside];
    [startTrainBtn setTitle:@"开始锻炼" forState:UIControlStateNormal];
    [startTrainBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startTrainBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.view addSubview:startTrainBtn];

    //两个框
    CGFloat dayView = (APPCONFIG_UI_SCREEN_FWIDTH - APPCONFIG_UI_VIEW_PADDING * 2 - APPCONFIG_UI_VIEW_BETWEEN_PADDING) / 2.0f;
    //左边日历框
    UIView *leftDayView = [CommonUtil createViewWithFrame:CGRectMake(APPCONFIG_UI_VIEW_PADDING, 0, dayView, LevelViewHeight)];
    [self.view addSubview:leftDayView];
    [leftDayView topOfView:startTrainBtn withMargin:APPCONFIG_UI_VIEW_BETWEEN_PADDING];
    
    UILabel *leftDayTipLabel = [CommonUtil createLabelWithText:@"坚持天数" andTextColor:tipTitleLabelColor andFont:[UIFont systemFontOfSize:15] andTextAlignment:NSTextAlignmentCenter];
    leftDayTipLabel.frame = CGRectMake(0, 0, leftDayView.width, DayLabelHeight);
    [leftDayView addSubview:leftDayTipLabel];
    
    UIImageView *leftCalendarImage = [[UIImageView alloc] init];
    leftCalendarImage.frame = CGRectMake(CalendarImageMargin.left, 0, leftDayView.width - CalendarImageMargin.left * 2, leftDayView.height - leftDayTipLabel.height);
    leftCalendarImage.image = [UIImage imageNamed:@"CalendarIcon"];
    leftCalendarImage.contentMode = UIViewContentModeScaleAspectFill;
    [leftDayView addSubview:leftCalendarImage];
    [leftCalendarImage bottomOfView:leftDayTipLabel withMargin:CalendarImageMargin.bottom];
    
    UILabel *leftHistoryDayLabel = [CommonUtil createLabelWithText:fatGuyCount andTextColor:tipTitleLabelColor andFont:[UIFont boldSystemFontOfSize:24] andTextAlignment:NSTextAlignmentCenter];
    leftHistoryDayLabel.frame = CGRectMake(0, APPCONFIG_UI_VIEW_BETWEEN_PADDING, leftCalendarImage.width, leftCalendarImage.height - APPCONFIG_UI_VIEW_BETWEEN_PADDING);
    [leftCalendarImage addSubview:leftHistoryDayLabel];
    
    //右边等级框
    UIView *rightDayView = [CommonUtil createViewWithFrame:CGRectMake(0, 0, dayView, LevelViewHeight)];
    [self.view addSubview:rightDayView];
    [rightDayView topOfView:startTrainBtn withMargin:APPCONFIG_UI_VIEW_BETWEEN_PADDING];
    [rightDayView rightOfView:leftDayView withMargin:APPCONFIG_UI_VIEW_BETWEEN_PADDING];
    
    UILabel *rightDayTipLabel = [CommonUtil createLabelWithText:fatGuyLevel andTextColor:tipTitleLabelColor andFont:[UIFont systemFontOfSize:15] andTextAlignment:NSTextAlignmentCenter];
    rightDayTipLabel.frame = CGRectMake(0, 0, rightDayView.width, DayLabelHeight);
    [rightDayView addSubview:rightDayTipLabel];
    
    WQProgressBar *levelProgressBar = [[WQProgressBar alloc] initWithFrame:CGRectMake(APPCONFIG_UI_VIEW_BETWEEN_PADDING, 0, rightDayView.width - APPCONFIG_UI_VIEW_BETWEEN_PADDING * 2, rightDayView.height - rightDayTipLabel.height - APPCONFIG_UI_VIEW_BETWEEN_PADDING)];
    [rightDayView addSubview:levelProgressBar];
    [levelProgressBar bottomOfView:rightDayTipLabel];

    //////////时间紧，先不改了///////////////
    //盖一层下拉scrollview
    UIScrollView* fatGuyScrollView = [[UIScrollView alloc] initWithFrame:fatGuyView.bounds];
    [fatGuyScrollView setDelegate:self];
    [fatGuyScrollView setContentSize:CGSizeMake(fatGuyScrollView.width, fatGuyScrollView.height * 2)];
    [fatGuyScrollView setPagingEnabled:YES];
    fatGuyScrollView.showsVerticalScrollIndicator = false;
    fatGuyScrollView.bounces = false;
    [self.view addSubview:fatGuyScrollView];
    
    //日历页
    UIView* calendarBackground = [[UIView alloc] initWithFrame:fatGuyScrollView.bounds];
    [calendarBackground setBackgroundColor:[UIColor whiteColor]];
    [fatGuyScrollView addSubview:calendarBackground];
    
    NSDate* today = [NSDate date];
    
    UILabel* calendarDate = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 200, 20)];
    [calendarDate setTextColor:tipTitleLabelColor];
    [calendarDate setFont:[UIFont boldSystemFontOfSize:16]];
    [calendarDate setText:[NSString stringWithFormat:@"%lu.%.2lu", (unsigned long)today.year, (unsigned long)today.month]];
    [calendarBackground addSubview:calendarDate];
    
    if ([today numberOfWeeksInMonth] == 6) {
        WQCalendar* calendar = [[WQCalendar alloc] initWithFrame:CGRectMake(10, 20, calendarBackground.frame.size.width - 20, 245)];
        [calendarBackground addSubview:calendar];
    } else {
        float tileWidth = (calendarBackground.frame.size.width - 20) / 7;
        for (int i = 0; i < 7; i++) {
            UILabel* calendarTitle = [[UILabel alloc] initWithFrame:CGRectMake(10 + i * tileWidth, 20 + 10, tileWidth, tileWidth - 10)];
            [calendarTitle setTextAlignment:NSTextAlignmentCenter];
            [calendarTitle setFont:[UIFont systemFontOfSize:16]];
            [calendarBackground addSubview:calendarTitle];
            
            switch (i) {
                case 0:
                    [calendarTitle setTextColor:themeRedColor];
                    [calendarTitle setText:@"S"];
                    break;
                    
                case 1:
                    [calendarTitle setTextColor:themeBlueColor];
                    [calendarTitle setText:@"M"];
                    break;
                    
                case 2:
                    [calendarTitle setTextColor:themeBlueColor];
                    [calendarTitle setText:@"T"];
                    break;
                    
                case 3:
                    [calendarTitle setTextColor:themeBlueColor];
                    [calendarTitle setText:@"W"];
                    break;
                    
                case 4:
                    [calendarTitle setTextColor:themeBlueColor];
                    [calendarTitle setText:@"T"];
                    break;
                    
                case 5:
                    [calendarTitle setTextColor:themeBlueColor];
                    [calendarTitle setText:@"F"];
                    break;
                    
                case 6:
                    [calendarTitle setTextColor:themeRedColor];
                    [calendarTitle setText:@"S"];
                    break;
                    
                    
                default:
                    break;
            }
        }
        
        WQCalendar* calendar = [[WQCalendar alloc] initWithFrame:CGRectMake(10, 20 + tileWidth, calendarBackground.frame.size.width - 20, 245)];
        [calendarBackground addSubview:calendar];
    }
    //全局下拉块
    scrollBlock = [[UIView alloc] initWithFrame:CGRectMake(0, 315 + 5, 40, 2)];
    [scrollBlock setCenter:CGPointMake(fatGuyScrollView.center.x, scrollBlock.center.y)];
    [scrollBlock setBackgroundColor:[UIColor whiteColor]];
    [[scrollBlock layer] setCornerRadius:2];
    [fatGuyScrollView addSubview:scrollBlock];
    
    [fatGuyScrollView setContentOffset:CGPointMake(0, fatGuyScrollView.height)];
}

#pragma mark - Class Extention Delegate
- (void)tappedStartTrainBtn
{
    ExerciseViewController* new = [[ExerciseViewController alloc] init];
    [self.navigationController pushViewController:new animated:YES];
}

#pragma mark - Scroll View Delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    float verticalY = scrollView.height - scrollView.contentOffset.y;
    if (verticalY < 20) {
        scrollBlock.frame = CGRectMake(scrollBlock.frame.origin.x, scrollView.height + 5 - verticalY, scrollBlock.frame.size.width, scrollBlock.frame.size.height);
        scrollBlock.backgroundColor = [UIColor whiteColor];
    } else {
        scrollBlock.frame = CGRectMake(scrollBlock.frame.origin.x, scrollView.height + 5 - 20, scrollBlock.frame.size.width, scrollBlock.frame.size.height);
        scrollBlock.backgroundColor = themeBlueColor;
    }
}

@end
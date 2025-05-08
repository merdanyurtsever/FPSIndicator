#import "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

@interface PSTableCell()
-(id)iconImageView;
@end

@implementation BDInfoListController
-(void)loadView{
    [super loadView];
    self.navigationItem.title = @"Brend0n";
    
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    id cell=[super tableView:tableView cellForRowAtIndexPath:indexPath];
    UIImageView* imageView=[cell iconImageView];
    imageView.layer.cornerRadius = 7.0;
    imageView.layer.masksToBounds = YES;
    return cell;
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray arrayWithCapacity:5];

        PSSpecifier* spec;

        spec = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Follow Me On Twitter"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_twitter);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"twitter" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Donate"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_paypal);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"paypal" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];


        spec = [PSSpecifier preferenceSpecifierNamed:@"Github"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_github);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"github" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Add my repo"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_cydia);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"cydia" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];


        //
        spec = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"打赏"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_alipay);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"alipay" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];


        spec = [PSSpecifier preferenceSpecifierNamed:@"Bilibili"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_bilibili);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"bilibili" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];
    }
    return _specifiers;
}

- (void)open_bilibili {
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"bilibili://space/22182611"]
                                         options:@{}
                               completionHandler:nil];
    }
}

- (void)open_github {
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/brendonjkding/FPSIndicator"]
                                         options:@{}
                               completionHandler:nil];
    }
}

- (void)open_alipay {
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://qr.alipay.com/fkx199226yyspdubbiibddc"]
                                         options:@{}
                               completionHandler:nil];
    }
}

- (void)open_paypal {
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://paypal.me/brend0n"]
                                         options:@{}
                               completionHandler:nil];
    }
}

- (void)open_cydia {
    NSURL *sileoURL = [NSURL URLWithString:@"sileo://source/https://brendonjkding.github.io"];
    if (@available(iOS 10.0, *)) {
        [UIApplication.sharedApplication openURL:sileoURL options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                NSURL *cydiaURL = [NSURL URLWithString:@"cydia://url/https://cydia.saurik.com/api/share#?source=http://brendonjkding.github.io"];
                [UIApplication.sharedApplication openURL:cydiaURL options:@{} completionHandler:nil];
            }
        }];
    }
}

- (void)open_twitter {
    NSArray *urlSchemes = @[
        @"twitter://user?screen_name=brendonjkding",
        @"tweetbot:///user_profile/brendonjkding",
        @"https://mobile.twitter.com/brendonjkding"
    ];
    
    if (@available(iOS 10.0, *)) {
        for (NSString *urlScheme in urlSchemes) {
            NSURL *url = [NSURL URLWithString:urlScheme];
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
                if (success) return;
            }];
        }
    }
}

@end
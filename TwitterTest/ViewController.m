//
//  ViewController.m
//  TwitterTest
//
//  Created by Regan Bell on 3/29/15.
//  Copyright (c) 2015 Regan Bell. All rights reserved.
//

#import "ViewController.h"
#import "STTwitter.h"
#import "STTwitterAPI.h"
#import "Tweet.h"

@interface ViewController () <UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (assign) NSInteger windowSize;
@property (assign) NSInteger steamRollerIndex;
@property (strong, nonatomic) NSMutableDictionary *tweetDict;
@property (strong, nonatomic) NSArray *buckets;
@property (strong, nonatomic) NSNumberFormatter *sharedFormatter;
@property (strong, nonatomic) NSArray *topTen;
@property (strong, nonatomic) NSTimer *bucketTimer;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) UIAlertView *windowAlertView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Top 10 Retweets";
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Set Window" message:@"How many minutes wide should the tweet window be?" delegate:self cancelButtonTitle:@"Go!" otherButtonTitles: nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    NSString *input = [alertView textFieldAtIndex:0].text;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSNumber *windowNumber = [formatter numberFromString:input];
    
    if (!windowNumber) {
        alertView.message = @"Input must be a number!";
    } else {
        NSInteger windowSize = [windowNumber integerValue];
        
        if (windowSize < 2 || windowSize > 5000) {
            alertView.message = @"Input should be between 1 and 5000.";
        } else {
            self.windowSize = windowSize;
            [self.windowAlertView dismissWithClickedButtonIndex:buttonIndex animated:NO];
            self.windowAlertView = nil;
        }
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    [self startStreamingTweets];
}

#pragma mark - Create Data Stream

- (void)startStreamingTweets {
    
    self.tweetDict = [NSMutableDictionary dictionary];
    
    NSMutableArray *mutableBuckets = [NSMutableArray arrayWithCapacity:self.windowSize];
    for (int i = 0; i < self.windowSize; i++) {
        NSMutableArray *bucket = [[NSMutableArray alloc] init];
        [mutableBuckets addObject:bucket];
    }
    self.buckets = [NSArray arrayWithArray:mutableBuckets];
    self.bucketTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:(@selector(steamRoll)) userInfo:nil repeats:YES];
    
    self.topTen = [NSArray array];
    
    STTwitterAPI *twitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:@"8AqQCy7umStCyNN356v7fw"
                                                          consumerSecret:@"vOvKV1QwuS1AeKPMIvJqErBxW7i1N12OL4UY2tNMs0c" oauthToken:@"29463499-9Og6hxW4HqFxcQyIrAdmLpbAnrwIk290ghOE0ez5f"
                                                        oauthTokenSecret:@"elXVYJRFmFFit3PiVTmI9eU0IvHqqD7H4yeEmClJ8c"];
    
    [twitter verifyCredentialsWithSuccessBlock:^(NSString *username) {
        
        [twitter getStatusesSampleDelimited:nil
                              stallWarnings:nil
                              progressBlock:^(NSDictionary *response) {
                                  [self parseTweetDictionary:response];
                              }
                          stallWarningBlock:nil
                                 errorBlock:^(NSError *error) {}];
        
    } errorBlock:^(NSError *error) {
        NSLog(@"%@", [error localizedDescription]);
    }];
}

#pragma mark - Parse Data Stream

- (void)parseTweetDictionary:(NSDictionary*)responseDict {
    
    Tweet *retweet = [Tweet tweetFromDictionary:responseDict];
    Tweet *original = retweet.retweetedTweet;
    if (!retweet || !original) {
        return;
    }
    
    Tweet *tweetToUpdate = self.tweetDict[original.tweetID];
    NSInteger timesRetweeted = 0;
    if (tweetToUpdate) {
        timesRetweeted = tweetToUpdate.timesRetweeted.integerValue;
    } else {
        tweetToUpdate = original;
    }
    
    tweetToUpdate.timesRetweeted = [NSNumber numberWithInteger:timesRetweeted + 1];
    [self updateTopTenWithTweet:tweetToUpdate];
    self.tweetDict[tweetToUpdate.tweetID] = tweetToUpdate;
    
    // Schedule removal of this retweet once it has aged out of the window
    // I remove one batch of retweets every minute
    int minutesPassed = -1 * (int)floor([retweet.createdAt timeIntervalSinceNow] / 60.0);
    NSInteger bucketIndex = (self.steamRollerIndex + (self.windowSize - minutesPassed)) % self.windowSize;
    [self.buckets[bucketIndex] addObject:tweetToUpdate.tweetID];
}

#pragma mark - Update Top Ten List

- (void)updateTopTenWithTweet:(Tweet*)tweet {
    
    Tweet *bottom = [self.topTen lastObject];
    if (bottom.timesRetweeted.intValue > tweet.timesRetweeted.intValue && self.topTen.count == 10) {
        return;
    }
    
    NSArray *newTopTen;
    if (![self.topTen containsObject:tweet]) {
        newTopTen = [self.topTen arrayByAddingObject:tweet];
    } else
        newTopTen = [NSArray arrayWithArray:self.topTen];
    
    NSSortDescriptor *retweeted = [NSSortDescriptor sortDescriptorWithKey:@"timesRetweeted" ascending:NO];
    NSArray *sorted = [newTopTen sortedArrayUsingDescriptors:@[retweeted]];
    NSArray *orderedTopTen = [sorted subarrayWithRange:NSMakeRange(0, MIN(sorted.count, 10))];
    self.topTen = orderedTopTen;
    [self.tableView reloadData];
}

#pragma mark - Delete Old Tweets

- (void)steamRoll {
    
    [self steamRollBucketAtIndex:self.steamRollerIndex];
    self.steamRollerIndex = (self.steamRollerIndex + 1) % self.windowSize;
}

- (void)steamRollBucketAtIndex:(NSInteger)index {
    
    for (NSString *tweetID in self.buckets[index]) {
        Tweet *original = self.tweetDict[tweetID];
        NSInteger timesRetweeted = original.timesRetweeted.integerValue;
        timesRetweeted--;
        if (timesRetweeted < 1) {
            [self.tweetDict removeObjectForKey:tweetID];
        }
        else
            original.timesRetweeted = [NSNumber numberWithInteger:timesRetweeted];
    }
    [self.buckets[index] removeAllObjects];
}

#pragma mark - Table View Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    Tweet *tweet = self.topTen[indexPath.row];
    if (!tweet) {
        return cell;
    }
    cell.textLabel.text = tweet.text;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Retweeted %@ times", tweet.timesRetweeted];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.topTen.count;
}

- (NSNumberFormatter *)sharedFormatter {
    
    if (!_sharedFormatter) {
        _sharedFormatter = [[NSNumberFormatter alloc] init];
    }
    return _sharedFormatter;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

//
//  Tweet.m
//  Pods
//
//  Created by Regan Bell on 3/29/15.
//
//

#import "Tweet.h"

@implementation Tweet

+ (NSDateFormatter*)sharedFormatter {
    
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"eee MMM dd HH:mm:ss ZZZZ yyyy"];
    });
    return formatter;
}

- (BOOL)isEqual:(id)object {
    
    if ([object respondsToSelector:@selector(tweetID)]) {
        return [self.tweetID isEqualToNumber:[object tweetID]];
    } else
        return [super isEqual:object];
}

- (NSString *)description {
    
    return [NSString stringWithFormat:@"Retweeted %d times", self.timesRetweeted.intValue];
}

+ (Tweet *)tweetFromDictionary:(NSDictionary *)dictionary {
    
    Tweet *newTweet = [[Tweet alloc] init];
    
    NSDictionary *retweetedDict = dictionary[@"retweeted_status"];

    NSString *createdAtString = dictionary[@"created_at"];
    if (!createdAtString) {
        return nil;
    }
    NSDate *createdAt = [self.sharedFormatter dateFromString:createdAtString];
    NSString *text = dictionary[@"text"];
    if (!text) {
        return nil;
    }
    NSNumber *tweetID = dictionary[@"id"];
    if (!tweetID) {
        return nil;
    }
    Tweet *retweetedTweet = [Tweet tweetFromDictionary:retweetedDict];
    
    newTweet.text = text;
    newTweet.createdAt = createdAt;
    newTweet.timesRetweeted = @0;
    newTweet.retweetedTweet = retweetedTweet;
    newTweet.tweetID = tweetID;
    return newTweet;
}

@end

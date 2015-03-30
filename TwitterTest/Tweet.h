//
//  Tweet.h
//  Pods
//
//  Created by Regan Bell on 3/29/15.
//
//

#import <Foundation/Foundation.h>

@interface Tweet : NSObject

@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSDate *createdAt;
@property (strong, nonatomic) NSNumber *timesRetweeted;
@property (strong, nonatomic) Tweet *retweetedTweet;
@property (strong, nonatomic) NSNumber *tweetID;

+ (Tweet*)tweetFromDictionary:(NSDictionary*)dictionary;

@end

//
//  YYKVStorage.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/4/22.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSInteger YYSQLRowID;
/**
 YYKVStorageItem is used by `YYKVStorage` to store key-value pair and meta data.
 Typically, you should not use this class directly.
 */
@interface YYSQLStorageItem : NSObject

@property (nonatomic, assign, readonly) YYSQLRowID rowID;
///< value
@property (nonatomic, strong) NSData *value;
///< modification unix timestamp
@property (nonatomic, assign, readonly) NSInteger modTime;
///< last access unix timestamp
@property (nonatomic, assign, readonly) NSInteger accessTime;
@end
 
 
@interface YYSQLStorage : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

@property (nonatomic, readonly) NSString *path;        ///< The path of this storage.
@property (nonatomic) BOOL errorLogsEnabled;           ///< Set `YES` to enable error logs for debug.

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;


- (YYSQLRowID)saveItemWithValue:(NSData *)value;
 
- (BOOL)removeItemForRowID:(YYSQLRowID)rowID;
 

- (BOOL)removeAllItems;
 

#pragma mark - Get Items
///=============================================================================
/// @name Get Items
///=============================================================================
- (nullable YYSQLStorageItem *)theYoungest;
- (nullable YYSQLStorageItem *)theOldest;

- (nullable YYSQLStorageItem *)getItemForRowID:(YYSQLRowID)rowID;
 
- (nullable NSData *)getValueForRowID:(YYSQLRowID)rowID;
   

- (void)updateAccessTimeForRowID:(YYSQLRowID)rowID;


- (int)getItemsCount;

@end

NS_ASSUME_NONNULL_END

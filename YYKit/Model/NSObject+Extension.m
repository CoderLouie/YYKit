//
//  NSObject+YYModel.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSObject+YYModel.h"
#import "YYClassInfo.h"
#import <objc/message.h>

#import "NSObject+YYDatabase.h"
#import "NSObject+YYCodable.h"
 
ColumnName DBColumnInsertTime = @"c_insertTime";
ColumnName DBColumnInsertTimestamp = @"c_insertTimestamp";
ColumnName DBColumnDefaultPK = @"rowid";
TableName  DBDefaultTableName = @"common";

@interface NSArray<__covariant ObjectType> (__DBAdd)
- (NSArray *)_db_map:(id _Nullable (^)(ObjectType obj, NSUInteger idx))block;
@end
@implementation NSArray (__DBAdd)
- (NSArray *)_db_map:(id _Nullable (^)(id _Nonnull, NSUInteger))block {
    NSParameterAssert(block != nil);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id value = block(obj, idx);
        if (value != nil) [result addObject:value];
    }];
    return result;
}
@end

@interface NSData (__DBAdd)
@end
@implementation NSData (__DBAdd)
- (NSString *)_db_columnString {
    if (!self.length) return nil;
    return [self base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}
+ (NSData *)_db_dataWithColumnString:(NSString *)str {
    if (!str.length) return nil;
    return [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
}
@end

#define force_inline __inline__ __attribute__((always_inline))

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, YYEncodingNSType) {
    YYEncodingTypeNSUnknown = 0,
    YYEncodingTypeNSString,
    YYEncodingTypeNSMutableString,
    YYEncodingTypeNSValue,
    YYEncodingTypeNSNumber,
    YYEncodingTypeNSDecimalNumber,
    YYEncodingTypeNSData,
    YYEncodingTypeNSMutableData,
    YYEncodingTypeNSDate,
    YYEncodingTypeNSURL,
    YYEncodingTypeNSArray,
    YYEncodingTypeNSMutableArray,
    YYEncodingTypeNSDictionary,
    YYEncodingTypeNSMutableDictionary,
    YYEncodingTypeNSSet,
    YYEncodingTypeNSMutableSet,
};

static force_inline NSString *DBEscapeColumnValue(NSString *columnValue) {
    return [columnValue stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
}
typedef NS_ENUM(NSInteger, DBColumnType) {
    DBColumnTypeUnknown = 0,
    DBColumnTypeInterger,
    DBColumnTypeReal,
    DBColumnTypeText,
    DBColumnTypeBlob,
};
static force_inline NSString *YYDBTypeNameFromType(DBColumnType type) {
    switch (type) {
        case DBColumnTypeInterger: return @"integer";
        case DBColumnTypeReal: return @"real";
        case DBColumnTypeText: return @"text";
        case DBColumnTypeBlob: return @"blob";
        default: return @"";
    }
}
static force_inline DBColumnType YYDBTypeFromEncodingType(YYEncodingType type) {
    switch (type & YYEncodingTypeMask) {
        case YYEncodingTypeBool:
        case YYEncodingTypeInt8:
        case YYEncodingTypeUInt8:
        case YYEncodingTypeInt16:
        case YYEncodingTypeUInt16:
        case YYEncodingTypeInt32:
        case YYEncodingTypeUInt32:
        case YYEncodingTypeInt64:
        case YYEncodingTypeUInt64: return DBColumnTypeInterger;
            
        case YYEncodingTypeFloat:
        case YYEncodingTypeDouble:
        case YYEncodingTypeLongDouble: return DBColumnTypeReal;
            
        case YYEncodingTypeObject:
        case YYEncodingTypeClass:
        case YYEncodingTypeSEL: return DBColumnTypeText;
        default: return DBColumnTypeUnknown;
    }
}
static force_inline DBColumnType YYDBTypeFromNSType(YYEncodingNSType type) {
    switch (type) {
        case YYEncodingTypeNSString:
        case YYEncodingTypeNSMutableString:
        case YYEncodingTypeNSNumber:
        case YYEncodingTypeNSDecimalNumber:
        case YYEncodingTypeNSDate:
        case YYEncodingTypeNSURL:
        case YYEncodingTypeNSArray:
        case YYEncodingTypeNSMutableArray:
        case YYEncodingTypeNSDictionary:
        case YYEncodingTypeNSMutableDictionary:
        case YYEncodingTypeNSSet:
        case YYEncodingTypeNSMutableSet: return DBColumnTypeText;
            
        case YYEncodingTypeNSData:
        case YYEncodingTypeNSMutableData: return DBColumnTypeText;
            
        default: return DBColumnTypeUnknown;
    }
}

/// Get the Foundation class type from property info.
static force_inline YYEncodingNSType YYClassGetNSType(Class cls) {
    if (!cls) return YYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return YYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return YYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return YYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return YYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return YYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return YYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return YYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return YYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return YYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return YYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return YYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return YYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return YYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return YYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return YYEncodingTypeNSSet;
    return YYEncodingTypeNSUnknown;
}

/// Whether the type is c number.
static force_inline BOOL YYEncodingTypeIsCNumber(YYEncodingType type) {
    switch (type & YYEncodingTypeMask) {
        case YYEncodingTypeBool:
        case YYEncodingTypeInt8:
        case YYEncodingTypeUInt8:
        case YYEncodingTypeInt16:
        case YYEncodingTypeUInt16:
        case YYEncodingTypeInt32:
        case YYEncodingTypeUInt32:
        case YYEncodingTypeInt64:
        case YYEncodingTypeUInt64:
        case YYEncodingTypeFloat:
        case YYEncodingTypeDouble:
        case YYEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}

/// Parse a number value from 'id'.
static force_inline NSNumber *YYNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"true" :   @(YES),
                @"false" :  @(NO),
                @"yes" :    @(YES),
                @"no" :     @(NO),
                @"nil" :    (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        NSNumber *num = dic[string.lowercaseString];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([string rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = string.UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else {
            const char *cstring = string.UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));
        }
    }
    return nil;
}

/// Parse string to date.
static force_inline NSDate *YYNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^YYNSDateParseBlock)(NSString *string);
#define kParserNum 34
    static YYNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             2014-01-20 12:24:48.000
             2014-01-20T12:24:48.000
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            NSDateFormatter *formatter3 = [[NSDateFormatter alloc] init];
            formatter3.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter3.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter3.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
            
            NSDateFormatter *formatter4 = [[NSDateFormatter alloc] init];
            formatter4.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter4.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter4.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                } else {
                    return [formatter2 dateFromString:string];
                }
            };
            
            blocks[23] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter3 dateFromString:string];
                } else {
                    return [formatter4 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             2014-01-20T12:24:48.000Z
             2014-01-20T12:24:48.000+0800
             2014-01-20T12:24:48.000+12:00
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            blocks[20] = ^(NSString *string) { return [formatter dateFromString:string]; };
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
            
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]?: [formatter2 dateFromString:string]; };
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[28] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
            blocks[29] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             Fri Sep 04 00:12:21.000 +0800 2015
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"EEE MMM dd HH:mm:ss.SSS Z yyyy";
            blocks[34] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
    });
    if (!string) return nil;
    if (string.length > kParserNum) return nil;
    YYNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
#undef kParserNum
}


/// Get the 'NSBlock' class.
static force_inline Class YYNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}

/**
 Get the ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *YYISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}
 
static force_inline NSString *_DBExtraDebugColumns() {
    return [NSString stringWithFormat:@"%@ text not null default (strftime('%%s','now')), %@ text not null default (datetime('now','localtime'))", DBColumnInsertTimestamp, DBColumnInsertTime];
}

/// Get the value with key paths from dictionary
/// The dic should be NSDictionary, and the keyPath should not be nil.
static force_inline id YYValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = dic;
    for (NSString *keyPath in keyPaths) {
        if (![value isKindOfClass:[NSDictionary class]]) return nil;
        NSUInteger left = [keyPath rangeOfString:@"["].location;
        if (left != NSNotFound) {
            NSString *sub = [keyPath substringToIndex:left];
            value = value[sub];
            if (![value isKindOfClass:[NSArray class]]) return nil;
            NSUInteger right = [keyPath rangeOfString:@"]"].location;
            if (right == NSNotFound) return nil;
            NSString *idxStr = [keyPath substringWithRange:(NSRange){left + 1, right - left - 1}];
            if (!idxStr.length) return nil;
            NSInteger idx = idxStr.integerValue;
            NSArray *array = (NSArray *)value;
            if (idx < array.count) value = array[idx];
            else return nil;
        } else {
            value = value[keyPath];
        }
    }
    return value;
}

/// Get the value with multi key (or key path) from dictionary
/// The dic should be NSDictionary
static force_inline id YYValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        } else {
            value = YYValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}

/// A property info in object model.
@interface _YYModelPropertyMeta : NSObject {
    @package
    NSString *_name;             ///< property's name
    YYEncodingType _type;        ///< property's type
    YYEncodingNSType _nsType;    ///< property's Foundation type
    BOOL _isCNumber;             ///< is c number type
    Class _cls; ///< 属性类型，
    Class _genericCls; ///< 如果是容器类型，是容器类型内元素的类型，如果不是容器类型为nil。
    SEL _getter;                 ///< getter, or nil if the instances cannot respond
    SEL _setter;                 ///< setter, or nil if the instances cannot respond
    BOOL _isKVCCompatible;       ///< YES if it can access with key-value coding
    BOOL _isStructAvailableForKeyedArchiver; ///< YES if the struct can encoded with keyed archiver/unarchiver
    BOOL _hasCustomClassFromDictionary; ///< class/generic class implements +modelCustomClassForDictionary:
    
    NSString *_mappedToKey; ///< 表明该属性取数据源中_mappedToKey对应的value的值。
    NSArray *_mappedToKeyPath;///< 表明该属性取数据源中_mappedToKeyPath对应路径的value值，如果为nil说明没有关键路径
    NSArray *_mappedToKeyArray;///< key或者keyPath的数组，表明可从多个key中取值。
    YYClassPropertyInfo *_info;  ///< property's info
    _YYModelPropertyMeta *_next;///< 下一个元数据，如果有多个属性映射到同一个键。
}
@end

@implementation _YYModelPropertyMeta
+ (instancetype)metaWithClassInfo:(YYClassInfo *)classInfo propertyInfo:(YYClassPropertyInfo *)propertyInfo generic:(Class)generic {
    
    _YYModelPropertyMeta *meta = [self new];
    meta->_info = propertyInfo;
    meta->_genericCls = generic;
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeObject) {
        meta->_nsType = YYClassGetNSType(propertyInfo.cls);
    } else {
        meta->_isCNumber = YYEncodingTypeIsCNumber(meta->_type);
    }
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeStruct) {
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        //如果是以上结构体则支持归解档
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
    }
    meta->_cls = propertyInfo.cls;
    
    if (generic) {
        //容器类元素是否实现了 modelCustomClassForDictionary协议
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == YYEncodingTypeNSUnknown) {
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(modelCustomClassForDictionary:)];
    }
    
    if (propertyInfo.getter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
            meta->_getter = propertyInfo.getter;
        }
    }
    if (propertyInfo.setter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
            meta->_setter = propertyInfo.setter;
        }
    }
    
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        // 以下类型支持KVC
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeBool:
            case YYEncodingTypeInt8:
            case YYEncodingTypeUInt8:
            case YYEncodingTypeInt16:
            case YYEncodingTypeUInt16:
            case YYEncodingTypeInt32:
            case YYEncodingTypeUInt32:
            case YYEncodingTypeInt64:
            case YYEncodingTypeUInt64:
            case YYEncodingTypeFloat:
            case YYEncodingTypeDouble:
            case YYEncodingTypeObject:
            case YYEncodingTypeClass:
            case YYEncodingTypeBlock:
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion: {
                meta->_isKVCCompatible = YES;
            } break;
            default: break;
        }
    }
    
    return meta;
}
@end


@interface _DBColumnMeta : NSObject {
    @package
    NSString *_name;
    DBColumnType _type;
    BOOL _ignoreValue;
}
@end
@implementation _DBColumnMeta
+ (instancetype)metaWithName:(NSString *)name type:(DBColumnType)type {
    _DBColumnMeta *one = [_DBColumnMeta new];
    one->_name = name.copy;
    one->_type = type;
    return one;
}
- (NSString *)_columnInfo {
    return [_name stringByAppendingFormat:@" %@", YYDBTypeNameFromType(_type)];
}
@end
/// A class info in object model.
@interface _YYModelMeta : NSObject {
    @package
    YYClassInfo *_classInfo;
    /// Key:mapped key and key path, Value:_YYModelPropertyMeta.
    NSDictionary *_mapper;
    /// Array<_YYModelPropertyMeta>, all property meta of this model.
    NSArray *_allPropertyMetas;
    
    NSArray<_YYModelPropertyMeta *> *_jsonPropertyMetas;
    
    NSDictionary *_dbMapper;
    /// [@[@"age", @(YYDBTypeInterger)], @[@"name", @(YYDBTypeText)]]
    NSMutableArray<_DBColumnMeta *> *_dbColumns;
    
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    YYEncodingNSType _nsType;
    
    BOOL _hasCustomClassFromDictionary;
    
    BOOL _useBuiltinPK;
    BOOL _dbIsInitialized;
    NSString *_db_primaryKey;
    NSString * (^_db_generateDDLSql)(NSString *tableName);
}

@end

@implementation _YYModelMeta
- (instancetype)initWithClass:(Class)cls {
    YYClassInfo *classInfo = [YYClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get container property's generic class
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(modelCustomClassInArray)]) {
        genericMapper = [(id<YYModel>)cls modelCustomClassInArray];
        if (genericMapper) {
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                /// object_getClass([NSObject class]]) == nil;
                if (!meta) return;
                if (class_isMetaClass(meta)) tmp[key] = obj;
                else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) tmp[key] = cls;
                }
            }];
            genericMapper = tmp;
        }
    }
    
    // Create all property metas.
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    YYClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) { // recursive parse super class, but ignore root class (NSObject/NSProxy)
        for (YYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            _YYModelPropertyMeta *meta = [_YYModelPropertyMeta
                                          metaWithClassInfo:classInfo
                                          propertyInfo:propertyInfo
                                          generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count) _allPropertyMetas = [allPropertyMetas.allValues sortedArrayUsingComparator:^NSComparisonResult(_YYModelPropertyMeta *p1, _YYModelPropertyMeta *p2) {
        return [p1->_name compare:p2->_name];
    }].copy;
    
    if (_allPropertyMetas.count) {
        NSInteger count = _allPropertyMetas.count;
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithCapacity:count];
        NSMutableDictionary *dbMapper = [NSMutableDictionary dictionaryWithCapacity:count];
         
        NSMutableArray *jsonPropertyMetas = [NSMutableArray arrayWithCapacity:count];
        NSMutableArray *colums = [NSMutableArray arrayWithCapacity:count];
        // Get db black list
        NSSet *dbBlacklist = nil;
        if ([cls respondsToSelector:@selector(db_blackPropertyNamesList)]) {
            NSArray *properties = [(id<YYDataBase>)cls db_blackPropertyNamesList];
            if (properties) dbBlacklist = [NSSet setWithArray:properties];
        }
         
        NSSet *dbIgnores = nil;
        if ([cls respondsToSelector:@selector(db_ignorePropertyNames)]) {
            NSArray *ignores = [(id<YYDataBase>)cls db_ignorePropertyNames];
            if (ignores) dbIgnores = [NSSet setWithArray:ignores];
        }
        
        // Get json black list
        NSSet *jsonBlacklist = nil;
        if ([cls respondsToSelector:@selector(ignoredModelPropertyNames)]) {
            NSArray *properties = [(id<YYModel>)cls ignoredModelPropertyNames];
            if (properties) jsonBlacklist = [NSSet setWithArray:properties];
        }
        
        for (_YYModelPropertyMeta *meta in _allPropertyMetas) {
            NSString *name = meta->_name;
            if (![jsonBlacklist containsObject:name]) {
                [jsonPropertyMetas addObject:meta];
                tmp[name] = meta;
            }
            
            if (![dbBlacklist containsObject:name]) {
                DBColumnType type = DBColumnTypeUnknown;
                if (meta->_nsType) {
                    type = YYDBTypeFromNSType(meta->_nsType);
                } else {
                    type = YYDBTypeFromEncodingType(meta->_type);
                }
                if (type == DBColumnTypeUnknown) continue;
                dbMapper[name] = meta;
                if (![dbIgnores containsObject:name]) {
                    _DBColumnMeta *column = [_DBColumnMeta metaWithName:name type:type];
                    [colums addObject:column];
                }
            }
        }
        _jsonPropertyMetas = jsonPropertyMetas;
         
        _dbColumns = colums;
        _dbMapper = dbMapper;
        
        allPropertyMetas = tmp;
    }
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    if ([cls respondsToSelector:@selector(replaceKeyFromPropertyName)]) {
        NSDictionary *customMapper = [(id <YYModel>)cls replaceKeyFromPropertyName];
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
            _YYModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (!propertyMeta) return;
            [allPropertyMetas removeObjectForKey:propertyName];
            
            if ([mappedToKey isKindOfClass:[NSString class]]) {
                if (mappedToKey.length == 0) return;
                
                propertyMeta->_mappedToKey = mappedToKey;
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
                for (NSString *onePath in keyPath) {
                    if (onePath.length == 0) {
                        NSMutableArray *tmp = keyPath.mutableCopy;
                        [tmp removeObject:@""];
                        keyPath = tmp;
                        break;
                    }
                }
                if (keyPath.count > 1) {
                    propertyMeta->_mappedToKeyPath = keyPath;
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
                
            } else if ([mappedToKey isKindOfClass:[NSArray class]]) {
                
                NSMutableArray *mappedToKeyArray = [NSMutableArray new];
                for (NSString *oneKey in ((NSArray *)mappedToKey)) {
                    if (![oneKey isKindOfClass:[NSString class]]) continue;
                    if (oneKey.length == 0) continue;
                    
                    NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                    if (keyPath.count > 1) {
                        [mappedToKeyArray addObject:keyPath];
                    } else {
                        [mappedToKeyArray addObject:oneKey];
                    }
                    
                    if (!propertyMeta->_mappedToKey) {
                        propertyMeta->_mappedToKey = oneKey;
                        propertyMeta->_mappedToKeyPath = keyPath.count > 1 ? keyPath : nil;
                    }
                }
                if (!propertyMeta->_mappedToKey) return;
                
                propertyMeta->_mappedToKeyArray = mappedToKeyArray;
                [multiKeysPropertyMetas addObject:propertyMeta];
                
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
            }
        }];
    }
    
    if ([cls respondsToSelector:@selector(replaceKeyFromPropertyName121:)]) {
        [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
            NSString *mappedToKey = [(id <YYModel>)cls replaceKeyFromPropertyName121:name];
            if (![mappedToKey isKindOfClass:[NSString class]]) return;
            if (mappedToKey.length == 0) return;
            
            [allPropertyMetas removeObjectForKey:name];
            propertyMeta->_mappedToKey = mappedToKey;
            
            NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
            for (NSString *onePath in keyPath) {
                if (onePath.length == 0) {
                    NSMutableArray *tmp = keyPath.mutableCopy;
                    [tmp removeObject:@""];
                    keyPath = tmp;
                    break;
                }
            }
            
            if (keyPath.count > 1) {
                propertyMeta->_mappedToKeyPath = keyPath;
                [keyPathPropertyMetas addObject:propertyMeta];
            }
            
            propertyMeta->_next = mapper[mappedToKey] ?: nil;
            mapper[mappedToKey] = propertyMeta;
        }];
    }
    
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        propertyMeta->_mappedToKey = name;
        propertyMeta->_next = mapper[name] ?: nil;
        mapper[name] = propertyMeta;
    }];
    
    if (mapper.count) _mapper = mapper;
    if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _classInfo = classInfo;
    _keyMappedCount = _jsonPropertyMetas.count;
    _nsType = YYClassGetNSType(cls);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);
    
    return self;
}

/// Returns the cached model class meta
+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    _YYModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    dispatch_semaphore_signal(lock);
    if (!meta || meta->_classInfo.needUpdate) {
        meta = [[_YYModelMeta alloc] initWithClass:cls];
        if (meta) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            dispatch_semaphore_signal(lock);
        }
    }
    return meta;
}

- (NSArray<NSString *> *)_dbColumnNames {
    return [self _dbColumnNamesDebugged:NO];
}

- (NSArray<NSString *> *)_dbColumnInfos {
    return [self _dbColumnInfosDebugged:NO];
}

- (NSArray<NSString *> *)_dbColumnNamesDebuged {
    return [self _dbColumnNamesDebugged:YES];
}
- (NSArray<NSString *> *)_dbColumnsOnMasterTable {
    NSArray *res = [_dbColumns _db_map:^id _Nullable(_DBColumnMeta *obj, NSUInteger idx) {
        NSString *name = obj->_name;
        if ([name isEqualToString:_db_primaryKey]) return nil;
        return name;
    }];
    return [res arrayByAddingObjectsFromArray:@[DBColumnInsertTimestamp, DBColumnInsertTime]];
}

- (NSArray<NSString *> *)_dbColumnInfosDebuged {
    return [self _dbColumnInfosDebugged:YES];
}


- (NSArray<NSString *> *)_dbColumnNamesDebugged:(BOOL)debug {
    NSArray *res = [_dbColumns _db_map:^id _Nullable(_DBColumnMeta *obj, NSUInteger idx) {
        return obj->_name;
    }];
    if (!debug) return res;
    return [res arrayByAddingObjectsFromArray:@[DBColumnInsertTimestamp, DBColumnInsertTime]];
}

- (NSArray<NSString *> *)_dbColumnInfosDebugged:(BOOL)debug {
    NSArray *column = !debug ? _dbColumns : self._dbDebugColumns;
    return [column _db_map:^id _Nullable(_DBColumnMeta *obj, NSUInteger idx) {
        return obj._columnInfo;
    }];
}

- (NSArray<_DBColumnMeta *>*)_dbDebugColumns {
    return [_dbColumns arrayByAddingObjectsFromArray:@[[_DBColumnMeta metaWithName:DBColumnInsertTimestamp type:DBColumnTypeReal], [_DBColumnMeta metaWithName:DBColumnInsertTime type:DBColumnTypeText]]];
}
@end

static force_inline NSArray *YYArrayFromJSON(id json) {
    if (!json) return nil;
    
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return arr;
}
static force_inline NSDictionary *YYDictionaryFromJSON(id json) {
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
static force_inline NSNumber *
ModelCreateNumberFromProperty(__unsafe_unretained id model,
                              __unsafe_unretained _YYModelPropertyMeta *meta) {
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default: return nil;
    }
}

/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 */
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _YYModelPropertyMeta *meta) {
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case YYEncodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case YYEncodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case YYEncodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case YYEncodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case YYEncodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case YYEncodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case YYEncodingTypeInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case YYEncodingTypeUInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case YYEncodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case YYEncodingTypeDouble: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case YYEncodingTypeLongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } // break; commented for code coverage in next line
        default: break;
    }
}

/**
 Set value to model with a property meta.
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id value,
                                     __unsafe_unretained _YYModelPropertyMeta *meta) {
    if (meta->_isCNumber) {
        NSNumber *num = YYNSNumberCreateFromID(value);
        ModelSetNumberToProperty(model, num, meta);
        if (num) [num class]; // hold the number
    } else if (meta->_nsType) {
        if (value == (id)kCFNull) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
        } else {
            switch (meta->_nsType) {
                case YYEncodingTypeNSString:
                case YYEncodingTypeNSMutableString: {
                    if ([value isKindOfClass:[NSString class]]) {
                        if (meta->_nsType == YYEncodingTypeNSString) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSString *)value).mutableCopy);
                        }
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSNumber *)value).stringValue :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                    } else if ([value isKindOfClass:[NSData class]]) {
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, string);
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSURL *)value).absoluteString :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                    } else if ([value isKindOfClass:[NSAttributedString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                } break;
                    
                case YYEncodingTypeNSValue:
                case YYEncodingTypeNSNumber:
                case YYEncodingTypeNSDecimalNumber: {
                    if (meta->_nsType == YYEncodingTypeNSNumber) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSNumberCreateFromID(value));
                    } else if (meta->_nsType == YYEncodingTypeNSDecimalNumber) {
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            if (dec._length == 0 && dec._isNegative) {
                                decNum = nil; // NaN
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        }
                    } else { // YYEncodingTypeNSValue
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSData:
                case YYEncodingTypeNSMutableData: {
                    NSData *data = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        data = [NSData _db_dataWithColumnString:value]; // hold
                        value = data;
                    }
                    if ([value isKindOfClass:[NSData class]]) {
                        if (meta->_nsType == YYEncodingTypeNSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            NSMutableData *data = ((NSData *)value).mutableCopy;
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSDate: {
                    if ([value isKindOfClass:[NSDate class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSDateFromString(value));
                    }
                } break;
                    
                case YYEncodingTypeNSURL: {
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSArray:
                case YYEncodingTypeNSMutableArray: {
                    NSArray *valueArr = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        valueArr = YYArrayFromJSON(value);
                        value = valueArr;
                    } else {
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
                    }
                    if (!valueArr) return;
                    if (meta->_genericCls) {
                        
                        NSMutableArray *objectArr = [NSMutableArray new];
                        for (id one in valueArr) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [objectArr addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls modelCustomClassForDictionary:one];
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                /// 发生递归调用
                                NSObject *newOne = [cls new];
                                [newOne setPropertiesValuesWithDictionary:one];
                                if (newOne) [objectArr addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                    } else {
                        if (meta->_nsType == YYEncodingTypeNSArray) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueArr);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           valueArr.mutableCopy);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSDictionary:
                case YYEncodingTypeNSMutableDictionary: {
                    NSDictionary *dicTmp = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        dicTmp = YYDictionaryFromJSON(value);
                    } else if ([value isKindOfClass:[NSDictionary class]]) {
                        dicTmp = value;
                    }
                    if (!dicTmp) return;
                    
                    if (meta->_genericCls) {
                        NSMutableDictionary *dic = [NSMutableDictionary new];
                        [dicTmp enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                            if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls modelCustomClassForDictionary:oneValue];
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                NSObject *newOne = [cls new];
                                [newOne setPropertiesValuesWithDictionary:(id)oneValue];
                                if (newOne) dic[oneKey] = newOne;
                            }
                        }];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                    } else {
                        if (meta->_nsType == YYEncodingTypeNSDictionary) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dicTmp);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           dicTmp.mutableCopy);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSSet:
                case YYEncodingTypeNSMutableSet: {
                    NSSet *valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                    else if ([value isKindOfClass:[NSString class]]) valueSet = [NSMutableSet setWithArray:YYArrayFromJSON(value)];
                    
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for (id one in valueSet) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls modelCustomClassForDictionary:one];
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                NSObject *newOne = [cls new];
                                [newOne setPropertiesValuesWithDictionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                    } else {
                        if (meta->_nsType == YYEncodingTypeNSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           ((NSSet *)valueSet).mutableCopy);
                        }
                    }
                } // break; commented for code coverage in next line
                    
                default: break;
            }
        }
    } else {
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeObject: {
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                } else if ([value isKindOfClass:meta->_cls] || !meta->_cls) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one setPropertiesValuesWithDictionary:value];
                    } else {
                        Class cls = meta->_cls;
                        if (meta->_hasCustomClassFromDictionary) {
                            cls = [cls modelCustomClassForDictionary:value];
                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                        }
                        one = [cls new];
                        [one setPropertiesValuesWithDictionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            } break;
                
            case YYEncodingTypeClass: {
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                } else {
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                        }
                    } else {
                        cls = object_getClass(value);
                        if (cls) {
                            if (class_isMetaClass(cls)) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                            }
                        }
                    }
                }
            } break;
                
            case YYEncodingTypeSEL: {
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                }
            } break;
                
            case YYEncodingTypeBlock: {
                if (isNull) {
                    ((void (*)(id, SEL, void (^)(void)))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)(void))NULL);
                } else if ([value isKindOfClass:YYNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)(void)))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)(void))value);
                }
            } break;
                
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion:
            case YYEncodingTypeCArray: {
                if ([value isKindOfClass:[NSValue class]]) {
                    const char *valueType = ((NSValue *)value).objCType;
                    const char *metaType = meta->_info.typeEncoding.UTF8String;
                    if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                        [model setValue:value forKey:meta->_name];
                    }
                }
            } break;
                
            case YYEncodingTypePointer:
            case YYEncodingTypeCString: {
                if (isNull) {
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsValue = value;
                    if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                    }
                }
            } // break; commented for code coverage in next line
                
            default: break;
        }
    }
}


typedef struct {
    void *modelMeta;  ///< _YYModelMeta
    void *model;      ///< id (self)
    void *dictionary; ///< NSDictionary (json)
} ModelSetContext;

/**
 Apply function for dictionary, to set the key-value pair to model.
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _YYModelMeta *meta = (__bridge _YYModelMeta *)(context->modelMeta);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

/**
 Apply function for model property meta, to set dictionary to model.
 
 @param _propertyMeta should not be nil, _YYModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = (__bridge _YYModelPropertyMeta *)(_propertyMeta);
    
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
        value = YYValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
        value = YYValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}
/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull),
 or nil if an error occurs.
 
 @param model Model, can be nil.
 @return JSON object, nil if an error occurs.
 */
static id ModelToJSONObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = ModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [YYISODateFormatter() stringFromDate:(id)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case YYEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case YYEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            NSMutableArray *superArr = nil;
            NSMutableArray *subArr = nil;
            BOOL contains = NO;
            
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                
                NSRange left = [key rangeOfString:@"["];
                if (left.location != NSNotFound) {
                    NSString *subKey = [key substringToIndex:left.location];
                    subDic = superDic[subKey];
                    if (subDic) {
                        
                    } else {
                        subDic = [NSMutableDictionary dictionary];
                        subArr = [NSMutableArray new];
                        superDic[subKey] = subArr;
                        if (superArr && contains) [superArr addObject:superDic];
                    }
                    NSInteger start = left.location + left.length;
                    NSRange right = [key rangeOfString:@"]"];
                    if (right.location == NSNotFound) {
                        NSLog(@"the mapper of keypath %@ which class is %@ error", key, propertyMeta->_cls);
                    } else {
                        contains = YES;
                        NSString *countStr = [key substringWithRange:(NSRange){start, right.location - start}];
                        if (countStr.length == 0) {
                            NSLog(@"the mapper of keypath %@ which class is %@ error", key, propertyMeta->_cls);
                        } else {
                            NSInteger count = countStr.integerValue;
                            for (NSInteger i = 0; i < count; i++)
                                [subArr addObject:[NSNull null]];
                        }
                    }
                    
                    superDic = subDic;
                    superArr = subArr;
                    subDic = nil;
                    subArr = nil;
                    if (i + 1 == max) if (superArr) [superArr addObject:value];
                } else {
                    subDic = superDic[key];
                    if (subDic) {
                        
                    } else {
                        if (i + 1 == max) {
                            superDic[key] = value;
                            if (superArr && contains) [superArr addObject:superDic];
                        } else {
                            subDic = [NSMutableDictionary new];
                            superDic[key] = subDic;
                            if (superArr && contains) [superArr addObject:superDic];
                        }
                    }
                    contains = NO;
                    superDic = subDic;
                    subDic = nil;
                }
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    return result;
}


@implementation NSObject (YYModel)

+ (instancetype)modelWithJSON:(id)json {
    NSDictionary *dic = YYDictionaryFromJSON(json);
    return [self modelWithDictionary:dic];
}

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:cls];
    // 可以根据dictionary数据创建一个不同于当前类的对象来完成json转model
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one setPropertiesValuesWithDictionary:dictionary]) return one;
    return nil;
}

- (BOOL)setPropertiesValuesWithJSON:(id)json {
    NSDictionary *dic = YYDictionaryFromJSON(json);
    return [self setPropertiesValuesWithDictionary:dic];
}

- (BOOL)setPropertiesValuesWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_jsonPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    
    return YES;
}

- (id)modelToJSONObject {
    id jsonObject = ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}

- (NSData *)modelToJSONData {
    id jsonObject = [self modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}

- (NSString *)modelToJSONString {
    NSData *jsonData = [self modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)modelCopy {
    if (self == (id)kCFNull) return self;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeBool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt8:
                case YYEncodingTypeUInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt16:
                case YYEncodingTypeUInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt32:
                case YYEncodingTypeUInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt64:
                case YYEncodingTypeUInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeFloat: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeDouble: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeLongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } // break; commented for code coverage in next line
                default: break;
            }
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject:
                case YYEncodingTypeClass:
                case YYEncodingTypeBlock: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL:
                case YYEncodingTypePointer:
                case YYEncodingTypeCString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }
                    } @catch (NSException *exception) {}
                } // break; commented for code coverage in next line
                default: break;
            }
        }
    }
    return one;
}

- (NSUInteger)modelHash {
    if (self == (id)kCFNull) return [self hash];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)((__bridge void *)self);
    return value;
}

- (BOOL)modelIsEqual:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if (![this isEqual:that]) return NO;
    }
    return YES;
}

+ (NSArray *)modelArrayWithKeyValues:(id)json {
    
    NSArray *arr = YYArrayFromJSON(json);
    if (!arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [self modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

+ (instancetype)modelWithFilename:(NSString *)filename {
    NSAssert(filename.length, @"filename参数有误");
    return [self modelWithFilePath:[[NSBundle mainBundle] pathForResource:filename ofType:nil]];
}
+ (instancetype)modelWithFilePath:(NSString *)path {
    NSAssert(path.length, @"path参数有误");
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:path], @"文件不存在");
    return [self modelWithJSON:[NSData dataWithContentsOfFile:path]];
}

+ (NSArray *)modelArrayWithFilename:(NSString *)filename {
    NSAssert(filename.length, @"filename参数有误");
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
    
    return [self modelArrayWithFilePath:path];
}

+ (NSArray *)modelArrayWithFilePath:(NSString *)path {
    NSAssert(path.length, @"path参数有误");
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:path], @"文件不存在");
    return [self modelArrayWithKeyValues:[NSData dataWithContentsOfFile:path]];
}

- (BOOL)outputToFilePath:(NSString *)path {
    NSDictionary *dict = [self modelToJSONObject];
    [[NSFileManager defaultManager]createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *fileType = path.pathExtension;
    if ([fileType.lowercaseString isEqualToString:@"json"]) {
        NSOutputStream *outStream = [[NSOutputStream alloc] initToFileAtPath:path append:NO];
        [outStream open];
        BOOL result = [NSJSONSerialization writeJSONObject:dict toStream:outStream options:NSJSONWritingPrettyPrinted error:NULL];
        [outStream close];
        return result;
    }
    return [dict writeToFile:path atomically:YES];
}

@end

NSDictionary *JSONFromFile(NSString *filename) {
    assert(filename.length);
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
    return JSONFromFilePath(path);
}
NSArray *JSONArrayFromFile(NSString *filename) {
    assert(filename.length);
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
    return JSONArrayFromFilePath(path);
}

NSDictionary *JSONFromFilePath(NSString *path) {
    assert(path.length);
    assert([[NSFileManager defaultManager] fileExistsAtPath:path]);
    return YYDictionaryFromJSON([NSData dataWithContentsOfFile:path]);
}
NSArray *JSONArrayFromFilePath(NSString *path) {
    assert(path.length );
    assert([[NSFileManager defaultManager] fileExistsAtPath:path]);
    return YYArrayFromJSON([NSData dataWithContentsOfFile:path]);
}

// MARK: - Coding

@implementation NSObject (YYCodable)

- (BOOL)cd_archive {
    NSString *path = [[self class] cd_filePath];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archiveRootObject:self toFile:path];
#pragma clang diagnostic pop
}
+ (instancetype)cd_unarchive {
    NSString *path = [self cd_filePath];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
#pragma clang diagnostic pop
    
}
+ (NSString *)cd_filePath {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/archive/"];
    NSString *path = nil;
    if ([self respondsToSelector:@selector(cd_filePathWithSuggestDirectory:)]) {
        path = [(id<YYCodeable>)self cd_filePathWithSuggestDirectory:dir];
    } else {
        path = [dir stringByAppendingFormat:@"%@.data", NSStringFromClass(self)];
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [manager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return path;
}
+ (BOOL)cd_remove {
    NSString *path = [self cd_filePath];
    return [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (void)modelEncodeWithCoder:(NSCoder *)aCoder {
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    
    // Get black list
    NSSet *blacklist = nil;
    Class cls = [self class];
    if ([cls respondsToSelector:@selector(cd_ignoredPropertyNames)]) {
        NSArray *properties = [(id<YYCodeable>)cls cd_ignoredPropertyNames];
        if (properties) blacklist = [NSSet setWithArray:properties];
    }
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(cd_allowedPropertyNames)]) {
        NSArray *properties = [(id<YYCodeable>)cls cd_allowedPropertyNames];
        if (properties) whitelist = [NSSet setWithArray:properties];
    }
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) continue;
        if ([blacklist containsObject:propertyMeta->_name]) continue;
        if (whitelist && ![whitelist containsObject:propertyMeta->_name]) continue;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta->_name];
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        if ([value isKindOfClass:[NSValue class]]) {
                            if ([value isKindOfClass:[NSNumber class]]) {
                                [aCoder encodeObject:value forKey:propertyMeta->_name];
                            }
                        } else {
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                    }
                } break;
                case YYEncodingTypeSEL: {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible && propertyMeta->_isStructAvailableForKeyedArchiver) {
                        @try {
                            NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
}

- (id)modelInitWithCoder:(NSCoder *)aDecoder {
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    // Get black list
    NSSet *blacklist = nil;
    Class cls = [self class];
    if ([cls respondsToSelector:@selector(cd_ignoredPropertyNames)]) {
        NSArray *properties = [(id<YYCodeable>)cls cd_ignoredPropertyNames];
        if (properties) blacklist = [NSSet setWithArray:properties];
    }
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(cd_allowedPropertyNames)]) {
        NSArray *properties = [(id<YYCodeable>)cls cd_allowedPropertyNames];
        if (properties) whitelist = [NSSet setWithArray:properties];
    }
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        if ([blacklist containsObject:propertyMeta->_name]) continue;
        if (whitelist && ![whitelist containsObject:propertyMeta->_name]) continue;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if ([value isKindOfClass:[NSNumber class]]) {
                ModelSetNumberToProperty(self, value, propertyMeta);
                [value class]; // hold the number
            }
        } else {
            YYEncodingType type = propertyMeta->_type & YYEncodingTypeMask;
            switch (type) {
                case YYEncodingTypeObject: {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL: {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible) {
                        @try {
                            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                            if (value) [self setValue:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}

@end


// MARK: - YYDataBase

static void DBModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _YYModelMeta *meta = (__bridge _YYModelMeta *)(context->modelMeta);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = [meta->_dbMapper objectForKey:(__bridge id)(_key)];
    
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

static id DBDescFromSimpleNSType(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return DBEscapeColumnValue((NSString *)model);
    if ([model isKindOfClass:[NSNumber class]]) return model;
    
    if ([model isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)model;
        if (!data.length) return nil;
        return [data _db_columnString];
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [YYISODateFormatter() stringFromDate:(id)model];
    
    return nil;
}

static id DBModelToJSONObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    id val = DBDescFromSimpleNSType(model);
    if (val) return val;
    
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = DBModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        model = array;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = DBModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_dbMapper == 0) return nil;
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithCapacity:64];; // avoid retain and release in block
    for (_DBColumnMeta *column in modelMeta->_dbColumns) {
        if (column->_ignoreValue) continue;
        NSString *columnName = column->_name;
        _YYModelPropertyMeta *propertyMeta = modelMeta->_dbMapper[columnName];
        if (!propertyMeta->_getter) continue;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = DBModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = DBModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case YYEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case YYEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) continue;
        if (!dic[propertyMeta->_name]) {
            dic[propertyMeta->_name] = value;
        }
    }
    
    return dic;
}
static force_inline NSString *DBValueDescription(id val) {
    if ([val isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%@", val];
    } else {
        return [NSString stringWithFormat:@"'%@'", val];
    }
}
static force_inline NSString *DBKeyValueDescription(NSArray *kv) {
    return [NSString stringWithFormat:@"%@ = %@", kv[0], DBValueDescription(kv[1])];
}

static id DBModelToObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    id val = DBDescFromSimpleNSType(model);
    if (val) return val;
    
    if ([model isKindOfClass:[NSDictionary class]] ||
        [model isKindOfClass:[NSArray class]] ||
        [model isKindOfClass:[NSSet class]]) {
        id jsonObject = DBModelToJSONObjectRecursive(model);
        if (!jsonObject) return nil;
        if (![jsonObject isKindOfClass:[NSArray class]] &&
            [jsonObject isKindOfClass:[NSDictionary class]]) return nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
        if (jsonData.length == 0) return nil;
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:[model class]];
    if (!modelMeta) return nil;
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:64];
    
    for (_DBColumnMeta *column in modelMeta->_dbColumns) {
        if (column->_ignoreValue) continue;
        NSString *columnName = column->_name;
        _YYModelPropertyMeta *propertyMeta = modelMeta->_dbMapper[columnName];
        if (!propertyMeta->_getter) continue;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = DBModelToObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = DBModelToObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case YYEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case YYEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) continue;
        [result addObject:@[propertyMeta->_name, value]];
    }
    
    return result;
}

@interface NSObject (_DBSupport)

@end
@implementation NSObject (_DBSupport)

+ (instancetype)db_modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    
    NSObject *one = [cls new];
    [one db_setPropertiesWithDictionary:dictionary];
    return one;
}

- (BOOL)db_setPropertiesWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:object_getClass(self)];
    NSInteger count = modelMeta->_dbMapper.count;
    if (count == 0) return NO;
    
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    
    CFDictionaryApplyFunction((CFDictionaryRef)dic, DBModelSetWithDictionaryFunction, &context);
    
    return YES;
}
@end

#import "YYDatabase.h"

#import "NSString+YYModel.h"
static force_inline NSString *YYTableNameFromClass(Class cls) {
    NSString *name = NSStringFromClass(cls);
    if ([name containsString:@"."]) {
        name = [name componentsSeparatedByString:@"."].lastObject;
    }
    return [NSString stringWithFormat:@"t_%@", name];
}
static force_inline NSString *YYTmpTableNameFromClass(Class cls) {
    return [NSString stringWithFormat:@"t_%@_tmp", NSStringFromClass(cls)];
}

static NSMapTable *_cache;
static dispatch_semaphore_t _lock;

static YYDatabase *_YYGetGlobalDBFromCache(Class cls) {
    NSString *path = [cls db_filePath];
    if (!path.length) return nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _lock = dispatch_semaphore_create(1);
        _cache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory capacity:0];
    });
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    YYDatabase *db = [_cache objectForKey:path];
    if (!db) {
        db = [[YYDatabase alloc] initWithPath:path];
        [_cache setObject:db forKey:path];
    }
    dispatch_semaphore_signal(_lock);
    return db;
}

// MARK: - ColumnConstraintWorker
typedef NS_ENUM(NSInteger, ColumnConstraintType) {
    NotNull = 0,
    Autoincrement,
    PrimaryKey,
    Unique,
    Default,
    ForeignReference,
    
    UniqueIndex,
    Index,
};

static force_inline NSString *KeyConstraintDescFromType(ColumnConstraintType type ) {
    switch (type) {
        case NotNull: return @"not null";
        case PrimaryKey: return @"primary key";
        case Autoincrement: return @"autoincrement";
        case Unique: return @"unique";
        case Default: return @"default";
        default: return @"";
    }
}

static force_inline NSArray *KeyConstraintOrder() {
    return @[@(NotNull), @(Unique), @(PrimaryKey), @(Autoincrement), @(Default)];
}

static force_inline NSString *ForeignKeyActionDesc(ForeignKeyAction action) {
    switch (action) {
        case nothing:
            return @"no action";
        case prohibit:
            return @"restrict";
        case setNULL:
            return @"set null";
        case setDefault:
            return @"set default";
        case cascade:
            return @"cascade";
        default:
            break;
    }
}

@interface ColumnConstraintWorker ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *types;
@end
@implementation ColumnConstraintWorker

- (void (^)(void))end {
    return ^(void) {};
}
- (ColumnConstraintWorker * _Nonnull (^)(void))notnull {
    return [self _addConstraint:NotNull];
}
- (ColumnConstraintWorker * _Nonnull (^)(void))primaryKey {
    return [self _addConstraint:PrimaryKey];
}
- (ColumnConstraintWorker * _Nonnull (^)(void))autoincrement {
    return [self _addConstraint:Autoincrement];
}
- (ColumnConstraintWorker * _Nonnull (^)(void))unique {
    return [self _addConstraint:Unique];
}
- (ColumnConstraintWorker * _Nonnull (^)(void))uniqueIndex {
    return [self _addConstraint:UniqueIndex];
}
- (ColumnConstraintWorker * _Nonnull (^)(void))index {
    return [self _addConstraint:Index];
}

- (ColumnConstraintWorker * _Nonnull (^)(id _Nonnull))defaulte {
    return ^(id value) {
        self->_types[@(Default)] = value;
        return self;
    };
}
- (ColumnConstraintWorker * _Nonnull (^)(TableName _Nonnull, ColumnName _Nonnull, ForeignKeyAction, ForeignKeyAction))foreignRef {
    return ^(TableName tableName, ColumnName column, ForeignKeyAction onDelete, ForeignKeyAction onUpdate) {
        NSString *del = ForeignKeyActionDesc(onDelete);
        NSString *up = ForeignKeyActionDesc(onUpdate);
        self->_types[@(ForeignReference)] = ^(ColumnName existName) {
            return [NSString stringWithFormat:@"foreign key(%@) references %@(%@) on delete %@ on update %@", existName, tableName, column, del, up];
        };
        return self;
    };
}

- (ColumnConstraintWorker *  _Nonnull (^)(void))_addConstraint:(ColumnConstraintType)type {
    return ^(void) {
        self->_types[@(type)] = @"1";
        return self;
    };
}

- (BOOL)containsPrimaryKey {
    return self.types[@(PrimaryKey)] != nil;
}
- (BOOL)containsAutoincrease {
    return self.types[@(Autoincrement)] != nil;
}

- (BOOL)containsUniqueIndex {
    return _types[@(UniqueIndex)] != nil;
}
- (BOOL)containsIndex {
    return _types[@(Index)] != nil;
}

- (NSString *)toConstraintWithColumnName:(NSString *)name type:(DBColumnType)type  {
    // 为了简单起见，这里只做一些必要的检验，
    if (self.types[@(Autoincrement)] && type != DBColumnTypeInterger) {
        NSAssert(NO, @"Autoincrement 约束只能添加在整形字段上, 但是 %@ is %@", name, YYDBTypeNameFromType(type));
    }
    
    NSMutableArray<NSString *> *res = [NSMutableArray arrayWithCapacity:8];
    NSArray *orders = KeyConstraintOrder();
    for (NSNumber *num in orders) {
        ColumnConstraintType type = num.integerValue;
        id value = self.types[num];
        if (value) {
            NSString *tag = KeyConstraintDescFromType(type);
            
            if (type == Default) {
                value = DBModelToObjectRecursive(value);
                if ([value isKindOfClass:[NSNumber class]]) {
                    tag = [tag stringByAppendingFormat:@" %@", value];
                } else if ([value isKindOfClass:[NSString class]]) {
                    tag = [tag stringByAppendingFormat:@" '%@'", value];
                } else {
                    if (DBErrorLogsEnabled) {
                        NSLog(@"can not convert %@ to NSSNumber or NSSting, please check your table or the default value design correctly", self.types[num]);
                    }
                    tag = nil;
                }
            }
            if (tag.length) [res addObject:tag];
        }
    }
    if (!res.count) return nil;
    return [res componentsJoinedByString:@" "];
}
- (NSString *)toForeignKeyConstraint:(ColumnName)columnName {
    NSString *(^block)(NSString *) = self->_types[@(ForeignReference)];
    if (!block) return nil;
    return block(columnName);
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _types = [NSMutableDictionary dictionaryWithCapacity:8];
    return self;
}
@end
@implementation ColumnConstraintMaker {
    @package
    NSMutableDictionary<ColumnName, ColumnConstraintWorker *> *_subs;
}

- (ColumnConstraintWorker * _Nonnull (^)(ColumnName _Nonnull))column {
    return ^(ColumnName name) {
        NSAssert(name.length, @"column name must not empty");
        ColumnConstraintWorker *work = self->_subs[name];
        if (!work) {
            work = [ColumnConstraintWorker new];
            self->_subs[name] = work;
        }
        return work;
    };
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _subs = [NSMutableDictionary dictionaryWithCapacity:16];
    return self;
}

@end

// MARK: - _YYModelMeta Extension
@interface _YYModelMeta (__Private)
- (NSString *)db_primaryKey;
- (NSString *)db_createTableSqlWithTableName:(NSString *)tableName;
@end
@implementation _YYModelMeta (__Private)

- (NSString *)db_primaryKey {
    if (_db_primaryKey.length) return _db_primaryKey;
    [self _db_initializeDDL];
    return _db_primaryKey;
}
- (NSString *)db_createTableSqlWithTableName:(NSString *)tableName {
    if (_db_generateDDLSql) return _db_generateDDLSql(tableName);
    [self _db_initializeDDL];
    return _db_generateDDLSql(tableName);
}


- (void)_db_initializeDDL {
    Class cls = self->_classInfo.cls; 

    ColumnConstraintMaker *maker = nil;
    if ([cls respondsToSelector:@selector(db_makeColumnConstraints:)]) {
        maker = [ColumnConstraintMaker new];
        [(id<YYDataBase>)cls db_makeColumnConstraints:maker];
    }
    
    NSArray *columns = _dbColumns;
    NSMutableArray<NSString *> *tmp = [NSMutableArray arrayWithCapacity:columns.count];
    NSMutableArray<NSString *> *foreigns = [NSMutableArray arrayWithCapacity:4];
    
    NSMutableArray<NSString *> *uniqueIndices = [NSMutableArray arrayWithCapacity:4];
    NSMutableArray<NSString *> *indices = [NSMutableArray arrayWithCapacity:4];
     
    ColumnConstraintWorker *w = nil;
    for (_DBColumnMeta *column in columns) {
        NSString *name = column->_name;
        DBColumnType type = column->_type;
        NSString *info = column._columnInfo;
        
        if (maker) w = maker->_subs[name];
        if (!w) { [tmp addObject:info]; continue; }
        
        NSString *cons = [w toConstraintWithColumnName:name type:type];
        if (cons.length) info = [info stringByAppendingFormat:@" %@", cons];
        
        if ([w containsUniqueIndex]) {
            [uniqueIndices addObject:name];
        } else if ([w containsIndex]) {
            [indices addObject:name];
        }
        
        /// 忽略自增长的字段
        if ([w containsAutoincrease]) {
            column->_ignoreValue = YES;
        }
        
        if ([w containsPrimaryKey]) {
            if (!_db_primaryKey) {
                _db_primaryKey = [name copy];
                [tmp insertObject:info atIndex:0];
            } else {
                NSAssert(NO, @"该库不支持联合主键，请检查(%@, %@)字段", _db_primaryKey, name);
            }
        } else {
            [tmp addObject:info];
        }
        NSString *foreignKey = [w toForeignKeyConstraint:name];
        if (foreignKey.length) [foreigns addObject:foreignKey];
    }
     
    if (!_db_primaryKey) {
        _useBuiltinPK = YES;
        NSString *pk = DBColumnDefaultPK;
        [tmp insertObject:[NSString stringWithFormat:@"%@ integer primary key autoincrement", pk] atIndex:0];
        _db_primaryKey = pk;
    }
    
    [tmp addObject:_DBExtraDebugColumns()];
    if (foreigns.count) [tmp addObjectsFromArray:foreigns];
    NSString *param = [tmp componentsJoinedByString:@", "];
    
    if (uniqueIndices.count || indices.count) {
        NSString *type = nil;
        NSString *indicesColumn = nil;
        if (uniqueIndices.count) {
            type = @"unique index";
            indicesColumn = [uniqueIndices componentsJoinedByString:@", "];
        } else {
            type = @"index";
            indicesColumn = [indices componentsJoinedByString:@", "];
        }
        _db_generateDDLSql = ^(NSString *tableName) {
            return [NSString stringWithFormat:@"create table if not exists %@(%@);create %@ if not exists %@_index on %@ (%@);", tableName, param, type, tableName, tableName, indicesColumn];
        };
    } else {
        _db_generateDDLSql = ^(NSString *tableName) {
            return [NSString stringWithFormat:@"create table if not exists %@(%@);", tableName, param];
        };
    }
}
@end

// MARK: - Sqlte date and time
DBCondition db_year_is(const char *column, int year) {
    return [NSString stringWithFormat:@"strftime('%%Y', %s, 'localtime') = '%d'", column, year];
}
DBCondition db_month_is(const char *column, int month) {
    return [NSString stringWithFormat:@"strftime('%%m', %s, 'localtime') = '%d'", column, month];
}
DBCondition db_day_is(const char *column, int day) {
    return [NSString stringWithFormat:@"strftime('%%d', %s, 'localtime') = '%d'", column, day];
}
// MARK: - NSObject - YYDataBase

@implementation NSObject (YYDataBase)

+ (NSString *)db_tableName {
    return YYTableNameFromClass(self);
}
+ (NSString *)db_filePath {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/database/"]; 
    NSString *path = nil;
    if ([self respondsToSelector:@selector(db_filePathWithSuggestDirectory:)]) {
        path = [(id<YYDataBase>)self db_filePathWithSuggestDirectory:dir];
        NSString *fileName = [path.lastPathComponent stringByDeletingPathExtension];
        if (![[NSURL fileURLWithPath:path] isFileURL] ||
            !fileName.length ||
            [fileName isEqualToString:@"(null)"]) {
            if (DBErrorLogsEnabled) {
                NSLog(@"since %@ is not a valid db file path, all db ops will not be executed", path);
            }
            return nil;
        }
        if (!path.pathExtension.length) path = [path stringByAppendingString:@".sqlite"];
    } else {
        path = [dir stringByAppendingFormat:@"%@.sqlite", DBDefaultTableName];
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [manager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return path;
}

+ (NSString *)db_version {
    if (![self _db_initializeIfNecessary]) return nil;
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    NSString *tableName = [self db_tableName];
    NSArray *res = [db query:[NSString stringWithFormat:@"select version from t_master where name = '%@';", tableName]];
    return res.count ? res[0][@"version"] : nil;
}
+ (BOOL)db_close {
    if (!_cache) return YES;
    
    NSString *path = [self db_filePath];
     
    BOOL res = YES;
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    YYDatabase *db = [_cache objectForKey:path];
    if (db)  {
        res = [db close];
        if (res) [_cache removeObjectForKey:path];
    }
    dispatch_semaphore_signal(_lock);
    return res;
}

- (BOOL)db_insert {
    if ([self isKindOfClass:[NSArray class]]) {
        return [(NSArray *)self db_inserts];
    }
    return [self _db_insert:NO];
}
- (BOOL)db_insertOrReplace {
    if ([self isKindOfClass:[NSArray class]]) {
        return [(NSArray *)self db_insertOrReplace];
    }
    return [self _db_insert:YES];
}


- (BOOL)db_update {
    if ([self isKindOfClass:[NSArray class]]) {
        return [(NSArray *)self db_updates];
    }
    
    return [[self class] _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        NSString *sql = [self _db_updateSqlWithTableName:tableName primaryKey:primaryKey];
        return @[sql];
    }];
}
- (BOOL)db_updateColumnsInString:(NSString *)columns {
    return [[self class] _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        NSString *sql = [self _db_updateSqlWithTableName:tableName
                                              primaryKey:primaryKey
                                               whiteList:columns
                                               blackList:nil];
        return @[sql];
    }];
}
- (BOOL)db_updateExcludeColumnInString:(NSString *)exclude {
    return [[self class] _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        NSString *sql = [self _db_updateSqlWithTableName:tableName
                                              primaryKey:primaryKey
                                               whiteList:nil
                                               blackList:exclude];
        return @[sql];
    }];
}

- (BOOL)db_delete {
    if ([self isKindOfClass:[NSArray class]]) {
        return [(NSArray *)self db_deletes];
    }
    return [[self class] _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        return @[[self _db_deleteSqlWithTableName:tableName primaryKey:primaryKey]];
    }];
}
+ (BOOL)db_deleteWithPrimaryValue:(id)primaryValue {
    if (!primaryValue) return YES;
    return [self _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) { 
        return @[[NSString stringWithFormat:@"delete from %@ where %@ = %@;", tableName, primaryKey, DBValueDescription(primaryValue)]];
    }];
}
+ (BOOL)db_deleteWithPrimaryValueInArray:(NSArray *)array {
    if (!array.count) return YES;
    return [self _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        
        NSString *valRange = [[array _db_map:^id _Nullable(id obj, NSUInteger idx) {
            return DBValueDescription(obj);
        }] componentsJoinedByString:@", "];
        return @[[NSString stringWithFormat:@"delete from %@ where %@ in(%@);", tableName, primaryKey, valRange]];
    }];
}
+ (BOOL)db_delete {
    return [self _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        return @[[NSString stringWithFormat:@"delete from %@;", tableName]];
    }];
}
+ (BOOL)db_resetReq {
    return [self _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        return @[[NSString stringWithFormat:@"update sqlite_sequence set seq = 0 where name = '%@';", tableName]];
    }];
}

+ (NSArray *)db_select {
    NSArray *rows = [self _db_selectAllRow];
    NSMutableArray *models = [NSMutableArray new];
    for (NSDictionary *row in rows) {
        [models addObject:[self db_modelWithDictionary:row]];
    }
    return models;
}
- (instancetype)db_select {
    Class cls = [self class];
    _YYModelMeta * meta = [_YYModelMeta metaWithClass:cls];
    NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
    NSString *primaryKey = meta.db_primaryKey;
    
    id primaryValue = [self valueForKeyPath:primaryKey];
    if (!primaryValue) return self;
    
    NSDictionary *row = [[self class] _db_selectRowWithPrimaryValue:primaryValue];
    if (!row) return self;
    [self db_setPropertiesWithDictionary:row];
    return self;
}
+ (instancetype)db_modelWithPrimaryValue:(id)value {
    if (!value) return nil;
    
    NSDictionary *row = [self _db_selectRowWithPrimaryValue:value];
    if (!row) return nil;
    return [self db_modelWithDictionary:row];
}
 

+ (BOOL)db_dropTable {
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    NSString *tableName = [self db_tableName];
    NSMutableArray *sqls = [NSMutableArray arrayWithCapacity:16];
    [sqls addObject:[NSString stringWithFormat:@"drop table if exists %@;", tableName]];
    [sqls addObject:[NSString stringWithFormat:@"delete from t_master where name = '%@';", tableName]];
    return [db executesNoRollback:sqls];
}
+ (BOOL)db_dropIndexTable {
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    NSString *tableName = [self db_tableName];
    return [db execute:[NSString stringWithFormat:@"drop index if exists %@_index;", tableName]];
}
 

+ (BOOL)db_execute:(NSString *)sql {
    if (!sql.length) return NO;
    [self db_updateTableIfNecessary];
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    return [db execute:sql];
}
+ (NSArray<NSDictionary<NSString *, id> *> *)db_query:(NSString *)sql {
    if (!sql.length) return nil;
    [self db_updateTableIfNecessary];
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    return [db query:sql];
}

+ (BOOL)db_updateTableIfNecessary {
    return [self _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
}
 
+ (BOOL)db_reInitialize {
    _YYModelMeta *meta = [_YYModelMeta metaWithClass:self];
    meta->_dbIsInitialized = NO;
    return [self _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
}
+ (NSInteger)db_lastInsertRowId {
    YYDatabase *db = _YYGetGlobalDBFromCache(self);
    if (!db) return 0;
    return [db lastInsertRowId];
}

+ (NSString *)db_createTableSql {
    return [self _db_createTableSqlWithTableName:[self db_tableName]];
}
+ (NSString *)db_lastErrorMessage {
    return _YYGetGlobalDBFromCache(self).lastErrorMessage;
}
+ (id)db_handle {
    return _YYGetGlobalDBFromCache(self);
}
// MARK: Private

+ (NSDictionary *)_db_selectRowWithPrimaryValue:(id)value {
    if (!value) return nil;
    __block id row = nil;
    [self _db_initializeIfNecessaryWithBarrierSqls:^(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta) {
        
        NSString *colums = [[meta _dbColumnNames] componentsJoinedByString:@", "];
        
        NSString *sql = [NSString stringWithFormat:@"select %@ from %@ where %@;", colums, tableName, DBKeyValueDescription(@[primaryKey, value])];
        NSArray *rows = [db query:sql];
        if (!rows.count) return;
        row = rows[0];
    }];
    return row;
}
+ (NSArray<NSDictionary<NSString *, id> *> *)_db_selectAllRow {
    __block NSArray *rows = nil;
    [self _db_initializeIfNecessaryWithBarrierSqls:^(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta) {
        
        NSString *colums = [[meta _dbColumnNames] componentsJoinedByString:@", "];
        
        NSString *sql = [NSString stringWithFormat:@"select %@ from %@;", colums, tableName];
        rows = [db query:sql];
    }];
    return rows;
}


- (NSString *)_db_insertSqlWithTableName:(NSString *)tableName
                                    meta:(_YYModelMeta *)meta
                         replaceIfNeeded:(BOOL)need {
    NSArray<NSArray *> *dbKeyValues = DBModelToObjectRecursive(self);
    // 执行插入
    NSString *names = [[dbKeyValues _db_map:^id _Nullable(NSArray *obj, NSUInteger idx) {
        return obj[0];
    }] componentsJoinedByString:@", "];
    
    NSString *values = [[dbKeyValues _db_map:^id _Nullable(NSArray *obj, NSUInteger idx) {
        return DBValueDescription(obj[1]);
    }] componentsJoinedByString:@", "];
    
    NSString *action = need ? @"insert or replace" : @"insert";
    return [NSString stringWithFormat:@"%@ into %@(%@) values (%@);", action, tableName, names, values];
}
- (NSString *)_db_updateSqlWithTableName:(NSString *)tableName
                              primaryKey:(NSString *)primaryKey {
    return [self _db_updateSqlWithTableName:tableName primaryKey:primaryKey whiteList:nil blackList:nil];
}
- (NSString *)_db_updateSqlWithTableName:(NSString *)tableName
                              primaryKey:(NSString *)primaryKey
                               whiteList:(NSString *)whiteList
                               blackList:(NSString *)blackList {
    NSSet<NSString *>*(^generator)(NSString *) = ^NSSet<NSString *>*(NSString *columns) {
        if (!columns.length) return nil;
        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *array = [[columns componentsSeparatedByString:@","] _db_map:^id _Nullable(NSString *obj, NSUInteger idx) {
            return [obj stringByTrimmingCharactersInSet:set];
        }];
        return [NSSet setWithArray:array];
    };
    NSSet<NSString *> *white = generator(whiteList);
    NSSet<NSString *> *black = generator(blackList);
    
    id primaryValue = [self valueForKeyPath:primaryKey];
    NSArray<NSArray *> *dbKeyValues = DBModelToObjectRecursive(self);
    NSString *cmps = [[dbKeyValues _db_map:^id _Nullable(NSArray *obj, NSUInteger idx) {
        NSString *name = obj[0];
        if ([name isEqualToString:primaryKey]) return nil;
        if (white && ![white containsObject:name]) return nil;
        if (black && [black containsObject:name]) return nil;
        return DBKeyValueDescription(obj);
    }] componentsJoinedByString:@", "];
    return [NSString stringWithFormat:@"update %@ set %@ where %@;", tableName, cmps, DBKeyValueDescription(@[primaryKey, primaryValue])];
}
- (NSString *)_db_deleteSqlWithTableName:(NSString *)tableName
                              primaryKey:(NSString *)primaryKey {
    return [NSString stringWithFormat:@"delete from %@ where %@;", tableName, DBKeyValueDescription(@[primaryKey, [self valueForKeyPath:primaryKey]])];
}
+ (NSString *)_db_createTableSqlWithTableName:(NSString *)tableName {
    return [[_YYModelMeta metaWithClass:self] db_createTableSqlWithTableName:tableName];
}

- (BOOL)_db_insert:(BOOL)replaceIfNeeded {
    return [[self class] _db_initializeIfNecessaryWithSqls:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSString *sql = [self _db_insertSqlWithTableName:tableName meta:meta replaceIfNeeded:replaceIfNeeded];
        return @[sql];
    }];
}


+ (BOOL)_db_initializeIfNecessaryWithBarrierSqls:(void(^)(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta))block {
    if (!block) return [self _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
    return [self _db_initializeIfNecessaryWithAdditionalSqlMake:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta) {
        block(tableName, primaryKey, db, meta);
        return nil;
    } barrier:YES];
}

+ (BOOL)_db_initializeIfNecessaryWithSqls:(NSArray<NSString *>*(^)(NSString *tableName, NSString *primaryKey, _YYModelMeta *meta))block {
    if (!block) return [self _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
    return [self _db_initializeIfNecessaryWithAdditionalSqlMake:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta) {
        return block(tableName, primaryKey, meta);
    } barrier:NO];
}
+ (BOOL)_db_initializeIfNecessary {
    return [self _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
}
+ (BOOL)_db_initializeIfNecessaryWithAdditionalSqlMake:(NSArray<NSString *>*(^)(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta))block barrier:(BOOL)barrier {
    
    Class cls = self;
    YYDatabase *db = _YYGetGlobalDBFromCache(cls);
    if (!db) return NO;
    
    _YYModelMeta *meta = [_YYModelMeta metaWithClass:cls];
    NSString *tableName = [cls db_tableName];
    
    NSString *primaryKey = meta.db_primaryKey;
    
    if (meta->_dbIsInitialized) {
        if (!block) return YES;
        return [db executes:block(tableName, primaryKey, db, meta)];;
    }
    meta->_dbIsInitialized = YES;
    
    NSMutableArray<NSString *> *sqls = [NSMutableArray arrayWithCapacity:16];
    if ([db query:@"select name from sqlite_master where type = 'table' and name = 't_master';"].count == 0) {
        NSString *first = [NSString stringWithFormat:@"create table if not exists t_master(name text primary key, columns text, primaryKey text, version text, %@);", _DBExtraDebugColumns()];
        [sqls addObject:first];
    } else {
        NSArray *result = [db query:[NSString stringWithFormat:@"select version, primaryKey, columns from t_master where name = '%@';", tableName]];
        if (result.count > 0) {
            if (![cls respondsToSelector:@selector(db_NewVersion)]) {
                if (!block) return YES;
                return [db executes:block(tableName, primaryKey, db, meta)];
            }
            // 判断是否需要更新表
            NSString *newVersion = [(id<YYDataBase>)cls db_NewVersion];
            NSString *dbVersion = result[0][@"version"];
            if ([newVersion compareVersion:dbVersion] < 1) {
                /// 没有增加版本号，无需迁移表
                if (!block) return YES;
                return [db executes:block(tableName, primaryKey, db, meta)];
            }
            NSCharacterSet *whiteSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            /// 新表的所有字段
            NSArray *newColumns = [meta _dbColumnsOnMasterTable];
            NSString *newColumnNames = [newColumns componentsJoinedByString:@","];
            
            /// 旧表的所有字段
            NSArray *dbColumns = [[result[0][@"columns"] componentsSeparatedByString:@","] _db_map:^id _Nullable(NSString *obj, NSUInteger idx) {
                return [obj stringByTrimmingCharactersInSet:whiteSet];
            }];
            NSString *dbColumnNames = [dbColumns componentsJoinedByString:@","];
            
            NSString *dbPK = result[0][@"primaryKey"];
            if ([newColumnNames isEqualToString:dbColumnNames] &&
                [dbPK isEqualToString:primaryKey]) {
                ///新表的所有字段与旧表的所有字段相同，无需迁移
                if (!block) return YES;
                return [db executes:block(tableName, primaryKey, db, meta)];
            }
            
            NSString *tmpTableName = YYTmpTableNameFromClass(cls);
            [sqls addObject:[NSString stringWithFormat:@"drop table if exists %@;", tmpTableName]];
            
            // 创建临时表
            NSString *sql = [meta db_createTableSqlWithTableName:tmpTableName];
            [sqls addObject:sql];
            
            // 填充新表的主键数据
            [sqls addObject:[NSString stringWithFormat:@"insert into %@ (%@) select %@ from %@;", tmpTableName, primaryKey, dbPK, tableName]];
              
            NSSet<NSString *> *dbColumnsSet = [NSSet setWithArray:dbColumns];
            NSDictionary<NSString *, NSString *> *nameMapper = nil;
            if ([cls respondsToSelector:@selector(db_newColumnNameFromOldColumnNamesVersioned:)]) {
                nameMapper = [(id<YYDataBase>)cls db_newColumnNameFromOldColumnNamesVersioned:dbVersion];
            }
            /// 数据迁移
            for (NSString *column in newColumns) {
                if ([column isEqualToString:primaryKey]) continue;
                NSString *dbColumn = column;
                if (nameMapper[column].length > 0) {
                    dbColumn = nameMapper[column];
                }
                // 说明是新增加的字段，忽略
                if (![dbColumnsSet containsObject:dbColumn]) continue;
                // update 临时表 set 新字段名称 = (select 旧字段名 from 旧表 where 临时表.主键 = 旧表.主键)
                NSString *setsql = [NSString stringWithFormat:@"update %@ set %@ = (select %@ from %@ where %@.%@ = %@.%@);", tmpTableName, column, dbColumn, tableName, tmpTableName, primaryKey, tableName, dbPK];
                [sqls addObject:setsql];
            }
            /// 删除旧表
            [sqls addObject:[NSString stringWithFormat:@"drop table if exists %@;", tableName]];
            /// 将临时表改名为旧表的表名，以达到替换的效果
            [sqls addObject:[NSString stringWithFormat:@"alter table %@ rename to %@;", tmpTableName, tableName]];
            /// 更新信息
            [sqls addObject:[NSString stringWithFormat:@"update t_master set columns = '%@', primaryKey = '%@', version = '%@' where name = '%@';", newColumnNames, primaryKey, newVersion, tableName]];
            
            if (!block) return [db executes:sqls];
            
            if (barrier) {
                BOOL res = [db executes:sqls];
                if (!res) return NO;
                return [db executes:block(tableName, primaryKey, db, meta)];
            } else {
                [sqls addObjectsFromArray:block(tableName, primaryKey, db, meta)];
                return [db executes:sqls];
            }
        }
    }
    NSString *sql = [meta db_createTableSqlWithTableName:tableName];
    [sqls addObject:sql];
    
    NSString *version = nil;
    if ([cls respondsToSelector:@selector(db_NewVersion)]) {
        version = [(id<YYDataBase>)cls db_NewVersion];
    }
    version = version.length ? version : @"0.0.1";
    
    // 记录此表的信息
    [sqls addObject:[NSString stringWithFormat:@"insert or replace into t_master (name, columns, primaryKey, version) values('%@', '%@', '%@', '%@');", tableName, [[meta _dbColumnsOnMasterTable] componentsJoinedByString:@","], primaryKey, version]];
    
    if (!block) return [db executes:sqls];
    if (barrier) {
        BOOL res = [db executes:sqls];
        if (!res) return NO;
        return [db executes:block(tableName, primaryKey, db, meta)];
    } else {
        [sqls addObjectsFromArray:block(tableName, primaryKey, db, meta)];
        return [db executes:sqls];
    }
}

@end


@implementation NSArray (YYDataBase)
- (BOOL)db_deletes {
    return [self _db_initializeIfNecessaryWithSqls:^(NSMutableArray *sqls, NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        NSString *valRange = [[self _db_map:^id _Nullable(id obj, NSUInteger idx) {
            id val = [obj valueForKeyPath:primaryKey];
            return DBValueDescription(val);
        }] componentsJoinedByString:@", "];
        [sqls addObject:[NSString stringWithFormat:@"delete from %@ where %@ in(%@);", tableName, primaryKey, valRange]];
    }];
}
- (BOOL)db_updates {
    return [self _db_initializeIfNecessaryWithSqls:^(NSMutableArray *sqls, NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        NSAssert(!meta->_useBuiltinPK, @"使用此方法必须指定主键");
        for (NSObject *obj in self) {
            NSString *sql = [obj _db_updateSqlWithTableName:tableName
                                                 primaryKey:primaryKey];
            [sqls addObject:sql];
        }
    }];
}
- (BOOL)db_inserts {
    return [self _db_inserts:NO];
}
- (BOOL)db_insertOrReplaces {
    return [self _db_inserts:YES];
}

// MARK: Private
- (BOOL)_db_inserts:(BOOL)replaceIfNeeded {
    return [self _db_initializeIfNecessaryWithSqls:^(NSMutableArray *sqls, NSString *tableName, NSString *primaryKey, _YYModelMeta *meta) {
        for (NSObject *obj in self) {
            NSString *sql = [obj _db_insertSqlWithTableName:tableName meta:meta replaceIfNeeded:replaceIfNeeded];
            [sqls addObject:sql];
        }
    }];
}

- (BOOL)_db_initializeIfNecessaryWithSqls:(void (^)(NSMutableArray *sqls, NSString *tableName, NSString *primaryKey, _YYModelMeta *meta))block {
    NSInteger count = self.count;
    if (!count) return YES;
    Class cls = [self[0] class];
    if (count > 1) {
        for (NSInteger i = 1; i < count; i++) {
            NSAssert([self[i] isMemberOfClass:cls], @"请确保数组中元素都是同一类型");
        }
    }
    if (!block) return [cls _db_initializeIfNecessaryWithAdditionalSqlMake:nil barrier:NO];
    return [cls _db_initializeIfNecessaryWithAdditionalSqlMake:^NSArray<NSString *> *(NSString *tableName, NSString *primaryKey, YYDatabase *db, _YYModelMeta *meta) {
        NSMutableArray *sqls = [NSMutableArray arrayWithCapacity:count];
        block(sqls, tableName, primaryKey, meta);
        return sqls;
    } barrier:NO];
}

@end


@implementation NSObject (DBColumns)
+ (NSString *)dbColumns {
    return [self dbColumnsExcludeInString:nil tableAlias:nil];
}
+ (NSString *)dbColumnsExcludeInString:(NSString *)exclude {
    return [self dbColumnsExcludeInString:exclude tableAlias:nil];
}
+ (NSString *)dbColumnsExcludeInString:(NSString *)exclude tableAlias:(NSString *)aliasName {
    NSMutableArray *columns = [NSMutableArray arrayWithArray:[[_YYModelMeta metaWithClass:self] _dbColumnNames]];
    if (exclude.length) {
        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        [columns removeObjectsInArray:[[exclude componentsSeparatedByString:@","] _db_map:^id _Nullable(NSString *obj, NSUInteger idx) {
            return [obj stringByTrimmingCharactersInSet:set];
        }]];
    }
    return [self _dbColumnsInArray:columns alias:aliasName];
}
+ (NSString *)dbColumnsInString:(NSString *)exclude tableAlias:(NSString *)aliasName {
    if (!exclude.length) return @"*";
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSMutableArray *columns = [NSMutableArray arrayWithArray:[[exclude componentsSeparatedByString:@","] _db_map:^id _Nullable(NSString *obj, NSUInteger idx) {
        return [obj stringByTrimmingCharactersInSet:set];
    }]];
    return [self _dbColumnsInArray:columns alias:aliasName];
}
+ (NSString *)_dbColumnsInArray:(NSArray<NSString *>*)columns alias:(NSString *)alias {
    if (!alias.length) return [columns  componentsJoinedByString:@", "];
    return [[columns _db_map:^id _Nullable(NSString *obj, NSUInteger idx) {
        return [NSString stringWithFormat:@"%@.%@", alias, obj];
    }] componentsJoinedByString:@", "];
}
@end

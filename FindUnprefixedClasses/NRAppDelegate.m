//
//  NRAppDelegate.m
//  FindUnprefixedClasses
//
//  Created by Nikolai Ruhe on 2013-02-11.
//  Copyright (c) 2013 Savoy Software. All rights reserved.
//

#import "NRAppDelegate.h"
#import <objc/runtime.h>

#define LOAD_PRIVATE_FRAMEWORKS 1
#define ALLOW_FRAMEWORK_PREFIX  0
#define ALLOW_OBVIOUS_PREFIXES  0

static unsigned int _classCount;
static unsigned int _badClassCount;

static void loadBundlesInDirectory(NSString *directory)
{
	for (NSString *path in [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:directory error:NULL]) {
		if (! [path hasSuffix:@".framework"])
			continue;
		NSString *bundlePath = [directory stringByAppendingPathComponent:path];
		NSBundle *bundle = [[NSBundle alloc] initWithPath:bundlePath];
		if (! [bundle isLoaded]) {
			[bundle load];
//			if ([bundle isLoaded]) {
//				NSLog(@"added bundle: %@", bundle);
//			}
		}
	}
}

static void loadManyBundles()
{
	NSString *uiKitPath = [[NSBundle bundleForClass:[UIView class]] bundlePath];
	NSString *systemLibrary = [[uiKitPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];

	// load all frameworks in /System/Library/Frameworks
	loadBundlesInDirectory([systemLibrary stringByAppendingPathExtension:@"Frameworks"]);

#if defined(LOAD_PRIVATE_FRAMEWORKS) && LOAD_PRIVATE_FRAMEWORKS
	// load all frameworks in /System/Library/PrivateFrameworks
	loadBundlesInDirectory([systemLibrary stringByAppendingPathComponent:@"PrivateFrameworks"]);
#endif
}

static NSDictionary *findBadClasses(void)
{
	// get all classes
	Class *allClasses = objc_copyClassList(&_classCount);

	NSRegularExpression *classNameChecker = [NSRegularExpression regularExpressionWithPattern:@"^_*[A-Z]{2}" options:0 error:NULL];
	NSMutableDictionary *badClasses = [NSMutableDictionary dictionary];

	for (unsigned int i = 0; i < _classCount; ++i) {
		Class class = allClasses[i];
		NSString *className = NSStringFromClass(class);

		if ([classNameChecker numberOfMatchesInString:className options:0 range:(NSRange){0, [className length]}] == 1)
			continue;

		NSString *imagePath = [NSString stringWithUTF8String:class_getImageName(class)];

#if defined(ALLOW_FRAMEWORK_PREFIX) && ALLOW_FRAMEWORK_PREFIX
		NSString *imageName = [imagePath lastPathComponent];
		if ([className hasPrefix:imageName])
			continue;
#endif

#if defined(ALLOW_OBVIOUS_PREFIXES) && ALLOW_OBVIOUS_PREFIXES
		BOOL hasCommonPrefix = NO;
		static NSArray *prefixes;
		if (prefixes == nil)
			prefixes = @[@"Web", @"_Web", @"Alt", @"Cal", @"_Cert", @"CardDAV", @"BookmarkDAV", @"MobileCal"];
		for (NSString *prefix in prefixes) {
			if ([className hasPrefix:prefix]) {
				hasCommonPrefix = YES;
				break;
			}
		}
		if (hasCommonPrefix)
			continue;
#endif

		NSMutableArray *classes = badClasses[imagePath];
		if (classes == nil) {
			classes = [NSMutableArray array];
			badClasses[imagePath] = classes;
		}
		[classes addObject:[NSValue valueWithNonretainedObject:class]];
		_badClassCount += 1;
	}

	return badClasses;
}

static void printBadClassesSortedByFramework(NSDictionary *badClasses)
{
	// sort executables by name
	NSArray *imageNames = [[badClasses allKeys] sortedArrayUsingSelector:@selector(compare:)];

	NSString *rootPath = [[[[[[NSBundle bundleForClass:[UIView class]] bundlePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];

	// walk over sorted images:
	for (NSString *imageName in imageNames) {

		NSString *path = imageName;
		if ([path hasPrefix:rootPath])
			path = [path substringFromIndex:[rootPath length]];
		printf("%s\n", [path UTF8String]);

		// sort classes by name:
		NSArray *classes = [badClasses[imageName] sortedArrayUsingComparator:^NSComparisonResult(NSValue *class1, NSValue *class2) {
			const char *className1 = class_getName([class1 pointerValue]);
			while (className1[0] == '_')
				className1 += 1;
			const char *className2 = class_getName([class2 pointerValue]);
			while (className2[0] == '_')
				className2 += 1;
			return strcmp(className1, className2);
		}];

		for (NSValue *boxedClass in classes) {
			Class class = [boxedClass pointerValue];
			printf("    @interface %s : %s\n", class_getName(class), class_getName(class_getSuperclass(class)));
		}
	}
}


@interface NRAppDelegate ()

@property (weak, nonatomic) IBOutlet UILabel *classCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *badPrefixLabel;

@end



@implementation NRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	loadManyBundles();

	NSDictionary *badClasses = findBadClasses();

	printBadClassesSortedByFramework(badClasses);

    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.classCountLabel.text = [NSString stringWithFormat:@"Loaded classes: %lu", (unsigned long)_classCount];
	self.badPrefixLabel.text = [NSString stringWithFormat:@"Classes with bad prefix: %lu", (unsigned long)_badClassCount];
}

@end

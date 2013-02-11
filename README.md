UnprefixedFrameworkClasses
==========================

This project tries to point out classes that are candidates for potential name clashes because they do not adhere to Apple's naming rules.

These rules [are decribed explicitly in the Apple developer documentation](http://developer.apple.com/library/ios/documentation/cocoa/conceptual/ProgrammingWithObjectiveC/Conventions/Conventions.html#//apple_ref/doc/uid/TP40011210-CH10-SW4).

[Bill Bumgarner acknowleges](http://stackoverflow.com/a/2849965/104790) the lack of a prefix for a system class to be a bug.

### What does this project do?

This test project explicitly loads framework bundles from /System/Library/Frameworks and /System/Library/PrivateFrameworks.
After that it scans all registered classes in the objc runtime to find classes that do not conform to Apple's naming rules.

All non-conforming classes will be printed to the console, sorted by framework.

### Results

In iOS 6.1 on an iPhone 5 there are 767 classes (of 10,307) that do not adhere to the naming rules. Here's a small choice of those that are most likely to result in name clashes:

- Face (CoreImage)
- Once (Foundation)
- RotationLayer (UIKit)
- WhiteView (UIKit)
- Message(MIME.framework)
- Account(Message.framework)
- Connection(Message.framework)

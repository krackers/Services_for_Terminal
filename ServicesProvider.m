//
//  ServicesProvider.m
//  Services for Terminal
//
//  Created by yt on 13/08/30.
//  Copyright 2013 yt. All rights reserved.
//

#import "ServicesProvider.h"
#import <Carbon/Carbon.h> //use OpenScripting.framework

static NSTimeInterval const lifetime = 60.0f; // lifetime

@implementation SuicideCommiter

#pragma mark Callback handlers

- (void)onTimer:(NSTimer *)__unused timer
{
	NSLog(@"%s:%d enter", __FILE__, __LINE__);

	// quit application
	NSApplication *app = [NSApplication sharedApplication];
	[app terminate:self];

	NSLog(@"%s:%d leave(!)", __FILE__, __LINE__); // does not come here
}

@end

@implementation ServicesProvider

#pragma mark Overriding

- (id)init
{
	// inherited
	[super init];
	// create the suicide commiter
	suicideCommiter = [[SuicideCommiter alloc] init];
	// setup the timer
	suicideTimer = [NSTimer
		scheduledTimerWithTimeInterval:lifetime
		target:suicideCommiter
		selector:@selector(onTimer:)
		userInfo:nil
		repeats:NO];

	return self;
}

- (void)dealloc
{
	// stop the timer
	[suicideTimer invalidate];
	// releasing owned objects
	[suicideCommiter release];
	[suicideTimer release];
	// inherited
	[super dealloc];
}

#pragma mark Methods listed in the NSServices section of Info.plist

- (void)editSelectedFileInTerminal:(NSPasteboard *)pboard
	userData:(NSString *) __unused userData
	error:(NSString **)errorMessagePtr
{
	NSLog(@"%s:%d enter", __FILE__, __LINE__);

	// get a NSString from the pasteboard

	NSArray *classes = [NSArray arrayWithObject:[NSString class]];
	if (![pboard canReadObjectForClasses:classes options:nil]){
		*errorMessagePtr = NSLocalizedString(
			@"Error: the pasteboard doesn't contain a string.",
			nil);
		NSLog(@"%s:%d %@", __FILE__, __LINE__, *errorMessagePtr);
		return;
	}
	
	NSString *pasteboardString = [pboard stringForType:NSPasteboardTypeString];

	NSLog(@"%s:%d %@", __FILE__, __LINE__, pasteboardString);
	
	// extract a filename
	
	NSString *filename = pasteboardString;
	NSUInteger length = [filename length];
	NSUInteger from = 0;
	NSUInteger to = length;
	
	// skip git status, /\t[a-z]+:   /
	while(from < length && [filename characterAtIndex:from] == '\t'){
		++from;
	}
	if(from == 1){
		NSUInteger i = from;
		while(i < length && islower([filename characterAtIndex:i])){
			++i;
		}
		if(i >= 2 && i < length && [filename characterAtIndex:i] == ':'){
			++i;
			while(i < length && [filename characterAtIndex:i] == ' '){
				++i;
			}
			from = i;
		}
	}
	
	int colon_count = 0;
	for(NSUInteger i = from; i < length; ++i){
		unichar c = [filename characterAtIndex:i];
		if(c == ':'){
			++colon_count;
			if(colon_count == 2){
				to = i;
				break;
			}
		}else if(colon_count >= 1 && c == ' '){
			to = i;
			break;
		}else if(c == '\n'){
			to = i; // strip after '\n'
			break;
		}
	}
	filename = [filename substringWithRange:NSMakeRange(from, to - from)];
	
	NSLog(@"%s:%d \"%@\"", __FILE__, __LINE__, filename);

	// run AppleScript
	NSDictionary* errors;
#if 1
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *scriptPath = [mainBundle
		pathForResource:@"editSelectedFileInTerminal"
		ofType:@"scpt"];
	NSURL *scriptURL = [[[NSURL alloc] initFileURLWithPath:scriptPath]
		autorelease];
	NSAppleScript *appleScript = [
		[[NSAppleScript alloc]
			initWithContentsOfURL:scriptURL
			error:&errors]
		autorelease];
	if(appleScript == nil){
		NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
		return;
	}
	
	NSLog(@"%s:%d %@", __FILE__, __LINE__, [appleScript source]);

	if(![appleScript compileAndReturnError:&errors]){
		NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
		return;
	}
	
	NSAppleEventDescriptor *result;
#if 0
	result = [appleScript executeAndReturnError:&errors];
	NSLog(@"%s:%d %@", __FILE__, __LINE__, result);
	NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
#endif

	// create the first parameter
	NSAppleEventDescriptor *input = [NSAppleEventDescriptor
		descriptorWithString:filename];

	NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];

	// create and populate the list of parameters (in our case just one)
	NSAppleEventDescriptor *args = [NSAppleEventDescriptor listDescriptor];
	[args insertDescriptor:input atIndex:1];
	[args insertDescriptor:parameters atIndex:2];

#if 0
	// create the AppleEvent target
	pid_t pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *target = [NSAppleEventDescriptor
		descriptorWithDescriptorType:typeKernelProcessID
		bytes:&pid
		length:sizeof(pid_t)];
#endif

	// create an NSAppleEventDescriptor with the script's method name to call,
	// this is used for the script statement: "on show_message(user_message)"
	// Note that the routine name must be in lower case.
#if 0
	NSAppleEventDescriptor *handler = [NSAppleEventDescriptor
		descriptorWithString:@"run"];
#endif

	// create the event for an AppleScript subroutine,
	// set the method name and the list of parameters
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor
		appleEventWithEventClass:kCoreEventClass //kASSubroutineEvent //kASAppleScriptSuite //'cplG'
		eventID:kAEOpenApplication //kASSubroutineEvent
		targetDescriptor:nil //target
		returnID:kAutoGenerateReturnID
		transactionID:kAnyTransactionID];
#if 0
	[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
#endif
	[event setParamDescriptor:args forKeyword:keyDirectObject];

	NSLog(@"%s:%d %@", __FILE__, __LINE__, event);

	result = [appleScript
		executeAppleEvent:event
		error:&errors];
	NSLog(@"%s:%d %@", __FILE__, __LINE__, result);
	NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
#else
	// create AppleScript in here
	NSString *escapedFilename = [filename
		stringByReplacingOccurrencesOfString:@"\""
		withString:@"\\\""];
		
	NSMutableString *source = [[[NSMutableString alloc] init] autorelease];
	[source appendFormat:@"set filename to \"%@\"\n", escapedFilename];
	[source appendString:@"set cmd to \"edit \" & quoted form of filename\n"];
	[source appendString:@"tell application \"Terminal\"\n"];
	[source appendString:@"\tdo script cmd in front tab of front window\n"];
	[source appendString:@"end tell\n"];

	NSLog(@"%s:%d %@", __FILE__, __LINE__, source);

	NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:source]
		autorelease];

	if(![appleScript compileAndReturnError:&errors]){
		NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
		return;
	}

	NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errors];
	NSLog(@"%s:%d %@", __FILE__, __LINE__, result);
	NSLog(@"%s:%d %@", __FILE__, __LINE__, errors);
#endif

	// extend lifetime
	[suicideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:lifetime]];

	NSLog(@"%s:%d leave", __FILE__, __LINE__);
}

@end

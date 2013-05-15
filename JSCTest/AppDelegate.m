//
//  AppDelegate.m
//  JavaScriptCore API Test
//
// -- Software License --
//
// Copyright (C) 2013, Steam Clock Software, Ltd.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// ----------------------

#import "AppDelegate.h"
#import "JavaScriptCore/API/JSContext.h"
#import "JavaScriptCore/API/JSExport.h"
#import "objc/runtime.h"

//---------------------------------------------------------------------------
// Protocol to list functions to be exported from a existing class
@protocol NSButtonExport <JSExport>

-(void)setTitle:(NSString*)title;
-(NSString*)title;

@end

//---------------------------------------------------------------------------
// Wrapper class to forward no-arg or one-arg (argument is stripped though)
// selector calls through to a JS object. So that we can call JS directly from
// ObjC rather than going through -[JSValue invokeMethod]
@interface Forwarder : NSObject
@property JSValue* value;
@end

@implementation Forwarder

-(id)initWithValue:(JSValue*)value {
    if((self = [super init])) {
        self.value = value;
    }
    
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSString* functionName = [NSStringFromSelector(aSelector) stringByReplacingOccurrencesOfString:@":" withString:@""];
    if ([self.value valueForProperty:functionName] ) {
        NSMethodSignature* signature = [NSMethodSignature signatureWithObjCTypes:"@:@"];
        return signature;
    }
    return nil;
}


- (void)forwardInvocation:(NSInvocation *)forwardedInvocation
{
    NSString* functionName = [NSStringFromSelector([forwardedInvocation selector]) stringByReplacingOccurrencesOfString:@":" withString:@""];
    [self.value invokeMethod:functionName withArguments:@[]];
}

@end

//---------------------------------------------------------------------------
// To call selectors using forwarding, need the selector to be declared somewhere
// This isn't used, just serves to define this selector
@protocol Dummy
-(void)logInfo;
@end


//---------------------------------------------------------------------------
// Our native test object

// Protocol to list bindings
@protocol NativeObjectExport <JSExport>
-(void)test;
-(void)log:(NSString*)string;
@end

// The native test object itself
@interface NativeObject : NSObject <NativeObjectExport>
@end

@implementation NativeObject

-(void)test {
    NSLog(@"native: test was called");
}

-(void)log:(NSString*)string {
    NSLog(@"js: %@", string);
}

@end


@interface AppDelegate ()

@property JSContext* context; // Our local javascript context

@end

// Need something persistant to store this, since setting it as a target doesn't retain it
id forwarder;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Could possibly build a protocol dynamically like this, doesn't work for me though, my objc-runtime-fu is not strong enough
    /*
    Protocol* newProtocol = objc_allocateProtocol("RuntimeProtocol");
    Protocol* exportProtocol = objc_getProtocol("JSExport");
    protocol_addProtocol(newProtocol, exportProtocol);
    protocol_addMethodDescription(newProtocol, @selector(setTitle:), "v@:@", YES, YES);
    protocol_addMethodDescription(newProtocol, @selector(title), "@@:", YES, YES);
    objc_registerProtocol(newProtocol);
    */
    
    // Attach out export protocol to NSButton
    Protocol* newProtocol = @protocol(NSButtonExport);
    class_addProtocol([NSButton class], newProtocol);

    // Load the script
    NSString* script = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"javascript" ofType:@"js"]] encoding:NSUTF8StringEncoding];

    // Create the button
    NSButton* button = [[NSButton alloc] initWithFrame:NSRectFromCGRect(CGRectMake(0, 0, 200, 50))];
    button.title = @"Hello Objective-C";
    [self.window.contentView addSubview:button];

    // Create the JS context
    self.context = [[JSContext alloc] init];
    
    // Bind out two test objects into global variables in the JS context
    self.context[@"nativeObject"] = [[NativeObject alloc] init];
    self.context[@"button"] = button;

    // Run the script
    [self.context evaluateScript:script];
    
    // Now pull out some test values, and run some functions
    JSValue* scriptObject = self.context[@"scriptObject"];

    // Run a method manually
    JSValue* result = [scriptObject invokeMethod:@"logInfo" withArguments:@[]];
    NSLog(@"native: logInfo result - \"%@\"", result);

    // Peek and poke at some variables
    NSLog(@"native: scriptObject data is \"%@\"", [scriptObject valueForProperty:@"data"]);
    NSLog(@"native: global variable value is \"%@\"", self.context[@"globalVariable"]);
    
    [scriptObject setValue:@"From Objective-C" forProperty:@"data"];
    
    // create our method forwarder
    forwarder = [[Forwarder alloc] initWithValue:scriptObject];
    
    // Call a JS function via forwarding
    [forwarder logInfo];
    
    // Set the JS object as the action target for the button
    [button setTarget:forwarder];
    [button setAction:@selector(buttonPressed:)];
    
}

@end

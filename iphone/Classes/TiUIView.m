/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import <QuartzCore/QuartzCore.h>
#import "TiBase.h"
#import "TiUIView.h"
#import "TiColor.h"
#import "TiRect.h"
#import "TiUtils.h"
#import "ImageLoader.h"
#import "Ti2DMatrix.h"
#import "Ti3DMatrix.h"
#import "TiViewProxy.h"
#import "TitaniumApp.h"


void ModifyScrollViewForKeyboardHeightAndContentHeightWithResponderRect(UIScrollView * scrollView,CGFloat keyboardTop,CGFloat minimumContentHeight,CGRect responderRect)
{
	CGRect scrollVisibleRect;
	scrollVisibleRect = [scrollView convertRect:[scrollView bounds] toView:nil];
	//First, find out how much we have to compensate.

	CGFloat obscuredHeight = scrollVisibleRect.origin.y + scrollVisibleRect.size.height - keyboardTop;	
	//ObscuredHeight is how many vertical pixels the keyboard obscures of the scroll view. Some of this may be acceptable.

	CGFloat unimportantArea = MAX(scrollVisibleRect.size.height - minimumContentHeight,0);
	//It's possible that some of the covered area doesn't matter. If it all matters, unimportant is 0.

	//As such, obscuredHeight is now how much actually matters of scrollVisibleRect.

	[scrollView setContentInset:UIEdgeInsetsMake(0, 0, MAX(0,obscuredHeight-unimportantArea), 0)];

	scrollVisibleRect.size.height -= MAX(0,obscuredHeight);
	
	//Okay, the scrollVisibleRect.size now represents the actually visible area.
	
	CGPoint offsetPoint = [scrollView contentOffset];

	CGPoint offsetForBottomRight;
	offsetForBottomRight.x = responderRect.origin.x + responderRect.size.width - scrollVisibleRect.size.width;
	offsetForBottomRight.y = responderRect.origin.y + responderRect.size.height - scrollVisibleRect.size.height;
	
	offsetPoint.x = MIN(responderRect.origin.x,MAX(offsetPoint.x,offsetForBottomRight.x));
	offsetPoint.y = MIN(responderRect.origin.y,MAX(offsetPoint.y,offsetForBottomRight.y));

	[scrollView setContentOffset:offsetPoint animated:YES];
}

void RestoreScrollViewFromKeyboard(UIScrollView * scrollView)
{
	CGSize scrollContentSize = [scrollView contentSize];
	CGPoint scrollOffset = [scrollView contentOffset];
	
	[scrollView setContentInset:UIEdgeInsetsZero];

	//Reposition the scroll to handle the uncovered area.
	CGRect scrollVisibleRect = [scrollView bounds];
	CGFloat maxYScrollOffset = scrollContentSize.height - scrollVisibleRect.size.height;
	if (maxYScrollOffset < scrollOffset.y)
	{
		scrollOffset.y = MAX(0.0,maxYScrollOffset);
		[scrollView setContentOffset:scrollOffset animated:YES];
	}
}


CGFloat AutoWidthForView(UIView * superView,CGFloat suggestedWidth)
{
	CGFloat result = 0.0;
	for (TiUIView * thisChildView in [superView subviews])
	{
		//TODO: This should be an unnecessary check, but this happening means the child class didn't override AutoWidth when it should have.
		if(![thisChildView respondsToSelector:@selector(minimumParentWidthForWidth:)])
		{
			NSLog(@"[WARN] %@ contained %@, but called AutoWidthForView was called for it anyways."
					"This typically means that -[TIUIView autoWidthForWidth] should have been overridden.",superView,thisChildView);
			//Treating this as if we had no autosize, and thus, 
			return suggestedWidth;
		}
		//END TODO
		result = MAX(result,[thisChildView minimumParentWidthForWidth:suggestedWidth]);
	}
	return result;
}

CGFloat AutoHeightForView(UIView * superView,CGFloat suggestedWidth,BOOL isVertical)
{
	CGFloat neededAbsoluteHeight=0.0;
	CGFloat neededVerticalHeight=0.0;

	for (TiUIView * thisChildView in [superView subviews])
	{
		if (![thisChildView respondsToSelector:@selector(minimumParentHeightForWidth:)])
		{
			continue;
		}
		CGFloat thisHeight = [thisChildView minimumParentHeightForWidth:suggestedWidth];
		if (isVertical)
		{
			neededVerticalHeight += thisHeight;
		}
		else
		{
			neededAbsoluteHeight = MAX(neededAbsoluteHeight,thisHeight);
		}
	}
	return MAX(neededVerticalHeight,neededAbsoluteHeight);
}



NSInteger zindexSort(TiUIView* view1, TiUIView* view2, void *reverse)
{
	int v1 = view1.zIndex;
	int v2 = view2.zIndex;
	
	int result = 0;
	
	if (v1 < v2)
	{
		result = -1;
	}
	else if (v1 > v2)
	{
		result = 1;
	}
	
	return result;
}


#define DOUBLE_TAP_DELAY		0.35
#define HORIZ_SWIPE_DRAG_MIN	12
#define VERT_SWIPE_DRAG_MAX		4

@implementation TiUIView

DEFINE_EXCEPTIONS

@synthesize proxy,parent,touchDelegate;

#pragma mark Internal Methods

-(void)dealloc
{
	RELEASE_TO_NIL(transformMatrix);
	RELEASE_TO_NIL(animation);
	[super dealloc];
}

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		
	}
	return self;
}


-(BOOL)viewSupportsBaseTouchEvents
{
	// give the ability for the subclass to turn off our event handling
	// if it wants too
	return YES;
}

-(BOOL)proxyHasTapListener
{
	return [proxy _hasListeners:@"singletap"] ||
			[proxy _hasListeners:@"doubletap"] ||
			[proxy _hasListeners:@"twofingertap"];
}

-(BOOL)proxyHasTouchListener
{
	return [proxy _hasListeners:@"touchstart"] ||
			[proxy _hasListeners:@"touchcancel"] ||
			[proxy _hasListeners:@"touchend"] ||
			[proxy _hasListeners:@"touchmove"] ||
			[proxy _hasListeners:@"click"] ||
			[proxy _hasListeners:@"dblclick"];
} 

-(void)initializeState
{
	virtualParentTransform = CGAffineTransformIdentity;
	multipleTouches = NO;
	twoFingerTapIsPossible = NO;
	touchEnabled = YES;
	BOOL touchEventsSupported = [self viewSupportsBaseTouchEvents];
	handlesTaps = touchEventsSupported && [self proxyHasTapListener];
	handlesTouches = touchEventsSupported && [self proxyHasTouchListener];
	handlesSwipes = touchEventsSupported && [proxy _hasListeners:@"swipe"];
	
	self.userInteractionEnabled = YES;
	self.multipleTouchEnabled = handlesTaps;	
	 
	self.backgroundColor = [UIColor clearColor]; 
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

-(void)willSendConfiguration
{
}

-(void)didSendConfiguration
{
	configured = YES;
}

-(void)configurationSet
{
	// can be used to trigger things after all properties are set
}

-(BOOL)viewConfigured
{
	return configured;
}

-(void)setProxy:(TiProxy *)p
{
	proxy = p;
	proxy.modelDelegate = self;
}

-(void)setParent:(TiViewProxy *)p
{
	parent = p;
}

-(UIImage*)loadImage:(id)image 
{
	if (image==nil) return nil;
	NSURL *url = [TiUtils toURL:image proxy:proxy];
	if (url==nil)
	{
		NSLog(@"[WARN] could not find image: %@",[url absoluteString]);
		return nil;
	}
	return [[ImageLoader sharedLoader] loadImmediateStretchableImage:url];
}

-(id)transformMatrix
{
	return transformMatrix;
}

#pragma mark Legacy layout calls
/*	These methods are due to layoutProperties and such things origionally being a property of UIView
	and not the proxy. To lessen dependance on UIView (In cases where layout is needed without views
	such as TableViews), this was moved to the proxy. In order to degrade gracefully, these shims are
	left here. They should not be relied upon, but instead used to find methods that still incorrectly
	rely on the view, and fix those methods.
*/

-(LayoutConstraint*)layoutProperties
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	return [(TiViewProxy *)proxy layoutProperties];
}

-(void)setLayoutProperties:(LayoutConstraint *)layout_
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	[(TiViewProxy *)proxy setLayoutProperties:layout_];
}

-(CGFloat)minimumParentWidthForWidth:(CGFloat)value
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	return [(TiViewProxy *)[self proxy] minimumParentWidthForWidth:value];
}

-(CGFloat)minimumParentHeightForWidth:(CGFloat)value
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	return [(TiViewProxy *)[self proxy] minimumParentHeightForWidth:value];
}

-(CGFloat)autoWidthForWidth:(CGFloat)value
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	return [(TiViewProxy *)[self proxy] autoWidthForWidth:value];
}

-(CGFloat)autoHeightForWidth:(CGFloat)value
{
	NSLog(@"[DEBUG] Using view proxy via redirection instead of directly for %@.",self);
	return [(TiViewProxy *)[self proxy] autoHeightForWidth:value];
}




#pragma mark Layout 


-(void)insertIntoView:(UIView*)newSuperview bounds:(CGRect)bounds
{
	if (newSuperview==self)
	{
		NSLog(@"[ERROR] invalid call to insertIntoView, new super view is same as myself");
		return;
	}
	ApplyConstraintToViewWithinViewWithBounds([(TiViewProxy *)proxy layoutProperties], self, newSuperview, bounds,YES);
	[(TiViewProxy *)[self proxy] clearNeedsReposition];
}

-(void)relayout:(CGRect)bounds
{
	if (repositioning==NO)
	{
		repositioning = YES;
		ApplyConstraintToViewWithinViewWithBounds([(TiViewProxy *)proxy layoutProperties], self, [self superview], bounds, YES);
		[(TiViewProxy *)[self proxy] clearNeedsReposition];
		repositioning = NO;
	}
}


-(void)updateLayout:(LayoutConstraint*)layout_ withBounds:(CGRect)bounds
{
	if (animating)
	{
#ifdef DEBUG		
		// changing the layout while animating is bad, ignore for now
		NSLog(@"[DEBUG] ignoring new layout while animating..");
#endif		
		return;
	}
	[self relayout:bounds];
}

-(void)performZIndexRepositioning
{
	if ([[self subviews] count] == 0)
	{
		return;
	}
	
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(performZIndexRepositioning) withObject:nil waitUntilDone:NO];
		return;
	}
	
	// sort by zindex
	NSArray *children = [[NSArray arrayWithArray:[self subviews]] sortedArrayUsingFunction:zindexSort context:NULL];
						 
	// re-configure all the views by zindex order
	for (TiUIView *child in children)
	{
		[child retain];
		[child removeFromSuperview];
		[self addSubview:child];
		[child release];
	}
}

-(unsigned int)zIndex
{
	return zIndex;
}

-(void)repositionZIndex
{
	if (parent!=nil && [parent viewAttached])
	{
		TiUIView *parentView = [parent view];
		[parentView performZIndexRepositioning];
	}
}

-(BOOL)animationFromArgument:(id)args
{
	// should happen already in completed callback but in case it didn't complete or was implicitly cancelled
	RELEASE_TO_NIL(animation);
	animation = [[TiAnimation animationFromArg:args context:[self.proxy pageContext] create:NO] retain];
	return (animation!=nil);
}

-(void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
	// for subclasses to do crap
}


-(void)setFrame:(CGRect)frame
{
	[super setFrame:frame];
	
	// this happens when a view is added to another view but not
	// through the framework (such as a tableview header) and it
	// means we need to force the layout of our children
	if (childrenInitialized==NO && 
		CGRectIsEmpty(frame)==NO &&
		[self.proxy isKindOfClass:[TiViewProxy class]])
	{
		childrenInitialized=YES;
		[(TiViewProxy*)self.proxy layoutChildren];
	}
}

-(void)checkBounds
{
	CGRect newBounds = [self bounds];
	if(!CGSizeEqualToSize(oldSize, newBounds.size))
	{
		oldSize = newBounds.size;
		[self frameSizeChanged:[TiUtils viewPositionRect:self] bounds:newBounds];
	}
}

-(void)setBounds:(CGRect)bounds
{
	[super setBounds:bounds];
	[self checkBounds];
}

-(void)layoutSubviews
{
	[super layoutSubviews];
	[self checkBounds];
}

-(void)updateTransform
{
	if ([transformMatrix isKindOfClass:[Ti2DMatrix class]])
	{
		self.transform = CGAffineTransformConcat(virtualParentTransform, [(Ti2DMatrix*)transformMatrix matrix]);
	}
	else if ([transformMatrix isKindOfClass:[Ti3DMatrix class]])
	{
		self.layer.transform = CATransform3DConcat(CATransform3DMakeAffineTransform(virtualParentTransform),[(Ti3DMatrix*)transformMatrix matrix]);
	}
	else
	{
		self.transform = virtualParentTransform;
	}
}


-(void)setVirtualParentTransform:(CGAffineTransform)newTransform
{
	virtualParentTransform = newTransform;
	[self updateTransform];
}

-(void)fillBoundsToRect:(TiRect*)rect
{
	CGRect r = [self bounds];
	[rect setRect:r];
}

#pragma mark Public APIs

-(void)setBorderColor_:(id)color
{
	TiColor *ticolor = [TiUtils colorValue:color];
	self.layer.borderWidth = MAX(self.layer.borderWidth,1);
	self.layer.borderColor = [ticolor _color].CGColor;
}
 
-(void)setBorderWidth_:(id)w
{ 
	self.layer.borderWidth = [TiUtils sizeValue:w];
}

-(void)setBackgroundColor_:(id)color
{
	if ([color isKindOfClass:[UIColor class]])
	{
		super.backgroundColor = color;
	}
	else
	{
		TiColor *ticolor = [TiUtils colorValue:color];
		super.backgroundColor = [ticolor _color];
	}
}

-(void)setOpacity_:(id)opacity
{
	self.alpha = [TiUtils floatValue:opacity];
}

-(void)setBackgroundImage_:(id)image
{
	NSURL *bgURL = [TiUtils toURL:image proxy:proxy];
	UIImage *resultImage = [[ImageLoader sharedLoader] loadImmediateStretchableImage:bgURL];
	if (resultImage==nil && [image isEqualToString:@"Default.png"])
	{
		// special case where we're asking for Default.png and it's in Bundle not path
		resultImage = [UIImage imageNamed:image];
	}
	self.layer.contents = (id)resultImage.CGImage;
	self.clipsToBounds = image!=nil;
}

-(void)setBorderRadius_:(id)radius
{
	self.layer.cornerRadius = [TiUtils floatValue:radius];
	self.clipsToBounds = YES;
}

-(void)setAnchorPoint_:(id)point
{
	self.layer.anchorPoint = [TiUtils pointValue:point];
}

-(void)setTransform_:(id)transform_
{
	RELEASE_TO_NIL(transformMatrix);
	transformMatrix = [transform_ retain];
	[self updateTransform];
}

-(void)setCenter_:(id)point
{
	self.center = [TiUtils pointValue:point];
}

-(void)setVisible_:(id)visible
{
	self.hidden = ![TiUtils boolValue:visible];
}

-(void)setZIndex_:(id)z
{
	zIndex = [TiUtils intValue:z];
	[self repositionZIndex];
}

-(void)setAnimation_:(id)arg
{
	[self.proxy replaceValue:nil forKey:@"animation" notification:NO];
	[self animate:arg];
}

-(void)setTouchEnabled_:(id)arg
{
	touchEnabled = [TiUtils boolValue:arg];
}

-(void)animate:(id)arg
{
	ENSURE_UI_THREAD(animate,arg);
	RELEASE_TO_NIL(animation);
	
	if ([self.proxy isKindOfClass:[TiViewProxy class]] && [(TiViewProxy*)self.proxy viewReady]==NO)
	{
#ifdef DEBUG
		NSLog(@"[DEBUG] animated called and we're not ready ... (will try again)");
#endif		
		if (animationDelayGuard++ > 5)
		{
#ifdef DEBUG
			NSLog(@"[DEBUG] animation guard triggered, we exceeded the timeout on waiting for view to become ready");
#endif		
			return;
		}
		[self performSelector:@selector(animate:) withObject:arg afterDelay:0.01];
		return;
	}
	
	animationDelayGuard = 0;

	if ([self animationFromArgument:arg])
	{
		animating = YES;
		[animation animate:self];
	}	
	else
	{
		NSLog(@"[WARN] animate called with %@ but couldn't make an animation object",arg);
	}
}

-(void)animationCompleted
{
	animating = NO;
}

#pragma mark Property Change Support

-(SEL)selectorForProperty:(NSString*)key
{
	NSString *method = [NSString stringWithFormat:@"set%@%@_:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]];
	return NSSelectorFromString(method);
}

-(void)readProxyValuesWithKeys:(id<NSFastEnumeration>)keys
{
	DoProxyDelegateReadValuesWithKeysFromProxy(self, keys, proxy);
}

-(void)propertyChanged:(NSString*)key oldValue:(id)oldValue newValue:(id)newValue proxy:(TiProxy*)proxy_
{
	DoProxyDelegateChangedValuesWithProxy(self, key, oldValue, newValue, proxy_);
}

-(void)transferProxy:(TiViewProxy*)newProxy
{
	TiViewProxy * oldProxy = (TiViewProxy *)[self proxy];
	NSArray * oldProperties = (NSArray *)[oldProxy allKeys];
	NSArray * newProperties = (NSArray *)[newProxy allKeys];
	[oldProxy retain];
	[self retain];

	[oldProxy setView:nil];
	[newProxy setView:self];
	[self setProxy:newProxy];

	for (NSString * thisKey in oldProperties)
	{
		if([newProperties containsObject:thisKey])
		{
			continue;
		}
		SEL method = SetterForKrollProperty(thisKey);
		if([self respondsToSelector:method])
		{
			[self performSelector:method withObject:nil];
			continue;
		}
		
		method = SetterWithObjectForKrollProperty(thisKey);
		if([self respondsToSelector:method])
		{
			[self performSelector:method withObject:nil withObject:nil];
		}		
	}

	for (NSString * thisKey in newProperties)
	{
		id newValue = [newProxy valueForKey:thisKey];
		id oldValue = [oldProxy valueForKey:thisKey];
		if([newValue isEqual:oldValue])
		{
			continue;
		}
		
		SEL method = SetterForKrollProperty(thisKey);
		if([self respondsToSelector:method])
		{
			[self performSelector:method withObject:newValue];
			continue;
		}
		
		method = SetterWithObjectForKrollProperty(thisKey);
		if([self respondsToSelector:method])
		{
			[self performSelector:method withObject:newValue withObject:nil];
		}		
	}

	[oldProxy release];
	[self release];
}


-(id)proxyValueForKey:(NSString *)key
{
	return [proxy valueForKey:key];
}

#pragma mark First Responder delegation

-(void)makeRootViewFirstResponder
{
	[[[TitaniumApp app] controller].view becomeFirstResponder];
}

#pragma mark Touch Events

- (void)handleSwipeLeft
{
	NSMutableDictionary *evt = [NSMutableDictionary dictionaryWithDictionary:[TiUtils pointToDictionary:touchLocation]];
	[evt setValue:@"left" forKey:@"direction"];
	[proxy fireEvent:@"swipe" withObject:evt];
}

- (void)handleSwipeRight
{
	NSMutableDictionary *evt = [NSMutableDictionary dictionaryWithDictionary:[TiUtils pointToDictionary:touchLocation]];
	[evt setValue:@"right" forKey:@"direction"];
	[proxy fireEvent:@"swipe" withObject:evt];
}

- (void)handleSingleTap 
{
	if ([proxy _hasListeners:@"singletap"])
	{
		NSDictionary *evt = [TiUtils pointToDictionary:tapLocation];
		[proxy fireEvent:@"singletap" withObject:evt];
	}
}

- (void)handleDoubleTap 
{
	if ([proxy _hasListeners:@"doubletap"])
	{
		NSDictionary *evt = [TiUtils pointToDictionary:tapLocation];
		[proxy fireEvent:@"doubletap" withObject:evt];
	}
}	

- (void)handleTwoFingerTap 
{
	if ([proxy _hasListeners:@"twofingertap"])
	{
		NSDictionary *evt = [TiUtils pointToDictionary:tapLocation];
		[proxy fireEvent:@"twofingertap" withObject:evt];
	}
}

- (BOOL)interactionDefault
{
	return YES;
}

- (BOOL)interactionEnabled
{
	if (touchEnabled)
	{
		// we allow the developer to turn off touch with this property but make the default the
		// result of the internal method interactionDefault. some components (like labels) by default
		// don't want or need interaction if not explicitly enabled through an addEventListener
		return [self interactionDefault];
	}
	return NO;
}

- (BOOL)hasTouchableListener
{
	return (handlesSwipes|| handlesTaps || handlesTouches);
}

- (UIView *)hitTest:(CGPoint) point withEvent:(UIEvent *)event 
{
	BOOL hasTouchListeners = [self hasTouchableListener];
	
	// delegate to our touch delegate if we're hit but it's not for us
	if (hasTouchListeners==NO && touchDelegate!=nil)
	{
		return touchDelegate;
	}
	
	// if we don't have any touch listeners, see if interaction should
	// be handled at all.. NOTE: we don't turn off the views interactionEnabled
	// property since we need special handling ourselves and if we turn it off
	// on the view, we'd never get this event
	if (hasTouchListeners == NO && [self interactionEnabled]==NO)
	{
		return nil;
	}
	
    return [super hitTest:point withEvent:event];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	UITouch *touch = [touches anyObject];
	
	if (handlesSwipes)
	{
		touchLocation = [touch locationInView:self];
	}
	
	if (handlesTaps)
	{
		// cancel any pending handleSingleTap messages 
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleSingleTap) object:nil];
		
		int count = [[event touchesForView:self] count];
		
		// update our touch state
		if (count > 1)
		{
			multipleTouches = YES;
		}
		if (count > 2)
		{
			twoFingerTapIsPossible = NO;
		}
	}
	
	if (handlesTouches)
	{
		CGPoint point = [touch locationInView:[self superview]];
		NSDictionary *evt = [TiUtils pointToDictionary:point];
		
		if ([proxy _hasListeners:@"touchstart"])
		{
			[proxy fireEvent:@"touchstart" withObject:evt propagate:(touchDelegate==nil)];
		}
		
		if ([touch tapCount] == 1 && [proxy _hasListeners:@"click"])
		{
			[proxy fireEvent:@"click" withObject:evt propagate:(touchDelegate==nil)];
		}
		else if ([touch tapCount] == 2 && [proxy _hasListeners:@"dblclick"])
		{
			[proxy fireEvent:@"dblclick" withObject:evt propagate:(touchDelegate==nil)];
		}
	}
	
	if (touchDelegate!=nil)
	{
		[touchDelegate touchesBegan:touches withEvent:event];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
	UITouch *touch = [touches anyObject];
	if (handlesTouches)
	{
		CGPoint point = [touch locationInView:[self superview]];
		NSDictionary *evt = [TiUtils pointToDictionary:point];
		if ([proxy _hasListeners:@"touchmove"])
		{
			[proxy fireEvent:@"touchmove" withObject:evt propagate:(touchDelegate==nil)];
		}
	}
	if (handlesSwipes)
	{
		CGPoint point = [touch locationInView:self];
		// To be a swipe, direction of touch must be horizontal and long enough.
		if (fabsf(touchLocation.x - point.x) >= HORIZ_SWIPE_DRAG_MIN &&
			fabsf(touchLocation.y - point.y) <= VERT_SWIPE_DRAG_MAX)
		{
			// It appears to be a swipe.
			if (touchLocation.x < point.x)
			{
				[self handleSwipeRight];
			}
			else 
			{
				[self handleSwipeLeft];
			}
		}
	}
	
	if (touchDelegate!=nil)
	{
		[touchDelegate touchesMoved:touches withEvent:event];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if (handlesTaps)
	{
		BOOL allTouchesEnded = ([touches count] == [[event touchesForView:self] count]);
		
		// first check for plain single/double tap, which is only possible if we haven't seen multiple touches
		if (!multipleTouches) 
		{
			UITouch *touch = [touches anyObject];
			tapLocation = [touch locationInView:self];
			
			if ([touch tapCount] == 1) 
			{
				[self performSelector:@selector(handleSingleTap) withObject:nil afterDelay:DOUBLE_TAP_DELAY];
			} 
			else if([touch tapCount] == 2) 
			{
				[self handleDoubleTap];
			}
		}    
		
		// check for 2-finger tap if we've seen multiple touches and haven't yet ruled out that possibility
		else if (multipleTouches && twoFingerTapIsPossible) 
		{ 
			
			// case 1: this is the end of both touches at once 
			if ([touches count] == 2 && allTouchesEnded) 
			{
				int i = 0; 
				int tapCounts[2]; CGPoint tapLocations[2];
				for (UITouch *touch in touches) {
					tapCounts[i]    = [touch tapCount];
					tapLocations[i] = [touch locationInView:self];
					i++;
				}
				if (tapCounts[0] == 1 && tapCounts[1] == 1) 
				{ 
					// it's a two-finger tap if they're both single taps
					tapLocation = midpointBetweenPoints(tapLocations[0], tapLocations[1]);
					[self handleTwoFingerTap];
				}
			}
			
			// case 2: this is the end of one touch, and the other hasn't ended yet
			else if ([touches count] == 1 && !allTouchesEnded) 
			{
				UITouch *touch = [touches anyObject];
				if ([touch tapCount] == 1) 
				{
					// if touch is a single tap, store its location so we can average it with the second touch location
					tapLocation = [touch locationInView:self];
				} 
				else 
				{
					twoFingerTapIsPossible = NO;
				}
			}
			
			// case 3: this is the end of the second of the two touches
			else if ([touches count] == 1 && allTouchesEnded) 
			{
				UITouch *touch = [touches anyObject];
				if ([touch tapCount] == 1) 
				{
					// if the last touch up is a single tap, this was a 2-finger tap
					tapLocation = midpointBetweenPoints(tapLocation, [touch locationInView:self]);
					//[self handleTwoFingerTap];
				}
			}
		}
        
		// if all touches are up, reset touch monitoring state
		if (allTouchesEnded) 
		{
			twoFingerTapIsPossible = YES;
			multipleTouches = NO;
		}
	}
	
	if (handlesTouches)
	{
		UITouch *touch = [touches anyObject];
		CGPoint point = [touch locationInView:[self superview]];
		NSDictionary *evt = [TiUtils pointToDictionary:point];
		if ([proxy _hasListeners:@"touchend"])
		{
			[proxy fireEvent:@"touchend" withObject:evt propagate:(touchDelegate==nil)];
		}
	}
	if (handlesSwipes)
	{
		touchLocation = CGPointZero;
	}
	
	if (touchDelegate!=nil)
	{
		[touchDelegate touchesEnded:touches withEvent:event];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if (handlesTaps)
	{
		twoFingerTapIsPossible = YES;
		multipleTouches = NO;
	}
	if (handlesTouches)
	{
		UITouch *touch = [touches anyObject];
		CGPoint point = [touch locationInView:[self superview]];
		NSDictionary *evt = [TiUtils pointToDictionary:point];
		if ([proxy _hasListeners:@"touchcancel"])
		{
			[proxy fireEvent:@"touchcancel" withObject:evt propagate:(touchDelegate==nil)];
		}
	}
	if (handlesSwipes)
	{
		touchLocation = CGPointZero;
	}
	
	if (touchDelegate!=nil)
	{
		[touchDelegate touchesCancelled:touches withEvent:event];
	}
}

#pragma mark Listener management

-(void)listenerAdded:(NSString*)event count:(int)count
{
	if (count == 1 && [self viewSupportsBaseTouchEvents])
	{
		if ([self proxyHasTouchListener])
		{
			handlesTouches = YES;
		}
		if ([event hasSuffix:@"tap"])
		{
			handlesTaps = YES;
		}
		if ([event isEqualToString:@"swipe"])
		{
			handlesSwipes = YES;
		}
		
		if (handlesTouches || handlesTaps || handlesSwipes)
		{
			self.userInteractionEnabled = YES;
		}
		
		if (handlesTaps)
		{
			self.multipleTouchEnabled = YES;
		}
	}
}

-(void)listenerRemoved:(NSString*)event count:(int)count
{
	if (count == 0)
	{
		// unfortunately on a remove, we have to check all of them
		// since we might be removing one but we still have others
		
		if (handlesTouches && 
			[self.proxy _hasListeners:@"touchstart"]==NO &&
			[self.proxy _hasListeners:@"touchmove"]==NO &&
			[self.proxy _hasListeners:@"touchcancel"]==NO &&
			[self.proxy _hasListeners:@"touchend"]==NO &&
			[self.proxy _hasListeners:@"click"]==NO &&
			[self.proxy _hasListeners:@"dblclick"]==NO)
		{
			handlesTouches = NO;
		}
		if (handlesTaps &&
			[self.proxy _hasListeners:@"singletap"]==NO &&
			[self.proxy _hasListeners:@"doubletap"]==NO &&
			[self.proxy _hasListeners:@"twofingertap"]==NO)
		{
			handlesTaps = NO;
		}
		if (handlesSwipes &&
			[event isEqualToString:@"swipe"])
		{
			handlesSwipes = NO;
		}
		
		if (handlesTaps == NO && handlesTouches == NO)
		{
			self.userInteractionEnabled = NO;
			self.multipleTouchEnabled = NO;
		}
	}
}

@end

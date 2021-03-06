/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import <MapKit/MapKit.h>
#import "TiMapView.h"

@interface TiMapPinAnnotationView : MKPinAnnotationView {
@private
	TiMapView *map;
	BOOL observing;
	NSString * lastHitName;
}

-(id)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier map:(TiMapView*)map;
-(NSString *)lastHitName;

@end

/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiProxy.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2

@interface TiUIiPadDocumentViewerProxy : TiProxy<UIDocumentInteractionControllerDelegate> {
@private
	UIDocumentInteractionController *controller;
}

@property(nonatomic,readwrite,assign) id url;
@property(nonatomic,readonly) id icons;
@property(nonatomic,readonly) id name;


@end

#endif
/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUITableViewProxy.h"
#import "TiUITableView.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewAction.h"
#import "TiUtils.h"
#import "WebFont.h"
#import "TiViewProxy.h"
#import "TiComplexValue.h"

@implementation TiUITableViewProxy

#pragma mark Internal 

-(void)_configure
{
	[super _configure];
	[self replaceValue:NUMBOOL(YES) forKey:@"searchHidden" notification:NO];
	[self replaceValue:NUMBOOL(NO) forKey:@"autoHideSearch" notification:NO];
}

-(id<NSFastEnumeration>)allKeys
{
	NSArray * result = (NSArray *)[super allKeys];
	if (![result containsObject:@"data"])
	{
		return result;
	}
	result = [NSMutableArray arrayWithArray:result];
	[(NSMutableArray *)result removeObject:@"data"];
	[(NSMutableArray *)result insertObject:@"data" atIndex:0];
	return result;
}


-(TiUITableView*)tableView
{
	return (TiUITableView*)[self view];
}

-(TiUITableViewRowProxy*)newTableViewRowFromDict:(NSDictionary*)data
{
	TiUITableViewRowProxy *proxy = [[[TiUITableViewRowProxy alloc] _initWithPageContext:[self executionContext]] autorelease];
	[proxy _initWithProperties:data];
	return proxy;
}

-(TiUITableViewRowProxy*)tableRowFromArg:(id)data
{
	TiUITableViewRowProxy *row = nil;
	
	if ([data isKindOfClass:[NSDictionary class]])
	{
		row = [self newTableViewRowFromDict:data];
	}
	else if ([data isKindOfClass:[TiUITableViewRowProxy class]])
	{
		row = (TiUITableViewRowProxy*)data;
	}
	
	if (row == nil)
	{
		[self throwException:@"couldn't determine row data from argument" subreason:nil location:CODELOCATION];
	}
	return row;
}

-(NSMutableArray*)sections
{
	NSMutableArray *sections = [self valueForKey:@"data"];;
	if (sections == nil)
	{
		sections = [NSMutableArray array];
		[self replaceValue:sections forKey:@"data" notification:YES];
	}
	return sections;
}

-(TiUITableViewSectionProxy*)sectionForIndex:(NSInteger)index row:(TiUITableViewRowProxy**)rowOut
{
	NSMutableArray *sections = [self sections];
	int current = 0;
	int row = index;
	int sectionIdx = 0;
	
	TiUITableViewRowProxy *rowProxy = nil;
	TiUITableViewSectionProxy *sectionProxy = nil;
	
	for (sectionProxy in sections)
	{
		int rowCount = [sectionProxy rowCount];
		if (rowCount + current > index)
		{
			rowProxy = [sectionProxy rowAtIndex:row];
			if (rowOut!=nil)
			{	
				*rowOut = rowProxy;
			}
			break;
		}
		row -= rowCount;
		current += rowCount;
		sectionIdx++;
	}		
	
	return sectionProxy;
}

#pragma mark Public APIs

-(void)setSearchHidden:(id)args
{
	// we implement here to force it regardless of the current state 
	// since the user can manually change the search field by pulling 
	// down the row
	ENSURE_SINGLE_ARG(args,NSObject);
	[self replaceValue:args forKey:@"searchHidden" notification:YES];
}

-(void)selectRow:(id)args
{
	[[self view] performSelectorOnMainThread:@selector(selectRow:) withObject:args waitUntilDone:NO];
}

-(void)deselectRow:(id)args
{
	[[self view] performSelectorOnMainThread:@selector(deselectRow:) withObject:args waitUntilDone:NO];
}

-(void)scrollToIndex:(id)args
{
	ENSURE_UI_THREAD(scrollToIndex,args);
	
	NSInteger index = [TiUtils intValue:[args objectAtIndex:0]];
	NSDictionary *options = [args count] > 1 ? [args objectAtIndex:1] : nil;

	UITableViewScrollPosition scrollPosition = [TiUtils intValue:@"position" properties:options def:UITableViewScrollPositionNone];
	BOOL animated = [TiUtils boolValue:@"animated" properties:options def:YES];
	
	[(TiUITableView*)[self view] scrollToIndex:index position:scrollPosition animated:animated];
}

-(NSNumber*)getIndexByName:(id)args
{
	ENSURE_SINGLE_ARG(args,NSString);
	
	int c = 0;
	
	for (TiUITableViewSectionProxy *section in [(TiUITableView*)[self view] sections])
	{
		for (TiUITableViewRowProxy *row in [section rows])
		{
			if ([args isEqualToString:[row valueForUndefinedKey:@"name"]])
			{
				return NUMINT(c);
			}
			c++;
		}
	}
	return NUMINT(-1);
}

-(void)updateRow:(id)args
{
	ENSURE_UI_THREAD(updateRow,args);
	
	int index = [TiUtils intValue:[args objectAtIndex:0]];
    id data = [args objectAtIndex:1]; // Can be either dictionary or row object
    NSDictionary *anim = [args count] > 2 ? [args objectAtIndex:2] : nil;
	
	TiUITableViewRowProxy *newrow = [self tableRowFromArg:data];
	TiUITableView *table = [self tableView];
	
	NSMutableArray *sections = [self valueForKey:@"data"];
	
	int current = 0;
	int row = index;
	int sectionIdx = 0;
	
	TiUITableViewRowProxy *rowProxy = nil;
	TiUITableViewSectionProxy *sectionProxy = nil;
	
	for (sectionProxy in sections)
	{
		int rowCount = [sectionProxy rowCount];
		if (rowCount + current > index)
		{
			rowProxy = [sectionProxy rowAtIndex:row];
			break;
		}
		row -= rowCount;
		current += rowCount;
		sectionIdx++;
	}		
	
	if (rowProxy==nil)
	{
		[self throwException:[NSString stringWithFormat:@"cannot find row at index: %d",index] subreason:nil location:CODELOCATION];
		return;
	}
	
	newrow.section = rowProxy.section;
	newrow.row = rowProxy.row;
	newrow.parent = newrow.section;
	
    // Only update the row if we're loading it with data; but most of this should
    // be taken care of by -[TiUITableViewProxy tableRowFromArg:] anyway, right?
    if ([data isKindOfClass:[NSDictionary class]]) {
        [newrow updateRow:data withObject:anim];
    }
	
	TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:newrow animation:anim section:-1 type:TiUITableViewActionUpdateRow] autorelease];
	[table dispatchAction:action];
}

-(void)deleteRow:(id)args
{
	ENSURE_UI_THREAD(deleteRow,args);
	
	int index = [TiUtils intValue:[args objectAtIndex:0]];
	NSDictionary *anim = [args count] > 1 ? [args objectAtIndex:1] : nil;
	
	TiUITableView *table = [self tableView];
	
	NSMutableArray *sections = [self valueForKey:@"data"];
	
	if ([sections count]==0)
	{
		[self throwException:@"no rows found" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewRowProxy *row = nil;
	TiUITableViewSectionProxy *section = [self sectionForIndex:index row:&row];
	
	if (section==nil || row == nil)
	{
		[self throwException:@"no row found for index" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:row animation:anim section:section.section type:TiUITableViewActionDeleteRow] autorelease];
	[table dispatchAction:action];
}

-(void)insertRowBefore:(id)args
{
	ENSURE_UI_THREAD(insertRowBefore,args);
	
	int index = [TiUtils intValue:[args objectAtIndex:0]];
	NSDictionary *data = [args objectAtIndex:1];
	NSDictionary *anim = [args count] > 2 ? [args objectAtIndex:2] : nil;
	
	TiUITableView *table = [self tableView];
	
	NSMutableArray *sections = [self valueForKey:@"data"];
	if ([sections count]==0)
	{
		[self throwException:@"invalid number of rows" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewRowProxy *row = nil;
	TiUITableViewSectionProxy *section = [self sectionForIndex:index row:&row];
	
	if (section==nil || row == nil)
	{
		[self throwException:@"no row found for index" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewRowProxy *newrow = [self tableRowFromArg:data];
	newrow.section = section;
	newrow.row = row.row == 0 ? 0 : row.row - 1;
	newrow.parent = section;
	
	TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:newrow animation:anim section:section.section type:TiUITableViewActionInsertRowBefore] autorelease];
	[table dispatchAction:action];
}

-(void)insertRowAfter:(id)args
{
	ENSURE_UI_THREAD(insertRowAfter,args);
	
	int index = [TiUtils intValue:[args objectAtIndex:0]];
	NSDictionary *data = [args objectAtIndex:1];
	NSDictionary *anim = [args count] > 2 ? [args objectAtIndex:2] : nil;

	TiUITableView *table = [self tableView];
	
	NSMutableArray *sections = [self valueForKey:@"data"];
	if ([sections count]==0)
	{
		[self throwException:@"invalid number of rows" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewRowProxy *row = nil;
	TiUITableViewSectionProxy *section = [self sectionForIndex:index row:&row];
	
	if (section==nil || row == nil)
	{
		[self throwException:@"no row found for index" subreason:nil location:CODELOCATION];
		return;
	}
	
	TiUITableViewRowProxy *newrow = [self tableRowFromArg:data];
	newrow.section = section;
	newrow.row = row.row+1;
	newrow.parent = section;
	
	TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:newrow animation:anim section:section.section type:TiUITableViewActionInsertRowAfter] autorelease];
	[table dispatchAction:action];
}

-(void)appendRow:(id)args
{
	ENSURE_UI_THREAD(appendRow,args);
	
	id data = [args objectAtIndex:0];
	NSDictionary *anim = [args count] > 1 ? [args objectAtIndex:1] : nil;
	
	TiUITableViewRowProxy *row = [self tableRowFromArg:data];

	TiUITableView *table = [self tableView];

	NSMutableArray *sections = [self valueForKey:@"data"];
	if (sections == nil || [sections count]==0)
	{
		[self setData:[NSArray arrayWithObject:data] withObject:anim];
		return;
	}
	else
	{
		TiUITableViewSectionProxy *section = [sections lastObject];
		row.section = section;
		row.parent = section;
		
		TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:row animation:anim section:row.section.section type:TiUITableViewActionAppendRow] autorelease];
		[table dispatchAction:action];
	}	
}

-(void)setData:(id)args withObject:(id)properties
{
	ENSURE_ARRAY(args);
	ENSURE_UI_THREAD_WITH_OBJ(setData,args,properties);
	
	// this is on the non-UI thread. let's do the work here before we pass
	// it over to the view which will be on the UI thread
	
	Class dictionaryClass = [NSDictionary class];
	Class sectionClass = [TiUITableViewSectionProxy class];
	Class rowClass = [TiUITableViewRowProxy class];
	
	TiUITableView *table = [self tableView];
	
	NSMutableArray *data = [NSMutableArray array];
	
	TiUITableViewSectionProxy *section = nil;
	
	for (id row in args)
	{
		if ([row isKindOfClass:dictionaryClass])
		{
			NSDictionary *dict = (NSDictionary*)row;
			TiUITableViewRowProxy *rowProxy = [self newTableViewRowFromDict:dict];
			NSString *header = [dict objectForKey:@"header"];
			if (section == nil || header!=nil)
			{
				// if we don't yet have a section, that means we need to create one
				// if we have a header property, that means start a new section
				section = [[[TiUITableViewSectionProxy alloc] _initWithPageContext:[self executionContext] args:nil] autorelease];
				[data addObject:section];
			}
			if (header!=nil)
			{
				[section setValue:header forUndefinedKey:@"headerTitle"];
			}
			NSString *footer = [dict objectForKey:@"footer"];
			if (footer!=nil)
			{
				[section setValue:footer forUndefinedKey:@"footerTitle"];
			}
			[section add:rowProxy];
		}
		else if ([row isKindOfClass:sectionClass])
		{
			section = (TiUITableViewSectionProxy*)row;
			[data addObject:section];
		}
		else if ([row isKindOfClass:rowClass])
		{
			id rowHeader = [row valueForKey:@"header"];
			id rowFooter = [row valueForKey:@"footer"];
			if (section == nil || rowHeader!=nil)
			{
				section = [[[TiUITableViewSectionProxy alloc] _initWithPageContext:[self executionContext] args:nil] autorelease];
				if (rowHeader!=nil)
				{
					[section setValue:rowHeader forUndefinedKey:@"headerTitle"];
				}
				[data addObject:section];
			}
			if (rowFooter!=nil)
			{
				[section setValue:rowFooter forUndefinedKey:@"footerTitle"];
			}
			[section add:row];
		}
	}
	
	[self replaceValue:data forKey:@"data" notification:NO];

	TiUITableViewAction *action = [[[TiUITableViewAction alloc] initWithRow:nil animation:properties section:0 type:TiUITableViewActionSetData] autorelease];
	[table dispatchAction:action];
}

-(void)setData:(id)args
{
	// if you pass in no args, it's a non animation set
	[self setData:args withObject:[NSDictionary dictionaryWithObject:NUMINT(UITableViewRowAnimationNone) forKey:@"animationStyle"]];
}

@end 

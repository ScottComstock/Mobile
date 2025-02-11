//
//  DictionaryTableViewController.m
//  Learn Navi iPhone App
//
//  Created by Michael Gillogly on 1/20/10.
//  Copyright 2010 LearnNa'vi.org Community. All rights reserved.
//aInfixes

#import "DictionaryEntry.h"
#import "DictionaryTableViewController.h"
#import "DictionaryEntryViewController.h"
#import "UIViewAdditions.h"

@implementation DictionaryTableViewController


@synthesize dictionaryContent, dictionarySearchContent, dictionaryContentIndex, dictionaryContentIndexMod, dictionarySearchContentIndex, dictionarySearchContentIndexMod, indexCounts, query, queryIndex; 
@synthesize querySearch, querySearchIndex, search_term, savedSearchTerm, savedScopeButtonIndex, searchWasActive, viewController, segmentedControl, currentMode, databasePath, indexSearchCounts, dictionaryUpdates;

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

- (void) addViewController:(UIViewController *)controller {
	self.viewController = controller;
	
}


- (void)viewDidLoad {
    
	//listOfItems = [[NSMutableArray alloc] init];
	
	[super viewDidLoad];
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSString *mode = [prefs stringForKey:@"dictionary_language"];
	if([mode compare:@"navi"] == 0){
		currentMode = YES;
		self.title = @"Na'vi > 'ìnglìsì";
	} else if([mode compare:@"english"] == 0){
		currentMode = NO;
		self.title = @"English > Na'vi";
	} else {
		NSLog(@"Unknown mode: %@", mode);
		currentMode = YES;
		self.title = @"Na'vi > 'ìnglìsì";
	}
	
	[self filterDictionary:self];
	[self loadData];
	[self readEntriesFromDatabase];
	
	// create a filtered list that will contain products for the search results table.
	//self.filteredDictionaryContent = [NSMutableArray arrayWithCapacity:10];
	
	// restore search settings if they were saved in didReceiveMemoryWarning.
    if (self.savedSearchTerm)
	{
        [self.searchDisplayController setActive:self.searchWasActive];
        [self.searchDisplayController.searchBar setSelectedScopeButtonIndex:self.savedScopeButtonIndex];
        [self.searchDisplayController.searchBar setText:savedSearchTerm];
        
        self.savedSearchTerm = nil;
    }
	
	[self.tableView reloadData];
	self.tableView.scrollEnabled = YES;
	cellSizeChanged = NO;
	
	//defaultTintColor = [segmentedControl.tintColor retain];    // keep track of this for later
	
	[segmentedControl setTitle:[[prefs stringForKey:@"filter1"] capitalizedString] forSegmentAtIndex:1];
	[segmentedControl setTitle:[[prefs stringForKey:@"filter2"] capitalizedString] forSegmentAtIndex:2];
	[segmentedControl setTitle:[[prefs stringForKey:@"filter3"] capitalizedString] forSegmentAtIndex:3];
	[segmentedControl setTitle:[[prefs stringForKey:@"filter4"] capitalizedString] forSegmentAtIndex:4];
	[segmentedControl setTitle:[[prefs stringForKey:@"filter5"] capitalizedString] forSegmentAtIndex:5];
	
	UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc]
												initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
												target:nil action:nil];
	
	UIBarButtonItem *segmentBarItem = [[UIBarButtonItem alloc] initWithCustomView:segmentedControl];
	[segmentedControl release];
	
	//self.navigationItem.rightBarButtonItem = segmentBarItem;
	self.toolbarItems = [NSArray arrayWithObjects:
                         flexibleSpaceButtonItem,
						 segmentBarItem,
						 flexibleSpaceButtonItem,
                         nil];
	[segmentBarItem release];
	[flexibleSpaceButtonItem release];
	//self.tableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);
	
	UIButton* modalViewButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[modalViewButton addTarget:self action:@selector(swapDictionaryMode:) forControlEvents:UIControlEventTouchUpInside];
	[modalViewButton setImage:[UIImage imageNamed:@"Refresh.png"] forState:UIControlStateNormal];
	[modalViewButton setSize:[[UIImage imageNamed:@"Refresh.png"] size]];
	UIBarButtonItem *modalBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:modalViewButton];
	self.navigationItem.rightBarButtonItem = modalBarButtonItem;
	[modalBarButtonItem release];
}

- (IBAction) filterDictionary:(id)sender {
	
	cellSizeChanged = YES;
	
	NSString *queryAlpha = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND alpha = \"%%@\" ORDER BY navi_no_specials  LIMIT %%d,1";
	NSString *queryAlphaIndex = @"SELECT alpha,COUNT(*) FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' GROUP BY alpha";
	NSString *queryBeta = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND beta = \"%%@\" ORDER BY definition LIMIT %%d,1";
	NSString *queryBetaIndex = @"SELECT beta,COUNT(*) FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' GROUP BY beta";
	
	//Search Versions
	NSString *querySearchAlpha = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND alpha = \"%%@\" AND navi like \"%%%%%%@%%%%\" ORDER BY navi_no_specials  LIMIT %%d,1";
	NSString *querySearchAlphaIndex = @"SELECT alpha,COUNT(*) FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND navi like \"%%%%%%@%%%%\" GROUP BY alpha";
	NSString *querySearchBeta = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND beta = \"%%@\" AND definition like \"%%%%%%@%%%%\" ORDER BY definition LIMIT %%d,1";
	NSString *querySearchBetaIndex = @"SELECT beta,COUNT(*) FROM entries WHERE partOfSpeech like '%%%%^%@^%%%%' AND definition like \"%%%%%%@%%%%\" GROUP BY beta";
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	if(currentMode){
		switch(segmentedControl.selectedSegmentIndex) {
			case 0:
				// All
				// Do nothing
				queryIndex = @"SELECT alpha,COUNT(*) FROM entries GROUP BY alpha";
				query = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE alpha = \"%@\" ORDER BY navi_no_specials LIMIT %d,1";
				
				querySearchIndex = @"SELECT alpha,COUNT(*) FROM entries WHERE navi like \"%%%@%%\" GROUP BY alpha";
				querySearch = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE alpha = \"%@\" AND navi like \"%%%@%%\" ORDER BY navi_no_specials LIMIT %d,1";
				
				break;
			case 1:
				// Nouns
				[self setQueryIndex:[NSString stringWithFormat:queryAlphaIndex,[prefs stringForKey:@"filter1"]]];
				[self setQuery:[NSString stringWithFormat:queryAlpha,[prefs stringForKey:@"filter1"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchAlphaIndex,[prefs stringForKey:@"filter1"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchAlpha,[prefs stringForKey:@"filter1"]]];
				break;
			case 2:
				// Pronouns
				[self setQueryIndex:[NSString stringWithFormat:queryAlphaIndex,[prefs stringForKey:@"filter2"]]];
				[self setQuery:[NSString stringWithFormat:queryAlpha,[prefs stringForKey:@"filter2"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchAlphaIndex,[prefs stringForKey:@"filter2"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchAlpha,[prefs stringForKey:@"filter2"]]];
				break;
			case 3:
				// Verbs
				[self setQueryIndex:[NSString stringWithFormat:queryAlphaIndex,[prefs stringForKey:@"filter3"]]];
				[self setQuery:[NSString stringWithFormat:queryAlpha,[prefs stringForKey:@"filter3"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchAlphaIndex,[prefs stringForKey:@"filter3"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchAlpha,[prefs stringForKey:@"filter3"]]];
				break;
			case 4:
				// Adjectives
				[self setQueryIndex:[NSString stringWithFormat:queryAlphaIndex,[prefs stringForKey:@"filter4"]]];
				[self setQuery:[NSString stringWithFormat:queryAlpha,[prefs stringForKey:@"filter4"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchAlphaIndex,[prefs stringForKey:@"filter4"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchAlpha,[prefs stringForKey:@"filter4"]]];
				break;
			case 5:
				// Adverbs
				[self setQueryIndex:[NSString stringWithFormat:queryAlphaIndex,[prefs stringForKey:@"filter5"]]];
				[self setQuery:[NSString stringWithFormat:queryAlpha,[prefs stringForKey:@"filter5"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchAlphaIndex,[prefs stringForKey:@"filter5"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchAlpha,[prefs stringForKey:@"filter5"]]];
				break;
			default:
				break;
				
		}
		
		
	} else {
		switch(segmentedControl.selectedSegmentIndex) {
			case 0:
				// All
				// Do nothing
				queryIndex = @"SELECT beta,COUNT(*) FROM entries GROUP BY beta";
				query = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE beta = \"%@\" ORDER BY definition LIMIT %d,1";
				
				querySearchIndex = @"SELECT beta,COUNT(*) FROM entries WHERE definition like \"%%%@%%\" GROUP BY beta";
				querySearch = @"SELECT id, navi, navi_no_specials, ipa, infixes, definition, partOfSpeech, fancyPartOfSpeech, alpha, beta, version FROM entries WHERE beta = \"%@\" AND definition like \"%%%@%%\" ORDER BY definition LIMIT %d,1";
				
				break;
			case 1:
				// Nouns
				[self setQueryIndex:[NSString stringWithFormat:queryBetaIndex,[prefs stringForKey:@"filter1"]]];
				[self setQuery:[NSString stringWithFormat:queryBeta,[prefs stringForKey:@"filter1"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchBetaIndex,[prefs stringForKey:@"filter1"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchBeta,[prefs stringForKey:@"filter1"]]];
				break;
			case 2:
				// Pronouns
				[self setQueryIndex:[NSString stringWithFormat:queryBetaIndex,[prefs stringForKey:@"filter2"]]];
				[self setQuery:[NSString stringWithFormat:queryBeta,[prefs stringForKey:@"filter2"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchBetaIndex,[prefs stringForKey:@"filter2"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchBeta,[prefs stringForKey:@"filter2"]]];
				break;
			case 3:
				// Verbs
				[self setQueryIndex:[NSString stringWithFormat:queryBetaIndex,[prefs stringForKey:@"filter3"]]];
				[self setQuery:[NSString stringWithFormat:queryBeta,[prefs stringForKey:@"filter3"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchBetaIndex,[prefs stringForKey:@"filter3"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchBeta,[prefs stringForKey:@"filter3"]]];
				break;
			case 4:
				// Adjectives
				[self setQueryIndex:[NSString stringWithFormat:queryBetaIndex,[prefs stringForKey:@"filter4"]]];
				[self setQuery:[NSString stringWithFormat:queryBeta,[prefs stringForKey:@"filter4"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchBetaIndex,[prefs stringForKey:@"filter4"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchBeta,[prefs stringForKey:@"filter4"]]];
				break;
			case 5:
				// Adverbs
				[self setQueryIndex:[NSString stringWithFormat:queryBetaIndex,[prefs stringForKey:@"filter5"]]];
				[self setQuery:[NSString stringWithFormat:queryBeta,[prefs stringForKey:@"filter5"]]];
				[self setQuerySearchIndex:[NSString stringWithFormat:querySearchBetaIndex,[prefs stringForKey:@"filter5"]]];
				[self setQuerySearch:[NSString stringWithFormat:querySearchBeta,[prefs stringForKey:@"filter5"]]];
				break;
			default:
				break;
				
		}
		
	}
	if (self.searchDisplayController.active)
	{
		[self readSearchEntriesFromDatabase];
		[self.searchDisplayController.searchResultsTableView reloadData];
	} else {
		
		[self readEntriesFromDatabase];
		[self.tableView reloadData];
	}
	
	
	
	
}

- (IBAction) swapDictionaryMode:(id)sender {
	
	[UIView beginAnimations:@"Swap Dictionary" context:nil];
	[UIView setAnimationDuration:0.75];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.navigationController.view cache:YES];

	if(currentMode) {
		[[self navigationItem] setTitle:@"English > Na'vi"];
				
		NSArray *vcs = [[self navigationController] viewControllers];
		[[[vcs objectAtIndex:0] navigationItem] setBackBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"Home"
																									   style: UIBarButtonItemStyleBordered
																									  target:nil
																									  action:nil]];
		[[self navigationController] setViewControllers:vcs];
		
	} else {
		[[self navigationItem] setTitle:@"Na'vi > 'ìnglìsì"];
		NSArray *vcs = [[self navigationController] viewControllers];
		[[[vcs objectAtIndex:0] navigationItem] setBackBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"Kelutral"
																									  style: UIBarButtonItemStyleBordered
																									 target:nil
																									 action:nil]];
		[[self navigationController] setViewControllers:vcs];
		
	}	
	
	
	currentMode = !currentMode;
	
	//Need a more elegant way to load...
	//
	[self filterDictionary:self];
	[UIView commitAnimations];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[[self navigationController] setNavigationBarHidden:NO animated:YES];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	[[self navigationController] setToolbarHidden:NO animated:YES];

}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
	[[self navigationController] setToolbarHidden:NO animated:YES];
	
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
	//(interfaceOrientation == UIInterfaceOrientationPortrait);
}*/


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.searchWasActive = [self.searchDisplayController isActive];
    self.savedSearchTerm = [self.searchDisplayController.searchBar text];
    self.savedScopeButtonIndex = [self.searchDisplayController.searchBar selectedScopeButtonIndex];
	
	//self.filteredDictionaryContent = nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	// The header for the section is the region name -- get this from the region at the section index.
		
	
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{
		return [dictionarySearchContentIndexMod objectAtIndex:section];
    }
	else
	{
		return [dictionaryContentIndexMod objectAtIndex:section];
	}
	
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Number of sections is the number of regions.
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{
		return [dictionarySearchContentIndex count];
    }
	else
	{
		return [dictionaryContentIndex count];
	}
}

#pragma mark Table view methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	/*
	 If the requesting table view is the search display controller's table view, return the count of the filtered list, otherwise return the count of the main list.
	 */
	
	
	
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{

		NSNumber *count = [indexSearchCounts objectForKey:[dictionarySearchContentIndex objectAtIndex:section]];
		
		return [count intValue]; 
    }
	else
	{
        // Number of rows is the number of time zones in the region for the specified section.
		//DictionarySection *dictSection = [dictionaryActiveContent objectAtIndex:section];
		//return [dictSection.entries count];
		
		//---get the letter in each section; e.g., A, B, C, etc.---
		NSNumber *count = [indexCounts objectForKey:[dictionaryContentIndex objectAtIndex:section]];
		
		
		
		return [count intValue];    		
		
    }
	
	
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *kCellID = @"cellID";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
	if(cellSizeChanged){
		
		while(cell != nil){
			cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
		}
		cellSizeChanged = NO;
	}
	
	
	if (cell == nil)
	{	
		
		//cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellID] autorelease];
		cell = [self getCellContentView:kCellID];
		//cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
	
	
	/*
	 If the requesting table view is the search display controller's table view, configure the cell using the filtered content, otherwise use the main list.
	 */
	DictionaryEntry *entry = nil;
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{
		//---get the letter in the current section---
		NSString *alphabet = [dictionarySearchContentIndex objectAtIndex:[indexPath section]];
		entry = [self readSearchEntryFromDatabase:alphabet row:indexPath.row];
    }
	else
	{
		//---get the letter in the current section---
		NSString *alphabet = [dictionaryContentIndex objectAtIndex:[indexPath section]];
		entry = [self readEntryFromDatabase:alphabet row:indexPath.row];
    }
    
	UILabel *lblTemp1 = (UILabel *)[cell viewWithTag:1];
	UILabel *lblTemp2 = (UILabel *)[cell viewWithTag:2];
	UILabel *lblTemp3 = (UILabel *)[cell viewWithTag:3];

	if(currentMode){
		lblTemp1.text = entry.navi;
		lblTemp2.text = entry.english_definition;
	} else {
		lblTemp2.text = entry.navi;
		lblTemp1.text = entry.english_definition;
	}

	CGSize expectedSize = [[lblTemp1 text] sizeWithFont:[lblTemp1 font] constrainedToSize:CGSizeMake(290, 25) lineBreakMode:[lblTemp1 lineBreakMode]];
	

	[lblTemp1 setFrame:CGRectMake(10, 5, expectedSize.width, 25)];
	[lblTemp3 setFrame:CGRectMake(20 + expectedSize.width, 5, 290, 25)];
	
	if ([dictionaryUpdates objectForKey:[entry ID]] != nil) {
		//NSLog(@"%@",[dictionaryUpdates objectForKey:[entry ID]]);
		//cell.contentView.backgroundColor = [UIColor greenColor];
		if ([(NSString *)[dictionaryUpdates objectForKey:[entry ID]] compare:@"Entry Added"] == 0) {
			[lblTemp3 setText:@"NEW"];
			[lblTemp3 setTextColor:[UIColor greenColor]];
		} else {
			[lblTemp3 setText:@"Updated"];
			[lblTemp3 setTextColor:[UIColor orangeColor]];
		}
		//[lblTemp3 setText:[dictionaryUpdates objectForKey:[entry ID]]];
		[lblTemp3 setHidden:NO];
	} else {
		//cell.contentView.backgroundColor = [UIColor whiteColor];
		[lblTemp3 setHidden:YES];
	}
	
	
	return cell;
}

- (UITableViewCell *) getCellContentView:(NSString *)cellIdentifier {
	
	UITableViewCell *cell;
	
	//CGRect CellFrame = CGRectMake(0, 0, 300, 60);
	CGRect Label1Frame = CGRectMake(10, 5, 290, 25);
	CGRect Label2Frame = CGRectMake(10, 28, 290, 25);
	CGRect Label3Frame = CGRectMake(300, 0, 300, 60); 
	UILabel *lblTemp;
	
	cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
	
	//Initialize Label with tag 1.
	lblTemp = [[UILabel alloc] initWithFrame:Label1Frame];
	[lblTemp setBackgroundColor:[UIColor colorWithWhite:0.93 alpha:0.0]];
	lblTemp.tag = 1;
	[cell.contentView addSubview:lblTemp];
	[lblTemp release];
	
	//Initialize Label with tag 2.
	lblTemp = [[UILabel alloc] initWithFrame:Label2Frame];
	[lblTemp setBackgroundColor:[UIColor colorWithWhite:0.93 alpha:0.0]];
	lblTemp.tag = 2;
	lblTemp.font = [UIFont boldSystemFontOfSize:12];
	lblTemp.textColor = [UIColor lightGrayColor];
	[cell.contentView addSubview:lblTemp];
	[lblTemp release];
	
	lblTemp = [[UILabel alloc] initWithFrame:Label3Frame];
	[lblTemp setBackgroundColor:[UIColor colorWithWhite:0.93 alpha:0.0]];
	[lblTemp setHidden:YES];
	lblTemp.tag = 3;
	[lblTemp setTextColor:[UIColor grayColor]];
	[lblTemp setFont:[UIFont italicSystemFontOfSize:15]];
	[cell.contentView addSubview:lblTemp];
	[lblTemp release];
	
	return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *avc;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        CGSize result = [[UIScreen mainScreen] bounds].size;
        if(result.height == 480)
        {
            avc=@"DictionaryEntryViewController";
        }
        if(result.height == 568)
        {
            avc=@"DictionaryEntryViewController-iPhone5";
        }
    }
    
    DictionaryEntryViewController *detailsViewController = [[DictionaryEntryViewController alloc] initWithNibName:avc bundle:[NSBundle mainBundle]];

	/*
	 If the requesting table view is the search display controller's table view, configure the next view controller using the filtered content, otherwise use the main list.
	 */
	DictionaryEntry *entry = nil;
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{
        //---get the letter in the current section---
		NSString *alphabet = [dictionarySearchContentIndex objectAtIndex:[indexPath section]];
		entry = [self readSearchEntryFromDatabase:alphabet row:indexPath.row];
    }
	else
	{
		//DictionarySection *dictSection = ;
		//entry = [dictSection.entries objectAtIndex:indexPath.row];
		//---get the letter in the current section---
		NSString *alphabet = [dictionaryContentIndex objectAtIndex:[indexPath section]];
		entry = [self readEntryFromDatabase:alphabet row:indexPath.row];
    }
	//detailsViewController.title = entry.entryName;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	//[(DictionaryViewController *)[self viewController] dictionaryEntrySelected:entry];
	self.navigationItem.backBarButtonItem =
	[[UIBarButtonItem alloc] initWithTitle:@"Dictionary"
									 style: UIBarButtonItemStyleBordered
									target:nil
									action:nil];
	
	[detailsViewController setMode:currentMode];
	[detailsViewController setEntry:entry];
	[[self navigationController] pushViewController:detailsViewController animated:YES];
    [detailsViewController release];
}




#pragma mark -
#pragma mark Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
	
	//[self.filteredDictionaryContent removeAllObjects]; // First clear the filtered array.
	
	/*
	 Search the main list for products whose type matches the scope (if selected) and whose name matches searchText; add items that match to the filtered array.
	 */
	self.searchDisplayController.searchResultsTableView.rowHeight = 60;
	[self setSearch_term:searchText];
	[self readSearchEntriesFromDatabase];
}

//---set the index for the table---
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (tableView == self.searchDisplayController.searchResultsTableView)
	{
		return dictionarySearchContentIndexMod;
	} else {
		
		return dictionaryContentIndexMod;
	}
}


#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:
	 [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:
	 [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (void)loadData {
	// Data preloaded in sqlite database;
	// need to load it into memory
	//
	databaseName = @"database.sqlite";
	
	NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir = [documentPaths objectAtIndex:0];
	[self setDatabasePath:[documentsDir stringByAppendingPathComponent:databaseName]];	
	// Execute the "checkAndCreateDatabase" function
	
	if(sqlite3_open([databasePath UTF8String], &database) != SQLITE_OK) {
		NSLog(@"Error 646");
	}
	
	//Pull out whats changed since last version
	
	if (dictionaryUpdates != nil) {
		[dictionaryUpdates release];
		dictionaryUpdates = nil;
	}
	
	dictionaryUpdates = [[NSMutableDictionary alloc] init];
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSString *dictionary_preupdate_version = [prefs stringForKey:@"database_pre-update_version"];
	
	NSString *queryString = [NSString stringWithFormat:@"select id, min(version), MIN(description) from changelog where version > %@ GROUP BY id ORDER by version", dictionary_preupdate_version];
	//NSLog(@"%@", queryString);
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryString UTF8String], -1, &compiledStatement, NULL);
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			NSString *aID;
			NSString *aVersion;
			NSString *aDescription;
			
			if(sqlite3_column_text(compiledStatement, 0) != NULL) {
				aID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			} else {
				aID = @"";
			}
			if(sqlite3_column_text(compiledStatement, 1) != NULL) {
				aVersion = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			} else {
				aVersion = @"";
			}
			if(sqlite3_column_text(compiledStatement, 2) != NULL) {
				aDescription = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 2)];
			} else {
				aDescription = @"";
			}
			
			//NSLog(@"id: %@  ver: %@  desc: %@",aID,aVersion,aDescription);
			[dictionaryUpdates setObject:aDescription forKey:aID];
			
		}
		
	}
	//NSLog(@"%@",dictionaryUpdates);
}


- (DictionaryEntry *) searchEntryFromDatabase:(NSString *)search row:(int)row {
	// Setup the database object
	DictionaryEntry *entry = nil;
	
	search = [self convertStringToDatabase:search];
	
	// Setup the SQL Statement and compile it for faster access
	NSString *queryString = [NSString stringWithFormat:[self querySearch],search,row];
	//const char *sqlStatement = "SELECT * FROM entries";
	//NSLog(@"Search Query: %@",queryString);
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryString UTF8String], -1, &compiledStatement, NULL);
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			NSString *aID;
			NSString *aNavi;
			NSString *aNavi_no_specials;
			NSString *aIpa;
			NSString *aInfixes;
			NSString *aEnglish_definition;
			NSString *aPart_of_speech;
			NSString *aFancy_type;
			NSString *aAlpha;
			NSString *aBeta;
			int aVersion;
			
			if(sqlite3_column_text(compiledStatement, 0) != NULL) {
				aID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			} else {
				aID = @"";
			}
			if(sqlite3_column_text(compiledStatement, 1) != NULL) {
				aNavi = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			} else {
				aNavi = @"";
			}
			if(sqlite3_column_text(compiledStatement, 2) != NULL) {
				aNavi_no_specials = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 2)];
			} else {
				aNavi_no_specials = @"";
			}
			if(sqlite3_column_text(compiledStatement, 3) != NULL) {
				aIpa = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
			} else {
				aIpa = @"";
			}
			if(sqlite3_column_text(compiledStatement, 4) != NULL) {
				aInfixes = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
			} else {
				aInfixes = @"";
			}
			if(sqlite3_column_text(compiledStatement, 5) != NULL) {
				aEnglish_definition = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 5)];
			} else {
				aEnglish_definition = @"";
			}
			if(sqlite3_column_text(compiledStatement, 6) != NULL) {
				aPart_of_speech = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 6)];
			} else {
				aPart_of_speech = @"";
			}
			if(sqlite3_column_text(compiledStatement, 7) != NULL) {
				aFancy_type = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 7)];
			} else {
				aFancy_type = @"";
			}
			if(sqlite3_column_text(compiledStatement, 8) != NULL) {
				aAlpha = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 8)];
			} else {
				aAlpha = @"";
			}
			if(sqlite3_column_text(compiledStatement, 9) != NULL) {
				aBeta = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 9)];
			} else {
				aBeta = @"";
			}			//NSString *aFancy_type = @"";
			if(sqlite3_column_text(compiledStatement, 10) != NULL) {
				aVersion = (int)sqlite3_column_text(compiledStatement, 9);
			} else {
				aVersion = 0;
			}
			
			// Create a new animal object with the data from the database
			entry = [DictionaryEntry entryWithID:aID navi:aNavi navi_no_specials:aNavi_no_specials english_definition:aEnglish_definition infixes:aInfixes part_of_speech:aPart_of_speech ipa:aIpa andFancyType:aFancy_type alpha:aAlpha beta:aBeta version:aVersion];
		}
	} else {
		NSLog(@"Error 604");
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	return entry;
}

- (DictionaryEntry *) readEntryFromDatabase:(NSString *)alpha row:(int)row {
	// Setup the database object
	DictionaryEntry *entry = nil;
					
	// Setup the SQL Statement and compile it for faster access
	NSString *queryString = [NSString stringWithFormat:[self query],alpha,row];
	//NSLog(@"Query: %@",queryString);
	//const char *sqlStatement = "SELECT * FROM entries";
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryString UTF8String], -1, &compiledStatement, NULL);
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			
			NSString *aID;
			NSString *aNavi;
			NSString *aNavi_no_specials;
			NSString *aIpa;
			NSString *aInfixes;
			NSString *aEnglish_definition;
			NSString *aPart_of_speech;
			NSString *aFancy_type;
			NSString *aAlpha;
			NSString *aBeta;
			int aVersion;
			
			if(sqlite3_column_text(compiledStatement, 0) != NULL) {
				aID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			} else {
				aID = @"";
			}
			if(sqlite3_column_text(compiledStatement, 1) != NULL) {
				aNavi = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			} else {
				aNavi = @"";
			}
			if(sqlite3_column_text(compiledStatement, 2) != NULL) {
				aNavi_no_specials = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 2)];
			} else {
				aNavi_no_specials = @"";
			}
			if(sqlite3_column_text(compiledStatement, 3) != NULL) {
				aIpa = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
			} else {
				aIpa = @"";
			}
			if(sqlite3_column_text(compiledStatement, 4) != NULL) {
				aInfixes = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
			} else {
				aInfixes = @"";
			}
			if(sqlite3_column_text(compiledStatement, 5) != NULL) {
				aEnglish_definition = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 5)];
			} else {
				aEnglish_definition = @"";
			}
			if(sqlite3_column_text(compiledStatement, 6) != NULL) {
				aPart_of_speech = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 6)];
			} else {
				aPart_of_speech = @"";
			}
			if(sqlite3_column_text(compiledStatement, 7) != NULL) {
				aFancy_type = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 7)];
			} else {
				aFancy_type = @"";
			}
			if(sqlite3_column_text(compiledStatement, 8) != NULL) {
				aAlpha = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 8)];
			} else {
				aAlpha = @"";
			}
			if(sqlite3_column_text(compiledStatement, 9) != NULL) {
				aBeta = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 9)];
			} else {
				aBeta = @"";
			}			//NSString *aFancy_type = @"";
			
			if(sqlite3_column_text(compiledStatement, 10) != NULL) {
				aVersion = (int)sqlite3_column_text(compiledStatement, 9);
			} else {
				aVersion = 0;
			}
			
			// Create a new animal object with the data from the database
			entry = [DictionaryEntry entryWithID:aID navi:aNavi navi_no_specials:aNavi_no_specials english_definition:aEnglish_definition infixes:aInfixes part_of_speech:aPart_of_speech ipa:aIpa andFancyType:aFancy_type alpha:aAlpha beta:aBeta version:aVersion];
		}
	} else {
		NSLog(@"Error 639: %@", queryString);
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
		
	//NSLog(@"Query: %@", queryString);
	return entry;
	
}

- (DictionaryEntry *) readSearchEntryFromDatabase:(NSString *)alpha row:(int)row {
	// Setup the database object
	DictionaryEntry *entry = nil;
	
	// Setup the SQL Statement and compile it for faster access
	NSString *queryString = [NSString stringWithFormat:[self querySearch],alpha,[self search_term],row];
	//NSLog(@"Query: %@",queryString);
	//const char *sqlStatement = "SELECT * FROM entries";
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryString UTF8String], -1, &compiledStatement, NULL);
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			NSString *aID;
			NSString *aNavi;
			NSString *aNavi_no_specials;
			NSString *aIpa;
			NSString *aInfixes;
			NSString *aEnglish_definition;
			NSString *aPart_of_speech;
			NSString *aFancy_type;
			NSString *aAlpha;
			NSString *aBeta;
			int aVersion;
			
			if(sqlite3_column_text(compiledStatement, 0) != NULL) {
				aID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			} else {
				aID = @"";
			}
			if(sqlite3_column_text(compiledStatement, 1) != NULL) {
				aNavi = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			} else {
				aNavi = @"";
			}
			if(sqlite3_column_text(compiledStatement, 2) != NULL) {
				aNavi_no_specials = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 2)];
			} else {
				aNavi_no_specials = @"";
			}
			if(sqlite3_column_text(compiledStatement, 3) != NULL) {
				aIpa = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
			} else {
				aIpa = @"";
			}
			if(sqlite3_column_text(compiledStatement, 4) != NULL) {
				aInfixes = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
			} else {
				aInfixes = @"";
			}
			if(sqlite3_column_text(compiledStatement, 5) != NULL) {
				aEnglish_definition = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 5)];
			} else {
				aEnglish_definition = @"";
			}
			if(sqlite3_column_text(compiledStatement, 6) != NULL) {
				aPart_of_speech = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 6)];
			} else {
				aPart_of_speech = @"";
			}
			if(sqlite3_column_text(compiledStatement, 7) != NULL) {
				aFancy_type = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 7)];
			} else {
				aFancy_type = @"";
			}
			if(sqlite3_column_text(compiledStatement, 8) != NULL) {
				aAlpha = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 8)];
			} else {
				aAlpha = @"";
			}
			if(sqlite3_column_text(compiledStatement, 9) != NULL) {
				aBeta = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 9)];
			} else {
				aBeta = @"";
			}			//NSString *aFancy_type = @"";
			if(sqlite3_column_text(compiledStatement, 10) != NULL) {
				aVersion = (int)sqlite3_column_text(compiledStatement, 9);
			} else {
				aVersion = 0;
			}
			
			// Create a new animal object with the data from the database
			entry = [DictionaryEntry entryWithID:aID navi:aNavi navi_no_specials:aNavi_no_specials english_definition:aEnglish_definition infixes:aInfixes part_of_speech:aPart_of_speech ipa:aIpa andFancyType:aFancy_type alpha:aAlpha beta:aBeta version:aVersion];
			
		}
	} else {
		NSLog(@"Error 629: %@", queryString);
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	
	return entry;
}

-(void) readEntriesFromDatabase {
	// Setup the database object
	
	if(databasePath == nil){
		[self loadData];
	}
	
	// Init the animals Array
	indexCounts = [[NSMutableDictionary alloc] init];
	
    // Open the database from the users filessytem
	NSMutableArray *contentIndex = [[NSMutableArray alloc] init];
	NSMutableArray *contentIndexMod = [[NSMutableArray alloc] init]; 
	
	//const char *sqlStatement = "SELECT * FROM entries";
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryIndex UTF8String], -1, &compiledStatement, NULL);
	
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			NSString *aAlpha = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			NSString *aCount = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			//NSString *aFancy_type = @"";
			
			NSMutableString *alpha = [aAlpha copy];
			if(currentMode){
				aAlpha = [self convertStringFromDatabase:aAlpha];
			}
			// Create a new animal object with the data from the database
			NSNumber *aNumber = [NSNumber numberWithInt:[aCount intValue]];
			[indexCounts setObject:aNumber forKey:alpha];
			//NSLog(@"Query: %@", queryIndex);
			//NSLog(@"Alpha: %@ Num: %@",aAlpha, aNumber);
			
			[contentIndex addObject:alpha];
			[contentIndexMod addObject:aAlpha];
			
		}
	} else {
		NSLog(@"Error 701: %@ %@ %d", databasePath, queryIndex, sqlResult);
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	
	dictionaryContentIndex = contentIndex;
	dictionaryContentIndexMod = contentIndexMod;
}

-(void) readSearchEntriesFromDatabase {
	// Setup the database object
	
	if(databasePath == nil){
		[self loadData];
	}
	
	// Init the animals Array
	indexSearchCounts = [[NSMutableDictionary alloc] init];
	// Open the database from the users filessytem
	
	NSString *queryString = [NSString stringWithFormat:[self querySearchIndex], [self search_term]];
	
	NSMutableArray *contentIndex = [[NSMutableArray alloc] init];
	NSMutableArray *contentIndexMod = [[NSMutableArray alloc] init]; 
	//NSLog(@"QueryString: %@", queryString);
	//const char *sqlStatement = "SELECT * FROM entries";
	sqlite3_stmt *compiledStatement;
	int sqlResult = sqlite3_prepare_v2(database, [queryString UTF8String], -1, &compiledStatement, NULL);
	
	if(sqlResult == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			NSString *aAlpha = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
			NSString *aCount = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
			//NSString *aFancy_type = @"";
			
			NSMutableString *alpha = [aAlpha copy];
			if(currentMode){
				aAlpha = [self convertStringFromDatabase:aAlpha];
			}
			// Create a new animal object with the data from the database
			NSNumber *aNumber = [NSNumber numberWithInt:[aCount intValue]];
			[indexSearchCounts setObject:aNumber forKey:alpha];
			//NSLog(@"Query: %@", queryIndex);
			//NSLog(@"Alpha: %@ Num: %@",aAlpha, aNumber);
			
           // DictionaryEntry *entry = [self readSearchEntryFromDatabase]
            
            //[content addObject:alpha];
			[contentIndex addObject:alpha];
			[contentIndexMod addObject:aAlpha];
			
		}
	} else {
		NSLog(@"Error 701: %@ %@", databasePath, queryIndex);
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	
	dictionarySearchContentIndex = contentIndex;
	dictionarySearchContentIndexMod = contentIndexMod;
    //dictionarySearchContent =
}


-(NSString *)convertStringFromDatabase:(NSString *)string {
	
	NSMutableString *aAlpha = [string mutableCopy];
	[aAlpha replaceOccurrencesOfString:@"b" withString:@"ä" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"B" withString:@"Ä" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"j" withString:@"ì" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"J" withString:@"Ì" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	
	return aAlpha;
}

-(NSString *)convertStringToDatabase:(NSString *)string {
	
	NSMutableString *aAlpha = [string mutableCopy];
	[aAlpha replaceOccurrencesOfString:@"ä" withString:@"b" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"Ä" withString:@"B" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"ì" withString:@"j" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	[aAlpha replaceOccurrencesOfString:@"Ì" withString:@"J" options:NSLiteralSearch range:NSMakeRange(0, [aAlpha length])];
	
	return aAlpha;
}

- (void)dealloc {
	sqlite3_close(database);
	[dictionaryContent dealloc];
	 
    [super dealloc];
}

-(void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    NSLog(@"search bar editing begins");
}

-(void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    NSLog(@"search bar editing ends");
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    NSLog(@"search bar editing cancelled");
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    NSLog(@"search begins");
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
    NSLog(@"search ends");
}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller {
    NSLog(@"search began");
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    NSLog(@"search ended");
}


@end


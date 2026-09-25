/**
 * @copyright 2026 Muhammad Hassan
 * @discussion Dual-licensed under the GNU General Public License and the MIT License.
 * See LICENSE.md.
 */

#import "TTMDocumentToolbar.h"
#import "TTMDocument.h"

static NSToolbarIdentifier const TTMDocumentToolbarIdentifier = @"TTMDocumentToolbar";

static NSToolbarItemIdentifier const TTMToolbarCompleteItem = @"TTMToolbarCompleteItem";
static NSToolbarItemIdentifier const TTMToolbarPriorityItem = @"TTMToolbarPriorityItem";
static NSToolbarItemIdentifier const TTMToolbarDatesItem = @"TTMToolbarDatesItem";
static NSToolbarItemIdentifier const TTMToolbarArchiveItem = @"TTMToolbarArchiveItem";
static NSToolbarItemIdentifier const TTMToolbarDeleteItem = @"TTMToolbarDeleteItem";
static NSToolbarItemIdentifier const TTMToolbarSortItem = @"TTMToolbarSortItem";
static NSToolbarItemIdentifier const TTMToolbarFilterItem = @"TTMToolbarFilterItem";
static NSToolbarItemIdentifier const TTMToolbarSearchItem = @"TTMToolbarSearchItem";

@interface TTMDocumentToolbar ()

@property (nonatomic, weak) TTMDocument *document;
@property (nonatomic, readwrite) NSToolbar *toolbar;
@property (nonatomic, weak) NSMenuToolbarItem *filterItem;

@end

@implementation TTMDocumentToolbar

- (instancetype)initWithDocument:(TTMDocument*)document {
    self = [super init];
    if (self) {
        _document = document;
        _toolbar = [[NSToolbar alloc] initWithIdentifier:TTMDocumentToolbarIdentifier];
        _toolbar.delegate = self;
        _toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        _toolbar.allowsUserCustomization = YES;
        _toolbar.autosavesConfiguration = YES;
    }
    return self;
}

- (void)update {
    BOOL filtered = (self.document.activeFilterPredicateNumber != 0);
    self.filterItem.image = [self symbol:(filtered ? @"line.3.horizontal.decrease.circle.fill"
                                                   : @"line.3.horizontal.decrease.circle")
                             description:@"Filter"];
}

#pragma mark - NSToolbarDelegate Methods

- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return @[TTMToolbarCompleteItem, TTMToolbarPriorityItem, TTMToolbarDatesItem,
             NSToolbarFlexibleSpaceItemIdentifier,
             TTMToolbarSortItem, TTMToolbarFilterItem, TTMToolbarSearchItem];
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[TTMToolbarCompleteItem, TTMToolbarPriorityItem, TTMToolbarDatesItem,
             TTMToolbarArchiveItem, TTMToolbarDeleteItem,
             TTMToolbarSortItem, TTMToolbarFilterItem, TTMToolbarSearchItem,
             NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier];
}

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
    itemForItemIdentifier:(NSToolbarItemIdentifier)identifier
willBeInsertedIntoToolbar:(BOOL)flag {
    if ([identifier isEqualToString:TTMToolbarCompleteItem]) {
        return [self buttonItem:identifier label:@"Complete" paletteLabel:@"Toggle Completion"
                         symbol:@"checkmark.circle" action:@selector(toggleTaskCompletion:)];
    }
    if ([identifier isEqualToString:TTMToolbarArchiveItem]) {
        return [self buttonItem:identifier label:@"Archive" paletteLabel:@"Archive Completed Tasks"
                         symbol:@"archivebox" action:@selector(archiveCompletedTasks:)];
    }
    if ([identifier isEqualToString:TTMToolbarDeleteItem]) {
        return [self buttonItem:identifier label:@"Delete" paletteLabel:@"Delete Tasks"
                         symbol:@"trash" action:@selector(deleteSelectedTasks:)];
    }
    if ([identifier isEqualToString:TTMToolbarPriorityItem]) {
        NSMenu *menu = [self menuWithItemsForActions:@[@"setPriority:", @"increasePriority:",
                                                       @"decreasePriority:", @"",
                                                       @"removePriority:"]];
        return [self menuItem:identifier label:@"Priority" symbol:@"exclamationmark.circle" menu:menu];
    }
    if ([identifier isEqualToString:TTMToolbarDatesItem]) {
        NSMenu *menu = [self menuWithItemsForActions:@[@"setDueDate:", @"postpone:",
                                                       @"increaseDueDateByOneDay:",
                                                       @"decreaseDueDateByOneDay:",
                                                       @"removeDueDate:", @"",
                                                       @"setThresholdDate:",
                                                       @"increaseThresholdDateByOneDay:",
                                                       @"decreaseThresholdDateByOneDay:",
                                                       @"removeThresholdDate:"]];
        return [self menuItem:identifier label:@"Dates" symbol:@"calendar" menu:menu];
    }
    if ([identifier isEqualToString:TTMToolbarSortItem]) {
        NSMenu *menu = [[[NSApp mainMenu] itemWithTag:SORTMENUTAG].submenu copy];
        return [self menuItem:identifier label:@"Sort" symbol:@"arrow.up.arrow.down" menu:menu];
    }
    if ([identifier isEqualToString:TTMToolbarFilterItem]) {
        NSMenu *menu = [[[NSApp mainMenu] itemWithTag:FILTERMENUTAG].submenu copy];
        NSMenuToolbarItem *item = [self menuItem:identifier label:@"Filter"
                                          symbol:@"line.3.horizontal.decrease.circle" menu:menu];
        self.filterItem = item;
        [self update];
        return item;
    }
    if ([identifier isEqualToString:TTMToolbarSearchItem]) {
        NSSearchToolbarItem *item = [[NSSearchToolbarItem alloc] initWithItemIdentifier:identifier];
        item.searchField = self.document.searchField;
        item.label = @"Search";
        return item;
    }
    return nil;
}

#pragma mark - Item Factory Methods

- (NSImage*)symbol:(NSString*)name description:(NSString*)description {
    return [NSImage imageWithSystemSymbolName:name accessibilityDescription:description];
}

- (NSToolbarItem*)buttonItem:(NSToolbarItemIdentifier)identifier
                       label:(NSString*)label
                paletteLabel:(NSString*)paletteLabel
                      symbol:(NSString*)symbol
                      action:(SEL)action {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.label = label;
    item.paletteLabel = paletteLabel;
    item.toolTip = paletteLabel;
    item.image = [self symbol:symbol description:paletteLabel];
    item.bordered = YES;
    // No target, so the action goes up the responder chain to the document.
    item.action = action;
    return item;
}

- (NSMenuToolbarItem*)menuItem:(NSToolbarItemIdentifier)identifier
                         label:(NSString*)label
                        symbol:(NSString*)symbol
                          menu:(NSMenu*)menu {
    NSMenuToolbarItem *item = [[NSMenuToolbarItem alloc] initWithItemIdentifier:identifier];
    item.label = label;
    item.paletteLabel = label;
    item.toolTip = label;
    item.image = [self symbol:symbol description:label];
    item.menu = menu;
    return item;
}

// Builds a menu from copies of the main menu items with the given actions.
// An empty string adds a separator.
- (NSMenu*)menuWithItemsForActions:(NSArray<NSString*>*)actionNames {
    NSMenu *menu = [[NSMenu alloc] init];
    for (NSString *actionName in actionNames) {
        if (actionName.length == 0) {
            [menu addItem:[NSMenuItem separatorItem]];
            continue;
        }
        NSMenuItem *item = [self mainMenuItemWithAction:NSSelectorFromString(actionName)
                                                 inMenu:[NSApp mainMenu]];
        if (item) {
            [menu addItem:[item copy]];
        }
    }
    return menu;
}

- (NSMenuItem*)mainMenuItemWithAction:(SEL)action inMenu:(NSMenu*)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == action && !item.isAlternate) {
            return item;
        }
        if (item.submenu) {
            NSMenuItem *found = [self mainMenuItemWithAction:action inMenu:item.submenu];
            if (found) {
                return found;
            }
        }
    }
    return nil;
}

@end

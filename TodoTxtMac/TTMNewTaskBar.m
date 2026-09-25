/**
 * @copyright 2026 Muhammad Hassan
 * @discussion Dual-licensed under the GNU General Public License and the MIT License.
 * See LICENSE.md.
 */

#import "TTMNewTaskBar.h"
#import "TTMDocument.h"
#import "TTMTableView.h"

// Height of the glass capsules, and their distance from the window edges.
static const CGFloat TTMGlassBarHeight = 36.0;
static const CGFloat TTMGlassBarMargin = 12.0;

static void *TTMContentLayoutRectContext = &TTMContentLayoutRectContext;

@interface TTMNewTaskBar ()

@property (nonatomic, weak) TTMDocument *document;
@property (nonatomic, weak) NSWindow *window;
@property (nonatomic, weak) NSScrollView *scrollView;
@property (nonatomic, strong) NSView *barView;
@property (nonatomic, strong) NSView *badgeView;
@property (nonatomic, strong) NSButton *badgeButton;
@property (nonatomic) BOOL observingWindow;

@end

@implementation TTMNewTaskBar

- (instancetype)initWithDocument:(TTMDocument*)document {
    self = [super init];
    if (self) {
        _document = document;
    }
    return self;
}

- (void)dealloc {
    [self stopObservingWindow];
}

- (void)installInWindow:(NSWindow*)window {
    self.window = window;
    self.scrollView = self.document.tableView.enclosingScrollView;
    self.badgeButton = [self makeBadgeButton];
    BOOL wantsFloatingBar = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFloatingNewTaskBar"];
    if (@available(macOS 26.0, *)) {
        if (wantsFloatingBar) {
            [self installFloatingGlassBar];
        } else {
            [self installDockedBar];
        }
    } else {
        [self installDockedBar];
    }
    [self update];
}

- (void)update {
    NSUInteger preset = self.document.activeFilterPredicateNumber;
    self.badgeButton.title = [NSString stringWithFormat:@"Filter %lu", (unsigned long)preset];
    self.badgeView.hidden = (preset == 0);
}

#pragma mark - Liquid Glass Bar (macOS 26)

- (void)installFloatingGlassBar API_AVAILABLE(macos(26.0)) {
    NSTextField *textField = self.document.textField;
    textField.bezeled = NO;
    textField.bordered = NO;
    textField.drawsBackground = NO;
    textField.focusRingType = NSFocusRingTypeNone;

    NSGlassEffectView *entryGlass = [self glassWrapping:[self entryViewWithTextField:textField]];
    NSGlassEffectView *badgeGlass = [self glassWrapping:[self padded:self.badgeButton
                                                         horizontally:12.0]];
    self.badgeView = badgeGlass;

    NSStackView *row = [NSStackView stackViewWithViews:@[entryGlass, badgeGlass]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8.0;
    row.detachesHiddenViews = YES;
    [entryGlass setContentHuggingPriority:NSLayoutPriorityDefaultLow
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
    [entryGlass.heightAnchor constraintEqualToConstant:TTMGlassBarHeight].active = YES;
    [badgeGlass.heightAnchor constraintEqualToConstant:TTMGlassBarHeight].active = YES;

    // Both capsules share one container so they sample the same background.
    NSGlassEffectContainerView *container = [[NSGlassEffectContainerView alloc] init];
    container.contentView = row;
    [self pinEdgesOf:row toView:container];
    self.barView = container;

    // The bar floats over the bottom of the task list; the list scrolls underneath it.
    NSView *listContainer = self.scrollView.superview;
    NSView *contentView = self.window.contentView;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor
                                                constant:TTMGlassBarMargin],
        [container.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor
                                                 constant:-TTMGlassBarMargin],
        [container.bottomAnchor constraintEqualToAnchor:listContainer.bottomAnchor
                                               constant:-TTMGlassBarMargin],
        [container.heightAnchor constraintEqualToConstant:TTMGlassBarHeight],
    ]];

    // Automatic insets only cover the title bar, so manage both insets while the list scrolls
    // under the bar: the title bar at the top and the floating bar at the bottom.
    self.scrollView.automaticallyAdjustsContentInsets = NO;
    [self.window addObserver:self
                  forKeyPath:@"contentLayoutRect"
                     options:NSKeyValueObservingOptionInitial
                     context:TTMContentLayoutRectContext];
    self.observingWindow = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:self.window];
}

- (NSGlassEffectView*)glassWrapping:(NSView*)view API_AVAILABLE(macos(26.0)) {
    NSGlassEffectView *glass = [[NSGlassEffectView alloc] init];
    glass.cornerRadius = TTMGlassBarHeight / 2.0;
    glass.contentView = view;
    [self pinEdgesOf:view toView:glass];
    return glass;
}

- (void)updateScrollViewInsets {
    NSView *contentView = self.window.contentView;
    CGFloat titlebarHeight = NSHeight(contentView.bounds) - NSMaxY(self.window.contentLayoutRect);
    CGFloat barSpace = TTMGlassBarHeight + (2.0 * TTMGlassBarMargin);
    self.scrollView.contentInsets = NSEdgeInsetsMake(MAX(titlebarHeight, 0.0), 0.0, barSpace, 0.0);
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
    if (context == TTMContentLayoutRectContext) {
        [self updateScrollViewInsets];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)windowWillClose:(NSNotification*)notification {
    [self stopObservingWindow];
}

- (void)stopObservingWindow {
    if (!self.observingWindow) {
        return;
    }
    [self.window removeObserver:self forKeyPath:@"contentLayoutRect" context:TTMContentLayoutRectContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowWillCloseNotification
                                                  object:self.window];
    self.observingWindow = NO;
}

#pragma mark - Docked Bar (macOS 11-15)

- (void)installDockedBar {
    NSTextField *textField = self.document.textField;
    textField.bezeled = YES;
    textField.bezelStyle = NSTextFieldRoundedBezel;

    self.badgeButton.bezelStyle = NSBezelStyleInline;
    self.badgeButton.bordered = YES;
    self.badgeView = self.badgeButton;

    NSStackView *row = [NSStackView stackViewWithViews:@[textField, self.badgeButton]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8.0;
    row.detachesHiddenViews = YES;
    row.edgeInsets = NSEdgeInsetsMake(8.0, 10.0, 8.0, 10.0);
    [textField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                          forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSBox *separator = [[NSBox alloc] init];
    separator.boxType = NSBoxSeparator;

    NSStackView *bar = [NSStackView stackViewWithViews:@[separator, row]];
    bar.orientation = NSUserInterfaceLayoutOrientationVertical;
    bar.spacing = 0.0;
    [separator.widthAnchor constraintEqualToAnchor:bar.widthAnchor].active = YES;
    [row.widthAnchor constraintEqualToAnchor:bar.widthAnchor].active = YES;
    self.barView = bar;

    // The bar docks below the task list, inside the same vertical stack.
    NSStackView *listContainer = (NSStackView*)self.scrollView.superview;
    listContainer.spacing = 0.0;
    [listContainer addArrangedSubview:bar];
    [bar.widthAnchor constraintEqualToAnchor:listContainer.widthAnchor].active = YES;
}

#pragma mark - Subview Factory Methods

- (NSView*)entryViewWithTextField:(NSTextField*)textField {
    NSImageView *icon = [NSImageView imageViewWithImage:
                         [NSImage imageWithSystemSymbolName:@"plus"
                                   accessibilityDescription:@"New task"]];
    icon.contentTintColor = [NSColor secondaryLabelColor];

    NSStackView *entry = [NSStackView stackViewWithViews:@[icon, textField]];
    entry.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    entry.distribution = NSStackViewDistributionFill;
    entry.alignment = NSLayoutAttributeCenterY;
    entry.spacing = 6.0;
    entry.edgeInsets = NSEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [textField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                          forOrientation:NSLayoutConstraintOrientationHorizontal];
    return entry;
}

- (NSButton*)makeBadgeButton {
    NSImage *removeImage = [NSImage imageWithSystemSymbolName:@"xmark.circle.fill"
                                     accessibilityDescription:@"Remove filter"];
    NSButton *button = [NSButton buttonWithTitle:@"" image:removeImage
                                          target:self.document
                                          action:@selector(filterTaskListUsingTagforPreset:)];
    button.tag = 0; // filter preset 0 means "no filter"
    button.bordered = NO;
    button.imagePosition = NSImageTrailing;
    button.toolTip = @"Remove filter";
    return button;
}

- (NSView*)padded:(NSView*)view horizontally:(CGFloat)padding {
    NSStackView *stack = [NSStackView stackViewWithViews:@[view]];
    stack.edgeInsets = NSEdgeInsetsMake(0.0, padding, 0.0, padding);
    return stack;
}

- (void)pinEdgesOf:(NSView*)view toView:(NSView*)container {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor:container.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
}

@end

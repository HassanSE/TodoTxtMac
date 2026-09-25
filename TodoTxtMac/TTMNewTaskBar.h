/**
 * @copyright 2026 Muhammad Hassan
 * @discussion Dual-licensed under the GNU General Public License and the MIT License.
 * See LICENSE.md.
 */

#import <Cocoa/Cocoa.h>

@class TTMDocument;

/*!
 * @class TTMNewTaskBar
 * @abstract The bar at the bottom of the document window with the new task field and, while a
 * filter preset is active, a badge that removes the filter.
 * @discussion On macOS 26 the bar is a Liquid Glass capsule floating over the task list, which
 * scrolls underneath it. On earlier versions, or when the useFloatingNewTaskBar preference is off,
 * it is a plain bar docked below the task list.
 */
@interface TTMNewTaskBar : NSObject

/*!
 * @method initWithDocument:
 * @abstract Creates the bar for a document. The document's new task text field is moved into it.
 */
- (instancetype)initWithDocument:(TTMDocument*)document;

/*!
 * @method installInWindow:
 * @abstract Adds the bar to the document window, below or over the task list.
 */
- (void)installInWindow:(NSWindow*)window;

/*!
 * @method update
 * @abstract Shows, hides and relabels the filter badge to match the active filter preset.
 */
- (void)update;

@end

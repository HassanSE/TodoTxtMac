/**
 * @copyright 2026 Muhammad Hassan
 * @discussion Dual-licensed under the GNU General Public License and the MIT License.
 * See LICENSE.md.
 */

#import <Cocoa/Cocoa.h>

@class TTMDocument;

/*!
 * @class TTMDocumentToolbar
 * @abstract Builds the document window's toolbar: task commands, the sort and filter menus,
 * and the search field.
 * @discussion Button items send their actions up the responder chain to the document. Menu
 * items are copies of the main menu's items, so their titles, shortcuts and checkmarks match
 * the menu bar. On macOS 26 the system renders the toolbar in Liquid Glass.
 */
@interface TTMDocumentToolbar : NSObject <NSToolbarDelegate>

@property (nonatomic, readonly) NSToolbar *toolbar;

/*!
 * @method initWithDocument:
 * @abstract Creates the toolbar for a document. The document's search field is moved into it.
 */
- (instancetype)initWithDocument:(TTMDocument*)document;

/*!
 * @method update
 * @abstract Reflects document state, such as whether a filter preset is active, in the toolbar.
 */
- (void)update;

@end

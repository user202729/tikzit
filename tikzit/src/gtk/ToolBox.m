/*
 * Copyright 2012  Alex Merry <dev@randomguy3.me.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "ToolBox.h"

#import "Application.h"
#import "Configuration.h"
#import "Tool.h"

static void tool_button_toggled_cb (GtkWidget *widget, ToolBox *toolBox);
static void unretain (gpointer data);

#define TOOL_DATA_KEY  "tikzit-tool"

@implementation ToolBox

- (id) init {
    [self release];
    return nil;
}

- (id) initWithTools:(NSArray*)tools {
    self = [super init];

    if (self) {
        window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
        g_object_ref_sink (window);
        gtk_window_set_title (GTK_WINDOW (window), "Toolbox");
        gtk_window_set_role (GTK_WINDOW (window), "toolbox");
        gtk_window_set_type_hint (
                GTK_WINDOW (window),
                GDK_WINDOW_TYPE_HINT_UTILITY);
        gtk_window_set_default_size (GTK_WINDOW (window), 200, 500);
        gtk_window_set_deletable (GTK_WINDOW (window), FALSE);

        GtkBox *mainLayout = GTK_BOX (gtk_vbox_new (FALSE, 0));
        gtk_widget_show (GTK_WIDGET (mainLayout));
        gtk_container_add (GTK_CONTAINER (window), GTK_WIDGET (mainLayout));

        GtkWidget *toolPalette = gtk_tool_palette_new ();
        gtk_widget_show (toolPalette);
        gtk_container_add (GTK_CONTAINER (mainLayout), toolPalette);

        toolGroup = GTK_TOOL_ITEM_GROUP (gtk_tool_item_group_new ("Tools"));
        g_object_ref_sink (G_OBJECT (toolGroup));
        gtk_tool_item_group_set_label_widget (
                toolGroup,
                NULL);
        gtk_container_add (GTK_CONTAINER (toolPalette), GTK_WIDGET (toolGroup));
        gtk_widget_show (GTK_WIDGET (toolGroup));

        GSList *item_group = NULL;
        for (id<Tool> tool in tools) {
            NSString *tooltip = [NSString stringWithFormat:
                @"%@: %@ (%@)",
                [tool name], [tool helpText], [tool shortcut]];
            GtkToolItem *item = gtk_radio_tool_button_new_from_stock (
                    item_group,
                    [tool stockId]);
            gtk_tool_item_set_tooltip_text (item, [tooltip UTF8String]);
            item_group = gtk_radio_tool_button_get_group (
                    GTK_RADIO_TOOL_BUTTON (item));
            gtk_tool_item_group_insert (
                    toolGroup,
                    item,
                    -1);
            gtk_widget_show (GTK_WIDGET (item));
            g_object_set_data_full (
                    G_OBJECT(item),
                    TOOL_DATA_KEY,
                    [tool retain],
                    unretain);

            g_signal_connect (item, "toggled",
                              G_CALLBACK (tool_button_toggled_cb),
                              self);
        }

        gtk_widget_show (window);
    }

    return self;
}

- (void) dealloc {
    if (window) {
        g_object_unref (G_OBJECT (toolGroup));
        gtk_widget_destroy (window);
        g_object_unref (G_OBJECT (window));
    }

    [super dealloc];
}

- (id<Tool>) selectedTool {
    guint count = gtk_tool_item_group_get_n_items (toolGroup);
    for (guint i = 0; i < count; ++i) {
        GtkToolItem *item = gtk_tool_item_group_get_nth_item (toolGroup, i);
        if (gtk_toggle_tool_button_get_active (GTK_TOGGLE_TOOL_BUTTON (item))) {
            return (id)g_object_get_data (G_OBJECT (item), TOOL_DATA_KEY);
        }
    }
    return nil;
}

- (void) setSelectedTool:(id<Tool>)tool {
    guint count = gtk_tool_item_group_get_n_items (toolGroup);
    for (guint i = 0; i < count; ++i) {
        GtkToolItem *item = gtk_tool_item_group_get_nth_item (toolGroup, i);
        id<Tool> data = (id)g_object_get_data (G_OBJECT (item), TOOL_DATA_KEY);
        if (data == tool) {
            gtk_toggle_tool_button_set_active (
                    GTK_TOGGLE_TOOL_BUTTON (item),
                    TRUE);
            return;
        }
    }
}

- (void) loadConfiguration:(Configuration*)config {
}

- (void) saveConfiguration:(Configuration*)config {
}

@end

static void tool_button_toggled_cb (GtkWidget *widget, ToolBox *toolBox) {
    if (gtk_toggle_tool_button_get_active (GTK_TOGGLE_TOOL_BUTTON (widget))) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        id<Tool> tool = (id)g_object_get_data (G_OBJECT(widget), TOOL_DATA_KEY);
        [app setActiveTool:tool];
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObject:tool
                          forKey:@"tool"];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ToolSelectionChanged"
                          object:toolBox
                        userInfo:userInfo];

        [pool drain];
    }
}

static void unretain (gpointer data) {
    id obj = (id)data;
    [obj release];
}

// vim:ft=objc:ts=8:et:sts=4:sw=4

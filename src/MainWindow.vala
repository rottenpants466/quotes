/*
* Copyright (c) 2017 APP Developers (http://github.com/alons45/quotes)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Author <alons45@gmail.com>
*/

using Quotes.Configs;
using Quotes.Widgets;
using Quotes.Utils;


namespace Quotes {

	public class MainWindow : Gtk.ApplicationWindow {
		protected bool searching = false;

		protected Toolbar toolbar;
		protected QuoteClient quote_client;

		// Containers
		protected Gtk.Box quote_box;
		protected Gtk.Stack quote_stack;

		// Widgets
		protected Gtk.Label quote_text;
		protected Gtk.Label quote_author;
		protected Gtk.LinkButton quote_url;
		protected Gtk.Spinner spinner;
		protected Gtk.Clipboard clipboard;

		// Gdk
		protected Gdk.Display display;

		// Signals
		public signal void search_begin ();
		public signal void search_end (Json.Object? url, Error? e);

		public MainWindow (Application application) {
			Object (
				application: application,
				title: Properties.TITLE_HEADER_BAR,
				default_width: 800,
				default_height: 600
			);

			this.set_border_width (12);
			this.set_position (Gtk.WindowPosition.CENTER);

			this.quote_client = new QuoteClient (this);

			this.connect_signals ();
			this.initialize_gdk_vars ();
			this.initialize_gtk_vars ();

			// Initialize toolbar
			this.toolbar = new Toolbar ();
			this.set_titlebar (this.toolbar);
			this.button_events ();
			this.share_button_events ();

			this.complete_grid ();

			this.style_provider ();

			this.show_all ();

			this.quote_client.quote_query.begin ();
		}

		protected void on_search_begin () {
			this.toolbar.refresh_tool_button.sensitive = false;
			this.toolbar.copy_to_clipboard_button.sensitive = false;

			if (!this.quote_stack.visible) {
				this.quote_stack.set_visible (true);
			}
			this.quote_stack.set_visible_child_name ("spinner");
			this.spinner.start ();
			this.searching = true;
		}

		protected void on_search_end (Json.Object? quote, Error? error) {
			this.toolbar.refresh_tool_button.sensitive = true;
			this.toolbar.copy_to_clipboard_button.sensitive = true;
			this.searching = false;

			if (error != null) {
				return;
			}

			// Set quote text
			this.quote_text.set_text (
				"\"" + quote.get_string_member ("quoteText")._chomp () + "\""
			);
			// Set quote author
			if (quote.get_string_member ("quoteAuthor") != "") {
				this.quote_author.set_text (quote.get_string_member ("quoteAuthor"));
			} else {
				this.quote_author.set_text ("Anonymous author");
			}
			// Set quote uri
			this.quote_url.set_uri (quote.get_string_member ("quoteLink"));

			this.quote_stack.set_visible_child_name ("quote_box");
		}
		// End signals

		private void connect_signals () {
			this.search_begin.connect (this.on_search_begin);
			this.search_end.connect (this.on_search_end);
		}

		public void button_events () {
			this.toolbar.refresh_tool_button.clicked.connect ( () => {
				this.quote_client.quote_query.begin();
			});

			this.toolbar.copy_to_clipboard_button.clicked.connect ( () => {
				this.clipboard.set_text (this.complete_quote (), -1);
			});

			this.toolbar.share_button.clicked.connect ( () => {
				this.toolbar.popover.set_visible (true);
			});
		}

		// TODO: Se me ocurre que puedo separar estos metodos en el fichero de Toobar.vala
		// haciendo que reciban solo el parametro de la url y el string del quote y demás
		public void share_button_event (string url) {
		    try {
		        AppInfo.launch_default_for_uri (url.printf (this.complete_quote ()), null);
		    } catch (Error e) {
		        warning ("%s", e.message);
		    }
		    this.toolbar.popover.hide ();
		}

		public void share_button_events () {
			this.toolbar.facebook_button.clicked.connect (() => {
				try {
					AppInfo.launch_default_for_uri (
						"https://www.facebook.com/dialog/share?app_id=145634995501895&dialog=popup&redirect_uri=https://facebook.com&href=%s&quote=%s".printf(
							this.quote_url.get_uri(), this.complete_quote()
						),
						null
					);
				} catch (Error e) {
					warning ("%s", e.message);
				}
				this.toolbar.popover.hide ();
			});

			this.toolbar.twitter_button.clicked.connect (() => {
				this.share_button_event ("http://twitter.com/home/?status=%s");
			});

			this.toolbar.google_button.clicked.connect (() => {
				this.share_button_event ("https://plus.google.com/share?text=%s");
			});
		}

		private void initialize_gtk_vars () {
			this.quote_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			quote_box.set_spacing (10);

			this.quote_text = new Gtk.Label ("...");
			this.quote_text.set_selectable (true);
			this.quote_text.set_line_wrap (true);
			this.quote_text.set_justify (Gtk.Justification.CENTER);
			this.quote_text.get_style_context ().add_class ("quote-text");

			this.quote_author = new Gtk.Label ("...");
			this.quote_author.set_selectable (true);
			this.quote_author.get_style_context ().add_class ("quote-author");

			this.quote_url = new Gtk.LinkButton.with_label ("", "Link to quote");
			this.quote_url.get_style_context ().add_class ("quote-url");

			this.quote_stack = new Gtk.Stack ();
			this.quote_stack.set_visible (false);

			this.spinner = new Gtk.Spinner ();
			this.spinner.halign = Gtk.Align.CENTER;

			this.clipboard = Gtk.Clipboard.get_for_display (
				display, Gdk.SELECTION_CLIPBOARD
			);
		}

		private void initialize_gdk_vars () {
			this.display = this.get_display ();
		}

		private void complete_grid () {
			// Add widgets to Main Box
			quote_box.pack_start (this.quote_text);
			quote_box.pack_start (this.quote_author);
			quote_box.pack_start (this.quote_url);

			// Add widgets to Stack
			this.quote_stack.add_named (this.spinner, "spinner");
			this.quote_stack.add_named (quote_box, "quote_box");

			// Add widgets to Window
			this.add(quote_stack);
		}

		private void style_provider () {
			Gtk.CssProvider css_provider = new Gtk.CssProvider ();
			css_provider.load_from_resource ("com/github/alonsoenrique/quotes/window.css");
			Gtk.StyleContext.add_provider_for_screen (
				Gdk.Screen.get_default (),
				css_provider,
				Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
			);
		}

		private string complete_quote () {
			string complete_quote = this.quote_text.get_text () + " " +
									this.quote_author.get_text () + " " +
									this.quote_url.get_uri ();

			return complete_quote;
		}

	}

}

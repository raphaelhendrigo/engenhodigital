"""Main Kivy application definition for Engenho Digital."""

from pathlib import Path
from urllib.parse import quote
import webbrowser

from kivy.app import App
from kivy.core.window import Window
from kivy.lang import Builder
from kivy.resources import resource_find

from engdigital import config


class EngenhoDigitalApp(App):
    """Kivy App class for Engenho Digital."""

    def build(self):
        """Configure window properties and build the root widget."""
        self.title = config.APP_NAME

        # Set a neutral dark background.
        Window.clearcolor = (0.05, 0.08, 0.12, 1)

        kv_path = Path(__file__).resolve().parent.parent / "app.kv"
        assets_dir = Path(__file__).resolve().parent.parent / "assets"
        images_dir = Path(__file__).resolve().parent.parent / "assets" / "images"
        store_icon_path = assets_dir / "store" / "icon_512.png"
        icon_path = store_icon_path if store_icon_path.exists() else (images_dir / "icon.png")
        logo_path = images_dir / "logo.png"

        if icon_path.exists():
            self.icon = str(icon_path)
            self.logo_source = str(logo_path if logo_path.exists() else icon_path)
        else:
            # Fallback to bundled Kivy icon to avoid missing file errors.
            self.logo_source = resource_find("data/logo/kivy-icon-512.png") or ""

        self.website_url = config.WEBSITE_URL
        self.whatsapp_url = config.WHATSAPP_URL
        self.email_address = config.EMAIL_ADDRESS
        self.privacy_policy_url = config.PRIVACY_POLICY_URL
        self.support_phone = config.SUPPORT_PHONE

        return Builder.load_file(str(kv_path))

    def go(self, screen_name: str) -> None:
        """Navigate to the selected screen name if it exists."""
        if not self.root:
            return
        if screen_name not in self.root.screen_names:
            return
        self.root.current = screen_name

    def open_url(self, url: str) -> None:
        """Open an URL in the system browser."""
        if not url:
            return
        webbrowser.open(url)

    def open_email(self) -> None:
        """Draft an email using the configured contact address."""
        if not self.email_address:
            return
        subject = quote("Contato - Engenho Digital")
        recipient = quote(self.email_address)
        webbrowser.open(f"mailto:{recipient}?subject={subject}")

    def open_whatsapp(self) -> None:
        """Open WhatsApp chat URL, or fallback to website when unset."""
        if self.whatsapp_url and self.whatsapp_url.startswith("http"):
            webbrowser.open(self.whatsapp_url)
            return
        self.open_url(self.website_url)

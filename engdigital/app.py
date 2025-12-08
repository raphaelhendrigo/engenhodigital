"""Main Kivy application definition for Engenho Digital."""

from pathlib import Path

from kivy.app import App
from kivy.core.window import Window
from kivy.lang import Builder
from kivy.resources import resource_find

# Import screen classes to ensure they are registered before KV loading
from engdigital.screens.contact_screen import ContactScreen
from engdigital.screens.home_screen import HomeScreen
from engdigital.screens.services_screen import ServicesScreen


class EngenhoDigitalApp(App):
    """Kivy App class for Engenho Digital."""

    def build(self):
        """Configure window properties and build the root widget."""
        self.title = "Engenho Digital"

        # Set a neutral dark background
        Window.clearcolor = (0.05, 0.08, 0.12, 1)

        kv_path = Path(__file__).resolve().parent.parent / "app.kv"
        icon_path = Path(__file__).resolve().parent.parent / "assets" / "images" / "logo_placeholder.png"

        if icon_path.exists():
            self.icon = str(icon_path)
            self.logo_source = str(icon_path)
        else:
            # Fallback to bundled Kivy icon to avoid missing file errors
            self.logo_source = resource_find("data/logo/kivy-icon-512.png") or ""

        return Builder.load_file(str(kv_path))

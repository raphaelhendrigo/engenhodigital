"""Contact screen for Engenho Digital app."""

import webbrowser
from urllib.parse import quote

from kivy.properties import StringProperty
from kivy.uix.screenmanager import Screen


class ContactScreen(Screen):
    """Contact options for Engenho Digital."""

    website_url = StringProperty("https://www.engenhodigitalweb.com.br")
    whatsapp_url = StringProperty("https://wa.me/5599999999999")  # TODO: replace com numero real
    email_address = StringProperty("contato@engenhodigitalweb.com.br")  # TODO: substituir pelo e-mail oficial

    def open_website(self):
        """Open company website in default browser."""
        webbrowser.open(self.website_url)

    def open_whatsapp(self):
        """Open WhatsApp link; update number before release."""
        webbrowser.open(self.whatsapp_url)

    def open_email(self):
        """Draft an email using a mailto link."""
        mailto_url = f"mailto:{quote(self.email_address)}?subject={quote('Contato - Engenho Digital')}"
        webbrowser.open(mailto_url)

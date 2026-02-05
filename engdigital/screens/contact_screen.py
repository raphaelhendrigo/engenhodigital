"""Contact screen for Engenho Digital app."""

import webbrowser
from urllib.parse import quote

from kivy.properties import StringProperty
from kivy.uix.screenmanager import Screen

from engdigital import config


class ContactScreen(Screen):
    """Contact options for Engenho Digital."""

    website_url = StringProperty(config.WEBSITE_URL)
    whatsapp_url = StringProperty(config.WHATSAPP_URL)
    email_address = StringProperty(config.EMAIL_ADDRESS)
    privacy_policy_url = StringProperty(config.PRIVACY_POLICY_URL)
    support_phone = StringProperty(config.SUPPORT_PHONE)

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

    def open_privacy_policy(self):
        """Open privacy policy page in default browser."""
        webbrowser.open(self.privacy_policy_url)

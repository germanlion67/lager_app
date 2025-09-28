# ev

Lager App
Die Lager App ist eine Flutter-Anwendung zur Verwaltung von Elektronik-Artikeln und Komponenten. Sie ermöglicht das Erfassen, Bearbeiten, Suchen und Verwalten von Artikeln in einem lokalen Lager. Zu jedem Artikel können Name, Beschreibung, Ort, Fach, Menge und ein Bild hinterlegt werden. Die App unterstützt Import und Export von Artikeldaten (CSV/JSON), Nextcloud-Synchronisation sowie das Erfassen von Bildern per Datei oder Kamera. Eine integrierte Logfunktion hilft bei der Fehleranalyse. Die Anwendung ist für Desktop und mobile Geräte geeignet.

Features:

Artikelliste mit Suchfunktion
Artikel erfassen, bearbeiten und löschen
Mengenverwaltung
Bilder per Datei oder Kamera hinzufügen
Import/Export von Artikeldaten (CSV/JSON)
Nextcloud-Synchronisation
Fehler- und Ereignis-Logging
QR-Code-Scan für Artikel
Technologien:
Flutter, SQLite, Nextcloud WebDAV, Kamera, FilePicker

Hinweis:
Die App ist Open Source und kann beliebig erweitert werden.

Strucktur
+---lib
�   �   main.dart
�   �   
�   +---helpers
�   +---models
�   �       artikel_model.dart
�   �       
�   +---screens
�   �       artikel_detail_screen.dart
�   �       artikel_erfassen_screen.dart
�   �       artikel_list_screen.dart
�   �       nextcloud_settings_screen.dart
�   �       qr_scan_screen_mobile_scanner.dart
�   �       
�   +---services
�   �       api_service.dart
�   �       app_log_service.dart
�   �       artikel_db_service.dart
�   �       artikel_export_service.dart
�   �       artikel_import_service.dart
�   �       image_picker.dart
�   �       nextcloud_connection_service.dart
�   �       nextcloud_credentials.dart
�   �       nextcloud_sync_service.dart
�   �       nextcloud_webdav_client.dart
�   �       pdf_export_service.dart
�   �       pdf_service.dart
�   �       scan_service.dart
�   �       tag_service.dart
�   �       
�   +---test
�   �   +---services
�   +---widgets
�           article_icons.dart
�           

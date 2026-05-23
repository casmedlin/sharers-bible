run:
	python3 main.py

flatpak:
	flatpak-builder --force-clean build-dir flatpak/org.sharersbible.app.yml
	flatpak-builder --run build-dir flatpak/org.sharersbible.app.yml sharers-bible

snap:
	snapcraft

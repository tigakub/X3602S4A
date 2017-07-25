# X3602S4A
Xbox 360 USB Controller User Space "Driver" for Snap4Arduino

This macOS app polls the USB subsystem for devices that exhibit the Microsoft Xbox 360 usb game controller's Product and Vendor IDs, opens an interface to each it finds, and starts relaying telemetry from the controller to Snap4Arduino via HTTP GET requests to http://localhost:42001. Telemetry data is tagged with a unique name for each controller determined by the order in which the controllers are discovered (or attached).


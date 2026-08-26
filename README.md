# ResourceRing

A tiny native macOS overlay for CPU and memory usage.

- Outer ring: CPU usage
- Inner ring: memory usage
- Green / orange / red: increasing resource pressure
- Hover: exact percentages
- Click: open Activity Monitor
- Drag: move the ring anywhere on screen
- Right-click: open the menu and choose **Quit ResourceRing**

## Run

```sh
chmod +x build.sh
./build.sh
open ResourceRing.app
```

It initially appears in the top-right corner and stays visible across Spaces and full-screen apps.

## Controls

- **Hover** over the ring to reveal live CPU and memory percentages.
- **Click** the ring to open Activity Monitor.
- **Drag** the ring to reposition it. Releasing after a drag will not open Activity Monitor.
- **Right-click** the ring and choose **Quit ResourceRing** to close it when launched by double-clicking.

If you launched it from Terminal, you can also stop it with `Control-C`.

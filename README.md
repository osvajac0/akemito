# <h1 align="center"> Akemito </h1>

<p align="center"> <img src="https://github.com/osvajac0/akemito/blob/main/typewriter.gif"/> </p>

![banner](https://github.com/osvajac0/akemito/blob/main/banner.png)

# <p align="center">Akemito</p>

A Linux lightweight mouse position memory tool for X11.

## <p align="center">Features</p>

- Automatically saves cursor position after it remains still for `1 second`
- Restores saved position with a keyboard shortcut `Alt+Z`

## <p align="center">Requirements</p>

- `python3`
- `X11` (Xorg) window system
- Dependencies:
  - `pynput` (Python library for monitoring and controlling input devices)
  - `python-xlib` (Python interface to X11)

## <p align="center">Installation</p>


1. Clone or download this repository
```
 git clone https://github.com/osvajac0/akemito.git
```
2. Open the repository's directory
```
cd akemito
```

3. Make the install script executable:
```
 sudo chmod +x install_akemito.sh
```

4. Run the installation script:
```
sudo ./install_akemito.sh
```

## <p align="center">How it works?</p>

1. Akemito monitors your mouse cursor position
2. When the cursor remains still for the specified time `1 second`, it prepares to save the position
3. Once the cursor moves after being still, the position is saved
4. Press `Alt+Z` at any time to restore the cursor to the saved position

## <p align="center">Troubleshooting</p>

### <p align="center">My shortcut isn't working</p>

Make sure no other application is capturing the same keyboard shortcut. 

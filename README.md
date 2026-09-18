## Remote Dumper

Dump every RemoteEvent / RemoteFunction / Bindable from the currently loaded game.

**Separate loadstring — do not confuse with the main loader.**

# Remote Loader
loadstring(request({Url = "https://raw.githubusercontent.com/dreidadev-cmyk/VeilHub/main/remote/loader.lua", Method = "GET"}).Body)()


# Script Loader 
loadstring(request({Url="https://raw.githubusercontent.com/dreidadev-cmyk/VeilHub/main/loader.lua?v="..os.time(), Method="GET"}).Body)()

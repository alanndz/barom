# barom

Barom is my script to build rom. It very easy to use


Install barom in system:
```
curl -sL https://git.io/JkItH | bash
```

Alternative:
```
wget -O barom https://git.io/JUjwP
chmod +x barom
./barom -h
```

### Usage

```
$ barom -h

Usage: barom.sh [OPTION <ARGUMENT>] [OPTION] -- [BUILD COMMAND]

Options:
  -b, --build                     Start build
  -l, --lunch <lunch cmd>         Define lunch command, (ex: vayu-userdebug)
  -d, --device <device>           Define device for to build, (ex: vayu)
  -c, --clean <option>            Make clean/dirty, description in below
  -n, --name <rom name>           Define rom name, it will help to detect name file for upload
  --timer <..s/m/h>           Define timer to limit time when building (ex: 1m)
  -L                              Show lunch command only, dont start  the build
  -h, --help                      Show usage
  -v, --version                   Show version

Repo:
  -i, --init <manifest> <branch>  Define manifest and branch to repo init
  --reinit                        Repo init again with already define by -i
  -r, --resync                    Repo sync all repository after define using -i
  -r, --resync <path>             Repo sync with custom path not all repository
  --init-flags, --iflags <flags>  Init flags
  --force-sync                    Force sync repos, use it with -r, --resync

-c, --clean options description:
  full            make clobber and make clean
  dirty           make installclean
  clean           make clean
  device          make deviceclean

Telegram:
  -t, --telegram <ch id> <tg token>   Define channel id and telegram token, it will tracking proggress and send status to telegram channel
  --send-file-tg, --sft <path file>   Send file to telegram

Upload:
  -u, --upload <wet|trs|fio>       Upload rom after finished build
  --upload-rom-latest, --url       Upload latest rom from result folder
  --upload-file <file>             Upload file only and exit

CCache:
  --ccache-dir <dir path>         Set custom directory for ccache
  --ccache-size <..K/M/G>         Set custom size, (default: 50G)

Notes: [!] For upload, for now just support wetransfer<wet> fileio<fio> transfer<trs>
       [!] Dont use --upload-rom-latest, --upload-file, --send-file-tg with other option/argument

Example: barom -b -d vayu -l vayu-user -c clean -n BiancaProject -u wet -- m dudu
```

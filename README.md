# barom

Barom adalah singkatan dari Bakar Rom. Sebuah script untuk membangun(build) rom android dari source mentah menjadi matang yang siap untuk dipakai di smartphone.

Untuk menggunakannya sangat mudah sekali. Hal pertama yang anda lakukan adalah berada di direktori rom itu sendiri. Lalu pasang seperti di bawah ini


Install barom di system:
```
wget -O- https://git.io/JkItH | bash
```

Sedangkan untuk manual bisa seperti ini:
```
wget -O barom https://git.io/JUjwP
chmod +x barom
./barom -h
```

## Google Drive
Bagi yang mau upload rom nya ke google drive, pertama perlu menginstall grive dulu.
Untuk menginstallnya sangat mudah:

Pertama, login terlebih dahulu di gdrive.
```
gdrive list
```

Dalam build, juga bisa auto upload dengan command:
```
barom -b -c -o
```

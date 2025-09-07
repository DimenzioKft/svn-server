# SVN Server Docker Setup

Ez a Docker Compose konfiguráció egy Debian alapú SVN szervert hoz létre HTTPS támogatással.

## Funkciók

- **Debian bookworm-slim** alapú SVN szerver
- **HTTP protokoll** (SSL-t az nginx proxy manager kezeli)
- **Felhasználói hitelesítés** htpasswd alapon
- **Authorizációs kontroll** repository szinten
- **Automatikus backup** szolgáltatás (opcionális)
- **Csatlakozás npm_proxy hálózathoz** nginx proxy manager számára
- **Proxy header támogatás** HTTPS detektáláshoz

## Telepítés és indítás

1. **Projekt klónozása és környezeti változók beállítása**:
   ```bash
   git clone <repository-url>
   cd svn
   cp .env.example .env
   nano .env
   ```

2. **Konténer építése és indítása**:
   ```bash
   docker-compose up -d
   ```

3. **Logok ellenőrzése**:
   ```bash
   docker-compose logs -f svn-server
   ```

## Használat

### Nginx Proxy Manager konfigurálása
1. Hozz létre egy új Proxy Host-ot az nginx proxy manager-ben
2. **Domain Names**: `svn.yourdomain.com`
3. **Scheme**: `http`
4. **Forward Hostname/IP**: `svn-server` (konténer név)
5. **Forward Port**: `80`
6. **SSL**: Engedélyezd és konfiguráld a Let's Encrypt-et

### Web böngészőből
- Nyisd meg: `https://svn.yourdomain.com/svn/` (proxy-n keresztül)
- Vagy közvetlenül: `http://localhost:8080/svn/` (fejlesztéshez)
- Alapértelmezett felhasználó: `dimadmin`
- Alapértelmezett jelszó: Lásd `.env` fájl

### SVN kliens parancsokkal

```bash
# Repository checkout (proxy-n keresztül)
svn checkout https://svn.yourdomain.com/svn/repository

# Vagy közvetlenül (fejlesztéshez)
svn checkout http://localhost:8080/svn/repository

# Fájlok hozzáadása
svn add file.txt
svn commit -m "Added new file"

# Frissítés
svn update

# Repository böngészése
svn list https://svn.yourdomain.com/svn/repository
```

## Felhasználó kezelés

### 1. Jelszó megváltoztatása
```bash
# Interaktív módszer (biztonságosabb)
docker exec -it svn-server htpasswd /var/svn/.htpasswd dimadmin

# Batch módszer
docker exec svn-server htpasswd -b /var/svn/.htpasswd dimadmin új_jelszó
```

### 2. Új felhasználó hozzáadása

#### Interaktív módszer (ajánlott):
```bash
docker exec -it svn-server htpasswd /var/svn/.htpasswd újfelhasználó
```

#### Batch módszer:
```bash
docker exec svn-server htpasswd -b /var/svn/.htpasswd újfelhasználó jelszó123
```

#### Biztonságos batch módszer:
```bash
echo "jelszó123" | docker exec -i svn-server htpasswd -i /var/svn/.htpasswd újfelhasználó
```

### 3. Felhasználó törlése
```bash
# Felhasználó törlése a htpasswd fájlból
docker exec svn-server htpasswd -D /var/svn/.htpasswd felhasználónév

# Példa: testuser törlése
docker exec svn-server htpasswd -D /var/svn/.htpasswd testuser
```

### 4. Felhasználók listázása
```bash
# Összes felhasználó megjelenítése (jelszó hash-ekkel)
docker exec svn-server cat /var/svn/.htpasswd

# Csak a felhasználónevek listázása
docker exec svn-server cut -d: -f1 /var/svn/.htpasswd

# Felhasználók számának lekérdezése
docker exec svn-server wc -l /var/svn/.htpasswd
```

### 5. Felhasználó létrehozása lépésről lépésre

#### Példa: 'developer' felhasználó létrehozása
```bash
# 1. Felhasználó hozzáadása htpasswd-hez (interaktív)
docker exec -it svn-server htpasswd /var/svn/.htpasswd developer

# Vagy batch módszerrel
docker exec svn-server htpasswd -b /var/svn/.htpasswd developer dev123pass

# 2. Jogosultságok beállítása az authz.conf-ban
docker exec svn-server bash -c 'cat >> /var/svn/authz.conf << EOF

# Developer felhasználó hozzáadva
[repository:/trunk]
developer = rw
EOF'

# 3. Apache újraindítása a változások érvényesítéséhez
docker compose restart svn-server
```

#### Példa: 'readonly' felhasználó létrehozása
```bash
# 1. Felhasználó hozzáadása
docker exec svn-server htpasswd -b /var/svn/.htpasswd guest readonly123

# 2. Readonly jogosultság beállítása
docker exec svn-server bash -c 'sed -i "/readonly =/s/$/guest,/" /var/svn/authz.conf'

# 3. Konfiguráció ellenőrzése
docker exec svn-server cat /var/svn/authz.conf
```

### 6. Tömeges felhasználó kezelés

#### Több felhasználó létrehozása egyszerre
```bash
# users.txt fájl létrehozása a hoston
cat > users.txt << EOF
developer1:dev1pass
developer2:dev2pass
tester1:test1pass
manager1:mgr1pass
EOF

# Felhasználók hozzáadása ciklusban
while IFS=: read -r username password; do
    docker exec svn-server htpasswd -b /var/svn/.htpasswd "$username" "$password"
    echo "Felhasználó hozzáadva: $username"
done < users.txt

# Cleanup
rm users.txt
```

#### Felhasználói csoportok beállítása
```bash
# Authz konfiguráció frissítése csoportokkal
docker exec svn-server bash -c 'cat > /var/svn/authz.conf << EOF
[groups]
admins = dimadmin
developers = developer1, developer2
testers = tester1
managers = manager1
readonly = guest

[/]
@admins = rw
@managers = rw
@developers = rw
@testers = r
@readonly = r
* = 

[repository:/]
@admins = rw
@managers = rw
@developers = rw
@testers = r
@readonly = r
* = 

[repository:/trunk]
@developers = rw
@testers = r

[repository:/branches]
@developers = rw
@managers = rw

[repository:/tags]
@managers = rw
* = r
EOF'
```

### 7. Felhasználó validálás és tesztelés

#### Felhasználó létezésének ellenőrzése
```bash
# Ellenőrzés, hogy létezik-e a felhasználó
docker exec svn-server grep -q "^username:" /var/svn/.htpasswd && echo "Létezik" || echo "Nem létezik"

# Felhasználó keresése
docker exec svn-server grep "developer1" /var/svn/.htpasswd
```

#### Jelszó validálás
```bash
# Jelszó ellenőrzése (interaktív)
docker exec -it svn-server htpasswd -v /var/svn/.htpasswd developer1

# Hitelesítés tesztelése curl-lel
docker exec svn-server curl -u developer1:dev1pass -I http://localhost/svn/repository/
```

#### Jogosultság tesztelése
```bash
# SVN műveletek tesztelése különböző felhasználókkal
# Checkout tesztelés
svn checkout https://developer1:dev1pass@svn.yourdomain.com/svn/repository test-dev

# Commit jogosultság tesztelése
cd test-dev
echo "test" > test.txt
svn add test.txt
svn commit -m "Test commit by developer1"

# Readonly felhasználó tesztelése (sikertelen commit)
svn checkout https://guest:readonly123@svn.yourdomain.com/svn/repository test-guest
cd test-guest
echo "readonly test" > readonly.txt
svn add readonly.txt
# Ez sikertelen lesz, ha a jogosultságok jól vannak beállítva
svn commit -m "This should fail"
```

### 8. Felhasználó hibaelhárítás

#### Gyakori problémák és megoldások
```bash
# 1. "401 Unauthorized" hiba
# Ellenőrizd a jelszót és a felhasználónevet
docker exec svn-server grep "username" /var/svn/.htpasswd

# 2. "403 Forbidden" hiba
# Ellenőrizd az authz.conf jogosultságokat
docker exec svn-server cat /var/svn/authz.conf

# 3. Authz konfiguráció szintaxis ellenőrzése
docker exec svn-server svnauthz validate /var/svn/authz.conf

# 4. Apache konfiguráció tesztelése
docker exec svn-server apache2ctl configtest

# 5. Apache újraindítása jogosultság változások után
docker compose restart svn-server
```

#### Backup és visszaállítás
```bash
# Felhasználók mentése
docker exec svn-server cp /var/svn/.htpasswd /var/svn/.htpasswd.backup
docker exec svn-server cp /var/svn/authz.conf /var/svn/authz.conf.backup

# Visszaállítás
docker exec svn-server cp /var/svn/.htpasswd.backup /var/svn/.htpasswd
docker exec svn-server cp /var/svn/authz.conf.backup /var/svn/authz.conf
docker compose restart svn-server
```

#### Felhasználó audit log
```bash
# SVN access logok ellenőrzése
docker exec svn-server tail -f /var/log/apache2/access.log | grep svn

# Sikertelen hitelesítések keresése
docker exec svn-server grep "401" /var/log/apache2/access.log

# Felhasználó aktivitás keresése
docker exec svn-server grep "developer1" /var/log/apache2/access.log
```

## Jogosultságok kezelése

### Authz konfiguráció szerkesztése
```bash
# Jogosultságok megtekintése
docker exec svn-server cat /var/svn/authz.conf

# Jogosultságok szerkesztése
docker exec -it svn-server nano /var/svn/authz.conf
```

### Jogosultsági szintek
```ini
[groups]
admins = dimadmin
users = user1, user2, user3
readonly = guest1, guest2

[repository:/]
@admins = rw      # Admin csoport: írás/olvasás
@users = rw       # User csoport: írás/olvasás  
@readonly = r     # Readonly csoport: csak olvasás
* =               # Mások: nincs hozzáférés
```

### Jogosultság típusok
- **`rw`** - Írás és olvasás (read-write)
- **`r`** - Csak olvasás (read-only)
- **``** (üres) - Nincs hozzáférés

### Speciális jogosultságok
```ini
# Csak egy adott felhasználónak
[repository:/trunk]
user1 = rw
user2 = r

# Projekt specifikus jogok
[project1:/]
@developers = rw
@testers = r

[project2:/]
@project2_team = rw
```

## Biztonság

### SSL és proxy konfiguráció
- Az SSL-t az nginx proxy manager kezeli
- Add meg a `svn-server:80` címet a Forward beállításokban
- Engedélyezd az SSL-t és konfiguráld a domain-t
- A proxy automatikusan kezeli az HTTPS-t

## Könyvtárszerkezet

```
svn/
├── .env                     # Környezeti változók (másolva .env.example-ből)
├── .env.example             # Példa környezeti változók
├── .gitignore               # Git ignore szabályok
├── docker-compose.yml       # Docker Compose konfiguráció
├── Dockerfile               # Docker image definíció
├── entrypoint.sh            # Inicializációs script
├── README.md                # Dokumentáció
├── apache-config/           # Apache konfigurációs fájlok
│   ├── .gitkeep
│   └── 000-default.conf
├── svn-repos/               # SVN repository adatok
│   └── .gitkeep
├── logs/                    # Apache log fájlok
│   └── .gitkeep
└── backups/                 # Backup fájlok
    └── .gitkeep
```

### Fontosabb fájlok leírása

- **`.env`** - Személyre szabott környezeti változók (nem verziókezelt)
- **`.env.example`** - Példa konfiguráció új telepítésekhez
- **`.gitignore`** - Meghatározza, mely fájlok ne kerüljenek verziókezelésbe
- **`apache-config/000-default.conf`** - Apache VirtualHost konfiguráció
- **`svn-repos/`** - Itt tárolja az SVN a repository adatokat
- **`logs/`** - Apache access és error logok
- **`backups/`** - SVN dump fájlok tárolása

## Git verziókezelés

### Első beállítás
```bash
# Repository inicializálása
git init
git add .
git commit -m "Initial SVN server setup"

# Remote repository hozzáadása
git remote add origin <your-git-repository-url>
git push -u origin main
```

### Fontos fájlok kezelése
- **Verziókezelt fájlok**: Dockerfile, docker-compose.yml, entrypoint.sh, README.md, .env.example
- **Nem verziókezelt fájlok**: .env, svn-repos/, logs/, backups/, apache-config/ (kivéve .gitkeep)

### Új környezet telepítése
```bash
git clone <repository-url>
cd svn
cp .env.example .env
# Szerkeszd a .env fájlt a környezetednek megfelelően
nano .env
docker-compose up -d
```

## Backup

A backup szolgáltatás minden éjjel 2 órakor automatikus mentést készít:
```bash
# Manuális backup készítése
docker exec svn-server svnadmin dump /var/svn/repository > backup-$(date +%Y%m%d).dump

# Backup visszaállítása
svnadmin load /var/svn/new-repository < backup.dump
```

## Hálózat

A szerver két hálózaton van:
- `svn_network`: Belső SVN hálózat
- `npm_proxy`: Külső proxy hálózat (már meglévő)

## Hibaelhárítás

### Portok ellenőrzése
```bash
docker-compose ps
netstat -tlnp | grep :8080
```

### Logok ellenőrzése
```bash
# SVN szerver logok
docker-compose logs svn-server

# Apache error logok
docker exec svn-server tail -f /var/log/apache2/error.log

# Apache access logok
docker exec svn-server tail -f /var/log/apache2/access.log
```

### Konténer újraindítása
```bash
docker-compose restart svn-server
```

### Teljes újraépítés
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Hasznos parancsok

### SVN műveletek
```bash
# Repository információk (proxy-n keresztül)
svn info https://svn.yourdomain.com/svn/repository

# Repository történet
svn log https://svn.yourdomain.com/svn/repository

# Fájl verziók
svn log -v https://svn.yourdomain.com/svn/repository/file.txt

# Diff két verzió között
svn diff -r 1:2 https://svn.yourdomain.com/svn/repository/file.txt

# Közvetlen hozzáférés (fejlesztéshez)
svn info http://localhost:8080/svn/repository
```

### Felhasználó kezelés parancsok
```bash
# Gyors felhasználó létrehozás
docker exec svn-server htpasswd -b /var/svn/.htpasswd username password

# Felhasználó törlés és csoport frissítés
docker exec svn-server htpasswd -D /var/svn/.htpasswd username
docker exec svn-server sed -i '/username/d' /var/svn/authz.conf

# Összes felhasználó névvel és utolsó bejelentkezés
docker exec svn-server cut -d: -f1 /var/svn/.htpasswd | while read user; do
    echo -n "$user: "
    docker exec svn-server grep "$user" /var/log/apache2/access.log | tail -1 | cut -d' ' -f4 || echo "Nincs log"
done

# Felhasználói jogosultságok lekérdezése
docker exec svn-server bash -c 'for user in $(cut -d: -f1 /var/svn/.htpasswd); do
    echo "=== $user jogosultságai ==="
    grep -A 20 "^\[" /var/svn/authz.conf | grep -B 5 -A 5 "$user"
done'

# Csoport tagság ellenőrzése
docker exec svn-server grep -A 10 "^\[groups\]" /var/svn/authz.conf

# Jelszó erősség ellenőrzés (hossz alapú)
docker exec svn-server bash -c 'cut -d: -f2 /var/svn/.htpasswd | while read hash; do
    if [[ ${#hash} -lt 20 ]]; then echo "Gyenge jelszó hash: $hash"; fi
done'

# Felhasználói aktivitás statisztika
docker exec svn-server bash -c 'for user in $(cut -d: -f1 /var/svn/.htpasswd); do
    count=$(grep " $user " /var/log/apache2/access.log | wc -l)
    echo "$user: $count kérés"
done | sort -k2 -nr'

# Utolsó 10 SVN művelet felhasználókkal
docker exec svn-server tail -10 /var/log/apache2/access.log | grep svn | awk '{print $1, $4, $7}'
```

### Rendszergazda parancsok
```bash
# Konténer logok
docker compose logs -f svn-server

# Apache error logok
docker exec svn-server tail -f /var/log/apache2/error.log

# Apache access logok  
docker exec svn-server tail -f /var/log/apache2/access.log

# Konténerbe belépés
docker exec -it svn-server bash

# Repository információk
docker exec svn-server svnadmin info /var/svn/repository
```

## Tesztelés

### Felhasználó hitelesítés tesztelése
```bash
# Admin felhasználó tesztelése
docker exec svn-server curl -u dimadmin:JELSZÓ -I http://localhost/svn/repository/

# Új felhasználó tesztelése
docker exec svn-server curl -u testuser:password123 -I http://localhost/svn/repository/

# Sikeres válasz: HTTP/1.1 200 OK
# Sikertelen hitelesítés: HTTP/1.1 401 Unauthorized
```

### SVN műveletek tesztelése
```bash
# Test repository checkout
svn checkout https://svn.yourdomain.com/svn/repository test-checkout

# Test commit
cd test-checkout
echo "test file" > test.txt
svn add test.txt
svn commit -m "Test commit"

# Test update
svn update
```

### Jogosultság tesztelése
```bash
# Readonly felhasználó tesztelése (csak olvasás)
svn checkout https://readonly-user:password@svn.yourdomain.com/svn/repository

# Write felhasználó tesztelése (írás/olvasás)
svn checkout https://write-user:password@svn.yourdomain.com/svn/repository
```

## Gyors parancs referencia

### 🚀 Gyakori felhasználó műveletek
```bash
# Új felhasználó (interaktív)
docker exec -it svn-server htpasswd /var/svn/.htpasswd USERNAME

# Új felhasználó (batch)
docker exec svn-server htpasswd -b /var/svn/.htpasswd USERNAME PASSWORD

# Felhasználó törlése
docker exec svn-server htpasswd -D /var/svn/.htpasswd USERNAME

# Felhasználók listája
docker exec svn-server cut -d: -f1 /var/svn/.htpasswd

# Jelszó változtatás
docker exec -it svn-server htpasswd /var/svn/.htpasswd USERNAME
```

### 🔐 Jogosultság kezelés
```bash
# Authz konfiguráció megtekintése
docker exec svn-server cat /var/svn/authz.conf

# Authz szerkesztése
docker exec -it svn-server nano /var/svn/authz.conf

# Konfiguráció validálás
docker exec svn-server svnauthz validate /var/svn/authz.conf

# Apache újraindítás (jogosultság változás után)
docker compose restart svn-server
```

### 🧪 Tesztelés
```bash
# Hitelesítés teszt
docker exec svn-server curl -u USER:PASS -I http://localhost/svn/repository/

# Jelszó ellenőrzés
docker exec -it svn-server htpasswd -v /var/svn/.htpasswd USERNAME

# Repository checkout teszt
svn checkout https://USER:PASS@svn.yourdomain.com/svn/repository
```

### 📊 Monitoring
```bash
# Access logok
docker exec svn-server tail -f /var/log/apache2/access.log

# Error logok
docker exec svn-server tail -f /var/log/apache2/error.log

# Felhasználói aktivitás
docker exec svn-server grep "USERNAME" /var/log/apache2/access.log

# Sikertelen hitelesítések
docker exec svn-server grep "401" /var/log/apache2/access.log
```

### 💾 Backup és karbantartás
```bash
# Felhasználók backup
docker exec svn-server cp /var/svn/.htpasswd /var/svn/.htpasswd.backup

# Authz backup
docker exec svn-server cp /var/svn/authz.conf /var/svn/authz.conf.backup

# SVN repository backup
docker exec svn-server svnadmin dump /var/svn/repository > backup.dump

# Repository ellenőrzés
docker exec svn-server svnadmin verify /var/svn/repository
```

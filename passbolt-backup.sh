# Step 1: Make Directories

mkdir /backups/daily-backup-$(date +%Y%m%d)
mkdir /backups/daily-backup-$(date +%Y%m%d)/passbolt
mkdir /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc

# Step 2: Copy Private Keys
# Change /passbolt/serverkey.asc and /passbolt/serverkey_private.asc to wherever you have your persistent volume set up.

cp /passbolt/serverkey.asc	/backups/daily-backup-$(date +%Y%m%d)/passbolt
cp /passbolt/serverkey_private.asc /backups/daily-backup-$(date +%Y%m%d)/passbolt

# Step 3: Export Docker Variables
# Change "passbolt" to whatever your Passbolt App container is called in Docker.

docker exec passbolt env > /etc/passbolt-enviroment-production.txt
cp /etc/passbolt-enviroment-production.txt /backups/daily-backup-$(date +%Y%m%d)/passbolt
rm -f /etc/passbolt-enviroment-production.txt

# Step 4: Export Database
# 1. Change %MYDB_HOST% to the relevant docker container name for MySQL
# 2. Change %MYUSERNAME and %MYPASSWORD to the correct username and password for an account with read-only access to Passbolt. NOTE: Hard-coding credentials like this is considered to be insecure.
# 3. Change %MYDB_NAME% to the name of your passbolt database.

docker exec %MYDB_HOST% mysqldump --user="%MYUSERNAME%"--password="%MYPASSWORD%" %MYDB_NAME% > backups/daily-backup-$(date +%Y%m%d)/passbolt/passbolt-production-$(date +%Y%m%d%H%M).sql

# Step 5: Encrypt Files with Public Key
## Source: https://www.czeskis.com/random/openssl-encrypt-file.html

## Generate unique encryption key.

openssl rand -base64 32 > /etc/passbolt-key.bin

## Encrypt files with this unique encryption key.

openssl enc -aes-256-cbc -salt -in /backups/daily-backup-$(date +%Y%m%d)/passbolt/passbolt-enviroment-production.txt -out /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc/passbolt-enviroment-production.txt -pass file:/etc/passbolt-key.bin
openssl enc -aes-256-cbc -salt -in /backups/daily-backup-$(date +%Y%m%d)/passbolt/passbolt-production-$(date +%Y%m%d%H%M).sql -out /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc/passbolt-production-$(date +%Y%m%d%H%M).sql -pass file:/etc/passbolt-key.bin
openssl enc -aes-256-cbc -salt -in /backups/daily-backup-$(date +%Y%m%d)/passbolt/serverkey_private.asc -out /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc/serverkey_private.asc -pass file:/etc/passbolt-key.bin
openssl enc -aes-256-cbc -salt -in /backups/daily-backup-$(date +%Y%m%d)/passbolt/serverkey.asc -out /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc/serverkey.asc -pass file:/etc/passbolt-key.bin

## Encrypt the unique key itself.
## Change /etc/passbolt-public.key to your own public key from your private/public key pair.

openssl rsautl -encrypt -inkey /etc/passbolt-public.key -pubin -in /etc/passbolt-key.bin -out /backups/daily-backup-$(date +%Y%m%d)/passbolt/enc/decryption-key.bin

# Step 6: Remove Unencrypted Files

rm -f /etc/passbolt-key.bin
rm -f /backups/daily-backup-$(date +%Y%m%d)/passbolt/passbolt-enviroment-production.txt
rm -f /backups/daily-backup-$(date +%Y%m%d)/passbolt/passbolt-production-$(date +%Y%m%d%H%M).sql
rm -f /backups/daily-backup-$(date +%Y%m%d)/passbolt/serverkey_private.asc
rm -f /backups/daily-backup-$(date +%Y%m%d)/passbolt/serverkey.asc


# Step 7: Copy Files to another host.
# Configure your SCP job as required or use a different protocol.

scp -v -r /backups/daily-backup-$(date +%Y%m%d) %MYBACKUPHOST%

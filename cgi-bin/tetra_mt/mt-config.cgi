##          Movable Type configuration file                   ##
##                                                            ##

##################### REQUIRED SETTINGS ########################

CGIPath        /cgi-bin/tetra_mt/
StaticWebPath  /cgi-bin/tetra_mt/mt-static/

#================ DATABASE SETTINGS ==================
### MySQL or PostgreSQL ###
ObjectDriver DBI::mysql
Database as-tetra_mt
DBUser as-tetra
DBPassword suzaki215
DBHost mysql420.db.sakura.ne.jp

##### MAIL #####
MailTransfer sendmail
SendMailPath /usr/sbin/sendmail

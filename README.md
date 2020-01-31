# How to run:

1) Create new project on Google Cloud, grant it permissions for Google Sheets API (https://console.cloud.google.com/apis/dashboard -> "Enable APIs and services"), create new service account - save it's "email" address, will be needed later

2) Save .json with credentials for that service account

3) Next to ../bin create ../database with the following files:
		a) ```credentials``` - file with credentials for service account
		b) ```admins``` - file for storing TG usernames of users with permission to do admin commands
		c) ```agentsOnStart``` - empty file - stores names of agents that submitted stats at the start of the FS
		d) ```agentsOnEnd``` - empty file - stores names of agents that submitted stats at the end of the FS
		e) ```agentsOnEndButNotOnStartCount``` - empty file - stores number of agents that submitted stats at the end but not at the start
		f) ```currentRow``` - empty file
		g) ```spreadsheet``` - cannot be empty, put some ID there of bot will crash on start - stores id of actual Google Sheet
		h) ```telegramToken``` - put your bot TG access token here, talk to @BotFather on TG to get your token
		i) ```uvodniText``` - text to be printed with /info command, sent to TG as Markdown
		
	Those files are not on github for obvious reasons. Well...it should be in real SQL database or something but I'm too lazy to do that.
		
4) In source code in section superadmin commands change my name to your TG username, you might wanna change texts of ```/start```, ```/pomoc``` and ```/info```. You might wanna rewrite czech error messages as well.

5) Get dart dependencies with
    ```sh
    pub get
    ```
4) Run bot from the directory with ```../database```, will crash if you try to run it from any other, or rewrite source code to absolute paths when reading from ```../database``` with command
	```sh
	dart bin/main.dart
	```

5) ???

6) Profit
		
		
Example Sheet with extra fuctions (don't touch list names unless you change them in source code too): 
https://docs.google.com/spreadsheets/d/1Ezu1cUVhdQLa6PM7CP_TTHcxCrOb3zLLgb1ZTfE3fNU/edit?usp=sharing


# How to operate (as admin):

1)	Write to superadmin to be added as admin

2) Create copy of Google Sheet provided above:

3) Share that copy with edit permissions with your service account (here comes in hand the mail we saved from step 1) of how to run)

4) In your TG bot set id of your table via
	```/updateSheetId <table id>```
	where table id is the part of url between .../d/ and /edit...
	
5) To start accepting stats at the beginning of the FS write
	```/zacitPocatecniStaty```
	
6) To stop accepting stats at the beginning of the FS write
	```/ukoncitPocatecniStaty```
	
7) To start accepting stats at the end of the FS write
	```/zacitKonecneStaty```
	
8) To stop accepting stats at the end of the FS write
	```/ukoncitKonecneStaty```
	This will start process of automatic counting of gained stats of every agent, if agent did not send one of the stats, zeros are written
	
	
9) Then there's a ```/reset```, well...it reset all agent data, it preserves admins, table id	
	
    (Or just rewrite command names to whatever you like)


# How to use (as field agent on FS):

1) Start conversation with the bot

2) Type ```/upload <your stats copied from Ingress>``` in one message

3) And that it. Well there's ```/pomoc``` which takes image ukazka.png (not included in this repo) and sends it with some instructions how to use this bot, and ```/info``` which taktes text from file uvodniInfo and sends it to the user.
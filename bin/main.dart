import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:teledart/model.dart';

import 'package:logging/logging.dart';

import 'package:gsheets/gsheets.dart';

import 'dart:async';
import 'dart:io' as io;

//global variables to store running config shared between all threads
var uvodniText; //text to print with /info
var _credentials; //google account credentials
var _spreadsheetId; //id of currently used spreadsheet
List<String> alltime_languages = ["GESAMT", "ALL TIME", "OD POCZĄTKU", "DALL'INIZIO", "全部","CELÉ OBDOBÍ", "ЗА ВСЕ ВРЕМЯ", "SIEMPRE", "ALLE", "TOUS TEMPS", "全期間", "전체", "SIDEN STARTEN", "TUDO", "NÅGONSIN"];
const tableHeader = ['Agent Name', 'Agent Faction', 'Date (yyyy-mm-dd)', 'Time (hh:mm:ss)', 'Level', 'Lifetime AP', 'Current AP', 'Unique Portals Visited', 'Portals Discovered', 'Seer Points', 'XM Collected', 'OPR Agreements', 'Distance Walked', 'Resonators Deployed', 'Links Created', 'Control Fields Created', 'Mind Units Captured', 'Longest Link Ever Created', 'Largest Control Field', 'XM Recharged', 'Portals Captured', 'Unique Portals Captured', 'Mods Deployed', 'Resonators Destroyed', 'Portals Neutralized', 'Enemy Links Destroyed', 'Enemy Fields Destroyed', 'Max Time Portal Held', 'Max Time Link Maintained', 'Max Link Length x Days', 'Max Time Field Held', 'Largest Field MUs x Days', 'Unique Missions Completed', 'Hacks', 'Glyph Hack Points', 'Longest Hacking Streak', 'Agents Successfully Recruited', 'Mission Day(s) Attended', 'NL-1331 Meetup(s) Attended', 'First Saturday Events'];
List<String> admins = []; //database of admins TG usernames
var ss; //current spreadsheet
var sheet; //current worksheet
var currentRow = 2; //first free row on 'Pocatecni data' sheet 
var acceptStart = false; //accept stats on the beginning of the FS
var acceptEnd = false;	//accept stats on the end of the FS
List<String> agentsOnStart = []; //list of agents that sent their stats on the beginning
List<String> agentsOnEnd = [];	//list of agents that sent their stats on the end
var agentsOnEndButNotOnStartCount;	//count of agents that sent their stats only on the end

TeleDart teledart;
Logger log;

//not needed, for performance testing only
Future<void>TimeFunction(var message) async {
	final stopwatch = Stopwatch()..start();
	
	await processData(message);

	print('data processing including writing into sheet executed in ${stopwatch.elapsed}');
	//log.info('This commands data processing including writing into sheet executed in ${stopwatch.elapsed}');
}

//check if user sent all time statistics
bool languageCheck(var data) {
	for(var i = 0; i < alltime_languages.length; i++)
			if(data.contains(alltime_languages[i])) {
				return true;
			}
	return false;
}

//since telegram replaces tabs with spaces parsing is tinkered together in weird ways, it works for now, dont touch it
Future<void> processData(var message) async {
	await log.info("Message from: " + message.from.username + ", message text: " + message.text); //debug purposes
	
	//if we currently dont accept -> reject
	if(acceptStart == false && acceptEnd == false) {
		teledart.telegram.sendMessage(message.chat.id, 'Momentálně není otevřeno posílání statistik.');
		log.info('FS is closed');
		return;
	}
	
	//we need at least 2 lines -> first line is the header, second line agents stats
	if (message.text.split('\n').length == 1) {
		teledart.telegram.sendMessage(message.chat.id, 'Chyba uploadu, zkontroluj formát vložených dat. Pro návod použij /pomoc');
		log.severe('Wrong data format');
		return;
	}
	
	//we split by endline -> first line is the header, second line agents stats
	var header = message.text.split('\n')[0];
	
	//print(header.split(' ')); //debug only
	var rawData = message.text.split('\n')[1]; //used for checking ALL TIME in all languages
	var useableData = message.text.split('\n')[1].split(' '); //actual agents stats
	print(useableData); //debug only
	
	//check if agent sent all time stats, if not -> reject
	if (!languageCheck(rawData)) {
		teledart.telegram.sendMessage(message.chat.id, 'Prosímtě pošli ALL TIME statistiky. Pro návod použij /pomoc');
		log.severe('Not all time stats');
		return;
	}
	//we good
	else if (acceptStart == true) {
		int currentItemIndex;
		for(var i = 0; i < alltime_languages.length; i++) //well all time in different languages has different length (1-3 words) so this gets an offset in data for this
			if(rawData.contains(alltime_languages[i]))
				currentItemIndex = alltime_languages[i].split(' ').length;
		var agentNameIndex = currentItemIndex;
		
		//check if user already sent data in, if so ->reject
		if(agentsOnStart.contains(useableData[currentItemIndex])) {
			teledart.telegram.sendMessage(message.chat.id, 'Agente, statistiky se na začátku posílají pouze 1x.');
			log.severe('Multiple stats');
			return;
		}
		
		int rowIndex = currentRow;
		List<String> data = [];
		currentRow++;
		
		//backup currentRow
		io.File('database/currentRow').writeAsString(currentRow.toString());
		
		//parse data
		for(int i = 0; i < tableHeader.length; i++) {
			if (header.contains(tableHeader[i])) {
				data.add(useableData[currentItemIndex]);
				currentItemIndex++;
			}
			//if not found -> agent does not have this stat -> write 0 (skip)
			else {
				data.add('0');
			}
		}
		//add user to known users & backup
		agentsOnStart.add(useableData[agentNameIndex]);
		io.File('database/agentsOnStart').writeAsString(agentsOnStart.join(' '));
		
		//insert data into google sheet
		await sheet.values.insertRow(rowIndex, data);
		
		//respond to user 
		teledart.telegram.sendMessage(message.chat.id, 'Mám to, díky!');
		log.info('Success');
	}
	//same shit as on the start of FS
	else if (acceptEnd == true) {
		int currentItemIndex;
		
		//check all time
		for(var i = 0; i < alltime_languages.length; i++)
			if(rawData.contains(alltime_languages[i]))
				currentItemIndex = alltime_languages[i].split(' ').length;
		var agentNameIndex = currentItemIndex;
		
		//check already sent
		if(agentsOnEnd.contains(useableData[currentItemIndex])) {
			teledart.telegram.sendMessage(message.chat.id, 'Agente, statistiky se na konci posílají pouze 1x.');
			log.severe('Multiple stats');
			return;
		}
		List<String> data = [];
		
		//get row index of processed agent so his data are on the same row in 2 different sheets -> easier calculation of the winner
		var rowNumber = agentsOnStart.indexOf(useableData[2]);
		if (rowNumber == -1) { //agent didnt send stats on the start of the FS, so we add him to the end of list
			rowNumber = agentsOnStart.length + agentsOnEndButNotOnStartCount;
			agentsOnEndButNotOnStartCount++;
			io.File('database/agentsOnEndButNotOnStartCount').writeAsString(agentsOnEndButNotOnStartCount.toString());
		}
		rowNumber++;
		currentRow++;
		io.File('database/currentRow').writeAsString(currentRow.toString());
		
		//same parse
		for(int i = 0; i < tableHeader.length; i++) {
			if (header.contains(tableHeader[i])) {
				data.add(useableData[currentItemIndex]);
				currentItemIndex++;
			}
			else {
				data.add('0');
			}
		}
		agentsOnEnd.add(useableData[agentNameIndex]);
		io.File('database/agentsOnEnd').writeAsString(agentsOnEnd.join(' '));
		//insert
		await sheet.values.insertRow(rowNumber+1, data);
		teledart.telegram.sendMessage(message.chat.id, 'Mám to, díky!');
		log.info('Success');
	}
}

//----------------------------ADMIN COMMANDS-----------------------------
//set bot to accept stats on the end of FS
//admin command
Future<void> setAcceptFinalStats(var message) async {
	if (!admins.contains(message.from.username))
		return;
	if (acceptStart == true) {
		acceptStart = false;
	}
	acceptEnd = true;
	
	//switch current sheet to final stats
	sheet = await ss.worksheetByTitle('Konecna data');
	sheet.values.insertRow(1, tableHeader);
	
	teledart.telegram.sendMessage(message.chat.id, 'Přijímám finální staty.');
}

//set bot to accep stats on the start of FS
//admin command
Future<void> setAcceptEntryStats(var message) async {
	if (!admins.contains(message.from.username))
		return;
	if (acceptEnd == true) {
		acceptEnd = false;
	}
	acceptStart = true;
	
	//switch current sheet to entry stats
	sheet = await ss.worksheetByTitle('Pocatecni data');
	sheet.values.insertRow(1, tableHeader);
	
	teledart.telegram.sendMessage(message.chat.id, 'Přijímám vstupní staty.');
}

//no longer accept stats on the start of FS
//admin command
Future<void> setEndEntryStats(var message) async {
	if (!admins.contains(message.from.username))
		return;
	acceptStart = false;
	teledart.telegram.sendMessage(message.chat.id, 'Nadále nepřijímám počáteční staty.');
}

//no longer accept stats on the end of FS & call to calculate final stats
//admin command
Future<void> setEndFinalStats(var message) async {
	if (!admins.contains(message.from.username))
		return;
	acceptEnd = false;
	await teledart.telegram.sendMessage(message.chat.id, 'Nadále nepřijímám finální staty.');
	
	//at the end of FS calculate player stats
	teledart.telegram.sendMessage(message.chat.id, 'Počítám rozdíly jednotilvých hráčů');
	computeFinalStats(message);
	
}

//insert smart rows to sheet to calculate diff of players stats
Future<void> computeFinalStats(var message) async {
	sheet = await ss.worksheetByTitle('Vyhodnoceni');
	var rowNumber = 2; //first line is the header, g sheets are numbered from 1
	while (rowNumber < (agentsOnStart.length + agentsOnEndButNotOnStartCount + 2)) { //for all agents
		await sheet.values.insertRow(rowNumber, ["='Konecna data'!A${rowNumber}", "='Konecna data'!B${rowNumber}", "='Konecna data'!C${rowNumber}", "='Konecna data'!D${rowNumber}", "=IF(OR(ISBLANK('Pocatecni data'!A${rowNumber});ISBLANK('Konecna data'!A${rowNumber}));0;'Konecna data'!E${rowNumber}-'Pocatecni data'!E${rowNumber})", "=IF(OR(ISBLANK('Pocatecni data'!A${rowNumber});ISBLANK('Konecna data'!A${rowNumber}));0;'Konecna data'!F${rowNumber}-'Pocatecni data'!F${rowNumber})", "=IF(OR(ISBLANK('Pocatecni data'!A${rowNumber});ISBLANK('Konecna data'!A${rowNumber}));0;'Konecna data'!N${rowNumber}-'Pocatecni data'!N${rowNumber})", "=IF(OR(ISBLANK('Pocatecni data'!A${rowNumber});ISBLANK('Konecna data'!A${rowNumber}));0;'Konecna data'!X${rowNumber}-'Pocatecni data'!X${rowNumber})", "=IF(OR(ISBLANK('Pocatecni data'!A${rowNumber});ISBLANK('Konecna data'!A${rowNumber}));0;'Konecna data'!M${rowNumber}-'Pocatecni data'!M${rowNumber})"]);
		rowNumber++;
	}
	teledart.telegram.sendMessage(message.chat.id, 'Statistiky pro jednotlivce spočítány.');
}

//update used sheet ID & initialize
//admin command
Future<void> updateSheetId(var message) async {
	if (!admins.contains(message.from.username))
		return;
	_spreadsheetId =  message.text.split(' ')[1];
	
	
	final gsheets = GSheets(_credentials);
	ss = await gsheets.spreadsheet(_spreadsheetId);
	sheet = await ss.worksheetByTitle('Pocatecni data');
	sheet.values.insertRow(1, tableHeader);
	io.File('database/spreadsheet').writeAsString(_spreadsheetId);
	teledart.telegram.sendMessage(message.chat.id, 'Sheet ID updated.');
}

//resets all data except database of admins, deletes everything from actually used sheet
//admin command
Future<void> reset(var message) async {
	if (!admins.contains(message.from.username))
		return;
	
	agentsOnStart = [];
	io.File('database/agentsOnStart').writeAsString(agentsOnStart.join(' '));
	agentsOnEnd = [];
	io.File('database/agentsOnEnd').writeAsString(agentsOnEnd.join(' '));
	currentRow = 2;
	io.File('database/currentRow').writeAsString(currentRow.toString());
	agentsOnEndButNotOnStartCount = 0;
	io.File('database/agentsOnEndButNotOnStartCount').writeAsString(agentsOnEndButNotOnStartCount.toString());
	acceptStart = false;
	acceptEnd = false;
	sheet =  await ss.worksheetByTitle('Pocatecni data');
	await sheet.clear();
	sheet.values.insertRow(1, tableHeader);
	
	sheet =  await ss.worksheetByTitle('Konecna data');
	await sheet.clear();
	sheet.values.insertRow(1, tableHeader);
	
	teledart.telegram.sendMessage(message.chat.id, 'FS has been reset.');
}

//-------------------------SUPERADMIN COMMANDS-----------------------------
//add admin - telegram user that can control this bot
//superuser command - replace 'Vykend' with your TG username
Future<void> addAdmin(var message) async {
	if (message.from.username != 'Vykend')
		return;
	admins.add(message.text.split(' ')[1]);
	io.File('database/admins').writeAsString(admins.join(' '));
	teledart.telegram.sendMessage(message.chat.id, 'Admin ' + message.text.split(' ')[1] + ' added.');
}

//remove admin - telegram user that can control this bot
//superuser command - replace 'Vykend' with your TG username
Future<void> removeAdmin(var message) async {
	if (message.from.username != 'Vykend')
		return;
	if(admins.remove(message.text.split(' ')[1])) {
		io.File('database/admins').writeAsString(admins.join(' '));
		teledart.telegram.sendMessage(message.chat.id, 'Admin ' + message.text.split(' ')[1] + ' removed.');
	}
	else
		teledart.telegram.sendMessage(message.chat.id, message.text.split(' ')[1] + ' is not an admin.');
}



void main() async {
	
	//initialize logger
	Logger.root.level = Level.ALL;
	Logger.root.onRecord.listen((LogRecord rec) {
		new io.File("FSBot.log").writeAsString('${rec.level.name}: ${rec.time}: ${rec.message}\n', mode: io.FileMode.append);
	});
  
	//load last config
	_credentials = await io.File('database/credentials.json').readAsString();
	admins = await io.File('database/admins').readAsString().then((content) => content.split(' '));
	_spreadsheetId = await io.File('database/spreadsheet').readAsString();
	agentsOnStart = await io.File('database/agentsOnStart').readAsString().then((content) => content.split(' '));
	agentsOnEnd = await io.File('database/agentsOnEnd').readAsString().then((content) => content.split(' '));
	currentRow = await io.File('database/currentRow').readAsString().then((content) => int.tryParse(content) ?? 2);
	agentsOnEndButNotOnStartCount = await io.File('database/agentsOnEndButNotOnStartCount').readAsString().then((content) => int.tryParse(content) ?? 0);
	var telegramToken = await io.File('database/telegramToken').readAsString();
	uvodniText = await io.File('database/uvodniText').readAsString();
	
	//initializeconnection to telegram API
	teledart = TeleDart(Telegram(telegramToken), Event());
	teledart.start().then((me) => print('${me.username} is initialised'));
	
	log = new Logger('TGBot');
	
	log.info('Logger initialised');
    
	//login to google account & connect to sheet
	final gsheets = GSheets(_credentials);
	ss = await gsheets.spreadsheet(_spreadsheetId);
	sheet = await ss.worksheetByTitle('Pocatecni data');
	sheet.values.insertRow(1, tableHeader);
	
	//---------------------------------USER COMMANDS-----------------------------
	teledart.
		onCommand('start').listen((message) => teledart.replyMessage(message, 'Zdravíčko agente, vítej na FS. Sloužím k uploadu statistik. Prosím použij /upload \'All time statistiky z profilu\' (v jedné zprávě!) pro upload statistik do tabulky. Pro více informací o nahrání statistik zadej /pomoc, pro více informací o FS zadej /info').then((m) => log.info('new chatter')));
	
	teledart.
		onCommand('info').listen((message) => teledart.replyMessage(message, uvodniText, parse_mode: 'Markdown', disable_web_page_preview: true));
		
	teledart
		.onCommand('pomoc').listen((message) => teledart.replyPhoto(message, io.File('ukazka.png'), caption: '1) Běž do Ingressu a na svém profilu klikni na 2 divné čtverečky vpravo nad medajlema (viz obrázek) - toto zkopíruje tvoje statistiky do schránky.\n2) Vrať se do této konverzace a napiš \'/upload\' (bez uvozovek) a za to vlož MEZERU a za ni STATISTIKY ze schránky a celé to pošli. Ano, opravdu jako jednu zprávu, ne zvlášť - příklad viz obrázek.\n3) Stejný postup proveď po konci hracího okna při odevzdání výsledků.'));
	
	teledart
		.onMessage(entityType: 'bot_command', keyword: 'upload')
		.listen(((message) => TimeFunction(message)
		));
	
	//-----------------------------ADMIN COMMANDS-----------------------------
	teledart.onCommand('zacitPocatecniStaty').listen((message) => setAcceptEntryStats(message));
	teledart.onCommand('ukoncitPocatecniStaty').listen((message) => setEndEntryStats(message));
	teledart.onCommand('zacitKonecneStaty').listen((message) => setAcceptFinalStats(message));
	teledart.onCommand('ukoncitKonecneStaty').listen((message) => setEndFinalStats(message));
	teledart.onCommand('updateSheetId').listen((message) => updateSheetId(message));
	teledart.onCommand('reset').listen((message) => reset(message));
	
	//------------------------SUPERADMIN COMMANDS-----------------------------
	teledart.onCommand('addAdmin').listen((message) => addAdmin(message));
	teledart.onCommand('removeAdmin').listen((message) => removeAdmin(message));
}


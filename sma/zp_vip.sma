#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <zombieplague>

#define MODE 3
#define CHAT_PREFIX "[ V.I.P ]"

#define VIPACCES ADMIN_LEVEL_H
#define MJACCES ADMIN_LEVEL_H

#define FLAG_A (1<<0)
#define FLAG_B (1<<1)
#define FLAG_C (1<<2)
#define FLAG_D (1<<3)
#define FLAG_E (1<<4)
#define FLAG_K (1<<10)

#if cellbits == 32
const OFFSET_CLIPAMMO = 51;
#else
const OFFSET_CLIPAMMO = 65;
#endif
const OFFSET_LINUX_WEAPONS = 4;

const DMG_HEGRENADE = (1<<24);

#define set_flood(%1,%2) (%1 |= (1<<(%2&31)))
#define clear_flood(%1,%2) (%1 &= ~(1<<(%2&31)))
#define get_flood(%1,%2) (%1 & (1<<(%2&31)))

#if MODE & (1<<0) || MODE & (1<<1)
new amx_password_field_string[30];
#endif
#if MODE & (1<<0)
new g_user_privileges[33];
enum _:database_items {
	auth[50],
	password[50],
	accessflags,
	flags
}
new vips_database[database_items];
new Array:database_holder;
new g_hour_flags;
new g_hour;
#endif
#if MODE & (1<<1)
const ZV_PLUGIN_HANDLED = 97;
enum _:items {
	i_name[31],
	i_description[31],
	i_cost,
	i_team
}
new g_register_in_zp_extra
new g_zp_extra_item_number
new g_nonvip_tease
new g_menu_close
new extra_items[items]
new Array:items_database
new g_registered_items_count
new g_forward_return
new g_extra_item_selected
new g_team[33]
#endif
#if MODE == 3
new g_vip_buy_time
new g_vip_cost_ammo
new g_vip_buy_flags
#endif
new const MAXCLIP[] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 }
static const CONTACT[] = ""
new g_jumps, g_allow_jump, g_armor, g_killammo, g_infectammo, g_infecthealth, g_nemhealth, g_show_vips,
g_unlimited_clip, g_fall_damage, g_damage_reward, g_damage_increase, g_happy_hour, g_happy_hour_frag, g_happy_hour_ammo
new happy_hour_on
new g_bit
new chache_g_jumps
new maxplayers, g_msgSayText
new jumpnum[33]
new bool:dojump[33]
new Float:g_damage[33]

public plugin_init() {
	
	register_plugin("ZM VIP", "1.7.2", "aaarnas")
	RegisterHam(Ham_Spawn, "player", "FwdHamPlayerSpawnPost", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	register_event("ResetHUD", "HUDReset", "be")
	register_event("HLTV", "chache_cvars", "a", "1=0", "2=0")
	
	maxplayers = get_maxplayers()
	g_msgSayText = get_user_msgid("SayText")
	
	register_message(get_user_msgid("CurWeapon"), "message_cur_weapon")
	
	g_jumps = register_cvar("zp_vip_jumps", "1")
	g_allow_jump = register_cvar("zp_vip_allow_jump", "ab")
	g_armor = register_cvar("zp_vip_armor", "65")
	g_killammo = register_cvar("zp_vip_killammo", "2")
	g_infectammo = register_cvar("zp_vip_infectammo", "2")
	g_infecthealth = register_cvar("zp_vip_infecthealth", "300")
	g_nemhealth = register_cvar("zp_vip_nemextra", "1")
	g_show_vips = register_cvar("zp_vip_show", "1")
	g_unlimited_clip = register_cvar("zp_vip_unlimited_ammo", "0")
	g_fall_damage = register_cvar("zp_vip_no_fall_damage", "1")
	g_damage_reward = register_cvar("zp_vip_damage_reward", "500")
	g_damage_increase = register_cvar("zp_vip_damage_increase", "1.5")
	g_happy_hour = register_cvar("zp_vip_happy_hour", "off")
	g_happy_hour_frag = register_cvar("zp_vip_happy_hour_frag", "1")
	g_happy_hour_ammo = register_cvar("zp_vip_happy_hour_ammo", "1")
	register_cvar("amx_contactinfo", CONTACT, FCVAR_SERVER)
	register_cvar("zp_vip_version", "1.7.2", FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("zp_vip_version", "1.7.2")
		
#if MODE & (1<<0) || MODE & (1<<1)
	get_cvar_string("amx_password_field", amx_password_field_string, charsmax(amx_password_field_string))
	register_dictionary("zm_vip.txt")
#endif
#if MODE & (1<<0) && MODE & (1<<1)
	g_vip_cost_ammo = register_cvar("zp_vip_cost_ammo", "0")
	g_vip_buy_time = register_cvar("zp_vip_buy_time", "7")
	g_vip_buy_flags = register_cvar("zp_vip_buy_flags", "abcd")
	set_task(5.0,"check_date",0)
#endif
#if MODE & (1<<0)
	register_concmd("amx_reloadvips", "reload_vips", ADMIN_CFG)
	g_hour = register_cvar("zp_vip_hour", "off")
	g_hour_flags = register_cvar("zp_vip_hour_flags", "abe")
	reload_vips()
#endif
#if MODE & (1<<1)
	register_clcmd("say /vm", "menu_open")
	g_nonvip_tease = register_cvar("zp_vip_nonvip_tease", "1")
	g_register_in_zp_extra = register_cvar("zp_vip_register_in_zp_extra", "1")
	g_menu_close = register_cvar("zp_vip_menu_close", "1")
	
	new temp[31]
	formatex(temp, 30, "%L", LANG_SERVER, "VIP_EXTRA_NAME")
	if(get_pcvar_num(g_register_in_zp_extra)) g_zp_extra_item_number = zp_register_extra_item(temp, 0, 0)
	g_extra_item_selected = CreateMultiForward("zv_extra_item_selected", ET_CONTINUE, FP_CELL, FP_CELL)
#endif
	register_clcmd("say /vips", "print_adminlist")
	register_clcmd("say /vip", "ShowMotd")
}
public plugin_cfg()
{
	new directory[31]
	get_configsdir(directory, 30)
	server_cmd("exec %s/zm_vip.cfg", directory)
}

public chache_cvars() {
	
	static string[5]
	get_pcvar_string(g_allow_jump, string, charsmax(string))
	g_bit = read_flags(string)
	chache_g_jumps = get_pcvar_num(g_jumps)
	
	static hours[6], hour1s[3], hour2s[3], hour1, hour2, h, m, s
	get_pcvar_string(g_happy_hour, hours, charsmax(hours))
		
	if(equal(hours, "off")) {happy_hour_on = false; return; }
		
	strtok(hours, hour1s, charsmax(hour1s), hour2s, charsmax(hour2s), '-')
	hour1 = str_to_num(hour1s)
	hour2 = str_to_num(hour2s)
		
	time(h, m, s)
	if(hour1 <= h <= hour2) happy_hour_on = true
	else happy_hour_on = false
}
#if MODE & (1<<1) || MODE & (1<<0)
public plugin_natives() {
#if MODE & (1<<1)
	register_native("zv_register_extra_item", "native_zv_register_extra_item", 1)
#endif
#if MODE & (1<<0)
	register_native("zv_get_user_flags", "native_zv_get_user_flags", 1)
#endif	
}
#endif
public FwdHamPlayerSpawnPost(id) {
	
	if(!is_user_alive(id)) return HAM_IGNORED;
#if MODE & (1<<0)
	if(!(g_user_privileges[id] & FLAG_A))
#else
	if(!(get_user_flags(id) & VIPACCES))
#endif
		return PLUGIN_HANDLED;

	if(pev(id, pev_armorvalue) < get_pcvar_num(g_armor))
	set_pev(id, pev_armorvalue, float(get_pcvar_num(g_armor)))
	return HAM_IGNORED;
}

public fw_PlayerKilled_Post(victim, attacker) {
#if MODE & (1<<0)
	if(1 <= attacker <= maxplayers && g_user_privileges[attacker] & FLAG_A) {
#else
	if(1 <= attacker <= maxplayers && get_user_flags(attacker) & VIPACCES) {
#endif	
		if(is_user_alive(attacker) && zp_get_user_zombie(attacker) && !(zp_get_user_nemesis(attacker) && get_pcvar_num(g_nemhealth))) set_user_health(attacker, (get_user_health(attacker) + get_pcvar_num(g_infecthealth)))
		zp_set_user_ammo_packs(attacker, zp_get_user_ammo_packs(attacker) + get_pcvar_num(g_killammo))
		
		if(happy_hour_on) {
			
			static frag, ammo
			frag = get_pcvar_num(g_happy_hour_frag)
			ammo = get_pcvar_num(g_happy_hour_ammo)
			
			if(frag) set_user_frags(attacker, get_user_frags(attacker)+frag)
			if(ammo) zp_set_user_ammo_packs(attacker, zp_get_user_ammo_packs(attacker)+ammo)
		}
			
	}
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type) {
	
	if(victim == attacker)
		return HAM_IGNORED
		
	if(damage_type & DMG_HEGRENADE)
		return HAM_IGNORED
	
#if MODE & (1<<0)
	if(g_user_privileges[victim] & FLAG_A) {
#else
	if(get_user_flags(victim) & VIPACCES) {
#endif
		if(damage_type & DMG_FALL && get_pcvar_num(g_fall_damage))
			return HAM_SUPERCEDE;
	}
	
	if(!is_user_connected(attacker))
		return HAM_IGNORED
	
	if(zp_get_user_zombie(attacker) || zp_get_user_survivor(attacker))
		return HAM_IGNORED

#if MODE & (1<<0)
	if(g_user_privileges[attacker] & FLAG_D) {
#else
	if(get_user_flags(attacker) & VIPACCES) {
#endif
		damage *= get_pcvar_float(g_damage_increase)
		SetHamParamFloat(4, damage)
	}
	
#if MODE & (1<<0)
	if(g_user_privileges[attacker] & FLAG_D) {
#else
	if(get_user_flags(attacker) & VIPACCES) {
#endif
		if(get_pcvar_num(g_damage_reward) > 0) {
			g_damage[attacker]+=damage
			if(g_damage[attacker] > get_pcvar_float(g_damage_reward)) {
				zp_set_user_ammo_packs(attacker, zp_get_user_ammo_packs(attacker)+1)
				g_damage[attacker] -= get_pcvar_float(g_damage_reward)
			}
		}	
	}

	return HAM_IGNORED
}

public zp_user_infected_post(id, infector, nemesis) {
	
	setVip()
	if(!(1<=infector<=maxplayers)) return;
	
#if MODE & (1<<0)
	if(g_user_privileges[infector] & FLAG_A) {
#else
	if(get_user_flags(infector) & VIPACCES) {
#endif
		if(is_user_alive(infector)) set_user_health(infector, (get_user_health(infector) + get_pcvar_num(g_infecthealth)))
		zp_set_user_ammo_packs(infector, zp_get_user_ammo_packs(infector) + get_pcvar_num(g_infectammo))
		
		if(happy_hour_on) {
			
			static frag, ammo
			frag = get_pcvar_num(g_happy_hour_frag)
			ammo = get_pcvar_num(g_happy_hour_ammo)
			
			if(frag) set_user_frags(infector, get_user_frags(infector)+frag)
			if(ammo) zp_set_user_ammo_packs(infector, zp_get_user_ammo_packs(infector)+ammo)
		}
	}	
}

public client_connect(id) {
	
	jumpnum[id] = 0
	g_damage[id] = 0.0
	dojump[id] = false
#if MODE & (1<<0)
	set_flags(id)
	if(get_pcvar_num(g_show_vips) == 1 && g_user_privileges[id] & FLAG_A) {
#else
	if(get_pcvar_num(g_show_vips) == 1 && get_user_flags(id) & VIPACCES) {
#endif
		new name[100]
		get_user_name(id, name, 100)
		client_printcolor(0, "/g%L", LANG_PLAYER, "VIP_CONNECTED", name)
	}
#if MODE & (1<<0)
	else {
		static hours[6], hour1s[3], hour2s[3], hour1, hour2, h, m, s
		get_pcvar_string(g_hour, hours, charsmax(hours))
		
		if(equal(hours, "off")) return;
		
		strtok(hours, hour1s, charsmax(hour1s), hour2s, charsmax(hour2s), '-')
		hour1 = str_to_num(hour1s)
		hour2 = str_to_num(hour2s)
		
		time(h, m, s)
		if(hour1 <= h <= hour2) {
			
			new fflags[10]
			get_pcvar_string(g_hour_flags, fflags, charsmax(fflags))
			g_user_privileges[id] = read_flags(fflags)
		}
	}
#endif
}
#if MODE & (1<<1)
public zp_extra_item_selected(id, item_id)
	if(item_id == g_zp_extra_item_number)
		menu_open(id)

public menu_open(id) {
#if MODE & (1<<0)
	if(g_user_privileges[id] & FLAG_E)
		vip_menu(id)
#else
	if(get_user_flags(id) & VIPACCES)
		vip_menu(id)
#endif
#if MODE & (1<<0)
	else if(get_pcvar_num(g_vip_cost_ammo) != 0)
		get_pcvar_num(g_nonvip_tease) ? vip_menu(id) : buy_meniu(id)
#endif
	else client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "NOT_A_VIP")
	return ZP_PLUGIN_HANDLED
}
	
public vip_menu(id)
{
	if(g_registered_items_count == 0) {
		client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "OFF")
		return;
	}
	new holder[150], menu
	formatex(holder, charsmax(holder), "\r%L", id, "MENU_TOP")
	menu = menu_create(holder, "vip_menu_handler")
	new i, team_check, num[3], ammo_packs, check
	check = 0
	ammo_packs = zp_get_user_ammo_packs(id)
	
	switch(zp_get_user_zombie(id)) {
		
		case 0: {
			if(zp_get_user_survivor(id)) team_check = ZP_TEAM_SURVIVOR
			else team_check = ZP_TEAM_HUMAN
		}
		case 1: {
			if(zp_get_user_nemesis(id)) team_check = ZP_TEAM_NEMESIS
			else team_check = ZP_TEAM_ZOMBIE
		}
	}
	
	if(zp_get_user_zombie(id) && !zp_get_user_nemesis(id)) team_check |= FLAG_A
	else if(!zp_get_user_zombie(id)) team_check |= FLAG_B
	else if(zp_get_user_nemesis(id)) team_check |= FLAG_C
	else if(zp_get_user_survivor(id)) team_check |= FLAG_D
	g_team[id] = team_check
	for(i=0; i < g_registered_items_count; i++) {
		ArrayGetArray(items_database, i, extra_items)
		if(extra_items[i_team] == 0 || g_team[id] & extra_items[i_team]) {
			formatex(holder, charsmax(holder), "%s \r[%s] %s[%d %L]", extra_items[i_name], extra_items[i_description], ammo_packs < extra_items[i_cost] ? "\r" : "\y", extra_items[i_cost], id, "AMMO")
			formatex(num, 2, "%d", i)
			menu_additem(menu, holder, num, 0)
			check++
		}
	}
	if(check == 0) {
		client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "NO_ITEMS")
		return;
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	formatex(holder, charsmax(holder), "%L", id, "NEXT")
	menu_setprop(menu, MPROP_NEXTNAME, holder)
	formatex(holder, charsmax(holder), "%L", id, "BACK")
	menu_setprop(menu, MPROP_BACKNAME, holder)
	formatex(holder, charsmax(holder), "%L", id, "EXIT")
	menu_setprop(menu, MPROP_EXITNAME, holder)
	menu_display(id, menu, 0)
}
 
public vip_menu_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
#if MODE & (1<<0)
	if(get_pcvar_num(g_nonvip_tease) && !(g_user_privileges[id] & FLAG_A)) {
#if MODE & (1<<0)
		buy_meniu(id)
#else
		client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "NOT_A_VIP")
#endif
		menu_destroy(menu)
		return PLUGIN_HANDLED;
	}
#else
	if(get_pcvar_num(g_nonvip_tease) && !(get_user_flags(id) & VIPACCES)) {
#if MODE & (1<<0)
		buy_meniu(id)
#else
		client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "NOT_A_VIP")
#endif
		menu_destroy(menu)
		return PLUGIN_HANDLED;
	}
#endif
	new team_check
	switch(zp_get_user_zombie(id)) {
		
		case 0: {
			if(zp_get_user_survivor(id)) team_check = ZP_TEAM_SURVIVOR
			else team_check = ZP_TEAM_HUMAN
		}
		case 1: {
			if(zp_get_user_nemesis(id)) team_check = ZP_TEAM_NEMESIS
			else team_check = ZP_TEAM_ZOMBIE
		}
	}
	
	if(g_team[id] != team_check) {
		
		menu_destroy(menu)
		vip_menu(id)
		return PLUGIN_HANDLED;
	}
	
	new data[6], iName[64], item_id, ammo_packs
	new aaccess, callback
	menu_item_getinfo(menu, item, aaccess, data,5, iName, 63, callback)
	item_id = str_to_num(data)
	ammo_packs = zp_get_user_ammo_packs(id)
	ArrayGetArray(items_database, item_id, extra_items)
	if(ammo_packs >= extra_items[i_cost]) zp_set_user_ammo_packs(id, ammo_packs - extra_items[i_cost])
	else {
		client_printcolor(id, "/g%s %L", CHAT_PREFIX, id, "MISSING_AMMO", extra_items[i_cost]-ammo_packs)
		if(g_menu_close) menu_destroy(menu)
		else vip_menu(id)
		return PLUGIN_HANDLED
	}
	item_id++
	ExecuteForward(g_extra_item_selected, g_forward_return, id, item_id)
	if (g_forward_return >= ZV_PLUGIN_HANDLED)
		zp_set_user_ammo_packs(id, ammo_packs)
	
	if(!g_menu_close) vip_menu(id)
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
}
#endif
#if MODE & (1<<0) && MODE & (1<<1)
public buy_meniu(id)
{
	new holder[150], menu
	formatex(holder, charsmax(holder), "\r%L", id, "BUY_MENU_TOP", get_pcvar_num(g_vip_cost_ammo), get_pcvar_num(g_vip_buy_time))
	menu = menu_create(holder, "buy_menu_handler")
	new callback = menu_makecallback("_menu_callback")
	formatex(holder, charsmax(holder), "%L", id, "BUY_MENU_TYPE1")
	menu_additem(menu, holder)
	formatex(holder, charsmax(holder), "%L", id, "BUY_MENU_TYPE2")
	menu_additem(menu, holder, _, _, callback)
	formatex(holder, charsmax(holder), "%L", id, "BUY_MENU_TYPE3")
	menu_additem(menu, holder)
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	formatex(holder, charsmax(holder), "%L", id, "EXIT")
	menu_setprop(menu, MPROP_EXITNAME, holder)
	menu_display(id, menu, 0)
}
 
public buy_menu_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new ammo_packs = zp_get_user_ammo_packs(id)
	if(item > 0) {
		if(ammo_packs >= get_pcvar_num(g_vip_cost_ammo)) {
			amx_tempadmin(id, item)
			zp_set_user_ammo_packs(id, ammo_packs - get_pcvar_num(g_vip_cost_ammo))
			client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "BOUGHT_VIP", get_pcvar_num(g_vip_buy_time))
			
		}
		else client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "MISSING_AMMO", get_pcvar_num(g_vip_cost_ammo)-ammo_packs)
	}
	else {
		nick_buy_meniu(id)
		return PLUGIN_HANDLED
	}
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public nick_buy_meniu(id)
{
	new buttons_string[16], menu_string[151], menu_item[81], menu, client_password[20]
	get_user_info(id, amx_password_field_string, client_password, charsmax(client_password))
	formatex(menu_string, 150, "\r%L", id, "NICK_BUY_MENU_TOP", client_password)
	menu = menu_create(menu_string, "nick_buy_menu_handler")
	
	formatex(menu_item, 80, "%L", id, "NICK_BUY_MENU_TYPE1")
	menu_additem(menu, menu_item)
	formatex(menu_item, 80, "%L", id, "NICK_BUY_MENU_TYPE2")
	menu_additem(menu, menu_item)
	formatex(menu_item, 80, "%L", id, "NICK_BUY_MENU_TYPE3", get_pcvar_num(g_vip_cost_ammo) ,get_pcvar_num(g_vip_buy_time))
	menu_additem(menu, menu_item)
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	formatex(buttons_string, 15, "%L", id, "BACK")
	menu_setprop(menu, MPROP_EXITNAME, buttons_string)
	menu_display(id, menu, 0)
	
}
 
public nick_buy_menu_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		buy_meniu(id)
		return PLUGIN_HANDLED
	}

	switch(item) {
		case 0: {
			generate_password(id)
			set_task(0.2, "menu_delay", id)
		}
		case 1: nick_buy_meniu_sec(id)
		case 2: {
			
			new ammo_packs = zp_get_user_ammo_packs(id)
			if(ammo_packs >= get_pcvar_num(g_vip_cost_ammo)) {
				amx_tempadmin(id, 0)
				zp_set_user_ammo_packs(id, ammo_packs - get_pcvar_num(g_vip_cost_ammo))
				client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "BOUGHT_VIP", get_pcvar_num(g_vip_buy_time))
			
			}
			else client_printcolor(id, "/g%s /y%L", CHAT_PREFIX, id, "MISSING_AMMO", get_pcvar_num(g_vip_cost_ammo)-ammo_packs)
			
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}
	}
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
}
public nick_buy_meniu_sec(id)
{
	new holder[150], menu
	formatex(holder, charsmax(holder), "\r%L", id, "NICK_BUY_MENU_SEC_TOP")
	menu = menu_create(holder, "nick_buy_menu_sec_handler")
	
	formatex(holder, charsmax(holder), "%L", id, "BACK")
	menu_additem(menu, holder)
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER)
	menu_display(id, menu, 0)
}
 
public nick_buy_menu_sec_handler(id, menu, item)
{
	nick_buy_meniu(id)
	menu_destroy(menu)
	return PLUGIN_HANDLED;
}

public _menu_callback(id, menu, item) {
	
	if(item == 1) {
		new authid[30]
		get_user_authid(id, authid, charsmax(authid))
		if(equal(authid, "STEAM_0", 7)) return ITEM_ENABLED
		else return ITEM_DISABLED
	}
	
	return ITEM_ENABLED
}

public menu_delay(id) nick_buy_meniu(id)
#endif
public message_cur_weapon(msg_id, msg_dest, msg_entity)
{
	if (!get_pcvar_num(g_unlimited_clip)) return
#if MODE & (1<<0)
	if (!(g_user_privileges[msg_entity] & FLAG_C)) return
#else
	if (!(get_user_flags(msg_entity) & VIPACCES)) return
#endif
	if (!is_user_alive(msg_entity) || get_msg_arg_int(1) != 1) return
	
	static weapon, clip
	weapon = get_msg_arg_int(2)
	clip = get_msg_arg_int(3)
	
	if (MAXCLIP[weapon] > 2)
	{
		set_msg_arg_int(3, get_msg_argtype(3), MAXCLIP[weapon])
		
		if (clip < 2)
		{
			static wname[32], weapon_ent
			get_weaponname(weapon, wname, sizeof wname - 1)
			weapon_ent = find_ent_by_owner(-1, wname, msg_entity)
			fm_set_weapon_ammo(weapon_ent, MAXCLIP[weapon])
		}
	}
}

public HUDReset()
	setVip()
	
public setVip()
{
	new players[32], pNum
	get_players(players, pNum, "a")

	for (new i = 0; i < pNum; i++)
	{
		new id = players[i]
#if MODE & (1<<0)	
		if (g_user_privileges[id] & FLAG_A)
#else
		if (get_user_flags(id) & VIPACCES)
#endif
		{
			message_begin(MSG_ALL, get_user_msgid("ScoreAttrib"))
			write_byte(id)
			write_byte(4)
			message_end()
		}
	}
	return PLUGIN_HANDLED
}

public print_adminlist(user) 
{
	new adminnames[33][32]
	new message[256]
	new contactinfo[256], contact[112]
	new id, count, x, len
	
	for(id = 1 ; id <= maxplayers ; id++)
		if(is_user_connected(id))
#if MODE & (1<<0)
			if(g_user_privileges[id] & FLAG_A)
#else
			if(get_user_flags(id) & VIPACCES)
#endif
				get_user_name(id, adminnames[count++], 31)

	len = format(message, 255, "%L ", id, "VIP_STATUS")
	if(count > 0) {
		for(x = 0 ; x < count ; x++) {
			len += format(message[len], 255-len, "%s%s ", adminnames[x], x < (count-1) ? ", ":"")
			if(len > 96 ) {
				client_printcolor(user, "/g%s", message)
				len = format(message, 255, "")
			}
		}
		client_printcolor(user, "/g%s", message)
	}
	else {
		len += format(message[len], 255-len, "%L ", id, "VIP_STATUS_N")
		client_printcolor(user, "/g%s", message)
	}
	
	get_cvar_string("amx_contactinfo", contact, 63)
	if(contact[0])  {
		format(contactinfo, 111, "%L ", id, "VIP_STATUS_CON", contact)
		client_printcolor(user, "/g%s", contactinfo)
	}
	
}

public client_disconnect(id)
{
	jumpnum[id] = 0
	g_damage[id] = 0.0
	dojump[id] = false
}

public client_PreThink(id)
{
#if MODE & (1<<0)
	if(!is_user_alive(id) || !g_jumps || (!(g_user_privileges[id] & FLAG_B))) return PLUGIN_CONTINUE
#else
	if(!is_user_alive(id) || !g_jumps || (!(get_user_flags(id) & MJACCES))) return PLUGIN_CONTINUE
#endif
	static nbut, obut, fflags
	nbut= get_user_button(id)
	obut = get_user_oldbutton(id)
	fflags = get_entity_flags(id)
	
	if((nbut & IN_JUMP) && !(fflags & FL_ONGROUND) && !(obut & IN_JUMP))
	{
		if(jumpnum[id] < chache_g_jumps && 
		((g_bit & FLAG_D && zp_get_user_nemesis(id)) || 
		(g_bit & FLAG_C && zp_get_user_survivor(id)) || 
		(g_bit & FLAG_A && !zp_get_user_zombie(id)) ||
		(g_bit & FLAG_B && zp_get_user_zombie(id) && !zp_get_user_nemesis(id))))
		{
			dojump[id] = true
			jumpnum[id]++
			return PLUGIN_CONTINUE
		}
	}
	if((nbut & IN_JUMP) && (fflags & FL_ONGROUND))
	{
		jumpnum[id] = 0
		return PLUGIN_CONTINUE
	}
	
	return PLUGIN_CONTINUE
}

public client_PostThink(id)
{
#if MODE & (1<<0)
	if(!is_user_alive(id) || !get_pcvar_num(g_jumps) || (!(g_user_privileges[id] & FLAG_B))) return PLUGIN_CONTINUE
#else
	if(!is_user_alive(id) || !get_pcvar_num(g_jumps) || (!(get_user_flags(id) & MJACCES))) return PLUGIN_CONTINUE
#endif
	if(dojump[id] == true)
	{
		static Float:velocity[3]	
		entity_get_vector(id,EV_VEC_velocity,velocity)
		velocity[2] = random_float(265.0,285.0)
		entity_set_vector(id,EV_VEC_velocity,velocity)
		dojump[id] = false
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}	

public ShowMotd(id)
	show_motd(id, "vip.txt")
#if MODE & (1<<0)
public reload_vips() {
	
	if(database_holder) ArrayDestroy(database_holder)
	database_holder = ArrayCreate(database_items)
	new configsDir[64]
	get_configsdir(configsDir, 63)
	format(configsDir, 63, "%s/vips.ini", configsDir)
	
	new File=fopen(configsDir,"r");
	
	if (File)
	{
		static Text[512], Flags[32], AuthData[50], Privileges_Flags[32], Password[50]
		while (!feof(File))
		{
			fgets(File,Text,sizeof(Text)-1);
			
			trim(Text);
			
			// comment
			if (Text[0]==';') 
			{
				continue;
			}
			
			Flags[0]=0;
			AuthData[0]=0;
			Privileges_Flags[0]=0;
			Password[0]=0;
			
			// not enough parameters
			if (parse(Text,AuthData,sizeof(AuthData)-1,Password,sizeof(Password)-1,Privileges_Flags,sizeof(Privileges_Flags)-1,Flags,sizeof(Flags)-1) < 2)
			{
				continue;
			}

			vips_database[auth] = AuthData
			vips_database[password] = Password
			vips_database[accessflags] = read_flags(Privileges_Flags)
			vips_database[flags] = read_flags(Flags)
			ArrayPushArray(database_holder, vips_database)
		}
		
		fclose(File);
	}
	else log_amx("Error: vips.ini file doesn't exist")
}
#endif
#if MODE & (1<<0) && MODE & (1<<1)
public check_date()
{
	new holder[20]
	new y, m ,d
	date(y, m, d)
	format(holder, charsmax(holder), "m%dd%dy%d", m, d, y)

	new configdir[200]
	get_configsdir(configdir,199)

	new configfile1[200]

	format(configfile1,199,"%s/vips.ini",configdir)
	
	new text[512], len
	new pnum = file_size(configfile1,1)
	for(new i = 1; i < pnum; i++)
	{
		read_file(configfile1, i, text, 511, len)
		if ( contain(text, holder) != -1 ) 
		{
			DeleteLine(configfile1, i)
		}
	}
	return PLUGIN_HANDLED
}

public amx_tempadmin(id, type)
{	
	new authid[31], ip[31], name[51], client_password[20], p_flags[21], sdate[20]
	get_pcvar_string(g_vip_buy_flags, p_flags, charsmax(p_flags))
	get_user_authid(id, authid, charsmax(authid))
	get_user_ip(id, ip, charsmax(ip), 1)
	get_user_name(id, name, charsmax(name))
	get_user_info(id, amx_password_field_string, client_password, charsmax(client_password))
	
	get_date(get_pcvar_num(g_vip_buy_time), sdate, charsmax(sdate))
	
	new holder[200]
	switch(type) {
		case 0: formatex(holder, charsmax(holder), "^"%s^" ^"%s^" ^"%s^" ^"b^"; Exp: %s", name, client_password, p_flags, sdate)
		case 1: formatex(holder, charsmax(holder), "^"%s^" ^"^" ^"%s^" ^"ce^"; Exp: %s", authid, p_flags, sdate)
		case 2: formatex(holder, charsmax(holder), "^"%s^" ^"^" ^"%s^" ^"de^"; Exp: %s", ip, p_flags, sdate)
	}
	
	new configdir[200]
	get_configsdir(configdir, 199)
	new configfile1[200]
	format(configfile1,199,"%s/vips.ini",configdir)
	write_file(configfile1, holder, -1)
	server_cmd("amx_reloadvips")
	set_task(1.0, "set_flags", id)
	
}

DeleteLine( const szFilename[ ], const iLine )
{
	new iFile = fopen( szFilename, "rt" );
	if( !iFile )
	{
		return;
	}
	static const szTempFilename[ ] = "delete_line.txt";
	new iTempFile = fopen( szTempFilename, "wt" );
    
	new szData[ 256 ], iLineCount, bool:bReplaced = false;
	while( !feof( iFile ) )
	{
		fgets( iFile, szData, 255 );
        
		if( iLineCount++ == iLine )
		{
			bReplaced = true;
		}
		else
		{
			fputs( iTempFile, szData );
		}
	}
    
	fclose( iFile );
	fclose( iTempFile );
    
	if( bReplaced )
	{
		delete_file( szFilename );
        
		while( !rename_file( szTempFilename, szFilename, 1 ) ) { }
	}
	else
	{
		delete_file( szTempFilename );
	}
}

stock get_date(days, string[], chars) {
	
	new y, m, d
	date(y, m ,d)
	
	d+=days
	
	new go = true
	while(go) {
		switch(m) {
			case 1,3, 5, 7, 8, 10: {
				if(d>31) { d=d-31; m++; }
				else go = false
			}
			case 2: {
				if(d>28) { d=d-28; m++; }
				else go = false
			}
			case 4, 6, 9, 11: {
				if(d>30) { d=d-30; m++; }
				else go = false
			}
			case 12: {
				if(d>31) { d=d-31; y++; m=1; }
				else go = false
			}
		}
	}
	formatex(string, chars, "m%dd%dy%d", m, d ,y)
}
#endif

stock client_printcolor(id, const message[], any:...)
{
	static buffer[512], argscount
	argscount = numargs()
	
	if (!id) {
		
		static players[32], num, player, i, i2
		get_players(players, num , "ch")
			
		for (i = 0; i < num; i++) {
			
			player = players[i]
			
			static changed[5], changedcount
			changedcount = 0
			
			for (i2 = 2; i2 < argscount; i2++)
			{
				if (getarg(i2) == LANG_PLAYER)
				{
					setarg(i2, 0, player)
					changed[changedcount] = i2
					changedcount++
				}
			}
			
			vformat(buffer, charsmax(buffer), message, 3)
			
			replace_all(buffer, charsmax(buffer), "/g", "^4")
			replace_all(buffer, charsmax(buffer), "/y", "^1")
		
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, player)
			write_byte(player)
			write_string(buffer)
			message_end()
			
			for (i2 = 0; i2 < changedcount; i2++)
				setarg(changed[i2], 0, LANG_PLAYER)
		}
	}
	else {
		
		vformat(buffer, charsmax(buffer), message, 3)
		
		replace_all(buffer, charsmax(buffer), "/g", "^4")
		replace_all(buffer, charsmax(buffer), "/y", "^1")
		
		message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, id)
		write_byte(id)
		write_string(buffer)
		message_end()
	}
}

stock fm_find_ent_by_owner(entity, const classname[], owner)
{
	while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) && pev(entity, pev_owner) != owner) {}
	
	return entity;
}

stock fm_set_weapon_ammo(entity, amount)
{
	set_pdata_int(entity, OFFSET_CLIPAMMO, amount, OFFSET_LINUX_WEAPONS);
}
#if MODE & (1<<0)
public set_flags(id) {
	
	static authid[31], ip[31], name[51], index, client_password[30], size, log_flags[11]
	get_user_authid(id, authid, 30)
	get_user_ip(id, ip, 30, 1)
	get_user_name(id, name, 50)
	get_user_info(id, amx_password_field_string, client_password, charsmax(client_password))
	
	g_user_privileges[id] = 0
	size = ArraySize(database_holder)
	for(index=0; index < size ; index++) {
		ArrayGetArray(database_holder, index, vips_database)
		if(vips_database[flags] & FLAG_D) {
			if(equal(ip, vips_database[auth])) {
				if(!(vips_database[flags] & FLAG_E)) {
					if(equal(client_password, vips_database[password]))
						g_user_privileges[id] = vips_database[accessflags]
					else if(vips_database[flags] & FLAG_A) {
						server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "INV_PAS")
						break
					}
				}
				else g_user_privileges[id] = vips_database[accessflags]
				get_flags(vips_database[accessflags], log_flags, 10)
				log_amx("%L",LANG_PLAYER, "AUTHORISED", name, authid, ip, log_flags)
				break
			}
		}
		else if(vips_database[flags] & FLAG_C) {
			if(equal(authid, vips_database[auth])) {
				if(!(vips_database[flags] & FLAG_E)) {
					if(equal(client_password, vips_database[password]))
						g_user_privileges[id] = vips_database[accessflags]
					else if(vips_database[flags] & FLAG_A) {
						server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "INV_PAS")
						break
					}
				}
				else g_user_privileges[id] = vips_database[accessflags]
				get_flags(vips_database[accessflags], log_flags, 10)
				log_amx("%L",LANG_PLAYER, "AUTHORISED", name, authid, ip, log_flags)
				break
			}
		}
		else {
			if(vips_database[flags] & FLAG_K) {
				if((vips_database[flags] & FLAG_B && contain(name, vips_database[auth]) != -1) || equal(name, vips_database[auth])) {
					if(!(vips_database[flags] & FLAG_E)) {
						if(equal(client_password, vips_database[password]))
							g_user_privileges[id] = vips_database[accessflags]
						else if(vips_database[flags] & FLAG_A) {
							server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "INV_PAS")
							break
						}
					}
					else g_user_privileges[id] = vips_database[accessflags]
					get_flags(vips_database[accessflags], log_flags, 10)
					log_amx("%L",LANG_PLAYER, "AUTHORISED", name, authid, ip, log_flags)
					break
				}
			}
			else {
				if((vips_database[flags] & FLAG_B && containi(name, vips_database[auth]) != -1) || equali(name, vips_database[auth])) {
					if(!(vips_database[flags] & FLAG_E)) {
						if(equal(client_password, vips_database[password]))
							g_user_privileges[id] = vips_database[accessflags]
						else if(vips_database[flags] & FLAG_A) {
							server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "INV_PAS")
							break
						}
					}
					else g_user_privileges[id] = vips_database[accessflags]
					get_flags(vips_database[accessflags], log_flags, 10)
					log_amx("%L",LANG_PLAYER, "AUTHORISED", name, authid, ip, log_flags)
					break
				}
			}
		}
	}
}
#endif
#if MODE & (1<<0) && MODE & (1<<1)
stock generate_password(id) {
	
	new password_holder[30]
	formatex(password_holder, charsmax(password_holder), "%d%d%d%d%d", random(10), random(10), random(10), random(10), random(10))
	client_cmd(id, "setinfo %s %s", amx_password_field_string, password_holder)
}
#endif
#if MODE & (1<<0)
public native_zv_get_user_flags(id)
	return g_user_privileges[id]
#endif
#if MODE & (1<<1)
public native_zv_register_extra_item(const item_name[], const item_discription[], item_cost, item_team)
{
		if(!items_database) items_database = ArrayCreate(items)
		
		param_convert(1)
		param_convert(2)
		copy(extra_items[i_name], 30, item_name)
		copy(extra_items[i_description], 30, item_discription)
		extra_items[i_cost] = item_cost
		extra_items[i_team] = item_team
		ArrayPushArray(items_database, extra_items)
		g_registered_items_count++

		return g_registered_items_count
}

public plugin_end() if(items_database) ArrayDestroy(items_database)
#endif

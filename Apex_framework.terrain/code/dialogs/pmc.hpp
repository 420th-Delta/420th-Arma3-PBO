/* Private Military Company dialogs */
class QS_RD_PMC_Button: QS_RD_dialog_RscButton {
	colorText[]={1,1,1,1};
};
class QS_RD_PMC_Label: QS_RD_dialog_RscText {
	colorText[]={1,1,1,1};
	colorBackground[]={0,0,0,0};
};
class QS_RD_PMC_Edit: QS_RD_dialog_RscEdit {
	style=0;
	colorText[]={0.95,0.95,0.95,1};
	colorBackground[]={0.12,0.12,0.12,1};
};
class QS_RD_PMC_Combo: QS_RD_dialog_RscCombo_2 {
	colorText[]={1,1,1,1};
	colorBackground[]={0,0,0,0.5};
	colorSelectBackground[]={1,1,1,0.7};
	sizeEx=0.03;
	wholeHeight=0.45;
};
class QS_RD_PMC_Base {
	idd = -1;
	movingEnable = 1;
	enableSimulation = 1;
	class controls {
		class Frame: QS_RD_dialog_RscFrame {idc=-1; x=0.25*safezoneW+safezoneX; y=0.18*safezoneH+safezoneY; w=0.50*safezoneW; h=0.64*safezoneH; colorBackground[]={0,0,0,0.7}; colorDisabled[]={1,1,1,0.25};};
		class Background: QS_RD_dialog_Box {idc=-1; x=0.25*safezoneW+safezoneX; y=0.18*safezoneH+safezoneY; w=0.50*safezoneW; h=0.64*safezoneH; colorBackground[]={0,0,0,0.5};};
		class Title: QS_RD_dialog_RscText {idc=-1; text="PMC"; x=0.27*safezoneW+safezoneX; y=0.20*safezoneH+safezoneY; w=0.46*safezoneW; h=0.05*safezoneH; sizeEx=0.05; style=2; colorText[]={1,1,1,1};};
	};
};
class QS_RD_client_dialog_pmc: QS_RD_PMC_Base {
	idd=55000;
	onLoad="['onLoad',_this#0] call QS_fnc_clientMenuPMC";
	onUnload="['onUnload',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {idc=5501;};
		class Members: QS_RD_dialog_RscListNBox {idc=5502; x=0.28*safezoneW+safezoneX; y=0.27*safezoneH+safezoneY; w=0.44*safezoneW; h=0.42*safezoneH; columns[]={0.02,0.68};};
		class Invite: QS_RD_PMC_Button {idc=5503; text="Invite Player"; x=0.28*safezoneW+safezoneX; y=0.73*safezoneH+safezoneY; w=0.13*safezoneW; h=0.045*safezoneH; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_invite'] call QS_fnc_clientMenuPMC";};
		class Leave: QS_RD_PMC_Button {idc=5504; text="Leave PMC"; x=0.435*safezoneW+safezoneX; y=0.73*safezoneH+safezoneY; w=0.13*safezoneW; h=0.045*safezoneH; onButtonClick="['LEAVE_OPEN'] call QS_fnc_clientMenuPMC";};
		class Manage: QS_RD_PMC_Button {idc=5505; text="Manage PMC"; x=0.59*safezoneW+safezoneX; y=0.73*safezoneH+safezoneY; w=0.13*safezoneW; h=0.045*safezoneH; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_manage'] call QS_fnc_clientMenuPMC";};
		class Create: QS_RD_PMC_Button {idc=5506; text="Create PMC"; x=0.42*safezoneW+safezoneX; y=0.48*safezoneH+safezoneY; w=0.16*safezoneW; h=0.05*safezoneH; onButtonClick="['CREATE_OPEN'] call QS_fnc_clientMenuPMC";};
	};
};
class QS_RD_client_dialog_pmc_create: QS_RD_PMC_Base {
	idd=55100; onLoad="(_this#0 displayCtrl 5510) ctrlSetText ''";
	class controls: controls {
		class Title: Title {text="Create PMC";};
		class Label: QS_RD_PMC_Label {idc=-1; text="PMC Name"; x=0.35*safezoneW+safezoneX; y=0.36*safezoneH+safezoneY; w=0.30*safezoneW; h=0.035*safezoneH;};
		class Name: QS_RD_PMC_Edit {idc=5510; text=""; x=0.35*safezoneW+safezoneX; y=0.40*safezoneH+safezoneY; w=0.30*safezoneW; h=0.05*safezoneH;};
		class Create: QS_RD_PMC_Button {idc=5511; text="Create"; x=0.42*safezoneW+safezoneX; y=0.49*safezoneH+safezoneY; w=0.16*safezoneW; h=0.05*safezoneH; onButtonClick="['CREATE_SUBMIT',_this#0] call QS_fnc_clientMenuPMC";};
	};
};
class QS_RD_client_dialog_pmc_invite: QS_RD_PMC_Base {
	idd=55200; onLoad="['INVITE_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Invite Player";};
		class Players: QS_RD_dialog_RscListBox {idc=5520; x=0.30*safezoneW+safezoneX; y=0.27*safezoneH+safezoneY; w=0.40*safezoneW; h=0.40*safezoneH;};
		class Send: QS_RD_PMC_Button {idc=5521; text="Send Invite"; x=0.32*safezoneW+safezoneX; y=0.72*safezoneH+safezoneY; w=0.16*safezoneW; h=0.05*safezoneH; onButtonClick="['INVITE_SEND',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: QS_RD_PMC_Button {idc=5522; text="Exit"; x=0.52*safezoneW+safezoneX; y=0.72*safezoneH+safezoneY; w=0.16*safezoneW; h=0.05*safezoneH; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_manage: QS_RD_PMC_Base {
	idd=55300; onLoad="['MANAGE_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Manage PMC";};
		class Rename: QS_RD_PMC_Button {idc=5530; text="Change PMC Name"; x=0.37*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.26*safezoneW; h=0.05*safezoneH; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_rename'] call QS_fnc_clientMenuPMC";};
		class Ranks: Rename {idc=5531; text="Manage Ranks"; y=0.345*safezoneH+safezoneY; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_ranks'] call QS_fnc_clientMenuPMC";};
		class Members: Rename {idc=5532; text="Manage Members"; y=0.41*safezoneH+safezoneY; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_members'] call QS_fnc_clientMenuPMC";};
		class Skins: Rename {idc=5533; text="Manage Skins"; y=0.475*safezoneH+safezoneY; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_skins'] call QS_fnc_clientMenuPMC";};
		class Transfer: Rename {idc=5534; text="Transfer Ownership"; y=0.54*safezoneH+safezoneY; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_transfer'] call QS_fnc_clientMenuPMC";};
		class Disband: Rename {idc=5535; text="Disband PMC"; y=0.605*safezoneH+safezoneY; onButtonClick="['CONFIRM',['DISBAND',0]] call QS_fnc_clientMenuPMC";};
		class Exit: Rename {idc=5536; text="Exit"; y=0.69*safezoneH+safezoneY; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_rename: QS_RD_PMC_Base {
	idd=55400; onLoad="['RENAME_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Change PMC Name";};
		class Name: QS_RD_PMC_Edit {idc=5540; x=0.34*safezoneW+safezoneX; y=0.38*safezoneH+safezoneY; w=0.32*safezoneW; h=0.05*safezoneH;};
		class Save: QS_RD_PMC_Button {idc=5541; text="Save"; x=0.34*safezoneW+safezoneX; y=0.49*safezoneH+safezoneY; w=0.14*safezoneW; h=0.05*safezoneH; onButtonClick="['RENAME_SAVE',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: Save {idc=5542; text="Exit"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_ranks: QS_RD_PMC_Base {
	idd=55500; onLoad="['RANKS_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Manage Ranks";};
		class Rank: QS_RD_PMC_Combo {idc=5550; x=0.30*safezoneW+safezoneX; y=0.27*safezoneH+safezoneY; w=0.31*safezoneW; h=0.045*safezoneH; onLBSelChanged="['RANK_SELECT',_this#0,_this#1] call QS_fnc_clientMenuPMC";};
		class New: QS_RD_PMC_Button {idc=5551; text="New"; x=0.62*safezoneW+safezoneX; y=0.27*safezoneH+safezoneY; w=0.08*safezoneW; h=0.045*safezoneH; onButtonClick="['RANK_NEW',_this#0] call QS_fnc_clientMenuPMC";};
		class RankName: QS_RD_PMC_Edit {idc=5552; x=0.30*safezoneW+safezoneX; y=0.34*safezoneH+safezoneY; w=0.25*safezoneW; h=0.045*safezoneH;};
		class Hierarchy: QS_RD_PMC_Combo {idc=5553; x=0.57*safezoneW+safezoneX; y=0.34*safezoneH+safezoneY; w=0.13*safezoneW; h=0.045*safezoneH; tooltip="Rank Hierarchy";};
		class HierarchyLabel: QS_RD_PMC_Label {idc=-1; text="Rank Hierarchy"; x=0.57*safezoneW+safezoneX; y=0.315*safezoneH+safezoneY; w=0.13*safezoneW; h=0.025*safezoneH; sizeEx=0.026;};
		class P1: QS_RD_PMC_Label {idc=-1; text="Invite Player"; x=0.34*safezoneW+safezoneX; y=0.42*safezoneH+safezoneY; w=0.24*safezoneW; h=0.04*safezoneH;};
		class C1: QS_RD_RscCheckbox {idc=5554; x=0.60*safezoneW+safezoneX; y=0.42*safezoneH+safezoneY; w=0.03*safezoneW; h=0.04*safezoneH;};
		class P2: P1 {text="Manage Members"; y=0.47*safezoneH+safezoneY;}; class C2: C1 {idc=5555; y=0.47*safezoneH+safezoneY;};
		class P3: P1 {text="Manage Ranks"; y=0.52*safezoneH+safezoneY;}; class C3: C1 {idc=5556; y=0.52*safezoneH+safezoneY;};
		class P4: P1 {text="Manage Skins"; y=0.57*safezoneH+safezoneY;}; class C4: C1 {idc=5557; y=0.57*safezoneH+safezoneY;};
		class Save: QS_RD_PMC_Button {idc=5558; text="Save"; x=0.42*safezoneW+safezoneX; y=0.66*safezoneH+safezoneY; w=0.16*safezoneW; h=0.05*safezoneH; onButtonClick="['RANK_SAVE',_this#0] call QS_fnc_clientMenuPMC";};
	};
};
class QS_RD_client_dialog_pmc_members: QS_RD_PMC_Base {
	idd=55600; onLoad="['MEMBERS_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Manage Members";};
		class Members: QS_RD_dialog_RscListNBox {idc=5560; x=0.29*safezoneW+safezoneX; y=0.27*safezoneH+safezoneY; w=0.42*safezoneW; h=0.40*safezoneH; columns[]={0.02,0.68};};
		class Eject: QS_RD_PMC_Button {idc=5561; text="Eject Member"; x=0.31*safezoneW+safezoneX; y=0.72*safezoneH+safezoneY; w=0.17*safezoneW; h=0.05*safezoneH; onButtonClick="['MEMBER_EJECT',_this#0] call QS_fnc_clientMenuPMC";};
		class Modify: Eject {idc=5562; text="Modify Rank"; x=0.52*safezoneW+safezoneX; onButtonClick="['MEMBER_RANK',_this#0] call QS_fnc_clientMenuPMC";};
	};
};
class QS_RD_client_dialog_pmc_changeRank: QS_RD_PMC_Base {
	idd=55700; onLoad="['CHANGE_RANK_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {idc=5571; text="Change Member's Rank";};
		class Ranks: QS_RD_dialog_RscListBox {idc=5570; x=0.31*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.38*safezoneW; h=0.36*safezoneH;};
		class Save: QS_RD_PMC_Button {idc=5572; text="Save"; x=0.33*safezoneW+safezoneX; y=0.70*safezoneH+safezoneY; w=0.15*safezoneW; h=0.05*safezoneH; onButtonClick="['CHANGE_RANK_SAVE',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: Save {idc=5573; text="Exit"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_skins: QS_RD_PMC_Base {
	idd=55800; onLoad="['SKINS_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Manage Skins";};
		class Skins: QS_RD_dialog_RscListBox {idc=5580; x=0.31*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.38*safezoneW; h=0.36*safezoneH;};
		class Add: QS_RD_PMC_Button {idc=5581; text="Add Skin"; x=0.33*safezoneW+safezoneX; y=0.70*safezoneH+safezoneY; w=0.15*safezoneW; h=0.05*safezoneH; onButtonClick="['OPEN','QS_RD_client_dialog_pmc_addSkin'] call QS_fnc_clientMenuPMC";};
		class Remove: Add {idc=5582; text="Remove Skin"; x=0.52*safezoneW+safezoneX; onButtonClick="['SKIN_REMOVE',_this#0] call QS_fnc_clientMenuPMC";};
	};
};
class QS_RD_client_dialog_pmc_addSkin: QS_RD_PMC_Base {
	idd=55900; onLoad="['ADD_SKIN_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Add Skin";};
		class Skins: QS_RD_dialog_RscListBox {idc=5590; x=0.31*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.38*safezoneW; h=0.36*safezoneH;};
		class Add: QS_RD_PMC_Button {idc=5591; text="Add"; x=0.33*safezoneW+safezoneX; y=0.70*safezoneH+safezoneY; w=0.15*safezoneW; h=0.05*safezoneH; onButtonClick="['ADD_SKIN_SAVE',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: Add {idc=5592; text="Exit"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_confirm: QS_RD_PMC_Base {
	idd=56000; onLoad="['CONFIRM_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {idc=5601; text="Are You Sure?";};
		class Yes: QS_RD_PMC_Button {idc=5602; text="Yes"; x=0.34*safezoneW+safezoneX; y=0.48*safezoneH+safezoneY; w=0.14*safezoneW; h=0.055*safezoneH; onButtonClick="['CONFIRM_YES',_this#0] call QS_fnc_clientMenuPMC";};
		class No: Yes {idc=5603; text="No"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_transfer: QS_RD_PMC_Base {
	idd=56100; onLoad="['TRANSFER_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="Transfer Ownership";};
		class Members: QS_RD_dialog_RscListBox {idc=5610; x=0.31*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.38*safezoneW; h=0.36*safezoneH;};
		class Save: QS_RD_PMC_Button {idc=5611; text="Transfer"; x=0.33*safezoneW+safezoneX; y=0.70*safezoneH+safezoneY; w=0.15*safezoneW; h=0.05*safezoneH; onButtonClick="['TRANSFER_SAVE',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: Save {idc=5612; text="Exit"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};
class QS_RD_client_dialog_pmc_useSkins: QS_RD_PMC_Base {
	idd=56200; onLoad="['PMC_SKINS_LOAD',_this#0] call QS_fnc_clientMenuPMC";
	class controls: controls {
		class Title: Title {text="PMC Skins";};
		class Skins: QS_RD_dialog_RscListBox {idc=5620; x=0.31*safezoneW+safezoneX; y=0.28*safezoneH+safezoneY; w=0.38*safezoneW; h=0.36*safezoneH;};
		class Apply: QS_RD_PMC_Button {idc=5621; text="Apply"; x=0.33*safezoneW+safezoneX; y=0.70*safezoneH+safezoneY; w=0.15*safezoneW; h=0.05*safezoneH; onButtonClick="['PMC_SKIN_APPLY',_this#0] call QS_fnc_clientMenuPMC";};
		class Exit: Apply {idc=5622; text="Exit"; x=0.52*safezoneW+safezoneX; onButtonClick="closeDialog 2";};
	};
};

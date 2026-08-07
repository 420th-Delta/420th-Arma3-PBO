/*
	Role-restricted object spawn menu.
	The base control classes used here are declared in description.ext.
*/
class QS_RD_client_dialog_spawnMenu {
	idd = 42100;
	movingEnable = 0;
	enableSimulation = 1;
	onLoad = "['LOAD',(_this # 0)] call QS_fnc_spawnMenu;";
	onUnload = "uiNamespace setVariable ['QS_spawnMenu_display',displayNull];";

	class controlsBackground {
		class Background: QS_RD_dialog_Box {
			idc = -1;
			x = "0.20 * safezoneW + safezoneX";
			y = "0.16 * safezoneH + safezoneY";
			w = "0.60 * safezoneW";
			h = "0.68 * safezoneH";
			colorBackground[] = {0.02,0.02,0.02,0.94};
		};
		class Header: QS_RD_dialog_Box {
			idc = -1;
			x = "0.20 * safezoneW + safezoneX";
			y = "0.16 * safezoneH + safezoneY";
			w = "0.60 * safezoneW";
			h = "0.055 * safezoneH";
			colorBackground[] = {0.02,0.02,0.02,0.94};
		};
	};

	class controls {
		class Title: QS_RD_dialog_RscText {
			idc = -1;
			text = "SPAWN MENU";
			x = "0.215 * safezoneW + safezoneX";
			y = "0.167 * safezoneH + safezoneY";
			w = "0.25 * safezoneW";
			h = "0.035 * safezoneH";
			sizeEx = "0.027 * safezoneH";
			colorText[] = {1,1,1,1};
		};
		class Role: QS_RD_dialog_RscText {
			idc = 42101;
			text = "";
			style = 1;
			x = "0.48 * safezoneW + safezoneX";
			y = "0.167 * safezoneH + safezoneY";
			w = "0.30 * safezoneW";
			h = "0.035 * safezoneH";
			sizeEx = "0.019 * safezoneH";
			colorText[] = {1,1,1,1};
		};
		class VehicleList: QS_RD_dialog_RscListBox {
			idc = 42102;
			x = "0.215 * safezoneW + safezoneX";
			y = "0.275 * safezoneH + safezoneY";
			w = "0.31 * safezoneW";
			h = "0.48 * safezoneH";
			sizeEx = "0.020 * safezoneH";
			onLBSelChanged = "['SELECT',(_this # 0),(_this # 1)] call QS_fnc_spawnMenu;";
		};
		class CategoryAll: QS_RD_dialog_RscButton {
			idc = 42110;
			text = "ALL";
			x = "0.215 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.055 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','All'] call QS_fnc_spawnMenu;";
		};
		class CategoryGround: QS_RD_dialog_RscButton {
			idc = 42111;
			text = "GROUND";
			x = "0.275 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.075 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','Ground'] call QS_fnc_spawnMenu;";
		};
		class CategoryHelicopter: QS_RD_dialog_RscButton {
			idc = 42112;
			text = "HELICOPTER";
			x = "0.355 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.095 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','Helicopter'] call QS_fnc_spawnMenu;";
		};
		class CategoryVTOL: QS_RD_dialog_RscButton {
			idc = 42113;
			text = "VTOL";
			x = "0.455 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.060 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','VTOL'] call QS_fnc_spawnMenu;";
		};
		class CategoryPlane: QS_RD_dialog_RscButton {
			idc = 42114;
			text = "PLANE";
			x = "0.520 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.070 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','Plane'] call QS_fnc_spawnMenu;";
		};
		class CategoryAI: QS_RD_dialog_RscButton {
			idc = 42115;
			text = "AI";
			x = "0.595 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.050 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','AI'] call QS_fnc_spawnMenu;";
		};
		class CategorySupply: QS_RD_dialog_RscButton {
			idc = 42116;
			text = "SUPPLY";
			x = "0.650 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.080 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','Supply'] call QS_fnc_spawnMenu;";
		};
		class CategoryBoat: QS_RD_dialog_RscButton {
			idc = 42117;
			text = "BOAT";
			x = "0.735 * safezoneW + safezoneX";
			y = "0.225 * safezoneH + safezoneY";
			w = "0.050 * safezoneW";
			h = "0.035 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['CATEGORY','Boat'] call QS_fnc_spawnMenu;";
		};
		class Preview: QS_RD_dialog_RscPictureKeepAspect {
			idc = 42103;
			text = "";
			x = "0.545 * safezoneW + safezoneX";
			y = "0.285 * safezoneH + safezoneY";
			w = "0.235 * safezoneW";
			h = "0.18 * safezoneH";
		};
		class VehicleName: QS_RD_dialog_RscText {
			idc = 42104;
			text = "Select a vehicle";
			style = 2;
			x = "0.545 * safezoneW + safezoneX";
			y = "0.48 * safezoneH + safezoneY";
			w = "0.235 * safezoneW";
			h = "0.04 * safezoneH";
			sizeEx = "0.023 * safezoneH";
			colorText[] = {1,1,1,1};
		};
		class Details: QS_RD_RscStructuredText {
			idc = 42105;
			text = "";
			x = "0.545 * safezoneW + safezoneX";
			y = "0.525 * safezoneH + safezoneY";
			w = "0.235 * safezoneW";
			h = "0.12 * safezoneH";
			size = "0.018 * safezoneH";
			colorText[] = {1,1,1,1};
		};
		class Spawn: QS_RD_dialog_RscButton {
			idc = 42106;
			text = "SPAWN";
			x = "0.545 * safezoneW + safezoneX";
			y = "0.675 * safezoneH + safezoneY";
			w = "0.11 * safezoneW";
			h = "0.045 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "['SPAWN'] call QS_fnc_spawnMenu;";
		};
		class Close: QS_RD_dialog_RscButton {
			idc = -1;
			text = "CLOSE";
			x = "0.67 * safezoneW + safezoneX";
			y = "0.675 * safezoneH + safezoneY";
			w = "0.11 * safezoneW";
			h = "0.045 * safezoneH";
			colorText[] = {1,1,1,1};
			onButtonClick = "closeDialog 2;";
		};
	};
};

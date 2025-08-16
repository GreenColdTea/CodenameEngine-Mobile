package funkin.backend.system.framerate;

import funkin.backend.system.Logs;
import funkin.backend.utils.MemoryUtil;
import funkin.backend.utils.native.HiddenProcess;
#if cpp
import cpp.Float64;
import cpp.UInt64;
#end

using StringTools;

class SystemInfo extends FramerateCategory {
	public static var osInfo:String = "Unknown";
	public static var gpuName:String = "Unknown";
	public static var vRAM:String = "Unknown";
	public static var cpuName:String = "Unknown";
	public static var totalMem:String = "Unknown";
	public static var memType:String = "Unknown";
	public static var gpuMaxSize:String = "Unknown";

	static var __formattedSysText:String = "";

	public static function init() {
		#if linux
		var process = new HiddenProcess("cat", ["/etc/os-release"]);
		if (process.exitCode() != 0) Logs.error('Unable to grab OS Label');
		else {
			var osName = "";
			var osVersion = "";
			for (line in process.stdout.readAll().toString().split("\n")) {
				if (line.startsWith("PRETTY_NAME=")) {
					var index = line.indexOf('"');
					if (index != -1)
						osName = line.substring(index + 1, line.lastIndexOf('"'));
					else {
						var arr = line.split("=");
						arr.shift();
						osName = arr.join("=");
					}
				}
				if (line.startsWith("VERSION=")) {
					var index = line.indexOf('"');
					if (index != -1)
						osVersion = line.substring(index + 1, line.lastIndexOf('"'));
					else {
						var arr = line.split("=");
						arr.shift();
						osVersion = arr.join("=");
					}
				}
			}
			if (osName != "")
				osInfo = '${osName} ${osVersion}'.trim();
		}
		#elseif windows
		var windowsCurrentVersionPath = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";
		var buildNumber = Std.parseInt(RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "CurrentBuildNumber"));
		var edition = RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "ProductName");

		var lcuKey = "WinREVersion"; // Last Cumulative Update Key On Older Windows Versions
		if (buildNumber >= 22000) { // Windows 11 Initial Release Build Number
			edition = edition.replace("Windows 10", "Windows 11");
			lcuKey = "LCUVer"; // Last Cumulative Update Key On Windows 11
		}

		var lcuVersion = RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, lcuKey);

		osInfo = edition;

		if (lcuVersion != null && lcuVersion != "")
			osInfo += ' ${lcuVersion}';
		else if (lime.system.System.platformVersion != null && lime.system.System.platformVersion != "")
			osInfo += ' ${lime.system.System.platformVersion}';
		#elseif android
		var osName = lime.system.System.platformLabel;
        var osVersion = lime.system.System.platformVersion;
        var rom = detectROM();

		osInfo = osName + "(" + osVersion + ")" + " - " + rom;
		#else
		if (lime.system.System.platformLabel != null && lime.system.System.platformLabel != "" && lime.system.System.platformVersion != null && lime.system.System.platformVersion != "")
			osInfo = '${lime.system.System.platformLabel.replace(lime.system.System.platformVersion, "").trim()} ${lime.system.System.platformVersion}';
		else
			Logs.error('Unable to grab OS Label');
		#end

		try {
			#if windows
			cpuName = RegistryUtil.get(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "ProcessorNameString");
			#elseif mac
			var process = new HiddenProcess("sysctl -a | grep brand_string"); // Somehow this isn't able to use the args but it still works
			if (process.exitCode() != 0) throw 'Could not fetch CPU information';

			cpuName = process.stdout.readAll().toString().trim().split(":")[1].trim();
			#elseif linux
			var process = new HiddenProcess("cat", ["/proc/cpuinfo"]);
			if (process.exitCode() != 0) throw 'Could not fetch CPU information';

			for (line in process.stdout.readAll().toString().split("\n")) {
				if (line.indexOf("model name") == 0) {
					cpuName = line.substring(line.indexOf(":") + 2);
					break;
				}
			}
			#end
		} catch (e) {
			Logs.error('Unable to grab CPU Name: $e');
		}

		@:privateAccess if(FlxG.renderTile) { // Blit doesn't enable the gpu. Idk if we should fix this
			if (flixel.FlxG.stage.context3D != null && flixel.FlxG.stage.context3D.gl != null) {
				gpuName = Std.string(flixel.FlxG.stage.context3D.gl.getParameter(flixel.FlxG.stage.context3D.gl.RENDERER)).split("/")[0].trim();
				#if !flash
				var size = FlxG.bitmap.maxTextureSize;
				gpuMaxSize = size+"x"+size;
				#end

				if(openfl.display3D.Context3D.__glMemoryTotalAvailable != -1) {
					var vRAMBytes:Int = cast flixel.FlxG.stage.context3D.gl.getParameter(openfl.display3D.Context3D.__glMemoryTotalAvailable);
					if (vRAMBytes == 1000 || vRAMBytes == 1 || vRAMBytes <= 0)
						Logs.trace('Unable to grab GPU VRAM', ERROR, RED);
					else {
						var vRAMBytesFloat:#if cpp Float64 #else Float #end = vRAMBytes*1024;
						vRAM = CoolUtil.getSizeString64(vRAMBytesFloat);
					}
				}
			} else
				Logs.error('Unable to grab GPU Info');
		}

		#if cpp
		totalMem = Std.string(MemoryUtil.getTotalMem() / 1024) + " GB";
		#else
		Logs.error('Unable to grab RAM Amount');
		#end

		try {
			memType = MemoryUtil.getMemType();
		} catch (e) {
			Logs.error('Unable to grab RAM Type: $e');
		}
		formatSysInfo();
	}

	static function formatSysInfo() {
		__formattedSysText = "";
		if (osInfo != "Unknown") __formattedSysText += 'System: $osInfo';
		if (cpuName != "Unknown") __formattedSysText += '\nCPU: $cpuName ${openfl.system.Capabilities.cpuArchitecture} ${(openfl.system.Capabilities.supports64BitProcesses ? '64-Bit' : '32-Bit')}';
		if (gpuName != cpuName || vRAM != "Unknown") {
			var gpuNameKnown = gpuName != "Unknown" && gpuName != cpuName;
			var vramKnown = vRAM != "Unknown";

			if(gpuNameKnown || vramKnown) __formattedSysText += "\n";

			if(gpuNameKnown) __formattedSysText += 'GPU: $gpuName';
			if(gpuNameKnown && vramKnown) __formattedSysText += " | ";
			if(vramKnown) __formattedSysText += 'VRAM: $vRAM'; // 1000 bytes of vram (apus)
		}
		//if (gpuMaxSize != "Unknown") __formattedSysText += '\nMax Bitmap Size: $gpuMaxSize';
		if (totalMem != "Unknown" && memType != "Unknown") __formattedSysText += '\nTotal MEM: $totalMem $memType';
	}

	public function new() {
		super("System Info");
	}

	public override function __enterFrame(t:Int) {
		if (alpha <= 0.05) return;

		_text = __formattedSysText;
		_text += '${__formattedSysText == "" ? "" : "\n"}Garbage Collector: ${MemoryUtil.disableCount > 0 ? "OFF" : "ON"} (${MemoryUtil.disableCount})';

		this.text.text = _text;
		super.__enterFrame(t);
	}

	#if android
	static var sysPropGet = lime.system.JNI.createStaticMethod(
        "android/os/SystemProperties",
        "get",
        "(Ljava/lang/String;)Ljava/lang/String;"
    );

    static function getProp(key:String):String {
        try {
            return sysPropGet([key]);
        } catch (e:Dynamic) {
            return "";
        }
    }

    // --- Build fields ---
    static var buildManufacturer = lime.system.JNI.createStaticField("android/os/Build", "MANUFACTURER", "Ljava/lang/String;");
    static var buildBrand        = lime.system.JNI.createStaticField("android/os/Build", "BRAND", "Ljava/lang/String;");
    static var buildDisplay      = lime.system.JNI.createStaticField("android/os/Build", "DISPLAY", "Ljava/lang/String;");

    static function getBuildField(field:String):String {
        try {
            return switch (field) {
                case "MANUFACTURER": cast buildManufacturer;
                case "BRAND": cast buildBrand;
                case "DISPLAY": cast buildDisplay;
                default: "";
            }
        } catch (e:Dynamic) {
            return "";
        }
    }

    static function detectROM():String {
        var oneui = getProp("ro.build.version.oneui");
        if (oneui != "") return "OneUI " + oneui;

        var miui = getProp("ro.miui.ui.version.name");
        if (miui != "") {
            if (miui.toLowerCase().indexOf("hyper") != -1) return "HyperOS " + miui;
            return "MIUI " + miui;
        }

        var coloros = getProp("ro.build.version.opporom");
        if (coloros != "") return "ColorOS " + coloros;

        var oxygen = getProp("ro.oxygen.version");
        if (oxygen != "") return "OxygenOS " + oxygen;

        var vivo = getProp("ro.vivo.os.version");
        if (vivo != "") {
            if (vivo.toLowerCase().indexOf("origin") != -1) return "OriginOS " + vivo;
            return "Funtouch OS " + vivo;
        }

        var magic = getProp("ro.build.version.magic");
        if (magic != "") {
            if (magic.toLowerCase().indexOf("harmony") != -1) return "HarmonyOS " + magic;
            return "MagicOS " + magic;
        }

        var hios = getProp("ro.hios.id");
        if (hios != "") return "HiOS " + hios;

        // Fallback: use build fields
        var manufacturer = getBuildField("MANUFACTURER").toLowerCase();
        var brand = getBuildField("BRAND").toLowerCase();
        var display = getBuildField("DISPLAY").toLowerCase();

        if (manufacturer.indexOf("samsung") != -1) return "OneUI (detected by manufacturer)";
        if (manufacturer.indexOf("xiaomi") != -1 || brand.indexOf("redmi") != -1) {
            if (display.indexOf("hyperos") != -1) return "HyperOS";
            return "MIUI";
        }
        if (manufacturer.indexOf("huawei") != -1 || manufacturer.indexOf("honor") != -1) {
            if (display.indexOf("harmony") != -1) return "HarmonyOS";
            return "EMUI / MagicOS";
        }
        if (manufacturer.indexOf("oppo") != -1 || manufacturer.indexOf("realme") != -1) return "ColorOS";
        if (manufacturer.indexOf("oneplus") != -1) return "OxygenOS";
        if (manufacturer.indexOf("vivo") != -1 || brand.indexOf("iqoo") != -1) return "Funtouch OS / OriginOS";
        if (manufacturer.indexOf("tecno") != -1 || manufacturer.indexOf("infinix") != -1) return "HiOS";

        return "";
    }
	#end
}
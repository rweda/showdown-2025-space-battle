\m5_TLV_version 1d: tl-x.org
\m5
   / A template for players/teams to compete in:
   /
   / /----------------------------------------------------------------------------\
   / | The First Annual Makerchip ASIC Design Showdown, Summer 2025, Space Battle |
   / \----------------------------------------------------------------------------/
   /
   / Showdown details: https://www.redwoodeda.com/showdown-info and in the repository README.
   /
   / Each team provides their control logic in a file on GitHub based on:
   / https://github.com/rweda/showdown-2025-space-battle/blob/main/showdown_template.tlv
   /
   / Instructions for configuring the battle: Follow STEP 1 and STEP 2 below.

   use(m5-1.0)
   
   var(VIZ_mode, demo)  /// Enables VIZ for development.
                        /// Use "devel" or "demo". ("demo" will be used in competition.)
\SV
   // STEP 1: Include URLs for the player circuits (raw files from GitHub).
   ///m4_include_lib(https://raw.githubusercontent.com/amitops2103/verilog-space-commander/refs/heads/main/control_logic.sv)
   m4_include_lib(https://raw.githubusercontent.com/blackbolt-gt/ASIC_Showdown_Submission/refs/heads/main/space_battle_finale_v4.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Sanjitha-Manivelan/Bionic-Beavers/refs/heads/main/Bionic_Beavers.tlv)
   m4_include_lib(https://raw.githubusercontent.com/kiru234/Space_Battle_2025/refs/heads/main/F4.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Jacome1005/Verifast_TL-VERILOG_Showdown/refs/heads/main/showdown_template.tlv)
   ///m4_include_lib(https://raw.githubusercontent.com/yeshwanthkattta/Hunter_Showdown/refs/heads/main/triangle_team_verilog.tlv)

   // Include the Showdown framework.
   m4_include_lib(https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/2eb3c397252e0ce371180e4c8c225cddca6dff86/showdown_lib.tlv)
   
   m5_makerchip_module
\TLV

   // STEP 2: Enlist teams for battle.
   // Replace GITHUB_IDs and TEAM_NAMEs matching the included files.
   //
   /// BROKEN m5_team(amitops2103, verilog-space-commander)   /// BROKEN. Undefined M5 vars (Gamer)
   ///m5_team(209916212,  fleetRON)        /// blackbolt-gt
   m5_team(60561724,   Bionic Beavers)   /// Sanjitha-Manivelan
   m5_team(kiru234,    F4)   /// Working
   ///m5_team(Jacome1005, VeriFast)   /// Verilator warning
   /// BROKEN m5_team(yeshwanthkattta, ShipHunter)  /// BROKEN. Formatting issues; SV/Verilator issues.
   
   
   // Battle results:
   // fleetRON       vs. Bionic Beavers : fleetRON
   // F4             vs. VeriFast       : F4
   // fleetRON       vs. F4             : F4
   // Bionic Beavers vs. VeriFast       : VeriFast
   // fleetRON       vs. VeriFast       : VeriFast
   // Bionic Beavers vs. F4             : Beavers
   
   // Instantiate the Showdown environment.
   m5+showdown(/top, /secret)
   
   *passed = /secret$passed;   // Defines max cycles, up to ~600.
   *failed = /secret$failed;
\SV
   endmodule
   // Declare Verilog modules.
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 0)_module, ['m5_call(team_\m5_get_ago(github_id, 0)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 1)_module, ['m5_call(team_\m5_get_ago(github_id, 1)_module)'])

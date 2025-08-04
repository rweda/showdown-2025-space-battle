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
\TLV match(_team1_num, _team2_num)
   /match_t['']_team1_num['']_t['']_team2_num
      m5_push_var(github_id, m5_argn(m5_calc(_team1_num + 1), m5_eval(m5_team_ids)))
      m5_push_var(github_id, m5_argn(m5_calc(_team2_num + 1), m5_eval(m5_team_ids)))
      m5_push_var(team_name, m5_argn(m5_calc(_team1_num + 1), m5_eval(m5_team_names)))
      m5_push_var(team_name, m5_argn(m5_calc(_team2_num + 1), m5_eval(m5_team_names)))
      m5_DEBUG(BEFORE)
      m5+showdown(/match_t['']_team1_num['']_t['']_team2_num, /secretx)
      m5_DEBUG(AFTER)
      m5_pop(github_id)
      m5_pop(github_id)
      m5_pop(team_name)
      m5_pop(team_name)
      \viz_js
         box: {strokeWidth: 0},
         where: {left: _team1_num * 110 - 200, top: (m5_num_teams -1 - _team2_num) * 120 - 400, width: 300, height: 300}

\m5
   /The VIZ expression to test for victory in a match.
   /Team: 0/1 for team number to test for victory
   /TeamXNum: identifies the match on the grid
   fn(won, Team, Team0Num, Team1Num, {
      ~([' + (('/top/match_t']m5_Team0Num['_t']m5_Team1Num['/secretx$lose_id'.asInt() == (2 >> ']m5_Team[')) ? 1 : 0)'])
   })
   /Sum m5_Team's victory in all matches in which m5_Team competed.
   fn(score, Team, {
      ~(['score[ ']m5_Team[' ] = 0'])
      ~repeat(m5_num_teams, {
         ~if(m5_LoopCnt < m5_Team, {
            ~won(1, m5_LoopCnt, m5_Team)
         })
         ~if(m5_LoopCnt > m5_Team, {
            ~won(0, m5_Team, m5_LoopCnt)
         })
      })
      ~(;)
   })
\TLV

   // STEP 2: Enlist teams for battle.
   // Replace GITHUB_IDs and TEAM_NAMEs matching the included files.
   ///m5_team(amitops2103, verilog-space-commander)   /// BROKEN. Undefined M5 vars (Gamer)
   ///m5_team(209916212, fleetRON)        /// blackbolt-gt
   ///m5_team(60561724, Bionic Beavers)   /// Sanjitha-Manivelan
   ///m5_team(kiru234, F4)   /// Working
   ///m5_team(Jacome1005, VeriFast)   /// Verilator warning
   ///m5_team(yeshwanthkattta, ShipHunter)  /// BROKEN. Formatting issues; SV/Verilator issues.
   
   
   // Instantiate the Showdown environment.
   m5_var(team_names, ['fleetRON, Bionic Beavers, F4, VeriFast'])
   m5_var(team_ids, ['209916212, 60561724, kiru234, Jacome1005'])
   
   m5_var(num_teams, 4)
   m5+match(0, 1)
   m5+match(0, 2)
   m5+match(0, 3)
   m5+match(1, 2)
   m5+match(1, 3)
   m5+match(2, 3)
   ///m5_repeat(m5_num_teams, ['m5_repeat(m5_LoopCnt, ['m5_DEBUG(HEY)m5+match(m5_LoopCnt, m5_get_ago(LoopCnt, 1))'])'])
   /scores
      \viz_js
         m5_var(score_height, 30)
         box: {top: -20, width: 300, height: m5_score_height * m5_num_teams + 40, fill: "#d0d0d0", rx: 10, ry: 10},
         init() {
            const teamNames = [m5_repeat(m5_num_teams, ['"m5_argn(m5_calc(m5_LoopCnt + 1), m5_eval(m5_team_names))"[', ']'])];
            let ret = {};
            for (let t = 0; t < m5_num_teams; t++) {
               ret[`name${t}`] = new fabric.Text(teamNames[t], {left: 200, top: 5 + m5_score_height * t, fontSize: 20, fontFamily: "Arial", fill: "black", originX: "right"});
               ret[`score${t}`] = new fabric.Rect({left: 210, top: 5 + m5_score_height * t, fill: "blue", width: 0, height: 20});
            }
            return ret;
         },
         render() {
            debugger;
            let score = [];
            m5_repeat(m5_num_teams, ['m5_score(m5_LoopCnt)'])
            for(let t = 0; t < m5_num_teams; t++) {
               this.obj[`score${t}`].set({width: 20 * score[t]});
            }
         },
         where: {left: -165, top: 50, width: 300},
   ///*passed = /secretx$passed;   // Defines max cycles, up to ~600.
   ///*failed = /secretx$failed;
   ///*passed = *cyc_cnt > 10;
\SV
   endmodule
   // Declare Verilog modules.
   m5_repeat(m5_num_teams, ['m4_ifdef(['m5']_team_\m5_argn(m5_calc(m5_LoopCnt + 1), m5_eval(m5_team_ids))_module, ['m5_nl()m5_call(team_\m5_argn(m5_calc(m5_LoopCnt + 1), m5_eval(m5_team_ids))_module)m5_nl()'])'])

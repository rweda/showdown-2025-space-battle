\m5_TLV_version 1d: tl-x.org
\m5
   / A development template for:
   /
   / /----------------------------------------------------------------------------\
   / | The First Annual Makerchip ASIC Design Showdown, Summer 2025, Space Battle |
   / \----------------------------------------------------------------------------/
   /
   / Each player or team modifies this template to provide their own custom spacecraft
   / control circuitry. This template is for teams using TL-Verilog. A Verilog-based
   / template is provided separately. Monitor the Showdown Slack channel for updates.
   / Use the latest template for submission.
   /
   / Just 3 steps:
   /   - Replace all YOUR_GITHUB_ID and YOUR_TEAM_NAME.
   /   - Code your logic in the module below.
   /   - Submit by Sun. July 26, 11 PM IST/1:30 PM EDT.
   /
   / Showdown details: https://www.redwoodeda.com/showdown-info and in the reposotory README.
   /
   /
   / Your circuit should drive the following signals for each of your ships, in /ship[2:0]:
   / /ships[2:0]
   /    $xx_acc[3:0], $yy_acc[3:0]: Attempted acceleration for each of your ships (if sufficient energy);
   /                                capped by max_acceleration (see showdown_lib.tlv). (use "\$signed($yy_acc) for signed math)
   /    $attempt_fire: Attempt to fire (if sufficient energy remains).
   /    $fire_dir[1:0]: Direction to fire (if firing). (For the first player: 0 = right, 1 = down, 2 = left, 3 = up).
   /    $attempt_cloak: Attempted actions for each of your ships (if sufficient energy remains).
   /    $attempt_shield: Attempt to use shields (if sufficient energy remains).
   / Based on the following inputs, including state from the enemy in /_top/enemy_ship[2:0] (as updated by previous-cycle outputs):
   / /ship[2:0]
   /    *clk:           Clock; used implicitly by TL-Verilog constructs, but you can use this in embedded Verilog.
   /    $reset:         Reset.
   /    $xx_p[7:0], $yy_p[7:0]: Position of your ships as affected by previous cycle's acceleration. (signed value, unsigned type)
   /    $energy[7:0]:   The energy supply of each ship, as updated by inputs last cycle.
   /    $destroyed:     Asserted if and when the ships are destroyed.
   / /enemy_ship[2:0]: Reflecting enemy input in the previous cycle.
   /    $xx_p[7:0], $yy_p[7:0]: Positions of enemy ships. (signed value, unsigned type)
   /    $cloaked: Whether the enemy ships are cloaked; if asserted enemy xx_p and xy_p did not update.
   /    $destroyed: Whether the enemy ship has been destroyed.

   / See also the game parameters in the header of `showdown_lib.tlv`.

   use(m5-1.0)
   
   var(viz_mode, devel)  /// Enables VIZ for development.
                         /// Use "devel" or "demo". ("demo" will be used in competition.)


// Modify this TL-Verilog macro to implement your control circuitry.
// Replace YOUR_GITHUB_ID with your GitHub ID, excluding non-word characters (alphabetic, numeric,
// and "_" only)
\TLV team_YOUR_GITHUB_ID(/_top)
   /ship[*]
      
      //-----------------------\
      //  Your Code Goes Here  |
      //-----------------------/
      
      // E.g.:
      //$xx_acc[3:0] = 4'd0;
      //$yy_acc[3:0] = 4'd0;
      //$attempt_fire = 1'b0;
      //$fire_dir[1:0] = 2'd0;
      //$attempt_cloak = 1'b0;
      //$attempt_shield = 1'b0;


// [Optional]
// Visualization of your logic for each ship.
\TLV team_YOUR_GITHUB_ID_viz(/_top, _team_num)
   m5+io_viz(/_top, _team_num)   /// Visualization of your IOs.
   \viz_js
      m5_DefaultTeamVizBoxAndWhere()
      // Add your own visualization of your own logic here, if you like, within the bounds {left: 0..100, top: 0..100}.
      render() {
         // ... draw using fabric.js and signal values. (See VIZ docs under "LEARN" menu.)
         return [
            // For example...
            new fabric.Text('$destroyed'.asBool() ? "I''m dead! ☹️" : "I''m alive! 😊", {
               left: 10, top: 50, originY: "center", fill: "black", fontSize: 10,
            })
         ];
      },


// Compete!
// This defines the competition to simulate (for development).
// When this file is included as a library (for competition), this code is ignored.
\SV
   // Include the showdown framework.
   m4_include_lib(https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a211a27da91c5dda590feac280f067096c96e721/showdown_lib.tlv)
   
   m5_makerchip_module
\TLV
   // Enlist teams for battle.
   
   // Your team as the first. Provide:
   //   - your GitHub ID, (as in your \TLV team_* macro, above)
   //   - your team name--anything you like (that isn't crude or disrespectful)
   m5_team(YOUR_GITHUB_ID, YOUR_TEAM_NAME)
   
   // Choose your opponent.
   // Note that inactive teams must be commented with "///", not "//", to prevent M5 macro evaluation.
   ///m5_team(random, Random)
   ///m5_team(sitting_duck, Sitting Duck)
   m5_team(demo1, Test 1)
   
   
   // Instantiate the Showdown environment.
   m5+showdown(/top, /secret)
   
   *passed = /secret$passed || *cyc_cnt > 100;   // Defines max cycles, up to ~600.
   *failed = /secret$failed;
\SV
   endmodule

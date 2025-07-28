\m5_TLV_version 1d: tl-x.org
\m5
   / The First Annual Makerchip ASIC Showdown, Summer 2025: Space Battle
   / This file is the library providing the content.
   / See the repo's README.md for more information.
   use(m5-1.0)
   
   / +++++++++++ Game Parameters ++++++++++++
   
   define_hier(SHIP, 3, 0)   /// number of ships
   
   / The board (play area) spans -64..64, centered at 0,0.
   
   / Ship and bullet hit box width/height
   var(ship_width, 8)
   var(ship_height, 8)
   var(bullet_width, 2)
   var(bullet_height, 10)  /// (this is also the bullet's speed (distance per cycle))
   / Bullets travel (ship_height + bullet_height) / 2 = 9 each cycle.
   
   / Energy Supply
   var(reset_energy, 40)   /// your initial energy
   var(max_energy, 80)     /// your maximum energy
   var(recoup_energy, 15)  /// the amount you recharge each clock cycle, capped by max_energy.
   / Energy is adjusted by each of the following each cycle, after recouping and maxing, in this order.
   / Any action that would take energy below zero cannot be taken.
   / Acceleration costs energy equal to X acceleration + Y acceleration. If there is insufficient energy for all acceleration, no acceleration is applied.
   var(fire_cost, 30)      /// the energy cost of firing
   var(cloak_cost, 15)     /// the energy cost of cloaking (each active cycle)
   var(shield_cost, 25)    /// the energy cost of using your shield (each active cycle)
   
   / Max acceleration and velocity
   var(max_acceleration, 4'd4)
   var(max_velocity, 6'd8)
   
   define_hier(BULLET, 5, 0)    /// max number of bullets
   
   // Initial ship positions
   var(reset_x, ((#ship == 2) ? -8'd8 : -8'd40))
   var(reset_y, ((#ship == 1) ? -8'd8 : -8'd40))
   
   / ++++++++++ End of Contest Parameters ++++++++++++
   
   / VIZ config
   / viz_mode can be set before including this library.
   /   devel: [default] for development
   /   demo: optimized for demonstration
   if_var_ndef(viz_mode, [
      var(viz_mode, devel)
   ])
   case(viz_mode, devel, [
      var(show_hit_boxes, true)
      var(default_anim_duration, 250)
      var(early_turns, 0)
      var(trail_length, 3)
   ], [
      / demo mode
      var(show_hit_boxes, false)
      var(default_anim_duration, 1000)
      var(early_turns, 1)
      var(trail_length, 0)
   ])
   
   / Computed parameters.
   var(half_bullet_width, m5_calc(m5_bullet_width / 2))
   var(half_bullet_height, m5_calc(m5_bullet_height / 2))
   var(half_ship_width, m5_calc(m5_ship_width / 2))
   var(half_ship_height, m5_calc(m5_ship_height / 2))
   
   var(default_anim_easing, ['(t, b, c, d) => b + (t/d) * c'])  /// e.g. easeOutCubic or linear
   
   
   / Provide a library defining a team's control circuit, name, and ID.
   fn(team_raw_tlv, ?TlvFile, {
      / Include submitted TLV URL, reporting an error if it produces text output.
      if_null(m4_include_lib(_team1_lib), [
         error(['The following TL-Verilog library produced output text. Ignoring']m5_nl    m5_TlvFile)
      ])
      on_return(var, github_id, m5_github_id)   /// Preserve what the library defined after it gets popped by the return.
      on_return(var, team_name, m5_team_name)   ///   "
   })
   
   / Define which TLV macro to use for this team.
   / E.g. m5_team_macro(random)  /// For predefined random opponent.
   fn(team, TeamId, TeamName, {
      on_return(var, github_id, m5_TeamId)
      on_return(var, team_name, m5_TeamName)
   })
   
   / Verilog sign extend.
   macro(sign_extend, ['{{$3{$1[$2]}}, $1}'])
   
   / Cap a signed signal at a max value.
   fn(cap, Sig, MaxBit, Max, {
      ~(m5_Sig[m5_MaxBit] ? ((-m5_Sig > m5_Max) ? -m5_Max : m5_Sig) : (( m5_Sig > m5_Max) ?  m5_Max : m5_Sig))
   })
   
   
   / Animation methodology:
   
   / Assign JavaScript variables with the values of a signal needed for animating properties,
   / supporting the following use models:
   /   - "anim": assign is_\m5_Sig and was_\m5_Sig for use in animating a property from was to is.
   /   - "set": assign is_\m5_Sig and val_\m5_Sig for setting properties during animation period to val_*, then setting to is_*.
   /   - "both": [default] assign all three variables for "anim" and "set".
   / The step offset for accessing these values depends on the use model and whether we're animating
   / forward or backward. m5_prep_animation must have been called to initialize "forward", "step", and "animCyc".
   /
   /   /-----------------------------------------------------------
   /   |               step value           variable providing  variable
   /   |variable: use  (forward, backward)  step value          meaning
   /   |-----------------------------------------------------------
   /   | is_*:    both   (0,  0)            0                   value animating to
   /   | was_*:   anim   (-1, 1)            step                value animating from
   /   | val_*:   set    (0, 1)             animCyc             value at cycle being animated
   /   \-----------------------------------------------------------
   /
   / Params:
   /   Sig: The signal with optional alignment.
   /   Type: The "as" function to use to get the signal value ("Int", "SignedInt", "Bool", etc.).
   /   ?Use: Use model of the values for animation, as above, one of: "anim", "set", or "both".
   /   ?Path: The TLV path to the signal.
   fn(sig, Sig, Type, ?Use, ?Path, {
      ~($m5_Sig = 'm5_Path$m5_Sig'; const is_\m5_Sig = $m5_Sig.as\m5_Type['']();)
      ~if_neq(m5_Use, "set", {
         ~([' ']const was_\m5_Sig = $m5_Sig.step(step).as\m5_Type['']();)
      })
      ~if_neq(m5_Use, "anim", {
         ~([' ']const val_\m5_Sig = 'm5_Path$m5_Sig'.step(animCyc).as\m5_Type['']();)
      })
   })
   
   / Prepare for animation by setting "forward", "step", and "animCyc".
   fn(prep_animation, {
      ~(['const forward = this.steppedBy() >= 0; const step = forward ? -1 : 1; const animCyc = forward ? 0 : 1;   // Characterize animation.'])
   })

   macro(ApplyVal, ['this.applyValue('/ship[ship]$1', "$2");'])

   macro(DefaultTeamVizBoxAndWhere, ['box: {width: 210, height: 105, left: -55, top: -2.5, strokeWidth: 0}, where: {left: 0, top: 0, width: 80, height: 120},'])
   
// --------------- For the Verilog template ---------------

\TLV verilog_wrapper(/_top, _github_id)
   \SV_plus
      logic signed [7:0] id['']_github_id['']energy [m5_SHIP_RANGE];
      logic signed [7:0] id['']_github_id['']x [m5_SHIP_RANGE];
      logic signed [7:0] id['']_github_id['']y [m5_SHIP_RANGE];
      logic signed [7:0] id['']_github_id['']enemy_x_p [m5_SHIP_RANGE];
      logic signed [7:0] id['']_github_id['']enemy_y_p [m5_SHIP_RANGE];
      logic signed [3:0] id['']_github_id['']x_a [m5_SHIP_RANGE];
      logic signed [3:0] id['']_github_id['']y_a [m5_SHIP_RANGE];
      logic [1:0] id['']_github_id['']fire_dir [m5_SHIP_RANGE];
      team_['']_github_id team_['']_github_id(
         // Inputs:
         .clk(clk),
         .reset(/_top$reset),
         .x(id['']_github_id['']x),
         .y(id['']_github_id['']y),
         .energy(id['']_github_id['']energy),
         .destroyed(/ship[*]>>1$destroyed),
         .enemy_x_p(id['']_github_id['']enemy_x_p),
         .enemy_y_p(id['']_github_id['']enemy_y_p),
         .enemy_cloaked(/enemy_ship[*]$cloaked),
         .enemy_destroyed(/enemy_ship[*]$destroyed),
         // Outputs:
         .x_a(id['']_github_id['']x_a),
         .y_a(id['']_github_id['']y_a),
         .attempt_fire(/ship[*]$$attempt_fire),
         .attempt_shield(/ship[*]$$attempt_shield),
         .attempt_cloak(/ship[*]$$attempt_cloak),
         .fire_dir(id['']_github_id['']fire_dir)
      );
   /enemy_ship[*]
      \SV_plus
         assign *id['']_github_id['']enemy_x_p[enemy_ship] = $xx_p;
         assign *id['']_github_id['']enemy_y_p[enemy_ship] = $yy_p;
   /ship[*]
      \SV_plus
         assign *id['']_github_id['']x[ship] = >>1$xx_p;
         assign *id['']_github_id['']y[ship] = >>1$yy_p;
         assign *id['']_github_id['']energy[ship] = >>1$energy;
         assign $$xx_acc[3:0] = *id['']_github_id['']x_a[ship];
         assign $$yy_acc[3:0] = *id['']_github_id['']y_a[ship];
         assign $$fire_dir[1:0] = *id['']_github_id['']fire_dir[ship];
      //$xx_acc[3:0] = /_top$xx_acc_vect[4 * (ship + 1) - 1 : 4 * ship];
      //$yy_acc[3:0] = /_top$yy_acc_vect[4 * (ship + 1) - 1 : 4 * ship];
      //$fire_dir[1:0] = /_top$fire_dir_vect[2 * (ship + 1) - 1 : 2 * ship];


// ------------- VIZ Infra -------------

\TLV io_viz(/_name, _team_num)
   // Visualization for inputs.
   /ios_viz_only
      \viz_js
         box: {width: 210, height: 105, left: -55, top: -2.5, strokeWidth: 0},
         init() {
            const ret = {};
            const ship = this.getIndex("ship");
            const colors = ["red", "green"];
            
            // Headings
            ret[`heading${_team_num}.${ship}`] = new fabric.Text(`Player${_team_num}\nShip${ship}`, {
               left: m5_if(_team_num, 150, -50), top: 50,
               originX: m5_if(_team_num, "left", "right"), originY: "center",
               textAlign: "center",
               fontFamily: "Roboto", fontSize: 11,
               fill: colors[_team_num],
            })
            
            // Draw I/Os.
            
            let pos = {in: 5, out: 12};
            const makeIO = (name, out) => {
               const p = out ? pos.out : pos.in;
               ret[`${name}-pin`] = new fabric.Line([out ? 100 : 0, p + 7, out ? 110 : -10, p + 7], {stroke: "black", strokeWidth: 1});
               ret[name] = new fabric.Text(name, {
                  left: out ? 110 : -10, top: p,
                  originX: out ? "left" : "right",
                  fontFamily: "Roboto", fontSize: 6, fill: "purple",
               });
               ret[`${name}-value`] = new fabric.Text("-", {
                  left: out ? 110 : -10, top: p + 7,
                  originX: out ? "left" : "right",
                  fontFamily: "Courier New", fontSize: 6, fill: "blue",
               });
               pos[out ? "out" : "in"] += 15;
            };
            // A function to apply signal values.
            this.applyValue = (sig, as) => {
               name = sig.signal.notFullName;
               this.obj[`${name}-value`].set({text: sig[`as${as}`]().toString()});
            };
            // Outputs
            makeIO("$xx_acc", true);
            makeIO("$yy_acc", true);
            makeIO("$attempt_fire", true);
            makeIO("$fire_dir", true);
            makeIO("$attempt_cloak", true);
            // Inputs
            makeIO("$xx_p", false);
            makeIO("$yy_p", false);
            makeIO("$xx_v", false);
            makeIO("$yy_v", false);
            makeIO("$energy", false);
            makeIO("$destroyed", false);
            ret.block = new fabric.Rect({left: -1, top: -1, width: 101, height: 101, fill: "transparent", stroke: "black", strokeWidth: 1});
            
            this.miniScale = 100 / 128;
            const props = {width: m5_ship_width * this.miniScale, height: m5_ship_height * this.miniScale,
                           originX: "center", originY: "center", visible: false,};
            for (let p = 0; p < 2; p++) {
               const myTeam = p == _team_num;
               for (let s = 0; s < m5_SHIP_CNT; s++) {
                  const color = (myTeam && s != ship) ? "gray" : colors[p];
                  for (let c = 0; c < 2; c++) {
                     ret[`mini${p}.${s}.${c}`] = new fabric.Rect({...props, ...{
                        fill: color, strokeWidth: 0, opacity: 0.5 - c * 0.25,
                     }});
                  }
                  // Cloaked ships.
                  ret[`mini${p}.${s}.Cloaked`] = new fabric.Rect({...props, ...{
                     fill: "transparent", strokeWidth: 1, stroke: color,
                     opacity: 0.5,
                  }});
               }
            }
            
            // Make objects for requested actions.
            
            // Attempt cloaking
            ret.myCloak = new fabric.Rect({
               ...props, ...{
                  fill: "transparent", strokeWidth: 1, stroke: colors[_team_num], opacity: 0.5
               }
            });
            
            // Attempted firing
            ret.fire = new fabric.Group([
               // This invisible Rect establishes Group bounds.
               new fabric.Rect({
                  width:  (m5_ship_width  + 8) * this.miniScale,
                  height: (m5_ship_height + 8) * this.miniScale,
                  originX: "center", originY: "center",
                  visible: false,
                  strokeWidth: 0,
                  left: 0, top: 0,
               }),
               // This one is the fire indicator.
               new fabric.Rect({
                  width: 4 * this.miniScale, height: 4 * this.miniScale,
                  strokeWidth: 0, fill: "black",
                  originX: "center", originY: "center",
                  opacity: 0.5,
                  left: (m5_half_ship_width + 2) * this.miniScale,
                  top: 0,
               }),
            ], {
               originX: "center", originY: "center",
               visible: false,
            });
            
            // Acceleration
            ret.accel = new fabric.Circle({
               strokeWidth: 0, fill: colors[_team_num],
               originX: "center", originY: "center",
               radius: 2,
               visible: false
            });
            
            return ret;
         },
         render() {
            const ship = this.getIndex("ship");
            m5_ApplyVal($xx_acc, SignedInt)
            m5_ApplyVal($yy_acc, SignedInt)
            m5_ApplyVal($attempt_fire, Bool)
            m5_ApplyVal($fire_dir, Int)
            m5_ApplyVal($attempt_cloak, Bool)
            m5_ApplyVal($xx_p, SignedInt)
            m5_ApplyVal($yy_p, SignedInt)
            m5_ApplyVal($xx_v, SignedInt)
            m5_ApplyVal($yy_v, SignedInt)
            m5_ApplyVal($energy, Int)
            m5_ApplyVal($destroyed, Bool)
            
            // Draw mini ships.
            const scale = [this.miniScale, -this.miniScale];  // Indexed by _team_num. Sign flips P1.
            for (let p = 0; p < 2; p++) {
               const myTeam = p == _team_num;
               for (let s = 0; s < m5_SHIP_CNT; s++) {
                  const $xx_p = myTeam ? '/ship[s]$xx_p' : '/_name/enemy_ship[s]$xx_p';
                  const $yy_p = myTeam ? '/ship[s]$yy_p' : '/_name/enemy_ship[s]$yy_p';
                  const destroyed = (myTeam ? '/ship[s]$destroyed' : '/_name/enemy_ship[s]$destroyed').asBool();
                  const cloaked = !myTeam && '/_name/enemy_ship[s]$cloaked'.asBool();
                  for (let c = 0; c < 2; c++) {
                     this.obj[`mini${p}.${s}.${c}`].set({
                        left: $xx_p.asSignedInt() * scale[_team_num] + 50,
                        top: -$yy_p.asSignedInt() * scale[_team_num] + 50,
                        visible: !destroyed && !cloaked,
                     });
                     $xx_p.step(-1);
                     $yy_p.step(-1);
                  }
                  this.obj[`mini${p}.${s}.Cloaked`].set({
                     left: this.obj[`mini${p}.${s}.0`].left,
                     top:  this.obj[`mini${p}.${s}.0`].top,
                     visible: !destroyed && cloaked,
                  });
               }
            }
            
            const destroyed = '/ship[ship]$destroyed'.asBool();
            
            // Attempt cloak
            const attemptCloak = '/ship[ship]$attempt_cloak'.asBool();
            const myMini = this.obj[`mini${_team_num}.${ship}.0`];
            this.obj.myCloak.set({
               visible: attemptCloak && !destroyed,
               left: myMini.left,
               top: myMini.top,
            });
            if (attemptCloak) {
               // Hide my normal mini.
               myMini.set({visible: false});
            }
            // Attempt fire.
            const fire = '/ship[ship]$attempt_fire'.asBool();
            this.obj.fire.set({visible: fire && !destroyed});
            if (fire && !destroyed) {
               this.obj.fire.set({
                  left: myMini.left,
                  top:  myMini.top,
                  angle: 90 * ('/ship[ship]$fire_dir'.asInt() - 2 * _team_num),  // (flipped for second player)
               });
            }
            // Acceleration vector.
            const x1 =  '/ship[ship]$xx_p'.asSignedInt() * scale[_team_num] + 50;
            const y1 = -'/ship[ship]$yy_p'.asSignedInt() * scale[_team_num] + 50;
            this.obj.accel.set({
               left: x1 + '/ship[ship]$xx_acc'.asSignedInt() * scale[_team_num],
               top:  y1 - '/ship[ship]$yy_acc'.asSignedInt() * scale[_team_num],
               visible: !destroyed,
            });
         },
         where: {width: 210, height: 105, left: -55, top: -2.5}

// Use in place of io_viz if no custom VIZ is provided.
\TLV io_viz_only(/_top, _team_num)
   // Visualize IOs.
   m5+io_viz(/_top, _team_num)
   // Visualize your logic, if you like, here, within the bounds {left: 0..100, top: 0..100}.
   \viz_js
      m5_DefaultTeamVizBoxAndWhere()
   


// --------------- Sample player logic/VIZ ---------------

// Team logic providing random behavior.
\TLV team_random(/_top)
   /ship[*]
      m4_rand($rand, 31, 0, ship)
      $xx_acc[3:0] = $rand[3:0];
      $yy_acc[3:0] = $rand[7:4];
      $attempt_fire = $rand[8];
      $fire_dir[1:0] = $rand[10:9];
      $attempt_shield = $rand[11];
      $attempt_cloak = $rand[12];
         
      
\TLV team_random_viz(/_top, _team_num)
   // Visualize IOs.
   m5+io_viz(/_top, _team_num)
   
   // Visualize your logic, if you like, here, within the bounds {left: 0..100, top: 0..100}.
   \viz_js
      m5_DefaultTeamVizBoxAndWhere()
      init() {
         return {
            note: new fabric.Text("I''m so random!", {
               left: 10, top: 50, originY: "center", fill: "black", fontSize: 10,
            }),
            full: new fabric.Rect({
               left: 0, top: 0, width: 100, height: 100, strokeWidth: 0, fill: "#0000FF20",
            }),
         };
      },
      render() {
         // ... draw using fabric.js and signal values. (See VIZ docs under "LEARN" menu.)
      },



// An opponent providing demo first-player behavior.
\TLV team_demo1(/_top)
   /ship[*]
      $xx_acc[7:0] = #ship == 0 ?
                      *cyc_cnt == 1 ? (8'd3) :
                      *cyc_cnt == 2 ? (8'd3) :
                      *cyc_cnt == 3 ? (8'd2) :
                      *cyc_cnt == 5 ? (-8'd2) :
                      *cyc_cnt == 6 ? (-8'd2) :
                      *cyc_cnt == 7 ? (-8'd1) :
                      *cyc_cnt == 8 ? (-8'd1) :
                      *cyc_cnt == 9 ? (8'd2) :
                      *cyc_cnt == 10 ? (8'd2) :
                      *cyc_cnt == 12 ? (-8'd1) :
                      *cyc_cnt == 13 ? (-8'd3) :
                      *cyc_cnt == 14 ? (-8'd1) :
                      *cyc_cnt == 15 ? (-8'd1) :
                      8'd0 :
                   #ship == 1 ?
                      *cyc_cnt == 1 ? (8'd3) :
                      *cyc_cnt == 2 ? (8'd3) :
                      *cyc_cnt == 3 ? (8'd1) :
                      *cyc_cnt == 4 ? (-8'd3) :
                      *cyc_cnt == 5 ? (-8'd2) :
                      *cyc_cnt == 7 ? (8'd1) :
                      *cyc_cnt == 8 ? (-8'd1) :
                      *cyc_cnt == 9 ? (8'd1) :
                      *cyc_cnt == 10 ? (8'd3) :
                      8'd0 :
                   *cyc_cnt == 1 ? (8'd3) :
                   *cyc_cnt == 2 ? (8'd3) :
                   *cyc_cnt == 3 ? (8'd1) :
                   *cyc_cnt == 7 ? (-8'd1) :
                   *cyc_cnt == 8 ? (-8'd2) :
                   *cyc_cnt == 9 ? (-8'd2) :
                   *cyc_cnt == 10 ? (-8'd1) :
                   *cyc_cnt == 11 ? (-8'd1) :
                   *cyc_cnt == 13 ? (8'd1) :
                   *cyc_cnt == 14 ? (8'd1) :
                   8'd0;
      
      $yy_acc[3:0] = #ship == 0 ?
                      *cyc_cnt == 1 ? (8'd2) :
                      *cyc_cnt == 2 ? (8'd1) :
                      *cyc_cnt == 8 ? (-8'd1) :
                      *cyc_cnt == 9 ? (-8'd3) :
                      *cyc_cnt == 10 ? (-8'd2) :
                      *cyc_cnt == 11 ? (8'd1) :
                      *cyc_cnt == 12 ? (8'd3) :
                      *cyc_cnt == 13 ? (8'd3) :
                      *cyc_cnt == 14 ? (8'd1) :
                      *cyc_cnt == 16 ? (-8'd1) :
                      *cyc_cnt == 17 ? (-8'd3) :
                      *cyc_cnt == 18 ? (-8'd3) :
                      *cyc_cnt == 19 ? (-8'd2) :
                      *cyc_cnt == 20 ? (-8'd1) :
                      8'd0 :
                   #ship == 1 ?
                      *cyc_cnt == 1 ? (8'd3) :
                      *cyc_cnt == 2 ? (8'd3) :
                      *cyc_cnt == 3 ? (8'd1) :
                      *cyc_cnt == 7 ? (-8'd1) :
                      *cyc_cnt == 8 ? (-8'd2) :
                      *cyc_cnt == 9 ? (-8'd2) :
                      *cyc_cnt == 10 ? (-8'd2) :
                      8'd0 :
                   *cyc_cnt == 4 ? (8'd1) :
                   *cyc_cnt == 5 ? (8'd1) :
                   *cyc_cnt == 6 ? (8'd1) :
                   *cyc_cnt == 7 ? (8'd1) :
                   *cyc_cnt == 8 ? (8'd1) :
                   *cyc_cnt == 9 ? (8'd1) :
                   *cyc_cnt == 10 ? (8'd1) :
                   *cyc_cnt == 13 ? (8'd1) :
                   8'd0;
      
      
      
      $attempt_fire = #ship == 0 ?
                         (*cyc_cnt == 7) || (*cyc_cnt == 17) :
                      #ship == 1 ?
                         (*cyc_cnt == 4) :
                      (*cyc_cnt == 6) || (*cyc_cnt == 16);
      
      $fire_dir[1:0] = #ship == 0 ?
                          2'b11 :
                       #ship == 1 ?
                          2'b11 :
                       (*cyc_cnt == 16) ? 2'b10 : 2'b11;
      
      $attempt_shield = #ship == 0 ?
                           (*cyc_cnt >= 16) && (*cyc_cnt <= 19) :
                        #ship == 1 ?
                           (*cyc_cnt == 5) || (*cyc_cnt == 6) :
                        1'b0;
      
      $attempt_cloak = #ship == 0 ?
                          (*cyc_cnt >= 4) && (*cyc_cnt <= 10) :
                       #ship == 1 ?
                          1'b0 :
                       1'b0;
      
\TLV team_demo1_viz(/_top, _team_num)
   // Visualize IOs.
   m5+io_viz_only(/_top, _team_num)


// Team logic providing demo second player behavior.
\TLV team_demo2(/_top)
   /ship[*]
      $xx_acc[7:0] = #ship == 0 ?
                      *cyc_cnt == 1 ? (-8'd3) :
                      *cyc_cnt == 2 ? (-8'd2) :
                      *cyc_cnt == 3 ? (-8'd1) :
                      *cyc_cnt == 4 ? (8'd3) :
                      *cyc_cnt == 5 ? (8'd3) :
                      *cyc_cnt == 6 ? (8'd3) :
                      *cyc_cnt == 7 ? (8'd3) :
                      *cyc_cnt == 11 ? (-8'd2) :
                      *cyc_cnt == 12 ? (-8'd3) :
                      *cyc_cnt == 13 ? (-8'd3) :
                      *cyc_cnt == 14 ? (8'd3) :
                      *cyc_cnt == 15 ? (8'd2) :
                      *cyc_cnt == 16 ? (-8'd3) :
                      *cyc_cnt == 19 ? (8'd1) :
                      *cyc_cnt == 20 ? (8'd1) :
                      8'd0 :
                   #ship == 1 ?
                      *cyc_cnt == 1 ? (8'd3) :
                      *cyc_cnt == 2 ? (8'd3) :
                      *cyc_cnt == 3 ? (8'd1) :
                      *cyc_cnt == 7 ? (-8'd2) :
                      *cyc_cnt == 8 ? (8'd0) :
                      8'd0 :
                   *cyc_cnt == 1 ? (8'd3) :
                   *cyc_cnt == 2 ? (8'd3) :
                   *cyc_cnt == 3 ? (8'd1) :
                   8'd0;
      
      $yy_acc[3:0] = #ship == 0 ?
                      *cyc_cnt == 1 ? (-8'd3) :
                      *cyc_cnt == 2 ? (-8'd2) :
                      *cyc_cnt == 3 ? (8'd1) :
                      *cyc_cnt == 4 ? (8'd1) :
                      *cyc_cnt == 6 ? (8'd3) :
                      *cyc_cnt == 11 ? (8'd2) :
                      *cyc_cnt == 12 ? (8'd2) :
                      *cyc_cnt == 14 ? (8'd3) :
                      *cyc_cnt == 15 ? (-8'd1) :
                      *cyc_cnt == 16 ? (-8'd2) :
                      *cyc_cnt == 17 ? (8'd3) :
                      *cyc_cnt == 18 ? (8'd2) :
                      8'd0 :
                   #ship == 1 ?
                      *cyc_cnt == 1 ? (8'd1) :
                      *cyc_cnt == 2 ? (8'd2) :
                      *cyc_cnt == 5 ? (-8'd2) :
                      *cyc_cnt == 6 ? (-8'd2) :
                      *cyc_cnt == 7 ? (-8'd1) :
                      8'd0 :
                   *cyc_cnt == 1 ? (-8'd1) :
                   *cyc_cnt == 2 ? (-8'd1) :
                   *cyc_cnt == 4 ? (8'd1) :
                   *cyc_cnt == 5 ? (8'd2) :
                   *cyc_cnt == 6 ? (8'd2) :
                   8'd0;
      
      
      $attempt_fire = #ship == 0 ?
                         (*cyc_cnt == 5) || (*cyc_cnt == 15) || (*cyc_cnt == 18) :
                      #ship == 1 ?
                         (*cyc_cnt == 8) :
                      (*cyc_cnt == 5);
      
      $fire_dir[1:0] = #ship == 0 ?
                          (*cyc_cnt == 15) ? 2'b10 :
                          (*cyc_cnt == 18) ? 2'b11 :
                          2'b00 :
                       #ship == 1 ?
                          2'b1 :
                       2'b11;
      
      $attempt_shield = #ship == 0 ?
                         (*cyc_cnt >= 8) && (*cyc_cnt <= 13) :
                      #ship == 1 ?
                         1'b0 :
                      1'b0;
      
      $attempt_cloak = #ship == 0 ?
                          1'b0 :
                       #ship == 1 ?
                          1'b0 :
                       (*cyc_cnt >= 4);

\TLV team_demo2_viz(/_top, _team_num)
   // Visualize IOs.
   m5+io_viz_only(/_top, _team_num)


// An opponent that uses default values (and thus, the ships do absolutely nothing).
\TLV team_sitting_duck(/_top)
   /ship[*]

\TLV team_sitting_duck_viz(/_top, _team_num)
   // Visualize IOs.
   m5+io_viz_only(/_top, _team_num)

// ------------------- End of sample player logic -----------------------


// Macro to instantiate and connect up the logic for both players.
\TLV player_logic(/_secret, /_name, _team_num)
   /_name
      \viz_js
         box: {width: 80, height: 120, strokeWidth: 0},
         where: {left: m5_if(_team_num, 0, -80), top: -220, width: 80, height: 120},

      m5_var(enemy_num, m5_calc(1 - _team_num))
      m5_push_var(my_ship, /_secret/player[_team_num]/ship[#ship])
      m5_push_var(enemy_ship, /_secret/player[m5_enemy_num]/ship[#enemy_ship])
      $reset = /_secret$reset;
      `BOGUS_USE($reset)

      // State that is accessible to contestants.
      /m5_SHIP_HIER    // So team code can use /ship[*].
         $reset = /_secret$reset;
                  
         // Provide default control output signal values.
         $ANY = /_secret/default_controls$ANY;

         // Provide visibility to own ship state. These all come from m5_\my_ship, but we don't use $ANY to avoid exposing private state.
         $xx_p[7:0] = m5_my_ship>>1$xx_p;
         $yy_p[7:0] = m5_my_ship>>1$yy_p;
         $xx_v[5:0] = m5_my_ship>>1$xx_v;
         $yy_v[5:0] = m5_my_ship>>1$yy_v;
         $energy[7:0] = m5_my_ship>>1$energy;
         $destroyed = m5_my_ship>>1$destroyed;
         // The above do not have to be used.
         `BOGUS_USE($reset $xx_p $yy_p $xx_v $yy_v $energy $destroyed)

      // Provide visibility to enemy ship state.
      /prev_enemy_ship[m5_SHIP_RANGE]
         // This scope is a legacy name, aliased to /enemy_ship.
         $ANY = /_name/enemy_ship[#prev_enemy_ship]$ANY;
         `BOGUS_USE($dummy)  // Ensure non-empty $ANY.
      /enemy_ship[m5_SHIP_RANGE]
         $cloaked = m5_enemy_ship>>1$cloaked;
         // Position, with cloaking applied.
         $xx_p[7:0] = $cloaked ? >>1$xx_p : -m5_enemy_ship>>1$xx_p;  // Negative to map coordinate systems.
         $yy_p[7:0] = $cloaked ? >>1$yy_p : -m5_enemy_ship>>1$yy_p;
         $destroyed = m5_enemy_ship>>1$destroyed;
         $dummy = 1'b0;
         // The above do not have to be used.
         `BOGUS_USE($xx_p $yy_p $cloaked $destroyed)

      m5_pop(my_ship, enemy_ship)   /// To avoid exposureing /_secret.
      // ------ Instantiate Team Macro ------
      m5_var(my_github_id, m5_get_ago(github_id, m5_enemy_num))
      m5+call(team_\m5_my_github_id, /_name, /_secret)
      // Instantiate VIZ macro in devel mode if it exists (using an unofficial test).
      /ship[*]
         m5_if_eq(m5_viz_mode, devel, ['m4_ifdef(['m4tlv_team_']m5_my_github_id['_viz__body'], ['m5+call(team_\m5_myid['']_github_id['']_viz, /_name, _team_num)'])'])
      
\TLV showdown(/_top, /_secret)
   /// Each team submits a file containing a TLV macro whose name is the GitHub ID matching the
   /// repository and the submission (omitting unsupported characters, like '-') and a team name as:
   /// var(github_id, xxx)
   /// var(team_name, xxx)
   /// \TLV team_xxx()
   ///    ...
   
   /// Make sure both teams defined their github_id and team_name.
   m5_if_neq(m5_depth_of(github_id), 2, ['m5_error(['Need two teams defined, but have definitions for ']m5_depth_of(github_id)[' github_id's.'])'])
   m5_if_neq(m5_depth_of(team_name), 2, ['m5_error(['Need two teams defined, but have definitions for ']m5_depth_of(team_name)[' team_name's.'])'])
   
   $raw_reset = *reset;
   $reset = >>1$raw_reset;  // delay 1 cycle to see initial state in VIZ.
   
   /_secret
      // These provide defaults for the team control logic.
      /default_controls
         $attempt_fire = 1'b0;
         $xx_acc[3:0] = 4'b0;
         $yy_acc[3:0] = 4'b0;
         $fire_dir[1:0] = 2'b0;
         $attempt_shield = 1'b0;
         $attempt_cloak = 1'b0;
         $dummy = 1'b0;  // A dummy signal to ensure something is pulled through the $ANY.
         // These do not have to be (in fact, should not be) used.
         `BOGUS_USE($attempt_fire $xx_acc $yy_acc $fire_dir $attempt_shield $attempt_cloak)

      $reset = /_top$reset;

      /background
         // ================  BACKGROUND VIZ  ================
         \viz_js
            box: { left: -128, top: -128, width: 256, height: 256, strokeWidth: 0 },
         
         
            // ~~~~~~~~ Init ~~~~~~~~
            init()
            {
               let background = this.newImageFromURL(
                  "https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/back_grid_small.png",
                  "",
                  {  originX: "center", originY: "center",
                     left: 0, top: 0,
                     width: 128, height: 128,
                     imageSmoothing: false,
                  }
               );
         
               return { background_img: background };
            }
      
      
      // Win logic:
      $lose_id[1:0] =
         $reset              ? 2'd0 :
         >>1$lose_id != 2'd0 ? >>1$lose_id :  // sticky
         //default
                               /player[*]$lost;
      
      
      // ||||||||||||||||  PLAYER LOGIC ||||||||||||||||
      /player[1:0]
         $player_id = (#player != 0);
         
         // Win logic:
         $ship_cnt[m5_SHIP_CNT_RANGE] = m5_repeat(m5_SHIP_CNT, ['{ m5_SHIP_CNT_MAX'b0, ! /ship[m5_LoopCnt]$destroyed} + ']) m5_SHIP_CNT_HIGH'b0;
         $lost = (& /ship[*]>>1$destroyed) ||  // all my ships are destroyed
                 (*cyc_cnt > 590 && (/other_player$ship_cnt >= $ship_cnt));  // Time expired and I don't have more ships.
         
         /other_player
            $ANY = /player[!/player$player_id]$ANY;
            
            /m5_SHIP_HIER
               $ANY = /player[! /player$player_id]/ship$ANY;
         
         
         // ================  PLAYER VIZ  ================
         \viz_js
            box: { strokeWidth: 0},
         
            // This just flips the ships for the second player. There isn't any other viz for the player directly.
            layout: { left: 256, top: 256, angle: 180 },
         
         /m5_SHIP_HIER
            $reset = /_top$reset;
            
            
            // Inputs from opponent logic.
            
            $ANY = /player$player_id ? /_secret/team1/ship$ANY : /_secret/team0/ship$ANY;
            `BOGUS_USE($dummy)  // Make sure this is pulled through the $ANY chain from /defaults to prevent empty $ANYs.
            `BOGUS_USE($xx_a[3:0] $yy_a[3:0] $xx_acc[3:0] $yy_acc[3:0])  // A bug workaround to consume all bits for $ANY.
            
            // Cap acceleration, and assign zero on reset, just for better VIZ.
            $xx_a[3:0] = $reset ? 4'd0 : m5_cap($xx_acc, 3, m5_max_acceleration);
            $yy_a[3:0] = $reset ? 4'd0 : m5_cap($yy_acc, 3, m5_max_acceleration);
            
            
            // Process attempted actions, consuming energy for those that can be taken.
            
            // Recoup energy, capped by max.
            $recouped_energy[7:0] = >>1$energy + 8'd\m5_recoup_energy;
            $maxed_energy[7:0] = ($recouped_energy > 8'd\m5_max_energy) ? 8'd\m5_max_energy : $recouped_energy;
            // Accelerate
            $no_more_bullets = & /bullet[*]$bullet_exists;
            $do_accelerate = $maxed_energy >= $xx_a + $yy_a && ! >>1$destroyed;
            $energy_after_a[7:0] = $maxed_energy - ($do_accelerate ? m5_sign_extend($xx_a, 3, 4) + m5_sign_extend($yy_a, 3, 4) : 8'b0);
            // Fire
            $do_fire = $attempt_fire && $energy_after_a >= 8'd\m5_fire_cost && ! >>1$no_more_bullets && ! >>1$destroyed;
            $energy_after_fire[7:0] = $energy_after_a - ($do_fire ? 8'd\m5_fire_cost : 8'b0);
            // Cloak
            $do_cloak = $attempt_cloak && $energy_after_fire >= 8'd\m5_cloak_cost && ! >>1$destroyed;
            $energy_after_cloak[7:0] = $energy_after_fire - ($do_cloak ? 8'd\m5_cloak_cost : 8'b0);
            // Shield
            $do_shield = $attempt_shield && $energy_after_cloak >= 8'd\m5_shield_cost && ! >>1$destroyed;
            $energy_after_shield[7:0] = $energy_after_cloak - ($do_shield ? 8'd\m5_shield_cost : 8'b0);
            
            $energy[7:0] = $reset ? 8'd40 :
               $energy_after_shield;
            
            $cloaked = $do_cloak;  // Just a rename.
            
            
            // Update velocity and position, based on acceleration.
            
            // Cap velocity.
            $xx_vel[5:0] = $reset ? 6'b0 : >>1$xx_v + m5_sign_extend($xx_a, 3, 2);
            $yy_vel[5:0] = $reset ? 6'b0 : >>1$yy_v + m5_sign_extend($yy_a, 3, 2);
            $xx_v[5:0] = m5_cap($xx_vel, 5, m5_max_velocity);
            $yy_v[5:0] = m5_cap($yy_vel, 5, m5_max_velocity);
            
            $xx_p[7:0] = $reset ? m5_reset_x :
                         >>1$destroyed ? >>1$xx_p :
                         >>1$xx_p + m5_sign_extend($xx_v, 5, 2);
            $yy_p[7:0] = $reset ? m5_reset_y :
                         >>1$destroyed ? >>1$yy_p :
                         >>1$yy_p + m5_sign_extend($yy_v, 5, 2);
            
            
            // Determine ship collisions.
            
            // Bullet collisions with ships.
            /enemy_ship[m5_SHIP_RANGE]
               // Any bullet hit #enemy_ship.
               $hit = m5_repeat(m5_BULLET_CNT, ['/ship/bullet[m5_LoopCnt]/enemy_ship$hit || '])1'b0;
            // Is shot by any enemy ship
            $shot = m5_repeat(m5_SHIP_CNT, ['/player[! /player$player_id]/ship[m5_LoopCnt]/enemy_ship[#ship]$hit || '])1'b0;
            
            // Ship collisions with boarder.
            $out_of_bounds = $reset ? 1'b0 :
                   ($xx_p >= 8'd128 && $xx_p < (8'd192 + 8'd\m5_half_ship_width)) ||
                   ($xx_p < 8'd128 && $xx_p > (8'd64 - 8'd\m5_half_ship_width)) ||
                   ($yy_p >= 8'd128 && $yy_p < (8'd192 + 8'd\m5_half_ship_height)) ||
                   ($yy_p < 8'd128 && $yy_p > (8'd64 - 8'd\m5_half_ship_height));
            $destroyed = $reset ? 1'b0 :
                    >>1$destroyed ? 1'b1 :
                    ($shot && !>>1$do_shield) ||
                    $out_of_bounds;
            
            
            
            
            // ||||||||||||||||  BULLET LOGIC ||||||||||||||||
            /m5_BULLET_HIER
               // Identify firing bullets as a find-first, with each bullet propagating info to the next.
               $prev_found_fire = (#bullet == 0) ? 1'b0 : /bullet[#bullet - 1]$found_fire;  // An lower-indexed bullet fired.
               $successful_fire = /ship$do_fire && ! >>1$bullet_exists && ! $prev_found_fire;  // This bullet fires.
               $found_fire = $prev_found_fire || $successful_fire;  // This or a prior bullet fired.
               
               $bullet_exists = /_top$reset ? 1'b0 :
                                >>1$hit_an_enemy ? 1'b0 :
                                (>>1$bullet_exists || $successful_fire) ?
                                   // Hits border.
                                   ($bullet_dir[0] == 1'b0) ?
                                      (($bullet_x < (8'd64 + 8'd\m5_half_bullet_height)) || ($bullet_x > (8'd192 - 8'd\m5_half_bullet_height))) &&
                                      (($bullet_y < (8'd64 + 8'd\m5_half_bullet_width)) || ($bullet_y > (8'd192 - 8'd\m5_half_bullet_width))) :
                                   //else
                                     (($bullet_y < (8'd64 + 8'd\m5_half_bullet_height)) || ($bullet_y > (8'd192 - 8'd\m5_half_bullet_height))) &&
                                     (($bullet_x < (8'd64 + 8'd\m5_half_bullet_width)) || ($bullet_x > (8'd192 - 8'd\m5_half_bullet_width))) :
                                1'b0;
               
               // Bullet state.
               $bullet_dir[1:0] = $successful_fire ? /ship$fire_dir : >>1$bullet_dir;
               
               $bullet_x[7:0] = $successful_fire ?
                                   ($bullet_dir == 2'b00) ? (/ship$xx_p + 8'd\m5_half_ship_width + 8'd\m5_half_bullet_height) :
                                   ($bullet_dir == 2'b10) ? (/ship$xx_p - 8'd\m5_half_ship_width - 8'd\m5_half_bullet_height) :
                                   /ship$xx_p :
                                ($bullet_dir == 2'b00) ? (>>1$bullet_x + 8'd\m5_bullet_height) :
                                ($bullet_dir == 2'b10) ? (>>1$bullet_x - 8'd\m5_bullet_height) :
                                >>1$bullet_x;
               $bullet_y[7:0] = $successful_fire ?
                                   ($bullet_dir == 2'b01) ? (/ship$yy_p - 8'd\m5_half_ship_height - 8'd\m5_half_bullet_height) :
                                   ($bullet_dir == 2'b11) ? (/ship$yy_p + 8'd\m5_half_ship_height + 8'd\m5_half_bullet_height) :
                                   /ship$yy_p :
                                ($bullet_dir == 2'b01) ? (>>1$bullet_y - 8'd\m5_bullet_height) :
                                ($bullet_dir == 2'b11) ? (>>1$bullet_y + 8'd\m5_bullet_height) :
                                >>1$bullet_y;
               
               
               /enemy_ship[m5_SHIP_RANGE]
                  $ANY = /player/other_player/ship[#enemy_ship]$ANY;
                  $hit = (/_top$reset || >>1$destroyed || ! /bullet$bullet_exists) ? 1'b0 :
                         (/bullet$bullet_dir[0] == 1'b1) ?
                            ((($xx_p + 8'b10000000) > (- /bullet$bullet_x + 8'b10000000 - (8'd\m5_half_ship_width + 8'd\m5_half_bullet_width))) &&
                             (($xx_p + 8'b10000000) < (- /bullet$bullet_x + 8'b10000000 + (8'd\m5_half_ship_width + 8'd\m5_half_bullet_width))) &&
                             (($yy_p + 8'b10000000) > (- /bullet$bullet_y + 8'b10000000 - (8'd\m5_half_ship_height + 8'd\m5_half_bullet_height))) &&
                             (($yy_p + 8'b10000000) < (- /bullet$bullet_y + 8'b10000000 + (8'd\m5_half_ship_height + 8'd\m5_half_bullet_height)))
                            ) :
                            ((($xx_p + 8'b10000000) > (- /bullet$bullet_x + 8'b10000000 - (8'd\m5_half_ship_width + 8'd\m5_half_bullet_height))) &&
                             (($xx_p + 8'b10000000) < (- /bullet$bullet_x + 8'b10000000 + (8'd\m5_half_ship_width + 8'd\m5_half_bullet_height))) &&
                             (($yy_p + 8'b10000000) > (- /bullet$bullet_y + 8'b10000000 - (8'd\m5_half_ship_height + 8'd\m5_half_bullet_width))) &&
                             (($yy_p + 8'b10000000) < (- /bullet$bullet_y + 8'b10000000 + (8'd\m5_half_ship_height + 8'd\m5_half_bullet_width))));
               $hit_an_enemy = | /enemy_ship[*]$hit;
               
               
               
               
               
               // ================  BULLET VIZ  ================
               \viz_js
                  box: { left: -128, top: -128, width: 256, height: 256, strokeWidth: 0 },
                  layout: { left: 0, top: 0 },
               
               
                  // ~~~~~~~~ Init ~~~~~~~~
                  init()
                  {
                     const player_id = (this.getIndex("player") == 1);
                     ret = {};
               
                     // Load Bullet Image:
                     ret.bullet_img = this.newImageFromURL(
                        (`https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/bullet_sprites/p${player_id ? "2" : "1"}/smol_bullet.png`),
                        "",
                        {  left: 0, top: 0,
                           width: 3, height: 10,
                           imageSmoothing: false
                        }
                     );
                     ret.bullet_img.set({
                        originX: "center", originY: "center", visible: false,
                     });
               
               
                     // Create Bullet Rect:
                     ret.bullet_rect = new fabric.Rect({
                        width: 10, height: 2, strokeWidth: 0,
                        fill: (player_id ? "#00ffb350" : "#ffff0050"),
                        originX: "center", originY: "center", visible: false,
                     });
               
                     return ret;
                  },
               
               
                  // ######## Render ########
                  render()
                  {
                     const player_id = this.getIndex("player");
                     const ship_id = this.getIndex("ship");
               
                     m5_prep_animation()
                     m5_sig(successful_fire, Bool, anim, )
                     m5_sig(bullet_exists, Bool, anim, )
                     ///m5_sig(hit_an_enemy, Bool, anim, )
                     m5_sig(xx_p, SignedInt, anim, /ship[ship_id])
                     m5_sig(yy_p, SignedInt, anim, /ship[ship_id])
                     m5_sig(bullet_x, SignedInt, anim, )
                     m5_sig(bullet_y, SignedInt, anim, )
                     m5_sig(bullet_dir, Int, anim, )
                     
                     const forwardFire = is_successful_fire && forward;
                     const backwardFire = was_successful_fire && ! forward
                     const left = backwardFire ? is_xx_p : is_bullet_x;
                     const top =  -(backwardFire ? is_yy_p : is_bullet_y);
                     // Animate bullet image:
                     this.obj.bullet_img.set({
                        visible: was_bullet_exists || is_bullet_exists,
                        opacity: was_bullet_exists ? 1 : 0,
                        left: forwardFire ? was_xx_p : was_bullet_x,
                        top:  -(forwardFire ? was_yy_p : was_bullet_y),
                        angle: ((forwardFire ? is_bullet_dir : was_bullet_dir) + 1) * 90,
                     }).animate({
                        opacity: is_bullet_exists ? 1 : 0,
                        left,
                        top,
                     }, {
                        duration: m5_default_anim_duration,
                        easing: m5_default_anim_easing
                     }).thenSet({ visible: is_bullet_exists });
                     // Animate bullet rect similarly:
                     this.obj.bullet_rect.set({
                        visible: this.obj.bullet_img.visible && m5_show_hit_boxes,
                        opacity: this.obj.bullet_img.opacity,
                        left: this.obj.bullet_img.left,
                        top: this.obj.bullet_img.top,
                        angle: this.obj.bullet_img.angle - 90
                     }).animate({
                        opacity: is_bullet_exists ? 1 : 0,
                        left,
                        top,
                     }, {
                        duration: m5_default_anim_duration,
                        easing: m5_default_anim_easing
                     }).thenSet({ visible: is_bullet_exists && m5_show_hit_boxes });
                  }
            
            
            
            
            
            // =====================   SHIP VIZ   =====================
            
            \viz_js
               box: { left: -128, top: -128, width: 256, height: 256, strokeWidth: 0 },
               layout: { left: 0, top: 0 },
            
            
               // ~~~~~~~~ Init ~~~~~~~~
               init() {
                  let ret = {};
                  const player_id = (this.getIndex("player") == 1);
                  const ship_id = this.getIndex();
            
                  // Create Ship Rect.
                  ret.ship_rect = new fabric.Rect({
                     width: 8, height: 8, strokeWidth: 0,
                     fill: (player_id ? "#00ffb350" : "#ffff0050"),
                     originX: "center", originY: "center",
                     visible: false,
                  });
                  
                  // Load Ship Images.
                  for (let i = 0; i < 4; i++) {
                     ret[`ship_sprite${i}_img`] = this.newImageFromURL(
                        `https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/ship_sprites/p${player_id ? "2" : "1"}/smol_ship${i}.png`,
                        "",
                        { left: 0, top: 0,
                           width: 11, height: 15,
                           imageSmoothing: false,
                        }
                     );
                     ret[`ship_sprite${i}_img`].set({
                          originX: "center", originY: "center", visible: false,
                     });
                  }
            
                  // Load Shield Image:
                  ret.shield_img = this.newImageFromURL(
                     "https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/shield.png",
                     "",
                     { left: 0, top: 0,
                        width: 23, height: 23,
                        angle: player_id ? 180.0 : 0.0,
                        imageSmoothing: false,
                     }
                  );
                  ret.shield_img.set({ originX: "center", originY: "center", visible: false });
            
            
                  // Create Shield Meter:
                  const energyColor = ship_id == 0 ? "#e8e800" :
                                      ship_id == 1 ? "#30e810" :
                                                     "#00d0d0";
                  ret.energy_meter_back = new fabric.Rect({
                     width: 10, height: 1.5, strokeWidth: 0, fill: "#b0b0b0ff",
                     originX: "left", originY: "center", angle: player_id ? 180.0 : 0.0,
                     visible: false,
                  });
                  ret.energy_meter = new fabric.Rect({
                     width: 10, height: 1.5, strokeWidth: 0, fill: energyColor,
                     originX: "left", originY: "center", angle: player_id ? 180.0 : 0.0,
                     visible: false,
                  });
            
            
            
                  // Load Explosion Images.
                  for (let i = 0; i < 5; i++) {
                     ret[`explody_sprite${i}`] = this.newImageFromURL(
                        `https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/explosion_sprites/p${player_id ? "2" : "1"}/explody${i}.png`,
                        "",
                        { left: 0, top: 0,
                           width: 28, height: 28,
                           imageSmoothing: false,
                           // Adjust angle so that even when the ships flip, the explosion still faces the same direction.
                           angle: player_id ? 180 : 0
                        }
                     );
                     ret[`explody_sprite${i}`].set({
                          originX: "center", originY: "center", visible: false
                     });
                  }
                  
                  
                  // Trails.
                  for (let i = 0; i < m5_trail_length; i++) {
                     ret[`trail${i}`] = new fabric.Rect({
                         width: 1, height: 1,
                         visible: false, fill: player_id ? "#d0f0d0" : "#f0d0d0", strokeWidth: 0,
                         originX: "center",
                         originY: "center",
                         opacity: 1.0 - 0.3 * i,
                     });
                  }
                  
                  return ret;
               },
            
            
            
               // ######## Render ########
               render() {
                  let player_id = this.getIndex("player");
                  let ship_id = this.getIndex();
            
                  function asSigned(val, bit_count) {
                     if (val >= 2**(bit_count - 1)) {
                        val -= 2**bit_count;
                     }
                     return val;
                  }
            
            
                  m5_prep_animation()
                  m5_sig(xx_p, SignedInt, anim)
                  m5_sig(yy_p, SignedInt, anim)
                  m5_sig(xx_a, SignedInt, both)
                  m5_sig(yy_a, SignedInt, both)
                  m5_sig(do_cloak, Bool, anim)
                  m5_sig(destroyed, Bool, anim, >>1)
                  m5_sig(energy, Int, anim)
                  m5_sig(do_shield, Bool, anim)
                  m5_sig(shot, Bool, set)
            
                  const energy_meter_x_offset = player_id ? 5 : -5;
                  const energy_meter_y_offset = player_id ? -9 : 9;
            
            
                  // Determine the correct starting and ending angles for the ship for this cycle.
                  // In demo mode, starting/ending angles are based on the next cycle's acceleration
                  // for more realistic behavior. For devel mode, they reflect current values.
                  // When there is no acceleration, find the last acceleration to determine angle.
                  // So, determine was and is angles (with search and 1 cycle offset if demoing).
                  const getAccel = (step) => {
                     const $xx_a = '$xx_a'.step(step + m5_early_turns);   // Angle is based on next cycle's value.
                     const $yy_a = '$yy_a'.step(step + m5_early_turns);   //   "
                     const $reset = '$reset'.step(step + m5_early_turns);
                     while (! $reset && ($xx_a.asSignedInt() == 0) && ($yy_a.asSignedInt() == 0))
                     {
                        $xx_a.step(-1);
                        $yy_a.step(-1);
                        $reset.step(-1);
                     }
                     return [$xx_a.asSignedInt(1), $yy_a.asSignedInt(1)];
                  }
                  let [angle_was_xx_a, angle_was_yy_a] = getAccel(step);
                  let [angle_is_xx_a,  angle_is_yy_a ] = getAccel(0);
                  // Transition between angle of acceleration before and after.
                  const toAngle = (x, y) => (x == 0 && y == 0) ? 45 : -(Math.atan2(y, x) * 180 / Math.PI) + 90;
                  const set_angle = toAngle(angle_was_xx_a, angle_was_yy_a);
                  let animate_angle = toAngle(angle_is_xx_a, angle_is_yy_a);
                  // If the animate_angle is more than 180 degrees from the set_angle, adjust to minimize spin.
                  if (animate_angle > set_angle + 180) {animate_angle -= 360;}
                  if (animate_angle < set_angle - 180) {animate_angle += 360;}
                  // Use acceleration at the cycle we are transitioning over, then update for current cycle.
                  const toMagSq = (x, y) => x ** 2 + y ** 2;
                  const accelMag = toMagSq(val_xx_a, val_yy_a);
                  const finishMag = toMagSq(is_xx_a, is_xx_a);
                  
                  const toOpacity = (cloak) => cloak ? 0.25 : 1;
                  const toOpacityHitBox = (cloak) => cloak ? 0.4 : 1;
                  const visible = ! val_destroyed;
            
                  // Select Current Ship Image.
                  // Default to invisible.
                  for (let i = 0; i < 4; i++) {
                     this.obj[`ship_sprite${i}_img`].set({ visible: false });
                  }
                  const accelToImage = (x_a, y_a) => {
                     const accelMagSq = toMagSq(x_a, y_a);
                     const shipImgNum =
                            (accelMagSq == 0)        ? 0 :
                            (accelMagSq < 1.75 ** 2) ? 1 :
                            (accelMagSq < 5 ** 2)    ? 2 :
                                                       3;
                     return this.obj[`ship_sprite${shipImgNum}_img`];
                  };
                  // We set and hold a ship image matching the cycle's acceleration, then set to reflect the previous cycle.
                  // We animate ship angle to the next-cycle acceleration. 
                  const currentShipImage = accelToImage(val_xx_a, val_yy_a);
                  const nextShipImage    = accelToImage(is_xx_a, is_yy_a);
                  if (typeof nextShipImage == "undefined") {
                     debugger;
                  }
            
                  // Animate ship image
                  currentShipImage.set({
                     left: was_xx_p,
                     top: -was_yy_p,
                     angle: set_angle,
                     opacity: toOpacity(was_do_cloak),
                     visible
                  }).animate({
                     left: is_xx_p,
                     top: -is_yy_p,
                     angle: animate_angle,
                     opacity: toOpacity(is_do_cloak),
                  }, {
                     duration: m5_default_anim_duration,
                     easing: m5_default_anim_easing
                  }).then(() => {
                     // Switch to ship reflecting current acceleration.
                     currentShipImage.set({visible: false});
                     nextShipImage.set({
                        left: is_xx_p,
                        top: -is_yy_p,
                        angle: animate_angle,
                        visible: ! is_destroyed,
                        opacity: toOpacity(is_do_cloak),
                     });
                  });
                  
                  // Animate ship hit box similarly, but no angle
                  this.obj.ship_rect.set({
                     left: currentShipImage.left,
                     top: currentShipImage.top,
                     opacity: toOpacityHitBox(was_do_cloak),
                     visible: visible && m5_show_hit_boxes,
                  }).animate({
                     left: is_xx_p,
                     top: -is_yy_p,
                     opacity: toOpacityHitBox(is_do_cloak),
                  }, {
                     duration: m5_default_anim_duration,
                     easing: m5_default_anim_easing
                  }).thenSet({
                      visible: !is_destroyed && m5_show_hit_boxes,
                      opacity: toOpacityHitBox(is_do_cloak),
                  });

                  // Animate energy meter
                  this.obj.energy_meter_back.set({
                     left: currentShipImage.left + energy_meter_x_offset,
                     top: currentShipImage.top + energy_meter_y_offset,
                     visible: currentShipImage.visible
                  }).animate({
                     left: is_xx_p + energy_meter_x_offset,
                     top: -is_yy_p + energy_meter_y_offset,
                  }, {
                     duration: m5_default_anim_duration,
                     easing: m5_default_anim_easing
                  }).thenSet({
                     visible: !is_destroyed
                  });
                  this.obj.energy_meter.set({
                     left: currentShipImage.left + energy_meter_x_offset,
                     top: currentShipImage.top + energy_meter_y_offset,
                     scaleX: was_energy / m5_max_energy,
                     visible: currentShipImage.visible
                  }).animate({
                     left: is_xx_p + energy_meter_x_offset,
                     top: -is_yy_p + energy_meter_y_offset,
                     scaleX: is_energy / m5_max_energy,
                  }, {
                     duration: m5_default_anim_duration,
                     easing: m5_default_anim_easing
                  }).thenSet({
                     visible: !is_destroyed
                  });
            
                  // Animate shield
                  // Cycle of collision ends with an instant burst that is undone by the next animation.
                  // Grow on enable cycle. Shrink next cycle.
                  this.obj.shield_img.set({
                     left: currentShipImage.left,
                     top: currentShipImage.top,
                     // Enlarge shield during animation.
                     scaleX: was_do_shield ? 1.0 : 0.0,
                     scaleY: was_do_shield ? 1.0 : 0.0,
                     visible: (was_do_shield || is_do_shield) && ! val_destroyed
                  }).animate({
                     left: is_xx_p,
                     top: -is_yy_p,
                     scaleX: is_do_shield ? 1.0 : 0.0,
                     scaleY: is_do_shield ? 1.0 : 0.0,
                  }, {
                     duration: m5_default_anim_duration,
                     easing: m5_default_anim_easing
                  }).thenSet({
                     visible: ! is_destroyed && is_do_shield,
                     scaleX: is_shot ? 1.2 : 1.0,
                     scaleY: is_shot ? 1.2 : 1.0,
                  })

                  // Animate explosion if applicable:
                  if (val_destroyed && ! '>>1$destroyed'.step(animCyc - 1).asBool())
                  {
                     for (let i = 0; i < 5; i++)
                     {
                        this.obj[`explody_sprite${i}`]
                           .set({visible: false})
                           .wait(i * 140)
                           .thenSet({left: is_xx_p, top: -is_yy_p, visible: true})
                           .thenWait(140).thenSet({visible: false});
                     }
                  }
                  else
                  {
                     for (let i = 0; i < 5; i++)
                     {
                        this.obj[`explody_sprite${i}`].set({visible: false});
                     }
                  }
                  
                  // Show trails.
                  const $xx_p2 = '$xx_p';
                  const $yy_p2 = '$yy_p';
                  const $destroyed2 = '$destroyed';
                  for (let i = 0; i < m5_trail_length; i++) {
                     this.obj[`trail${i}`].set({
                        visible: ! $destroyed2.asBool(true),
                        left: $xx_p2.asSignedInt(0),
                        top: -$yy_p2.asSignedInt(0),
                     });
                     $xx_p2.step(-1);
                     $yy_p2.step(-1);
                     $destroyed2.step(-1);
                  }
               }
      
      
      
      
      /foreground
         // ================  FOREGROUND VIZ  ================
         \viz_js
            name: "foreground",
            box: { left: -128, top: -128, width: 256, height: 256, strokeWidth: 0 },
            
         
            // ~~~~~~~~ Init ~~~~~~~~
            init()
            {
               let ret = {};
         
               // Load End Screens.
               const loadEndImg = (file) =>
                  this.newImageFromURL(
                     `https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/end_screens/${file}`,
                     "",
                     {  originX: "center",
                        left: 0, top: 0,
                        width: 108, height: 100,
                        imageSmoothing: false,
                        visible: true,   // Note, this is the visibility of the Image, whereas the returned Object is a group.
                     }
                  );
               
               ret.p1win_img = loadEndImg("p1win.png").set({ visible: false });
               ret.p2win_img = loadEndImg("p2win.png").set({ visible: false });
               ret.tie_img   = loadEndImg("tie.png")  .set({ visible: false });
         
               // Create Background Masking Rects:
               ret.mask0 = new fabric.Rect({ left: 96, top: 0, width: 64, height: 256, strokeWidth: 0, fill: "#ffffffff", originX: "center", originY: "center" });
               ret.mask1 = new fabric.Rect({ left: 0, top: 96, width: 256, height: 64, strokeWidth: 0, fill: "#ffffffff", originX: "center", originY: "center" });
               ret.mask2 = new fabric.Rect({ left: -96, top: 0, width: 64, height: 256, strokeWidth: 0, fill: "#ffffffff", originX: "center", originY: "center" });
               ret.mask3 = new fabric.Rect({ left: 0, top: -128, width: 256, height: 128, strokeWidth: 0, fill: "#ffffffff", originX: "center", originY: "center" });
         
         
               // Load Picture Frame:
               ret.frame_img = this.newImageFromURL(
                  "https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a8e096c8901db15e33f809966a1754a8f3c7c3c3/gold_picture_frame.png",
                  "",
                  {  originX: "center", originY: "center",
                     left: 0, top: 0,
                     width: 190, height: 190,
                     imageSmoothing: false
                  }
               );
         
               return ret;
            },
         
         
            // ######## Render ########
            render()
            {
               // Nothing shown by default.
               this.obj.p1win_img.set({visible: false});
               this.obj.p2win_img.set({visible: false});
               this.obj.tie_img.set({visible: false});
              
               const forward = this.steppedBy() >= 0;
               const step = forward ? -1 : 1;   // The offset (step) for the cycle from which to animate.
               m5_sig(lose_id, Int, set, /_secret>>1)
               const animate = is_lose_id != was_lose_id;
               const lose_id = forward ? is_lose_id : was_lose_id;
               const endScreen =
                      (lose_id == 1) ? this.obj.p2win_img :
                      (lose_id == 2) ? this.obj.p1win_img :
                                       this.obj.tie_img;
               // Animate Y coords.
               const up = -164;
               const down = -64;
               if (animate || lose_id != 0) {
                  endScreen.set({visible: true, top: (animate && forward) ? up : down});
                  if (animate) {
                     endScreen.animate({
                        top: forward ? down : up,
                     }, {
                        duration: 1000,
                        easing: fabric.util.ease.easeOutCubic
                     });
                  } else if (lose_id != 0) {
                     endScreen.set({visible: true, top: -64});
                  }
               }
            }
      
      
      // ==================== Placard =================
      m5_var(p0_text, P1: m5_get_ago(team_name, 1))
      m5_var(p1_text, P2: m5_get_ago(team_name, 0))
      m5_var(placard_p0_len, m5_length(m5_p0_text))
      m5_var(placard_p1_len, m5_length(m5_p1_text))
      m5_var(placard_len, m5_if(m5_placard_p0_len < m5_placard_p1_len, m5_placard_p1_len, m5_placard_p0_len))
      m5_var(placard_width, m5_calc((m5_placard_len + 6) * 5))
      /placard
         // The "placard" showing team names.
         \viz_js
            box: { width: m5_placard_width, height: 19, left: 0,
                   fill: "#ebd077", stroke: "#504020", strokeWidth: 1 },
            lib: {
               pixelFont: "Press Start 2P"
            },
            init () {
               // Load pixelated font.
               const pixelFont = {
                  Silkscreen: "https://fonts.gstatic.com/s/silkscreen/v4/m8JXjfVPf62XiF7kO-i9YLNlaw.woff2",
                  "Pixelify Sans": "https://fonts.gstatic.com/s/pixelifysans/v1/CHy2V-3HFUT7aC4iv1TxGDR9DHEserHN25py2TTp0E1fZZM.woff2",
                  "Press Start 2P": "https://fonts.gstatic.com/s/pressstart2p/v15/e3t4euO8T-267oIAQAu6jDQyK3nVivM.woff2",
               };
               const font = new FontFace('/placard'.pixelFont, `url(${pixelFont[ '/placard'.pixelFont]})`);
               font.load().then((loadedFont) => {
                  // Add the font to the document
                  document.fonts.add(loadedFont);
                  this.getCanvas().renderAll();
               });
            },
            where: { left: -m5_calc(m5_placard_width / 2), top: 110, height: 20, scale: 1 }
         /player[1:0]
            \viz_js
               box: { width: m5_placard_width, height: 20, left: -m5_calc(m5_placard_width / 2), strokeWidth: 0 },
               layout: {top: 7},
               init() {
                  const fontWidthCorrection = {
                     Silkscreen: 1.39,
                     "Pixelify Sans": 1.075,
                     "Press Start 2P": 1.5,
                  };
                  
                  let p = this.getIndex();
                  let playerLabel = (fill) => {
                     ret = new fabric.Text(
                                `${p ? "m5_p1_text" : "m5_p0_text"}`,
                                { left: 10, top: 1,
                                  fontFamily: '/placard'.pixelFont, fontSize: "5", fontWeight: 400,
                                  originX: "left",
                                  fill: p ? "#197610" : "#a31a1a",
                                }
                            );
                     return ret;
                  };
                  ret = {
                     //shine: playerLabel("#ffefc0", 0.15),
                     label: playerLabel("#504020", 0),
                  };
                  /**
                  ret.test =
                     new fabric.Rect({
                          left: ret.label.left,
                          top: ret.label.top,
                          width: ret.label.width,
                          height: ret.label.height,
                          originX: ret.label.originX,
                          originY: ret.label.originY,
                          fill: "rgba(255, 0, 0, 0.2)"
                     });
                  **/
                  return ret;
               },
               where: {left: -m5_calc(m5_placard_width / 2), top: 2.7,},
      
      
      m5+player_logic(/_secret, /team0, 0)
      m5+player_logic(/_secret, /team1, 1)
      
      // Assert these to end simulation (before Makerchip cycle limit).
      $passed = (| /player[*]>>3$lost) && !>>1$reset;
      $failed = *cyc_cnt > 600;



\SV
   m5_makerchip_module
\TLV

   // Define teams.
   m5_team(random, Random 1)
   ///m5_team(random, Random 2)
   ///m5_team(demo1, Demo 1)
   m5_team(demo2, Demo 2)
   ///m5_team(sitting_duck, Sitting Duck)
   
   // Instantiate the Showdown environment.
   m5+showdown(/top, /secret)
   
   *passed = /secret$passed;
   *failed = /secret$failed;
\SV
   endmodule

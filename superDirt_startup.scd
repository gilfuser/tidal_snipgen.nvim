q = q ? ();
q.samples_path = "~/Samples/".standardizePath;
q.f_synths = File("~/Samples/dirt_synths.yaml".standardizePath, "w");
q.f_fx = File("~/Samples/dirt_fx.yaml".standardizePath, "w");
q.f_samps = File("~/Samples/dirt_samps.yaml".standardizePath, "w");

q.addedSynthDefs = q.addedSynthDefs ? SynthDescLib.global.synthDescs.keys;

q.numOrbs = q.numOrbs ? 8; // escolher quantas orbits serão usadas em Ndefs

if ( currentEnvironment.class == ProxySpace ) { topEnvironment.push };
fork{

  0.2.wait;
  if (~dirt != nil ) {
    ~dirt.stop; ~dirt.freeAllSoundFiles; ~dirt.free; ~dirt = nil; "reseting ~dirt".postln
  };
  ~dirt = SuperDirt(2, s);
  q.orbits_out_chans = Array.fill ( q.numOrbs, { |i| 2 + (i * 2) } );
  ~dirt.start( 57120, q.orbits_out_chans, NetAddr("0.0.0.0") );
  0.2.wait;

  ">>>>>> check point from SuperDirt Startup <<<<<<".postln;

  // "~/SuperCollider/instruments/01b_my_tidal_instruments.scd".standardizePath.load;
  0.2.wait;

  // (
  //   Task {
  //   ( q.numOrbs ).do { |i|
  //     var j = i + 1;
  //     var orbit = format("orb%",j).asSymbol;
  //     q[ orbit ] = ~dirt.orbits[i];
  //     wait(0.05);
  //     Ndef( orbit ).ar(2);
  //     wait(0.05);
  //     Ndef( orbit ).proxyspace.quant_(1).clock_(t);
  //     wait(0.05);
  //     q[ orbit ].outBus = Ndef( orbit ).bus;
  //     wait(0.05);
  //     Ndef( orbit ).play( q.orbits_out_chans[i] /* + 2 */ );
  //     wait(0.05);
  //     Ndef( orbit ).vol_(0.5);
  //     wait(0.05);
  //   };
  //   Ndef( \allOrbs, {
  //     Limiter.ar(
  //     ( Ndef(\orb1).ar * \amp1.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb2).ar * \amp2.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb3).ar * \amp3.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb4).ar * \amp4.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb5).ar * \amp5.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb6).ar * \amp6.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb7).ar * \amp7.kr(1, spec:\ampx4.asSpec) ) +
  //       ( Ndef(\orb8).ar * \amp8.kr(1, spec:\ampx4.asSpec) )
  //     );
  //   }).play.vol_(0.5);
  // }.play;
  // );

  // wait(8);
  // "~/SuperCollider/FX/myTidalFx.scd".standardizePath.load;
  wait(1);

  ////////////////////////////////////////////////////////////////////////

  // Recursive routine to search for folders with sound files and process them
(
  fork{

    // ~dirt.loadSoundFiles;
    // q.ds_default = {q.postSampleInfo(~dirt.buffers.keys)};

    q.postSampleInfo = { |ev buffers|
      var keys = buffers.asArray.sort;
      keys.do { |name|
        var samp = ~dirt.buffers[name];
        "% (%)   % - % sec (% kB)\n".postf(
        name,
            ~dirt.buffers[name].size,
            samp.minItem { |x| x.duration }.duration.round(0.01),
            samp.maxItem { |x| x.duration }.duration.round(0.01),
            samp.sum { |x| x.memoryFootprint } div: 1e3
        );
      };
      ''.postln;
    };
    q.sound_bank;
    q.write_in_file = { |ev bank_name drummachine sample_folder|
      var name = sample_folder.asSymbol;
      var samp = ~dirt.buffers[name];
      if (q.sound_bank != bank_name) {
        q.f_samps.write(format("\n%:\n",bank_name));
        q.f_samps.write(format("  drummachine: %\n",drummachine));
        // q.f_samps.write(format("  samps:\n"));
        q.sound_bank = bank_name;
      };
      q.f_samps.write(format( "  %:\n", name));
      q.f_samps.write(format( "    variations: %\n", ~dirt.buffers[name].size));
      if ( samp.minItem { |x| x.duration }.duration.round(0.01) <= 2.0 ) {
        q.f_samps.write("    is_shorter: true\n");
      };
      if (( samp.minItem { |x| x.duration }.duration.round(0.01) > 2.0 ) && ( samp.minItem { |x| x.duration }.duration.round(0.01) <= 4.0)) {
        q.f_samps.write("    is_short: true\n");
      };
      if (( samp.maxItem { |x| x.duration }.duration.round(0.01) > 4.0 ) && ( samp.maxItem { |x| x.duration }.duration.round(0.01) < 8.0) ) {
        q.f_samps.write("    is_long: true\n");
      };
      if ( samp.maxItem { |x| x.duration }.duration.round(0.01) >= 8.0 ) {
        q.f_samps.write("    is_longer: true\n");
      };
      ''.postln;
    };

    // Function to create a valid bank name and process sound files
    q.bank_names = Set[];

    q.make_bank_name = { |ev bank|
      // Process bank name: remove specific words and sanitize the names
      var bank_name;
      if (bank.folders.size > 0) {
        bank_name = bank.fullPath.basename
          .replace("tidal", "")
          .replace("samples", "")
          .replace("sounds", "")
          .replace("-", "_")
          .trim // Trim any leading or trailing whitespace
          .replace(" ", "_")
          .toLower
        ;
      };
      if ( bank_name.beginsWith("_") ) {
        bank_name = bank_name.replaceAt("", 0, 1)
      };
      q.bank_names.add(bank_name);
      bank_name;
    };

    // Function to find folders with sound files
  (
    q.all_banks = Set[];
    q.loaded_samples = Set[];

    q.snoop_log_and_load_samples = { |ev folder|
      var subfolders = folder.folders;
      var soundFile, sound_bank, bank_name, sample_path, drummachine = false;
      subfolders.do { |subfolder|
        if (subfolder.folderName.beginsWith("_").not) // choose not to load with a _ before dir name
          // check if the subfolders contains sound files
        {
            subfolder.files.collect { |file|
              soundFile = SoundFile.openRead(file.fullPath);
              if (soundFile.notNil) {
                if ((subfolder.fullPath.dirname != q.samples_path) and: not(q.all_banks.includes(subfolder.fullPath.dirname))) {
                  sound_bank = PathName(subfolder.fullPath.dirname); // subfolder parent
                  bank_name = q.make_bank_name(sound_bank);
                };
                if ( not(q.loaded_samples.includes(file.folderName))) {
                  sample_path = file.fullPath.dirname;
                  ~dirt.loadSoundFiles(sample_path);
                  if (file.folderName.endsWith("-bd")) {
                    drummachine = true;
                  };
                  q.loaded_samples.add(sample_path.basename);
                  q.write_in_file(bank_name, drummachine, sample_path.basename);
                };
                soundFile.close;
                file.fullPath;
              };
            };

        q.snoop_log_and_load_samples(subfolder);
      }
    };
  };
);
  1.wait;
  q.snoop_log_and_load_samples(PathName(q.samples_path));
  q.f_samps.close;
};
);
/////////////////////////////////////////////////////////////

/*
(
q.print_dirt_stuff = {
( SynthDescLib.global.synthDescs.keys - q.addedSynthDefs ).
asArray.sort.do { |key|
// clean synthDefs names as e.g. '_dirt_squiz' and get only 'squiz'
// as they are in ~dirt.modules
key = key.asString;
if ( key.beginsWith("dirt_") ) { key = key.replace("dirt_", "")};
if (key.find("_").notNil) {
var index = key.find("_");
// the following if is just because of dirt_pitch_shift2 and dirt_sample_long_1_2
if ( key.at(index+1).asString != "l" and: ( key.at(index+1).asString != "s" ) ) {
while {index < key.size} {key.takeAt(index)}
};
};
if (key.last.asString == "2") {key = key.replace("2", "")};
if ( (key != "global") and: ( not( key.contains("long")) ) ) { key.postln; };
};
'';
};
q.print_dirt_stuff;
);
*/

(
q.tidy_keys = { |env key|
  key = key.asString;
  if ( key.beginsWith("dirt_") ) { key = key.replace("dirt_", "")};
  if (key.find("_").notNil) {
    var index = key.find("_");
    if ( key.at(index+1).asString != "l" and: (
      key.at(index+1).asString != "s" ) ) {
        while {index < key.size} {key.takeAt(index)}
      };
  };
  if (key.last.asString == "2") {key = key.replace("2", "")};
  key;
};

q.filter_synths_and_fx = { |env key|
  var good_key = false;
  if ((key != "sample") .and (key != "envelope") .and (key != "vowel") ) {
    if ( (key != "global") and: ( not( key.contains("long")) ) ) {
      good_key = true;
    };
  };
  good_key;
};

q.filter_ctrls = { |env, name|
  var cool_to_ctrl = false;
  if ( (name != \out) .and (name != \sustain) .and (name != \begin) .and (name != \end) .and (name != \gate) .and (name != \pan) .and (name != \freq) .and (name != \) .and (name != \speed) .and (name != \amp) ) {
    cool_to_ctrl = true;
  };
  cool_to_ctrl;
};

q.print_dirt_stuff_params = {
  var ctrl_name, value, file, controls, is_synth;
( SynthDescLib.global.synthDescs.keys - q.addedSynthDefs ).
    asArray.sort.keysValuesDo { |key|
    is_synth = false;
    controls = SynthDescLib.match(key).controls;
    controls.do {|ctrl| if (ctrl.name == \freq) {is_synth = true}; };
    if (is_synth == true) { file = q.f_synths; } { file = q.f_fx };
    key = q.tidy_keys(key);
    if ( q.filter_synths_and_fx(key) == true ) {
      file.write(format("\n%:\n", key ));
      controls.do { |ctrl|
        ctrl_name = ctrl.name;
        value = ctrl.defaultValue.round(0.01);
        if (q.filter_ctrls(ctrl_name) == true) {
          file.write(format("  %: %\n", ctrl_name, value));
        };
      };
    };
  };
  q.f_synths.close;
  q.f_fx.close;
  "check files with tidal fx and synths".postln;
};


"super-dirt prepared".postln;
"check all FX and synths with:\n q.print_dirt_stuff\n".postln;

// {q.f_samps.close;}.defer(8);
q.print_samples = {
  "print samples set with:".postln;
  q.bank_names.collect{|bank|
    postf("q.ds_%\n", bank.basename)
  };
  '';
};
/*
// this is doing the same but worse
q.print_all_samples = {
q.bank_names.collect{|bank|
var do_this = format("q.ds_%\n", bank.basename);
do_this
};
};*/
q.print_samples;
);

{ q.print_dirt_stuff_params; }.defer(1);
};


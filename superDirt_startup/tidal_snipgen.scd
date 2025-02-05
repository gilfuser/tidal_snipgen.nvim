q = q ? ();
// q.samples_path = (Platform.userHomeDir +/+ "Samples").standardizePath;
q.samples_path = (Platform.userAppSupportDir +/+ "downloaded-quarks" +/+ "Dirt-Samples").standardizePath;

q.tsnipgen_temp_dir = Platform.userHomeDir +/+ ".tidal_snipgen";
if(File.mkdir(q.tsnipgen_temp_dir)) {
  postf("new directory created in %\n", q.tsnipgen_temp_dir)
} {
    postf("tidal_snipgen directory is: %\n", q.tsnipgen_temp_dir); post('')
  }; // if already exists, it won't overwrite it
q.f_samps = File( q.tsnipgen_temp_dir +/+ "dirt_samps.yaml".standardizePath, "w");
q.tsnipgen_samples_path = q.tsnipgen_temp_dir +/+ "samples_path.yaml";

if  ( File.exists(q.tsnipgen_samples_path) ) {
  if ( q.tsnipgen_samples_path.parseYAMLFile.at("user_defined") != "false" ) {
    q.samples_path = q.tsnipgen_samples_path.parseYAMLFile.at("user_defined").standardizePath;
  }
};

// run inside a Routine will garantee things are evaluated in the right order
fork{
0.2.wait;
">>>>>> generate snippets <<<<<<".postln;
// Recursive routine to search for folders with sound files and process them
(
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

r = ();
r.know = true;
q.sound_bank;
q.write_in_file = { |ev bank_name drummachine sample_folder|
  var name = sample_folder.asSymbol;
  var samp = ~dirt.buffers[name];
  if (q.sound_bank != bank_name) {
    q.f_samps.write(format("\n%:\n",bank_name));
    q.f_samps.write(format("  drummachine: %\n",drummachine));
    q.sound_bank = bank_name;
    postf("bank name: %\n", bank_name);
    r[bank_name.asSymbol] = [];
  };
  postf("bank name: %\n", bank_name);
  postf("sample name: %\n", name);
  r.at(bank_name.asSymbol).add(name);
  // q.banks_n_samps[bank_name.asSymbol].postln;
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

q.bank_names = Set[];

  (
q.all_banks = Set[];
q.loaded_samples = Set[];

q.search_log_load_samples = { |ev folder|
  var subfolders = folder.folders;
  // var is_root_bank = (folder.fullPath == q.samples_path);
  var soundFile, sound_bank, bank_name, trigger, sample_path, drummachine = false;
  subfolders.do { |subfolder|
    if (subfolder.folderName.beginsWith("_").not) // choose not to load with a _ before dir name
      // check if the subfolders contains sound files
    {
        subfolder.files.collect { |file|
          soundFile = SoundFile.openRead(file.fullPath);
          if (soundFile.notNil) {
            if ((subfolder.fullPath != q.samples_path) and: not(q.all_banks.includes(subfolder.fullPath.dirname))) {
              sound_bank = PathName(subfolder.fullPath.dirname); // subfolder parent
              bank_name = q.make_bank_name(sound_bank);
            };
            if ( not(q.loaded_samples.includes(file.folderName))) {
              sample_path = file.fullPath.dirname;
              ~dirt.loadSoundFiles(sample_path);
              if ( file.folderName.endsWith("-bd") .or (file.folderName.endsWith("-sd")) ) {
                drummachine = true;
              };
              q.loaded_samples.add(sample_path.basename);
              q.write_in_file(bank_name, drummachine, sample_path.basename);
            };
            soundFile.close;
            file.fullPath;
          };
        };

        q.search_log_load_samples(subfolder);
      }
  };
};
);
1.wait;
q.search_log_load_samples(PathName(q.samples_path));
q.f_samps.close;
);
/////////////////////////////////////////////////////////////

// clean synthDefs names as e.g. 'dirt_squiz2' and get only 'squiz'
// as they are in ~dirt.modules
q.keys_cleaner = { |env key|
  if ( key.beginsWith("dirt_") ) { key = key.replace("dirt_", "")};
  if (key.find("_").notNil) {
    var index = key.find("_");
    // the following 'if' is because of dirt_pitch_shift2 and dirt_sample_long_1_2
    /* if ( key.at(index+1).asString != "l" and: (
key.at(index+1).asString != "s" ) ) {
while {index < key.size} {key.takeAt(index)}
};
};
*/
    if (key.last.asString == "2") {key = key.replace("2", "")};
    key
  };

  q.filter_out_synths_and_fx = { |env key|
  ( not(key.contains("sample")) .and (key != "envelope") .and (key != "vowel") .and (key != "global") .and ( not( key.contains ("long")) ) .and (key != "cyclo")  .and (key != "gate") .and (key != "debug") and: not(key.beginsWith("in")) and: not(key.beginsWith("tutorial")) and: (key !="rms") and: (key != "monitor") and: (key != "out") and: (key != "shape") )
  };

  q.filter_out_ctrls = { |env, name|
  ( (name != \out) .and (name != \sustain) .and (name != \begin) .and (name != \end) .and (name != \gate) .and (name != \pan) .and (name != \freq) .and ( name != \ ) .and (name != \speed) .and (name != \amp) .and (name != \n) .and (name != \cps) );
  };

  q.is_fx = { |env, key|
  ( (key.beginsWith("dirt_")) or: (key.beginsWith("spectral-")) or: (key.beginsWith("dj-filter")) or: (key.beginsWith("squiz")) or: (key.beginsWith("waveloss")) )
  };

  q.is_synth = { |env, key|
  ( key.beginsWith("super") or: (key.beginsWith("sos")) or: (key.endsWith("sin")) or: (key == "imp") or: (key == "gabor") )
  };

  q.write_controls = { |env, file, key|
    var controls = SynthDescLib.match(key).controls;
    file.write(format("\n%:\n", key ));
    postf("\n%:\n", key);
    controls.do { |ctrl|
      var value = ctrl.defaultValue.round(0.01);
      if ( q.filter_out_ctrls(ctrl.name) ) {
        postf( "  %: %\n", ctrl.name, value);
        file.write(format("  %: %\n", ctrl.name, value));
      };
    };
  };
  q.new_synthDescs = q.new_synthDescs ?  SynthDescLib.global.synthDescs.keys - q.previous_synthDescs;
  q.allFxs = Set[];
  q.allSynths = Set[];
  q.f_synths = File( q.tsnipgen_temp_dir +/+ "dirt_synths.yaml".standardizePath, "w");
  q.f_fx = File( q.tsnipgen_temp_dir +/+ "dirt_fx.yaml".standardizePath, "w");
  q.print_dirt_stuff_params = {
    var file, controls, clean_key;
    q.new_synthDescs.asArray.sort.do { |key|
      key = key.asString;
      clean_key = q.keys_cleaner(key);
      if ( q.filter_out_synths_and_fx(clean_key) ) {
        if ( q.is_fx(key) )
        { file = q.f_fx;
            postf("fx: %\n", key);
            if ( not(q.allFxs.includes(clean_key)) ) {
              q.write_controls(file, key);
              q.allFxs.add(clean_key);
            };
          }
        {
            if(q.is_synth(key))
            {
                file = q.f_synths;
                postf("synth: %\n", key);
                if ( not(q.allSynths.includes(clean_key)) ) {
                  q.write_controls(file, key);
                  q.allSynths.add(clean_key);
                };
              } { "excluded synth or fx".postln; key.postln; };
          };
      };// {key.postln}; filtered out synthDescs
    };
    // q.print_dirt_stuff_params;
    q.f_synths.close;
    q.f_fx.close;
  };

  /*
(
q.print_dirt_stuff = {
( SynthDescLib.global.synthDescs.keys - q.previous_synthDescs ).
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

  /* q.print_dirt_stuff_params = {
var ctrl_name, value, file, controls, is_synth;
q.new_synthDescs.asArray.sort.keysValuesDo { |key|
is_synth = false;
controls = SynthDescLib.match(key).controls;
controls.do {|ctrl| if (ctrl.name == \freq) {is_synth = true}; };
if (is_synth == true) { file = q.f_synths; } { file = q.f_fx };
key = q.keys_cleaner(key);
if ( q.filter_out_synths_and_fx(key) == true ) {
file.write(format("\n%:\n", key ));
controls.do { |ctrl|
ctrl_name = ctrl.name;
value = ctrl.defaultValue.round(0.01);
if (q.filter_out_ctrls(ctrl_name) == true) {
file.write(format("  %: %\n", ctrl_name, value));
};
};
};
};
q.f_synths.close;
q.f_fx.close;
}; */

  /* q.print_samples = {
"samples:".postln;
q.bank_names.collect{|bank|
postf("q.ds_%\n", bank.basename)
};
'';
}; */
  wait(0.2);
  q.print_samples;
  wait(0.2);
  q.print_dirt_stuff_params;
};


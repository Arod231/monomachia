# Cascadeur's Python API for our clip round trip (Oct 6, 2026)

The question: how much of the Cascadeur round trip can Claude automate? The round trip is: load Claude's block-out, set up the scene and rig, then export the polished clip back to the asset repository. And can Claude drive Cascadeur at all?

Context. Claude keys block-outs by script in Blender on the UE5-style skeleton (52 bones mapped to Godot's humanoid profile, plus `B-handProp.L/R`) and exports GLB to the private asset repository. The owner polishes the signature moves (the deflect pairs, the Iai, the finishers) in Cascadeur Indie. The polished clips go back to the asset repository and through the game's clip pipeline.

Sources are primary only:

- Cascadeur's help pages, its Python API reference and its plans page.
- The files Nekki ships in the owner's install: Cascadeur 2026.2.3 (build 2026.2.3.0.16863, read from `cascadeur.exe`'s version info) at `C:\Program Files\Cascadeur`. These are the stubs, the bundled scripts and the templates.

A claim that rests only on community code or on strings read from the binary says so, and is marked **unconfirmed**. Nothing was run inside Cascadeur for this note.

## Answer

**Claude can drive a running Cascadeur.** Since 2026.2, Cascadeur ships a local MCP server. The owner starts it from the Scripts menu (**MCP > Start script server**). It listens on `http://127.0.0.1:8765/mcp` and has one tool, `run_script`. That tool runs any Python inside Cascadeur with the full `csc` API. ([2026.2 release notes](https://cascadeur.com/help/category/319); `resources\scripts\python\scripts\mcp\script_server\server.py`)

- Cascadeur must be open, with the GUI, and the owner must start the server each session.
- There is no documented headless or batch mode.

**What Claude can automate (all from the `csc` API, with the MCP server or as menu commands the owner clicks):**

- Open and save scenes, and loop over files: open a `.casc`, create scene tabs, save as.
- Import a model and an animation from FBX or GLB. Export the scene, the model or the animation only, to FBX or GLB. FBX export can be limited to the selected frames, and GLB export to the selected interval.
- Set the selected frame range on the timeline before an export.
- Read and write joint transforms on any frame. Set keys and an interval's interpolation (Bezier, Linear, Step, Fixed, Clamped, AI).
- Build the rig from a Quick Rigging Tool template. A template is a JSON file that Claude can write for our `B-` skeleton.
- Switch AutoPhysics, Animation Unbaking, Inbetweening, AutoPosing and the Mirror and Tween tools on and off through menu-action IDs. Nekki marks those IDs for gradual removal.

**What Claude can't automate:**

- Starting Cascadeur, signing in, or starting the MCP server. The owner does these.
- Configuring AutoPhysics, Unbaking or AutoPosing in depth. The API has only a few methods for them, and the settings API only reads.
- The polish itself. That stays the owner's eye and hand.

**Plan limits.** Indie exports every format (CASC, FBX, DAE, USD, GLTF) with no frame or joint limit. The Indie revenue cap is $100k a year. The plans page doesn't mention Python. The humanoid tools we need are on every plan: Rigging Tools, AutoPosing (humanoid and fingers), AutoPhysics, Unbaking and Inbetweening. Only Pro has Animation Retargeting, Scene Linking, Interaction with Environment and AutoPosing for quadrupeds. Since our block-outs and the Cascadeur scene share one skeleton, retargeting shouldn't be needed. That last point is untested. ([plans](https://cascadeur.com/plans))

**Recommended round trip:**

1. **Once per skeleton (Claude, checked by the owner).** Claude writes a Quick Rigging Tool template (`.qrigcasc`) that maps the `B-` bones, imports the skeleton and mesh GLB at a scale of 100, builds the rig by script (tested Oct 6, see the hands-on test) and saves `base_<fighter>.casc` in the asset repository. The owner checks the rig by eye.
2. **Per clip, set-up (Claude, over MCP or as a menu command).** Open the base scene in a new tab. Import Claude's block-out animation (GLB or FBX, animation only, scale 100; the Blender export keys every frame). Check the fit: export it straight back and flag any frame over 2 cm from the source. Optionally run Animation Unbaking. Save the clip as `<clip>.casc` beside its Blender source.
3. **Polish (owner).**
4. **Export (Claude, or a one-click command).** Select the clip's frame range. Export animation only (GLB with `include_animation`, `for_selected_interval` and the clip's fps, or FBX `export_joints_selected_frames`) with a scale of 0.01 into the asset repository.
5. **Back into our pipeline (our choice, not a Cascadeur fact).** A Claude Blender script imports that file as an action on the block-out's armature, back on frames 1 onward, and saves the `.blend` source. `npm run export` then makes the game's GLB as for every other clip, so the Blender export stays the only way art reaches the game. The `.casc` stays as the editable source of the polish.

**Where this differs from our docs.** The milestone 1 spec's "Who keys" row says Claude "can't operate Cascadeur" (`docs/specs/milestone-1.md`). With the 2026.2 MCP server, Claude can operate it while the owner has it open, and the hands-on test confirmed the set-up and export. On the owner's word (Oct 6) the spec now has Claude do them; the polish split is unchanged.

## 1. How scripts run, and outside control

- **Menu commands.** At start, Cascadeur reads the script files in its command folders and adds one item to the Commands menu per file. **Reload scripts** picks up later edits. ([Python Scripting in Cascadeur](https://cascadeur.com/help/tools/animation_tools/python_scripting_in_cascadeur); [Commands Menu](https://cascadeur.com/help/interface/main_menu/commands_menu))
- **What makes a command, on the help page.** The page says a command file has `command_name()` and `run(scene)`. ([Python Scripting in Cascadeur](https://cascadeur.com/help/tools/animation_tools/python_scripting_in_cascadeur))
- **What makes a command in 2026.2.3.** The shipped loader treats any module with a `run` function as a command. It takes the menu name from `name()` and the tooltip from `description()`, walking the packages named in the user's `settings.json`. That file holds `"Commands": ["commands"]` and `"Scripts": ["scripts"]`, plus an empty `"Python": {"Path": []}` and `"ScriptsDir": ""`. (`resources\scripts\python\python_actions_rule.py`; `%LOCALAPPDATA%\Nekki Limited\Cascadeur\settings.json`)
  - **Unconfirmed:** whether adding our own folder to `Python.Path` and a package name to `Commands` adds our commands without writing to Program Files. Neither setting is on the help pages.
- **Menus.** 2026.2 split the Commands menu into Commands (core scripts) and Scripts (additional scripts). It also added PySide for custom UI, and stub files for IntelliSense. ([2026.2](https://cascadeur.com/help/category/319))
- **Event scripts.** Scripts in `resources\scripts\python\events` respond to scene events such as creating, opening and saving a scene. ([Commands Menu](https://cascadeur.com/help/interface/main_menu/commands_menu))
- **Python console.** Window menu. Its own docs call it "intended primarily for running scripts, not for writing them." ([Python Scripting in Cascadeur](https://cascadeur.com/help/tools/animation_tools/python_scripting_in_cascadeur))
- **Batch inside the app.** Nekki's own sample loops over every `.casc` in a folder. For each it opens a tab, loads, saves and exports FBX. It is meant to run from the console. So batch work happens inside a running Cascadeur, not from outside it. (`resources\scripts\python\samples\casc_import_export.py`)

**The official MCP server (2026.2).** "Added support for a simple MCP server. Available in the Scripts menu through the MCP section." ([2026.2](https://cascadeur.com/help/category/319)) The Scripts menu page lists **Start script server** and **Stop script server**, and the server's details go to the Event log. ([Scripts Menu](https://cascadeur.com/help/category/320)) From the shipped code (`resources\scripts\python\scripts\mcp\script_server\server.py`, version 0.3.1, and its `README.md`):

- **Where it listens.** HTTP on `127.0.0.1:8765`: `GET /health`, `POST /run` with `{"code": ...}`, and `POST /mcp` (JSON-RPC, protocol `2024-11-05`).
- **What it offers.** One tool, `run_script` ("Run Python code inside Cascadeur on the next scene idle event"), and two resources: the API docs link and the list of importable modules.
- **How code runs.** On the main thread, at the next `scene_idle` event, with `scene`, `csc` and `app` in scope. An expression returns its `repr`. `print` output and event-log messages come back in the response.
- **Timeout.** A call waits at most 30 seconds, then reports "Timed out waiting for Cascadeur idle event".
- **Failures can report success.** A failed `scene.modify(...)` callback can still answer `ok: true`. Check the `modify` return value (False on failure), and read `%LOCALAPPDATA%\Nekki Limited\Cascadeur\logs\cascadeur_log.log` for the traceback.
- **No authentication.** Any local process can run code in Cascadeur while the server is on. It binds to localhost only.
- **Claude Code hook-up.** The install ships a `.mcp.json` (an `http` server at that URL) and an `AGENTS.md` that points agents at `run_script`. (`resources\scripts\python\.mcp.json`, `AGENTS.md`)
  - Adding it to our Claude Code settings is a configuration change the owner approves. One way is `claude mcp add --transport http cascadeur http://127.0.0.1:8765/mcp`.

**Command line. Undocumented; unconfirmed.** No help page lists command-line options. Strings and symbols in `presenter_lib.dll` and `cascadeur.exe` show a startup parser with these options:

- a positional `scene` ("A cascadeur scene file.");
- `run-script` ("Runs a command module directly on the app <command>.");
- `run-python-code` ("Runs a python code directly on the app <code>.");
- `single-user-mode`, `logger-silent-mode` and `help`.

An `isNoGui` flag exists in the startup parameters, but no option string for it was found. So there is no sign of a usable headless mode.

Community tools use `--run-script`:

- The GPL Cascadeur Bridge for Blender calls `cascadeur.exe --run-script <command>` after copying its commands into the commands folder ([arcsikex/cascadeur_bridge, utils/csc_handling.py](https://github.com/arcsikex/cascadeur_bridge)).
- A community MCP server does the same with a socket call-back ([ysk424/cascadeur-mcp](https://github.com/ysk424/cascadeur-mcp)).

Neither is Nekki's.

**Other MCP servers. Community, not Nekki; unconfirmed.** [IIshikiII/cascadeur-mcp](https://github.com/IIshikiII/cascadeur-mcp) (MIT; a file mailbox polled inside Cascadeur; says it is "independent of Nekki"). [ysk424/cascadeur-mcp](https://github.com/ysk424/cascadeur-mcp) (`--run-script` per call). We don't need either: the built-in server does the same job with Nekki's code.

## 2. Import and export by script

- **FBX: `csc.fbx.FbxLoader`.** Get it from `get_tool("FbxSceneLoader").get_fbx_loader(scene)`. ([FbxLoader](https://cascadeur.com/python-api/_generate/csc.fbx.FbxLoader.html))
  - Import: `import_model`, `import_scene`, `import_animation`, `import_animation_to_selected_objects`, `import_animation_to_selected_frames`, `add_model`, `add_model_to_selected`, `get_takes`.
  - Export: `export_model`, `export_all_objects`, `export_joints` (animation), `export_joints_selected_frames`, `export_joints_selected_objects`, `export_scene_selected_frames`, `export_scene_selected_objects`.
  - All take a file path. No dialog is needed.
- **FBX settings: `csc.fbx.FbxSettings`.** `mode` (Binary or Ascii), `up_axis` (X, Y or Z), `bake_animation`, `apply_euler_filter`. There is no scale or fps setting. ([FbxSettings](https://cascadeur.com/python-api/_generate/csc.fbx.FbxSettings.html))
- **Nekki's own wrapper.** `pycsc.general.fbx` maps "animation" export to `export_joints`. (`resources\scripts\python\pycsc\general\fbx.py`)
- **Nekki's quick export.** The shipped Quick Export command exports "animation from a selected interval" with `export_joints_selected_frames`. ([Scripts Menu](https://cascadeur.com/help/category/320); `scripts\quick_export\export_to_default_folder.py`)
- **GLB/glTF: `csc.glb`.** In the 2026.2.3 stubs, but not yet in the web API reference.
  - Calls: `process_import(scene, path, ImportOptions)` and `process_export(scene, path, ExportOptions)`.
  - Shared options: `include_animation`, `for_selected_interval`, `for_selected_objects`, `fps` and `scale_factor`.
  - Import also has `include_objects`, `is_update_mode` and `ignore_mesh_transform`. Export also has skin and mesh options, such as `weights_per_vertex_limit` and `remove_empty_nodes`.
  - Nekki's Meshy bridge imports GLB this way.
  - (`resources\scripts\stubs\csc\glb.pyi`; `scripts\meshy\meshy_cascadeur_bridge.py`; [csc index](https://cascadeur.com/python-api/csc.html) has no `csc.glb`)
- **GLB in the app.** The File menu's GLB export has Animation, Model, Scene and Scene-from-selected presets, plus "Export selected intervals". The import has an Animation preset and "Import to selected interval". ([Export GLB/GLTF](https://cascadeur.com/help/category/283); [Import GLB/GLTF/VRM](https://cascadeur.com/help/category/282))
- **USD and DAE.** Only through menu-action IDs: `File.Export.Scene.Usd...`, `File.Import.Animation.Usd...`, `File.Import.Fbx/Dae`, `File.Export.Fbx/Dae` and others. These open the app's dialogs. **Unconfirmed:** whether they can run without one. ([Actions ID list](https://cascadeur.com/help/category/301))
- **Frame ranges.** Select a range on the tracks with `scene.get_layers_selector().set_full_selection_by_parts(layer_ids, first, last)`, then use the "selected frames" or `for_selected_interval` exports. (`resources\scripts\stubs\csc\layers\__init__.pyi`)

## 3. Scene set-up and the rig

- **Scenes.** Open and close scene tabs: `SceneManager.create_application_scene`, `set_current_scene`, `remove_application_scene`. ([SceneManager](https://cascadeur.com/python-api/_generate/csc.app.SceneManager.html))
- **Loading.** `DataSourceManager.load_scene(path)` loads a scene with its extras. `ProjectLoader.load_from(path, domain_scene)` is a minimal load. ([DataSourceManager](https://cascadeur.com/python-api/_generate/csc.app.DataSourceManager.html); [ProjectLoader](https://cascadeur.com/python-api/_generate/csc.app.ProjectLoader.html))
- **Saving.** `save_scene_as(scene, path)`, or `view.Scene.save(path)`. ([DataSourceManager](https://cascadeur.com/python-api/_generate/csc.app.DataSourceManager.html); `samples\casc_import_export.py`)
- **Quick Rigging Tool from script.** `csc.tools.RiggingWindow` (got with `get_tool('RiggingToolWindowTool')` in Nekki's scripts) has:
  - `load_template_by_fileName` and `load_template_by_content`;
  - `create_from_qrt_by_fileName` and `create_from_qrt_by_content`;
  - `generate_rig_elements`, `open_quick_rigging_tool` and `set_is_create_autoposing`.
  - `csc.rig.QrtData` holds the QRT options: `is_align_pelvis`, `is_create_layers`, `is_spline_ik`, the hinge directions, `twists`, `untwists`.
  - (`resources\scripts\stubs\csc\tools\__init__.pyi`; `rigging\_proxy_rig_builder.py`; [QrtData](https://cascadeur.com/python-api/_generate/csc.rig.QrtData.html))
  - **Unconfirmed:** the exact call order that turns a template into a finished rig. No sample shows it end to end.
- **Templates.** QRT templates (`.qrigcasc`) are plain JSON.
  - Each body part maps a Cascadeur bone (`pelvis`, `stomach`, `chest`, `neck`, `head`, `clavicle_l`, `arm_l`, `forearm_l`, `hand_l`, `thigh_l`, `calf_l`, `foot_l`, `toe_l` and the right side) to a joint name and its parent path.
  - Sections exist for the five fingers of each hand (three joints each) and for the twist bones.
  - The install ships UE4, UE5, Mixamo (with and without namespace), Metahuman, Rokoko, Daz, CC3 and other templates.
  - In the UE5 template, `stomach` is `spine_02` and `chest` is `spine_04`.
  - (`resources\autorig_templates\UE5.qrigcasc`)
  - The help page: templates placed in `autorig_templates` are used to recognise a skeleton automatically. Twists are limited to "two per limb" for humanoids. ([Quick Rigging Tool](https://cascadeur.com/help/rig/rig_mode/quick_rigging_tool))
  - **For us:** none of the shipped templates uses our `B-` names, so Claude writes one. Our rig has no upper chest, so `stomach` → `B-spine` and `chest` → `B-chest` is the likely map. That is untested.
- **Prop bones.** Templates have no prop section. The help says a prop joint outside the character's chain needs its proto moved to the right place in the rig hierarchy, with **Bind with parent** off. ([Rigging Props](https://cascadeur.com/help/rig/advanced_rigging/adding_objects/rigging_props))
  - Rigging Tools can also make "Autoposing props" controllers for a prop's rigid body. ([Rigging Tools](https://cascadeur.com/help/rig/rig_mode/rigging_tools))
  - **Unconfirmed:** how `B-handProp.L/R` come through QRT and back out in an export. Test them by hand.

## 4. Keyframes by script

- **Every change goes through a modify call.** `scene.modify`, `modify_with_session`, `modify_update` or `modify_update_with_session` each take a callback. Each lands in undo history. ([Cascadeur Python API](https://cascadeur.com/help/category/215); [domain.Scene](https://cascadeur.com/python-api/_generate/csc.domain.Scene.html))
- **Reading and writing joint values.** Find a joint's Transform behaviour, then its data (for example `global_position`). Read with `DataViewer.get_data_value(id, frame)` and write with `DataEditor.set_data_value(id, frame, value)`. A value can be a vector, a quaternion, a `Rotation` or a matrix. ([DataViewer](https://cascadeur.com/python-api/_generate/csc.model.DataViewer.html); [DataEditor](https://cascadeur.com/python-api/_generate/csc.model.DataEditor.html))
  - Nekki's `move_joints.py` sample does this, then runs `scene_updater.run_update(...)` to recompute global data. (`resources\scripts\python\samples\move_joints.py`)
- **Animation tracks are called "layers" in the API.**
  - `layers.Editor.set_section`, `change_section` and `unset_section` set and remove keys and set each interval's interpolation and IK/FK type.
  - `layers.Layer.key_frame_indices`, `is_key` and `sections` read them.
  - The interpolation types are `BEZIER`, `LOW_AMPLITUDE_BEZIER` (viscous), `LINEAR`, `STEP`, `FIXED`, `NONE`, `CLAMPED_BEZIER` and `AI`.
  - ([Cascadeur Python API](https://cascadeur.com/help/category/215) has a worked `change_section` example; [layers.Editor](https://cascadeur.com/python-api/_generate/csc.layers.Editor.html); [Interpolation](https://cascadeur.com/python-api/_generate/csc.layers.layer.Interpolation.html))
- **Frames.** `scene.get_current_frame()` and `set_current_frame()`. `DataViewer.get_animation_size()`. ([domain.Scene](https://cascadeur.com/python-api/_generate/csc.domain.Scene.html); [DataViewer](https://cascadeur.com/python-api/_generate/csc.model.DataViewer.html))
- **Menu-action equivalents.** `Timeline.Add|Remove key`, `Timeline.Bezier.Bezier on selected interval`, `Timeline.Resize interval` and so on. ([Actions ID list](https://cascadeur.com/help/category/301))

## 5. AutoPhysics, AutoPosing, Unbaking, Inbetweening and trajectories

The direct API is thin. Most of these tools are only switched on and off through `ActionManager.call_action(<id>)`. Nekki says of that method: "We plan to gradually remove this method's functionality in the future. Instead, the most utilised tools will be available in the API with an extended functionality." ([Actions ID list](https://cascadeur.com/help/category/301); [ActionManager](https://cascadeur.com/python-api/_generate/csc.app.ActionManager.html))

| Tool | Direct API | Action IDs | Source |
|---|---|---|---|
| AutoPhysics | `AutoPhysicTool.turn_off()`, `turn_off_all_fulcrum_points()` | `AutoPhysicsTool.Switch Auto Physics`, `Snap To Auto Physics`, `Set priority frame`, `Switch Frozen Auto Physics` | [AutoPhysicTool](https://cascadeur.com/python-api/_generate/csc.tools.AutoPhysicTool.html); [Actions](https://cascadeur.com/help/category/301) |
| AutoPosing | `AutoPosingTool.add(session)`, `update(session)`, activate and deactivate | `AutoPosingTool.AutoPosing`, `AutoUnlock`, `SwitchLock`, `SwitchLockOnInterval` | [AutoPosingTool](https://cascadeur.com/python-api/_generate/csc.tools.AutoPosingTool.html); [Actions](https://cascadeur.com/help/category/301) |
| Animation Unbaking | `AnimationUnbakingTool.get_interpolation_difference()` only | `View.Animation unbaking` | [AnimationUnbakingTool](https://cascadeur.com/python-api/_generate/csc.tools.AnimationUnbakingTool.html); [Actions](https://cascadeur.com/help/category/301) |
| Inbetweening | `InbetweeningTool.get_update_parameter()` and `set_update_parameter(bool)`; the `AI` interpolation type on a section | `Scene.Inbetween interpolation switcher` | `stubs\csc\tools\__init__.pyi`; [Interpolation](https://cascadeur.com/python-api/_generate/csc.layers.layer.Interpolation.html); [Actions](https://cascadeur.com/help/category/301) |
| Trajectories | `Trajectory` and `BallisticTrajectory`: activate and deactivate only | the `TrajectoryTool.*` display and edit-mode IDs | [Trajectory](https://cascadeur.com/python-api/_generate/csc.tools.Trajectory.html); [Actions](https://cascadeur.com/help/category/301) |
| Mirror and Tween Machine | `MirrorTool.core()`, `AttractorTool`, `csc.tools.attractor.attract(...)` | `MirrorTool.Mirror on interval`, `TweenMachine.*` | [csc index](https://cascadeur.com/python-api/csc.html); [Actions](https://cascadeur.com/help/category/301) |

- **The direct API is under-documented.** Most of the methods in the table have no docstring on the reference pages (same links).
- **Tool settings can't be set by script.** The settings API only reads: `SettingsManager.get_bool_value`, `get_float_value` and `get_color_value`. There are no setters. A Nekki script reads the Unbaking settings this way, for example `AnimationUnbakingTool/IkPreference`. (`stubs\csc\app\__init__.pyi`; `ml\editable_animation.py`)
- **The per-character AutoPhysics parameters are scene data.** A shipped script reads the AutoPhysics behaviour's data on the centre of mass. **Unconfirmed:** whether writing them by script is supported. (`commands\restore_values.py`)
- **What the tools need.** Inbetweening works on the selected interval with at least two keys, at most 120 frames apart. ([Inbetweening](https://cascadeur.com/help/category/278)) Unbaking's settings are Interpolation difference, AutoPosing precision and fingers difference. ([Animation Unbaking](https://cascadeur.com/help/category/221))

## 6. Plan limits

- **Indie, from the [plans page](https://cascadeur.com/plans).**
  - Price: $19 a month, or $8 a month billed yearly. A yearly plan "Gives access to a Perpetual license".
  - Revenue cap: "The revenue must be less than $100k per year".
  - Export: "CASC, FBX, DAE, USD, GLTF". Indie is not held to Free's "300 frames per scene / 120 joints per scene" limit.
- **Which plans have what.** Read from the plans page's comparison table markup ([plans](https://cascadeur.com/plans)).

| Feature | Free | Indie | Pro | Teams |
|---|---|---|---|---|
| Physics-based tools (AutoPhysics) | yes | yes | yes | yes |
| Animation unbaking | yes | yes | yes | yes |
| Inbetweening tool | yes | yes | yes | yes |
| AutoPosing, and AutoPosing for fingers | yes | yes | yes | yes |
| Rigging tools | yes | yes | yes | yes |
| Animation retargeting | no | no | yes | yes |
| Interaction with environment in AutoPhysics | no | no | yes | yes |
| Scene linking tool | no | no | yes | yes |
| Autoposing for quadrupeds | no | no | yes | yes |

- **Python.** Neither the plans page nor the end-user agreement mentions Python, scripting, the API or MCP. So no plan restriction on scripting is documented. ([plans](https://cascadeur.com/plans); [end-user agreement](https://cascadeur.com/help/cascadeur_end_user_agreement))
- **The revenue test**, from the plans FAQ and clause 1.6 of the agreement:
  - It is gross revenue or funding in the 12 months before the download, below US $100,000.
  - For an individual making their own products, it counts "all earnings and funding received by you in connection with your use of the Software (for example, selling a game made with the use of the Software...)". ([plans](https://cascadeur.com/plans); [end-user agreement](https://cascadeur.com/help/cascadeur_end_user_agreement))
- **Credit.** Nekki asks for "reasonable efforts to mention that you have made your animations with Cascadeur". ([plans](https://cascadeur.com/plans))

## 7. Stability, documentation and versions

- **The docs lag the build.**
  - The help page still says "Cascadeur uses Python 3.8" and `command_name()`. The 2026.2.3 install ships `python311.dll` and uses `name()`. ([Python Scripting in Cascadeur](https://cascadeur.com/help/tools/animation_tools/python_scripting_in_cascadeur); `C:\Program Files\Cascadeur\python311.dll`; `python_actions_rule.py`)
  - The web reference has no `csc.glb` and no `InbetweeningTool`, which the shipped stubs have. ([csc index](https://cascadeur.com/python-api/csc.html); `resources\scripts\stubs\csc\`)
  - Treat the stubs in the install as the API for the installed version.
- **Many methods are under-documented.** Many reference pages give a signature with no docstring, for example AutoPosingTool, Trajectory and AnimationUnbakingTool. (Links in section 5.)
- **What the API was built for.** "Python scripting in Cascadeur provides low-level access to the software systems". The available methods focus mainly on rig generation and rigging tool implementation. ([Cascadeur Python API](https://cascadeur.com/help/category/215))
- **The menu-action route will shrink.** Nekki plans to remove `call_action`'s functionality gradually. ([Actions ID list](https://cascadeur.com/help/category/301))
- **The MCP server is new.** It is version 0.3.1, from 2026.2 (released August 2026), and the release notes call it "simple". (`server.py`; [2026.2](https://cascadeur.com/help/category/319))
- **Pin the version.** Scripts should pin to the installed version and be re-checked on each Cascadeur update. Yearly Indie keeps a perpetual build of each major version released during the subscription. ([plans](https://cascadeur.com/plans))

## Hands-on test (Oct 6, 2026)

Run from Claude Code against the owner's Cascadeur 2026.2.3 with the script server started, by plain HTTP to `http://127.0.0.1:8765/mcp` (the session predated the `cascadeur` server's entry in the user config). The clip was task 31's Right Cut (`exports/clips/right_cut.glb`, 44 frames at 30 fps, armature only). Every output went to a scratch folder, not the asset repository.

- **The link works (question 1).** `initialize`, `tools/list` and `tools/call run_script` answer in 2 to 4 seconds a call. Scripts see `app`, `scene` and `csc` on Python 3.11.0. Import and export each took under 0.2 s, far inside the 30-second wait. A QRT build wasn't timed.
- **Import by joint name, no retargeting (question 6).** `csc.glb.process_import` with `include_objects` and `include_animation`, into a new tab, brings in all 57 nodes with our names: the 52 mapped bones, `B-handProp.L/R`, `B-spineProxy`, `B-root` and `Armature`. It warns "No object with id Armature was found in import data" and succeeds. The timeline holds 45 frames (0 to 44).
- **Frame 0 is added.** Our Blender exports key frames 1 to 44 (times 0.033 to 1.467 s). Cascadeur adds a frame 0 in the rest pose. Selecting frames 1 to 44 (`get_layers_selector().set_full_selection_by_parts(all_layer_ids, 1, 44)`, no modify session needed) and exporting with `for_selected_interval` gives 44 frames at times 0 to 1.433 s: the same frames, one frame earlier. The way back into Blender has to put them back on frames 1 to 44, or the markers shift by a frame.
- **Constant channels are lost unless every frame is keyed.** The game's export (`scripts/blender/export_blend.py`, the glTF exporter's default animation-size optimisation) writes a channel that never changes as two `STEP` keys, on the first and last frames. Cascadeur keys those two frames and falls back to the rest pose between them: on Right Cut the gripping fingers open on frames 2 to 43, with fingertips up to 12.4 cm out. Exported from the same `.blend` with `export_optimize_animation_size=False` (every channel keyed on all 44 frames, `LINEAR`), the round trip is exact: across all 57 nodes and 44 frames the mean world-position gap is under 0.01 mm and the worst 0.01 mm, the prop bones included (question 5's export half).
- **The exported clip (question 7).** GLB, no meshes, one skin, one animation, 171 channels (translation, rotation and scale on all 57 nodes), every one `LINEAR` with a key on every frame, metres and Y up as in the source.
- **The rig from a template works by script (question 4).** The order, with no dialog at any step:
  1. Import the skeleton GLB with `scale_factor = 100` (and export with `0.01`). Cascadeur works in centimetres; at our metres the fighter is 1.8 units tall and the rig build fails on its hinge check ("Main hinge point projection is equal to hinge additional point position"), whatever the elbows' bend. The scaling alone round-trips exactly.
  2. Rig mode on without its dialog: create a "Rig info" object with a `RigInfo` behaviour whose `related_joints` are the skeleton's 56 joints, select it, and call `rig_mode.on.on(...)` inside `modify_update_with_session`, as `rig_mode.on.run_after_import` does before it asks about the QRT. Colour can be `None` with the new generator.
  3. `RiggingToolWindowTool.editor(...)`: `load_template_by_content(<template>)` maps all 51 of our template's bones (body 5, arms 8, legs 8, fingers 30; `stomach` → `B-spine`, `chest` → `B-chest`, no twist bones), then `generate_rig_elements()` builds the rig in 2 to 3 s (59 objects → 316).
  4. `rig_mode.off.run(scene, True)` back to animation mode in 2 to 6 s (279 objects).
  The rest pose's elbows are bent only 0.4°, and that is no problem at centimetre scale. The template is generated from our bone names: 51 of the 56 joints, leaving out `B-root`, `B-spineProxy`, `B-jaw` and `B-handProp.L/R`, which stay plain joints.
- **The rig refits the block-out (questions 5 and 6).** With the rig built, either on the animated scene or on a base scene that then imports the clip's animation (`include_objects = False`, `include_animation = True`, 1.5 s), the exported clip is no longer exact. Every bone stays within 1.4 cm on 43 of the 44 frames (the fingertips the worst), and the prop bones move with the hands. On frame 17, the fastest moment of the cut, the right elbow swings 25 cm inward while the shoulder and hand stay put: the rig solves that arm with a different elbow direction. The result is the same with or without AutoPosing and by either route, so it's deterministic. Cascadeur logs "Local position/rotation of B-… has changed after rig generation" on most frames for most body bones.
- **What that means for the round trip.** A block-out that Claude imports onto the rig needs a fidelity check before the owner polishes: export it straight back, compare with the source frame by frame, and flag any frame over 2 cm, as frame 17 is here. The polished clip is checked by the game's own tests anyway (bands, contact distance, the sheets).
- **Not yet tested:** questions 2, 3, 8 and 9, a fix for the elbow frame (keying the elbow direction controller from the source, or Unbaking), the GLB import into the game's clip pipeline, and how the owner polishes with no fighter mesh in the scene (no fighter model is exported yet; `exports/fighters/` is empty).
- **A lesson for scripts.** `scene_manager.scenes()` doesn't list tabs in the order they were opened. A script that closes its own tabs must keep the tab objects it created, never index the list.

## Key poses and AI inbetweening by script (Oct 7, 2026)

The owner chose to have the bare-hands clips made in Cascadeur (milestone-1 task 89). Built as `scripts/cascadeur/generate.mjs` (see `docs/architecture.md`); what it found in Cascadeur 2026.2.3:

- **The Cascadeur half runs in stages, one script call each.** `POST /run` waits at most 30 seconds, and the AI inbetweens are only computed once Cascadeur is idle after the keys are set: an export in the same call as the keys carried the block-out's frames, not the inbetweens. So `generate_clip.py` runs by stage (`rig`: a new tab, kept by id in `builtins._monomachia_tabs` so each later stage finds its own tab even if another session switches the current one, then the GLB import and the rig; `keys`: the keys dropped off every frame but the key poses, AI interpolation between; `export`; `close`: the tab's own `save(path)`, synchronous, since `DataSourceManager.save_scene_as` wrote nothing from a script, then `remove_application_scene`). The driver repeats the export until two in a row, 1.5 s apart, have the same SHA-256, which happens once the inbetweens are in. A call that times out is treated as still running: the driver waits for `/health` to show an empty queue. Two sessions using Cascadeur at once crashed it (Oct 7, 17:29), so the driver takes a lock inside Cascadeur (`builtins._lane_lock`, the lane's branch name and a take time) before its first stage and lets it go after closing its tab.
- **A GLB slid to 0 s imports without the rest-pose frame.** The block-outs are exported with `export_anim_slide_to_zero`, so Cascadeur's frame k is the clip's frame k and no frame 0 is added.
- **The rig is built from a template by script** as the hands-on test found (`rig_mode.on.on` inside `modify_update_with_session`, `RiggingToolWindowTool` `load_template_by_content` and `generate_rig_elements`, `rig_mode.off.run(scene, True)`). The template is committed as `scripts/cascadeur/iglesias.qrigcasc` (51 bones). On the three punches the rig kept the key-pose frames exact (0.0 cm).
- **Key poses and AI inbetweening work by script.** Inside `scene.modify`, `layers_editor().unset_section(frame, layer)` drops a key and `change_section(frame, layer, f)` with `section.interval.interpolation = Interpolation.AI` sets the AI interpolation, as Nekki's own keyframe-reduction command does. The export then carries Cascadeur's inbetweens: on the Jab 4 to 8 cm off the block-out between the key poses, exact on them.
- **AI inbetweening lets planted feet drift** 1 to 3 cm between key poses, so the Blender half holds the feet to the block-out's (legs on IK, knees toward the generated clip's).
- **AutoPhysics does nothing from a script.** `call_action("AutoPhysicsTool.Switch Auto Physics")` then `"AutoPhysicsTool.Snap To Auto Physics"` on the selected interval left the clip unchanged (0.0 cm); `AutoPhysicTool.editor(...).turn_off()` turns it back off. It isn't run; the polish can.

## Open questions (for a hands-on test in the owner's Cascadeur)

1. **The MCP link.** With the server started, does Claude Code connect to `http://127.0.0.1:8765/mcp` and run `run_script`? Does a long call (a GLB export of a 3-second clip, a QRT build) finish inside the 30-second wait? If not, does it still finish in the background?
2. **Our own commands folder.** Do `settings.json`'s `Python.Path` and `Commands` entries add a command folder outside Program Files? Or do our commands have to be copied into `resources\scripts\python\commands` (which needs admin rights)?
3. **The command line.** Does `cascadeur.exe --help` print the options found in the binary? Does `--run-script` or `--run-python-code` act on an already-running Cascadeur, or start a second one? Does a positional `.casc` path open that scene?
4. **Quick Rigging Tool from script.** Which `RiggingWindow` call order turns a hand-written `B-` template into a finished rig (`load_template_by_content`, then `create_from_qrt_by_content`, then `generate_rig_elements`)? Does mapping `stomach` → `B-spine` and `chest` → `B-chest` give a sound spine?
5. **Prop bones.** Do `B-handProp.L/R` survive QRT, polish and export, with their keys? Does the weapon still sit in the hand after the round trip?
6. **Animation onto the base scene.** Does `FbxLoader.import_animation`, or `csc.glb.process_import` with `include_animation` and without objects, map Claude's block-out onto the rigged base scene by joint name? Or does it need the Pro-only retargeting? Do the hips' travel and the root come through unscaled?
7. **The exported clip.** What does a GLB export with `include_animation`, `for_selected_interval` and `fps=30` contain? Animation only, all 55 or 56 bones, our names, the right frame count, Y up, metres? Does the existing import read it like a Blender export?
8. **The tools from script.** Do `call_action("View.Animation unbaking")`, `call_action("AutoPhysicsTool.Switch Auto Physics")` and `call_action("AutoPhysicsTool.Snap to Auto Physics")` run without a dialog? Do they act on the current selection?
9. **USD and DAE.** Do their action IDs export without a dialog? We probably don't need them, since GLB and FBX have direct calls.

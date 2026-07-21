# Quaternions Are Not That Scary

This repository supports a proposed talk for the Ruby Nights Auckland meetup about using quaternions for 3D rotations with Ruby.

It contains:

- a quaternion cube demo runnable with the DragonRuby Game Toolkit in `app/`;
- the Marp slide source in `slides/quaternions_dragonruby_marp.md`;
- the exported presentation in `slides/quaternions_dragonruby_marp.pdf`;
- implementation and presentation plans in `doc/plan/`.

## Run the demo

Place this repository in a DragonRuby distribution as its `mygame` directory, then run DragonRuby from the repository root:

```sh
../dragonruby
```

Use `X`, `Y`, and `Z` to rotate around the three axes, `J`, `K`, and `L` to rotate in the opposite direction, and `R` to reset the cube.

## Licence

The original demo code is available under the MIT Licence. The original slides and documentation are available under the [Creative Commons Attribution 4.0 International Licence](https://creativecommons.org/licenses/by/4.0/).

See `LICENSE.md` for the exact scope. DragonRuby and other third-party material retain their own licences; see `open-source-licenses.txt` for bundled notices.

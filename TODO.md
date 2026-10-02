# Intellivision Build Runner

**Applies to version:** 1.0.5

Just like any other software, _IVBR_ obviously has limitations: some are there almost by-design because it's tailored to my own way of working which is different from others'; some might be bugs or just things that I haven't had time to implement yet even though they'd be nice to have.

Here's a brief list in no particular order:

## TODOs

- [ ] ability to run pre-execution scripts/programs
- [ ] ability to run post-execution scripts/programs
- [ ] create configuration files/execution instructions, some simple use cases:
  - [ ] configure aforementioned pre/post scripts
  - [ ] manage options for _IntyBASIC_, _AS1600_ and _JZIntv_ without cluttering the command line
  - [ ] this could help with repetitive/predictable builds
- [ ] better tests
- [ ] optional pause between the different phases
- [ ] consider a _Bash_ port (not sure about this because _PowerShell_ is multiplatform since long time, even though I do a couple of Windows specific assumptions in the code, but nothing that can't be modified if/when needed), not in my top list as of now

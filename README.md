# VineFlower-1.11.1-CLI-Wrapper
This is a simple CLI script to easily interact with VineFlower 1.11.1 in command line. It accepts .JAR files and/or .class directories. Requires Java (JDK 21+ Recommended)

# Features
- Import .JAR files directly, or use extracted class directories
- Searches Maven Central for required libraries
- Writes to console & file with info and links to the libraries found
- Recommends Java version for rebuild of decompiled sources
- Scans classes to find required libraries
- Offers to optionally download libraries to new sources directory
- If libraries are downloaded, creates compile & run bat files

# Disclaimer
- This tool is meant for research purposes only. Only decompile .JARs or classes you have permission to do so with
- As with any decompiler, VineFlower may not generate buildable code by itself. You will likely have to manually refactor
- It does a best attempt at fetching libraries & generating configs, for more complex projects, results may vary.

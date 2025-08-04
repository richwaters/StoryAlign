# storyalign
storyalign is a macOS command line tool that combines an epub book with an audiobook to produce an enriched epub  containing synchronized narration.

storyalign is based on the storyteller-platform project available here: https://gitlab.com/storyteller-platform/storyteller. It extracts the core alignment functionality from that project into a standalone tool with minimal dependencies.


## Requirements

- macOS on ARM (Apple Silicon)  
- DRM-free EPUB 3  
- M4B audiobook format  


## Quickstart
Download the zip containing the binary with this command:

`curl -O -L https://github.com/richwaters/StoryAlign/releases/latest/download/storyalign-macos-arm64.zip`

- unzip the downloaded file

- copy the storyalign binary to a directory in your PATH or run it in place with:

- storyalign \<epub file\> \<audiobook file\>

On first run, it will prompt for confirmation to download necessary model files, and then create a new epub with "\_narrated" appended to the basename of the input epub file. Subsequent runs will bypass the downloads.

      
## Source Installation

-  git clone https://github.com/richwaters/StoryAlign.git
-  cd StoryAlign
-  make install

That places the binary into the bin subdirectory. From there, you can cp ./bin/storyalign into a
location in your PATH or run it in place.


## Usage

storyalign [--help] [--version] [--outfile=\<file\>] [--whisper-model=\<file\>] [--log-level=(debug|info|timestamp|warn|error)] [--no-progress] [--throttle]  [--audio-loader=(avfoundation|ffmpeg)] [--report=(none|score|stats|full|json)] [--whisper-beam-size=\<number\>] [--whisper-dtw] [--session-dir=\<directory\>] [--stage=(epub|audio|transcribe|align|xml|export|report|all)] \<ebook\> \<audiobook\>

### Arguments:
  \<ebook\>        The input ebook file (in .epub format)

  \<audio book\>    The input audiobook file (in .m4b format).

### Options:

**--outfile** <file>
      Set the file in which to save the aligned book. Defaults to the
      name and path of the input  file with '\_narrated' appended to the
      basename of that file.

**--whisper-model** <file>
      The whisper model file. This is a 'ggml' file compatible with
      the whisper.cpp library. The 'ggml-tiny.en.bin' model is appropriate
      and best for most cases. If this option is not specified,
      storyalign will download and install the model after prompting for
      confirmation. If you do specify a model file, make sure the companion
      .mlmodelc files are installed the same location as the specified .bin
      file.

**--log-level**=(debug|info|timestamp|warn|error)
      Set the level of logging output. Defaults to 'warn'. Set to
      'error' to only report errors. If set to anything above 'warn',
      either redirect stderr (where these messages are sent) or user
      the --no-progress flag to prevent conflicts.

**--no-progress**
      Suppress progress updates.

**--throttle**
      By default, storyalign will use all of the resources the the
      operating system allows. That can end up working the
      device pretty hard. Use this option to pair back on that. Aligning
      the book will take longer, but it'll keep the fans off.

**--audio-loader** (avfoundation|ffmpeg)
      Selects the audio-loading engine. The default is 'avfoundation',
      which uses Apple's builtin frameworks to load and decode audio. In
      most cases this should work fine. The 'ffmpeg' option uses the
      FFmpeg command-line utility to load and decode audio. This might be
      helpful if you encounter issues with the default. To make use of
      it, you must have ffmpeg installed on your system and in your path.

**--version**
      Show version information

**-h**, **--help**
      Show help information.

=====

### Development Options:
  These options are useful for debugging and testing, but they usually
  aren't used in normal operation.

**--report**=(none|score|stats|full|json)
      Show a report describing the results of the alignment when it
      has completed. This 'score' choice emits a score that predicts the
      percentage of sentences that have been aligned correctly. Other
      options show more detailed information about what was aligned.
      The default is 'none'.

**--whisper-beam-size** <number (1-8)>
      Set the number of paths explored by whisper.cpp when looking for the
      the best transcription. Higher values will consider more options. That
      doesn't necessarily mean more accuracy. In fact, it's a bit
      arbitrary. (Lookup 'beam search curse' to learn more). storyalign
      defaults to 2 for large & medium models, 7 for tiny models and 5 for
      all other models.

**--whisper-dtw**
      Enable dynamic type warping experimental feature for whisper.cpp and
      the experimental handling of what information in storyalign. This
      might improve accuracy of the timing of the transcription.

**--session-dir** <directory>
      Set the directory used for session data. It is required when --stage
      is specified, and it tells storyalign where to store both temporary
      and persisted data.

**--stage** (epub|audio|transcribe|align|xml|export|report|all)
      The processing stage to be run. When set, \(toolName) expects to find 
      intermediate files stored in the directory pointed to by the session-dir
      argument. It will re-generate missing information required to run
      the specified stage.


## Models & Transcriptions
storyalign uses the 'whisper.cpp' for transcription of the audio book. That project can be found at: https://github.com/ggml-org/whisper.cpp. By default, storyalign uses the tiny.en model which it downloads installs under a .storyalign directory in the user's home folder. Other models can be downloaded from https://huggingface.co/ggerganov/whisper.cpp/tree/main. For best results, and to avoid a bunch of warnings, **the companion .mlmodelc.zip file should be downloaded and installed in the same directory as the .bin model**. 

The large-v3-turbo seems to work the best in most cases, but in some cases the larger models can actually work worse. They can get stuck in a punctuation-less mode, and they can also suffer from the 'beam-search-curse'. To be honest, the whole thing seems a bit of a crap-shoot. In the case of storyalign, you can spend a lot of time trying to get things perfect, but ultimately it's only the difference of a fraction of a percent of sentences being misaligned, and that doesn't have much of an affect on the reading/listening experience.

That said, the quality of the narrated epub is mostly dependent on the quality of the transcription so it is important for that part to work.


## Scores & Reports
The --report option can be used to tell storyalign to produce a report about how well it thinks the alignment worked. This includes a score that is based on the percentage of sentences that it thinks were aligned correctly. This should usually be over 98 or 99%, but it can be less, especially for shorter books. This is due to the fact that some portions of the book like acknowledgement, about the author, etc. might not appear in the audio at all. For smaller books those sections are a larger percentage of the total book, which causes a lower overall score. Proper epubs will have 'bodymatter' and 'backmatter' attributes that point to the actual content of the book, but use of 'backmatter' is still spotty.

The storyalign reporting uses various mechanisms to determine if a sentence might be misaligned, but the main surefire indicator is if a sentence is too fast. That said, the current version of the reports still produces a lot of false positives. 



## Epub Readers
There are two iOS epub readers I know of that support the narrated epubs created by storyalign are the 'Storyteller reader' from https://apps.apple.com/us/app/storyteller-reader/id6474467720 and 'BookFusion' from https://apps.apple.com/us/app/bookfusion/id1141834096.  As storyalign is derived from storyteller-platform, you are highly encouraged to download that app and support that project as much as possible.

On the Mac, there is an app called 'Thorium Reader' at: https://www.edrlab.org/software/thorium-reader/. I don't do much ebook reading on my Mac, but this app's search functionality has been incredibly useful in investigating misalignments reported in storyalign's reports.


## DRM-free Books
DRM (Digital rights management) is a set of technical controls (mostly encryption) added to books to supposedly prevent unauthorized use or distribution. My sense is that author's themselves don't care much about it, and it is used to lock you into a single book-reading platform more than anything else. For obvious reasons, storyalign only works on DRM-free books. Many books can be purchased DRM-free from various platforms like ebookshop.org, libro.fm, and kobo. 


## Support Tools

### smilcheck
smilcheck is a tool that can be useful for checking the epub-3 media overlays used by these narrated books. It's a work-in-progress, as I decided to focus more on the reporting within storyalign instead of continuing to improve smilcheck. Still, smilcheck is a useful external tool, as it can be run on any read-aloud epub, not just those created by storyalign. It works in a similar fashion to storyalign's reporting in that it examines the pacing of sentences to find misalignments. It differs in that it only uses the information in the final enhanced epub to make it's determinations.

Usage is simply: smilcheck \<epub file\>

smilcheck should generally be run after confirming the book passes the checks in the epubcheck tool available here: https://www.w3.org/publishing/epubcheck/  (or with brew install epubcheck), as that tool performs important checks on the structure of the book, while smilcheck mostly focuses on sentence pacing.


### epubdiff.sh
This is a tool that performs a diff on 2 epubs. It doesn't do the diff itself, as it relies on an external tool (set by DIFFTOOL) at the top of the script for that. It just unzips the epubs into temporary directories and calls the difftool to perform the diff.

Usage is: epubdiff.sh \<epub file 1\> \<epub file 2\>


### epubstrip.sh
epubstrip.sh slims down a narrated epub by removing the audio and some of the meta information that contains dates and times. It outputs a checksum of the content of the epub when it completes. This checksum is then used by the full book tests to ensure that code modifications don't cause unintended changes to the produced book.

Usage is: epubstrip.sh \<epub file\>


### mkExpected.sh
This tool is used to make the expected result files for the full book tests. When complete, it outputs the checksum of the stripped content which can then be manually entered into the testinfo.json file. 

Usage is: mkExpected.sh \<book name (no extension)\>


### generate_schemes_for_book.sh
It's helpful to debug the tool by running the different stages. To accomplish that, an Xcode scheme is used for each separate run stage. The generate_schemes_for_book.sh tool is used to generate the schemes from a template. This is a lot easier than using the Xcode scheme editor to add arguments, environment, etc. for each scheme. Basically, you can set all of the arguments for all of the schemes with a simple command. The basename of the epub file and the audio file must match for this script to work.

Usage is: generate_schemes_for_book.sh <options> <epub file>




## Contributing

Contributions, comments, and bug reports are welcome via GitHub issues, discussions, and pull requests.


## License

This project is released under the MIT License. See LICENSE for details.


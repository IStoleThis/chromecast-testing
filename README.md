<p align="center">
 <img width=200px height=200px src="assets/app_icons/icon-red.png"/>
</p>

<h1 align="center"> Mangayomi </h1>

<div align="center">

 [![GitHub downloads](https://img.shields.io/github/downloads/kodjodevf/mangayomi/total?label=downloads&labelColor=27303D&color=0D1117&logo=github&logoColor=FFFFFF&style=flat)](https://github.com/kodjodevf/mangayomi/releases)
![star](https://img.shields.io/github/stars/kodjodevf/mangayomi)
 [![Discord server](https://img.shields.io/discord/1157628512077893666.svg?label=&labelColor=6A7EC2&color=7389D8&logo=discord&logoColor=FFFFFF)](https://discord.com/invite/EjfBuYahsP) 


Mangayomi is an open-source Flutter app for reading manga, novels, and watching animes across multiple platforms.

**This fork adds Chromecast casting to the anime player.**
</div>

> [!NOTE]
> This is an unofficial fork of [kodjodevf/mangayomi](https://github.com/kodjodevf/mangayomi). It adds [Chromecast casting](#chromecast-casting); everything else is the official app, made by its developers.

> [!WARNING]
> **Official Warning**: Mangayomi does not have an official website. This GitHub repository ([kodjodevf/mangayomi](https://github.com/kodjodevf/mangayomi)) and our official [Discord server](https://discord.com/invite/EjfBuYahsP) are the **only official sources** for Mangayomi. Always download official releases from our GitHub repository.

## Features

<div align="left">

Features include:
* Reading manga, webtoons, comics, novels, animes, movies, and more.
* Local reading of content.
* A configurable reader with multiple viewers, reading directions and other settings.
* Tracker support for anime and manga: [MyAnimeList](https://myanimelist.net/), [AniList](https://anilist.co/), [SIMKL](https://simkl.com/), [trakt](https://app.trakt.tv/) and [Kitsu](https://kitsu.io/) support.
* Categories to organize your library.
* Light and dark themes.
* Create backups locally to read offline or to your desired cloud service.
* Cast anime to a Chromecast or Google TV (this fork).

</div>

## Chromecast casting

Tap the cast icon at the top of the anime player and pick a Chromecast, Google TV or TV with Chromecast built-in on the same Wi-Fi.

* Works with sources that need extra headers: the app relays the stream to the TV.
* Starts where you were, saves your watch progress as the TV plays, and rolls on to the next episode when autoplay is on.
* The cast panel works as a remote: play/pause, back or forward 10 seconds, seek and volume.
* On iOS, casting keeps going with the screen locked or while you use other apps, even ones playing sound, and the lock screen and Control Center can control the TV.
* WebVTT and SRT subtitles show on the TV. (Chromecast doesn't support ASS subtitles.)

Keep the phone on the same Wi-Fi as the TV while casting, because the video goes through it.

## Download
**iOS with Chromecast casting:** add this fork's source to your sideloading app (below), or get the IPA from this fork's [releases](https://github.com/IStoleThis/chromecast-testing/releases).

**Other platforms:** get the official app from the [Mangayomi releases page](https://github.com/kodjodevf/mangayomi/releases). This fork only publishes iOS builds.

## iOS Sideloading Sources
<a href="https://intradeus.github.io/http-protocol-redirector?r=altstore://source?url=https://github.com/IStoleThis/chromecast-testing/releases/latest/download/altstore-source.json"><img alt="AltStore Source" src="repo/images/buttons/altstore_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=feather://source/https://github.com/IStoleThis/chromecast-testing/releases/latest/download/altstore-source.json"><img alt="Feather Source" src="repo/images/buttons/feather_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=sidestore://source?url=https://github.com/IStoleThis/chromecast-testing/releases/latest/download/altstore-source.json"><img alt="Sidestore Source" src="repo/images/buttons/sidestore_button.png" width="150"></a>
&nbsp;
<a href="https://github.com/IStoleThis/chromecast-testing/releases/latest/download/altstore-source.json"><img alt="Direct URL Source" src="repo/images/buttons/url_button.png" width="150"></a>

Builds from this fork are unsigned. AltStore and SideStore sign them with your Apple ID as they install them (with a free Apple ID, the app has to be refreshed every 7 days); Feather signs them with the certificate you've imported.

# Contributing

Contributions are welcome!

To get started with extension development, see [CONTRIBUTING-DART.md](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-DART.md) for create sources in Dart or [CONTRIBUTING-JS.md](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-JS.md) for create sources in JavaScript.

## Using flutter_rust_bridge

To run and build this app, you need to have
[Flutter SDK](https://docs.flutter.dev/get-started/install)
and [Rust toolchain](https://www.rust-lang.org/tools/install)
installed on your system.
You can check that your system is ready with the commands below.
Note that all the Flutter subcomponents should be installed.

```bash
rustc --version
flutter doctor
```

You also need to have the CLI tool for flutter_rust_bridge ready.

```bash
cargo install 'flutter_rust_bridge_codegen'
```

run the following command:

```bash
flutter_rust_bridge_codegen generate
```

Now you can run and build this app just like any other Flutter projects.

```bash
flutter run
```



## License

    Copyright 2023 Moustapha Kodjo Amadou

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    

## Disclaimer

Mangayomi is not hosting any kind of content and the developer(s) of this application does not have any affiliation with the content providers that are freely available in the internet.
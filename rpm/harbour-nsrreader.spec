Name:       harbour-nsrreader
Summary:    NSR Reader - PDF viewer for musicians
Version:    0.22.0
Release:    1
License:    GPLv3
URL:        https://github.com/smatkovi/harbour-nsrreader
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   poppler-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(poppler-qt5)
BuildRequires:  desktop-file-utils

%description
A fast PDF viewer geared towards reading sheet music: pre-rendering,
keyboard/bar navigation, text jumps (Coda/Segno/Fine), annotations and
a type-to-search file browser.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

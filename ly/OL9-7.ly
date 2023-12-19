\version "2.24.0"
\header { tagline = "" }
\paper {
  indent = 0\cm
  top-margin = 0\cm
  right-margin = 0.13\cm % to fit lyric hyphens
  bottom-margin = 0\cm
  left-margin = 0\cm
  paper-width = 7\cm
  page-breaking = #ly:one-page-breaking
  system-system-spacing.basic-distance = #11
  score-system-spacing.basic-distance = #11
  ragged-last = ##f
}


%% Author: Thomas Morley
%% https://lists.gnu.org/archive/html/lilypond-user/2020-05/msg00002.html
#(define (line-position grob)
"Returns position of @var[grob} in current system:
   @code{'start}, if at first time-step
   @code{'end}, if at last time-step
   @code{'middle} otherwise
"
  (let* ((col (ly:item-get-column grob))
         (ln (ly:grob-object col 'left-neighbor))
         (rn (ly:grob-object col 'right-neighbor))
         (col-to-check-left (if (ly:grob? ln) ln col))
         (col-to-check-right (if (ly:grob? rn) rn col))
         (break-dir-left
           (and
             (ly:grob-property col-to-check-left 'non-musical #f)
             (ly:item-break-dir col-to-check-left)))
         (break-dir-right
           (and
             (ly:grob-property col-to-check-right 'non-musical #f)
             (ly:item-break-dir col-to-check-right))))
        (cond ((eqv? 1 break-dir-left) 'start)
              ((eqv? -1 break-dir-right) 'end)
              (else 'middle))))

#(define (tranparent-at-line-position vctor)
  (lambda (grob)
  "Relying on @code{line-position} select the relevant enry from @var{vctor}.
Used to determine transparency,"
    (case (line-position grob)
      ((end) (not (vector-ref vctor 0)))
      ((middle) (not (vector-ref vctor 1)))
      ((start) (not (vector-ref vctor 2))))))

noteHeadBreakVisibility =
#(define-music-function (break-visibility)(vector?)
"Makes @code{NoteHead}s transparent relying on @var{break-visibility}"
#{
  \override NoteHead.transparent =
    #(tranparent-at-line-position break-visibility)
#})

#(define delete-ledgers-for-transparent-note-heads
  (lambda (grob)
    "Reads whether a @code{NoteHead} is transparent.
If so this @code{NoteHead} is removed from @code{'note-heads} from
@var{grob}, which is supposed to be @code{LedgerLineSpanner}.
As a result ledgers are not printed for this @code{NoteHead}"
    (let* ((nhds-array (ly:grob-object grob 'note-heads))
           (nhds-list
             (if (ly:grob-array? nhds-array)
                 (ly:grob-array->list nhds-array)
                 '()))
           ;; Relies on the transparent-property being done before
           ;; Staff.LedgerLineSpanner.after-line-breaking is executed.
           ;; This is fragile ...
           (to-keep
             (remove
               (lambda (nhd)
                 (ly:grob-property nhd 'transparent #f))
               nhds-list)))
      ;; TODO find a better method to iterate over grob-arrays, similiar
      ;; to filter/remove etc for lists
      ;; For now rebuilt from scratch
      (set! (ly:grob-object grob 'note-heads)  '())
      (for-each
        (lambda (nhd)
          (ly:pointer-group-interface::add-grob grob 'note-heads nhd))
        to-keep))))

squashNotes = {
  \override NoteHead.X-extent = #'(-0.2 . 0.2)
  \override NoteHead.Y-extent = #'(-0.75 . 0)
  \override NoteHead.stencil =
    #(lambda (grob)
       (let ((pos (ly:grob-property grob 'staff-position)))
         (begin
           (if (< pos -7) (display "ERROR: Lower brevis then expected\n") (display "OK: Expected brevis position\n"))
           (if (<= pos -6) ly:text-interface::print ly:note-head::print))))
}
unSquashNotes = {
  \revert NoteHead.X-extent
  \revert NoteHead.Y-extent
  \revert NoteHead.stencil
}

hideNotes = \noteHeadBreakVisibility #begin-of-line-visible
unHideNotes = \noteHeadBreakVisibility #all-visible

% work-around for resetting accidentals
% https://lilypond.org/doc/v2.23/Documentation/notation/displaying-rhythms#unmetered-music
cadenzaMeasure = {
  \cadenzaOff
  \partial 1024 s1024
  \cadenzaOn
}

#(define-markup-command (accent layout props text) (markup?)
  "Underline accented syllable"
  (interpret-markup layout props
    #{\markup \override #'(offset . 4.3) \underline { #text }#}))

responsum = \markup \concat {
  "R" \hspace #-1.05 \path #0.1 #'((moveto 0 0.07) (lineto 0.9 0.8)) \hspace #0.05 "."
}

spaceSize = #0.6828661417322834 % exact space size for TeX Gyre Schola

\layout {
  \context {
    \Staff
    \remove "Time_signature_engraver"
    \override LedgerLineSpanner.after-line-breaking = #delete-ledgers-for-transparent-note-heads
  }
  \context {
    \Lyrics {
      \override LyricSpace.minimum-distance = \spaceSize
      \override LyricText.font-name = #"TeX Gyre Schola"
      \override LyricText.font-size = 1
      \override StanzaNumber.font-name = #"TeX Gyre Schola Bold"
      \override StanzaNumber.font-size = 1
    }
  }
  \context {
    \Score 
    \override NoteHead.text =
      #(lambda (grob) 
        (let ((pos (ly:grob-property grob 'staff-position)))
          #{\markup {
            \combine
              \halign #-0.55 \raise #(if (= pos -6) 0 0.5) \override #'(thickness . 2) \draw-line #'(3.2 . 0)
              \musicglyph "noteheads.sM1"
          }#}))
  }
}

% magnetic-lyrics.ily
%
%   written by
%     Jean Abou Samra <jean@abou-samra.fr>
%     Werner Lemberg <wl@gnu.org>
%
%   adapted by
%     Jiri Hon <jiri.hon@gmail.com>
%
% Version 2022-Apr-15

% https://www.mail-archive.com/lilypond-user@gnu.org/msg149350.html

#(define (Left_hyphen_pointer_engraver context)
   "Collect syllable-hyphen-syllable occurrences in lyrics and store
them in properties.  This engraver only looks to the left.  For
example, if the lyrics input is @code{foo -- bar}, it does the
following.

@itemize @bullet
@item
Set the @code{text} property of the @code{LyricHyphen} grob between
@q{foo} and @q{bar} to @code{foo}.

@item
Set the @code{left-hyphen} property of the @code{LyricText} grob with
text @q{foo} to the @code{LyricHyphen} grob between @q{foo} and
@q{bar}.
@end itemize

Use this auxiliary engraver in combination with the
@code{lyric-@/text::@/apply-@/magnetic-@/offset!} hook."
   (let ((hyphen #f)
         (text #f))
     (make-engraver
      (acknowledgers
       ((lyric-syllable-interface engraver grob source-engraver)
        (set! text grob)))
      (end-acknowledgers
       ((lyric-hyphen-interface engraver grob source-engraver)
        ;(when (not (grob::has-interface grob 'lyric-space-interface))
          (set! hyphen grob)));)
      ((stop-translation-timestep engraver)
       (when (and text hyphen)
         (ly:grob-set-object! text 'left-hyphen hyphen))
       (set! text #f)
       (set! hyphen #f)))))

#(define (lyric-text::apply-magnetic-offset! grob)
   "If the space between two syllables is less than the value in
property @code{LyricText@/.details@/.squash-threshold}, move the right
syllable to the left so that it gets concatenated with the left
syllable.

Use this function as a hook for
@code{LyricText@/.after-@/line-@/breaking} if the
@code{Left_@/hyphen_@/pointer_@/engraver} is active."
   (let ((hyphen (ly:grob-object grob 'left-hyphen #f)))
     (when hyphen
       (let ((left-text (ly:spanner-bound hyphen LEFT)))
         (when (grob::has-interface left-text 'lyric-syllable-interface)
           (let* ((common (ly:grob-common-refpoint grob left-text X))
                  (this-x-ext (ly:grob-extent grob common X))
                  (left-x-ext
                   (begin
                     ;; Trigger magnetism for left-text.
                     (ly:grob-property left-text 'after-line-breaking)
                     (ly:grob-extent left-text common X)))
                  ;; `delta` is the gap width between two syllables.
                  (delta (- (interval-start this-x-ext)
                            (interval-end left-x-ext)))
                  (details (ly:grob-property grob 'details))
                  (threshold (assoc-get 'squash-threshold details 0.2)))
             (when (< delta threshold)
               (let* (;; We have to manipulate the input text so that
                      ;; ligatures crossing syllable boundaries are not
                      ;; disabled.  For languages based on the Latin
                      ;; script this is essentially a beautification.
                      ;; However, for non-Western scripts it can be a
                      ;; necessity.
                      (lt (ly:grob-property left-text 'text))
                      (rt (ly:grob-property grob 'text))
                      (is-space (grob::has-interface hyphen 'lyric-space-interface))
                      (space (if is-space " " ""))
                      (extra-delta (if is-space spaceSize 0))
                      ;; Append new syllable.
                      (ltrt-space (if (and (string? lt) (string? rt))
                                (string-append lt space rt)
                                (make-concat-markup (list lt space rt))))
                      ;; Right-align `ltrt` to the right side.
                      (ltrt-space-markup (grob-interpret-markup
                               grob
                               (make-translate-markup
                                (cons (interval-length this-x-ext) 0)
                                (make-right-align-markup ltrt-space)))))
                 (begin
                   ;; Don't print `left-text`.
                   (ly:grob-set-property! left-text 'stencil #f)
                   ;; Set text and stencil (which holds all collected
                   ;; syllables so far) and shift it to the left.
                   (ly:grob-set-property! grob 'text ltrt-space)
                   (ly:grob-set-property! grob 'stencil ltrt-space-markup)
                   (ly:grob-translate-axis! grob (- (- delta extra-delta)) X))))))))))


#(define (lyric-hyphen::displace-bounds-first grob)
   ;; Make very sure this callback isn't triggered too early.
   (let ((left (ly:spanner-bound grob LEFT))
         (right (ly:spanner-bound grob RIGHT)))
     (ly:grob-property left 'after-line-breaking)
     (ly:grob-property right 'after-line-breaking)
     (ly:lyric-hyphen::print grob)))

squashThreshold = #0.4

\layout {
  \context {
    \Lyrics
    \consists #Left_hyphen_pointer_engraver
    \override LyricText.after-line-breaking =
      #lyric-text::apply-magnetic-offset!
    \override LyricHyphen.stencil = #lyric-hyphen::displace-bounds-first
    \override LyricText.details.squash-threshold = \squashThreshold
    \override LyricHyphen.minimum-distance = 0
    \override LyricHyphen.minimum-length = \squashThreshold
  }
}

squashText = \override LyricText.details.squash-threshold = 9999
unSquashText = \override LyricText.details.squash-threshold = \squashThreshold

leftText = \override LyricText.self-alignment-X = #LEFT
unLeftText = \revert LyricText.self-alignment-X

starOffset = #(lambda (grob) 
                (let ((x_offset (ly:self-alignment-interface::aligned-on-x-parent grob)))
                  (if (= x_offset 0) 0 (+ x_offset 1.2))))

star = #(define-music-function (syllable)(string?)
"Append star separator at the end of a syllable"
#{
  \once \override LyricText.X-offset = #starOffset
  \lyricmode { \markup {
    #syllable
    \override #'((font-name . "TeX Gyre Schola Bold")) \hspace #0.2 \lower #0.65 \larger "*"
  } }
#})

starAccent = #(define-music-function (syllable)(string?)
"Append star separator at the end of a syllable and make accent"
#{
  \once \override LyricText.X-offset = #starOffset
  \lyricmode { \markup {
    \accent #syllable
    \override #'((font-name . "TeX Gyre Schola Bold")) \hspace #0.2 \lower #0.65 \larger "*"
  } }
#})

breath = #(define-music-function (syllable)(string?)
"Append breathing indicator at the end of a syllable"
#{
  \lyricmode { \markup { #syllable "+" } }
#})

optionalBreath = #(define-music-function (syllable)(string?)
"Append optional breathing indicator at the end of a syllable"
#{
  \lyricmode { \markup { #syllable "(+)" } }
#})


\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { r8 e' d c d g g g \cadenzaMeasure \bar "|" r g f e e d~ d4 \cadenzaMeasure \bar "|" f8 f a b c c c4 \cadenzaMeasure \bar "|" d8 d4( b8)] g g g4 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Dě -- kuj -- te Ho -- spo -- di -- nu, ne -- boť je dob -- rý, je -- ho mi -- lo -- sr -- den -- ství tr -- vá na vě -- ky. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g e)] e2 \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e)] c c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "1."
\leftText O -- \squashText sla -- vuj -- te Ho -- spo -- di -- na, ne -- boť je \unLeftText \unSquashText \markup \accent dob -- \star rý, \leftText je -- \squashText ho mi -- lo -- sr -- den -- ství tr -- vá \unLeftText \unSquashText \markup \accent na vě -- ky. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8 g e e4 \cadenzaMeasure \bar "|" r8 a \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e)] c c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "2."
\leftText Lé -- \squashText pe je u -- tí -- kat se \unLeftText \unSquashText \markup \accent "k Ho" -- spo -- di -- \star nu, než \leftText dů -- \squashText vě -- řo -- vat \unLeftText \unSquashText \markup \accent "v člo" -- vě -- ka. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8 g e e4 \cadenzaMeasure \bar "|" r8 a \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e c)] c2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "3."
\leftText Lé -- \squashText pe je u -- tí -- kat se \unLeftText \unSquashText \markup \accent "k Ho" -- spo -- di -- \star nu, než \leftText dů -- \squashText vě -- řo -- vat \unLeftText \unSquashText \markup \accent "v moc" -- né. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { r8 e' d c d g g g \cadenzaMeasure \bar "|" r g f e e d~ d4 \cadenzaMeasure \bar "|" f8 f a b c c c4 \cadenzaMeasure \bar "|" d8 d4( b8)] g g g4 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Dě -- kuj -- te Ho -- spo -- di -- nu, ne -- boť je dob -- rý, je -- ho mi -- lo -- sr -- den -- ství tr -- vá na vě -- ky. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g)] e e4 r \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8 e c c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "4."
\leftText O -- \squashText te -- vře -- te mně brá -- ny spra -- ve -- \unLeftText \unSquashText \markup \accent dl -- no -- \star sti, \leftText ve -- \squashText jdu ji -- mi, a -- bych vzdal dí -- ky \unLeftText \unSquashText \markup \accent Ho -- spo -- di -- nu. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g e)] e4 \cadenzaMeasure \bar "|" r8 a \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8 e c c2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "5."
\leftText To -- \squashText to je Ho -- spo -- di -- no -- va \unLeftText \unSquashText \markup \accent brá -- \star na, jí \leftText pro -- \squashText chá -- ze -- jí \unLeftText \unSquashText \markup \accent spra -- ve -- dli -- ví. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g)] e e4 r \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e c)] c2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "6."
\leftText Dě -- \squashText ku -- ji ti, žes mě \unLeftText \unSquashText \markup \accent vy -- sly -- \star šel \leftText a \squashText stal se mou \unLeftText \unSquashText \markup \accent spá -- sou. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { r8 e' d c d g g g \cadenzaMeasure \bar "|" r g f e e d~ d4 \cadenzaMeasure \bar "|" f8 f a b c c c4 \cadenzaMeasure \bar "|" d8 d4( b8)] g g g4 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Dě -- kuj -- te Ho -- spo -- di -- nu, ne -- boť je dob -- rý, je -- ho mi -- lo -- sr -- den -- ství tr -- vá na vě -- ky. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g e)] e4 r \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e c)] c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "7."
\leftText Ho -- \squashText spo -- di -- ne, dej \unLeftText \unSquashText \markup \accent spá -- \star su, \leftText Ho -- \squashText spo -- di -- ne, po -- přej \unLeftText \unSquashText \markup \accent zda -- ru! } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8 g[( e)] e2 \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e c)] c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "8."
\leftText Po -- \squashText žeh -- na -- ný, kdo \unLeftText \unSquashText \markup \accent při -- chá -- \star zí \leftText "v Ho" -- \squashText spo -- di -- no -- vě \unLeftText \unSquashText \markup \accent jmé -- nu. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" b8[( g e)] e4 r \cadenzaMeasure \bar "|" \squashNotes a\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes \bar "" g8[( e c)] c4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "9."
\leftText Žeh -- \squashText ná -- me vám "z Ho" -- spo -- di -- no -- va \unLeftText \unSquashText \markup \accent do -- \star mu. \leftText Bůh \squashText je Ho -- spo -- din a do -- přál nám \unLeftText \unSquashText \markup \accent svět -- lo. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key c \major \relative { r8 e' d c d g g g \cadenzaMeasure \bar "|" r g f e e d~ d4 \cadenzaMeasure \bar "|" f8 f a b c c c4 \cadenzaMeasure \bar "|" d8 d4( b8)] g g g4 \cadenzaMeasure \bar "||" \break } \bar "|." }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Dě -- kuj -- te Ho -- spo -- di -- nu, ne -- boť je dob -- rý, je -- ho mi -- lo -- sr -- den -- ství tr -- vá na vě -- ky. } }
    >>
    \layout {}
}

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
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { r8 c''8 \squashNotes c\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g g4 r \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e d d4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "1."
Jak \leftText ne -- \squashText smír -- ná je tvá dob -- ro -- \unLeftText \unSquashText ti -- vost, \markup \accent Ho -- spo -- di -- \star ne, \leftText u -- \squashText cho -- val jsi ji těm, kdo se tě bo -- \breath "jí," po -- přá -- váš ji těm, kdo se "k to" -- bě u -- tí -- \unLeftText \unSquashText ka -- jí \markup \accent před lid -- mi. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g2 \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e[( d)] d2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "2."
\leftText Tvo -- \squashText je tvář je jim bez -- \unLeftText \unSquashText peč -- nou \markup \accent o -- chra -- \star nou \leftText před \squashText spik -- \unLeftText \unSquashText nu -- tím \markup \accent li -- dí, } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g4 r \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e[( d)] d4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "3."
\leftText u -- \squashText krý -- \unLeftText \unSquashText váš je \markup \accent ve sta -- \star nu \leftText před \squashText svár -- li -- \unLeftText \unSquashText vý -- mi \markup \accent řeč -- mi. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g4 r \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e[( d)] d4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "4."
\leftText Po -- \squashText žeh -- nán buď Ho -- spo -- din, \unLeftText \unSquashText že mi \markup \accent pro -- ká -- \star zal \leftText po -- \squashText di -- vu -- hod -- né mi -- lo -- sr -- den -- ství "v o" -- pev -- \unLeftText \unSquashText ně -- ném \markup \accent mě -- stě. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g4 \cadenzaMeasure \bar "|" r8 g8 \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e[( d)] d2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "5."
\leftText Už \squashText jsem si \unLeftText \unSquashText ří -- kal \markup \accent sklí -- če -- \star ně: „Jsem \leftText za -- \squashText pu -- zen \unLeftText \unSquashText od tvých \markup \accent o -- čí!“ } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a[( g)] g4 r \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e d d4 r \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "6."
\leftText Tys \squashText však u -- sly -- šel můj hla -- \unLeftText \unSquashText si -- tý \markup \accent ná -- \star řek, \leftText když \squashText jsem vo -- lal \unLeftText \unSquashText "k to" -- bě \markup \accent o po -- moc. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a[( g)] g2 \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e[( d)] d2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "7."
\leftText Mi -- \squashText luj -- te Ho -- spo -- di -- na, všich -- ni \unLeftText \unSquashText je -- ho \markup \accent sva -- \star tí, \leftText Ho -- \squashText spo -- din za -- cho -- \unLeftText \unSquashText vá -- vá \markup \accent věr -- né, } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { \squashNotes c''\breve*1/16 \hideNotes \breve*1/16 \bar "" \breve*1/16 \breve*1/16 \bar "" \unHideNotes \unSquashNotes b8 a \bar "" a g g g4 r \cadenzaMeasure \bar "|" \squashNotes g\breve*1/16 \hideNotes \breve*1/16 \bar "" \unHideNotes \unSquashNotes fis8 e \bar "" e d d d2 \cadenzaMeasure \bar "||" \break } }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = "8."
\leftText a -- \squashText le pl -- nou \unLeftText \unSquashText mě -- rou \markup \accent od -- plá -- cí \star těm, \leftText kdo \squashText si \unLeftText \unSquashText dr -- ze \markup \accent po -- čí -- na -- jí. } }
    >>
    \layout {}
}

\score {
    <<
        \new Voice = "melody" { \cadenzaOn \key g \major \relative { d'8 g g g fis4 e a8 a a2 \cadenzaMeasure \bar "|" d,8 a' a \bar "" b a \bar "" g4 fis \bar "" g8 a b b b2 \cadenzaMeasure \bar "||" \break } \bar "|." }
        \new Lyrics \lyricsto "melody" { \lyricmode { \set stanza = \responsum
Vzmuž -- te se a buď -- te srd -- na -- tí, všich -- ni, kdo spo -- lé -- há -- te na Ho -- spo -- di -- na. } }
    >>
    \layout {}
}

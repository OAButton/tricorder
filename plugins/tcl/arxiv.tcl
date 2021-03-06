#!/usr/bin/env tclsh

#
# Copyright (c) 2005 Richard Cameron, CiteULike.org
# All rights reserved.
#
# This code is derived from software contributed to CiteULike.org
# by
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#        This product includes software developed by
#		 CiteULike <http://www.citeulike.org> and its
#		 contributors.
# 4. Neither the name of CiteULike nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY CITEULIKE.ORG AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

source util.tcl
set url [gets stdin]

#
# arXiv are very sensitive about scrapers and robots. By agreement, we can use their main
# page at http://arxiv.org if we set the following useragent string:
#
::http::config -useragent "CiteULike Plugin - contact plugins@citeulike.org"

proc arxiv_id {url} {
	set mirrors [list arxiv.org arxiv.com xxx.soton.ac.uk xxx.lanl.gov]
	set re "([join $mirrors "|"])"
	append re {[^/]*}
	append re {/(pdf|abs|format|ps)/([^/]+/?[^/?]+)}

	if {[regexp $re $url match -> document_type arxiv_id]} {
		return $arxiv_id
	}

	if {[regexp {front.math.ucdavis.edu/([^/]+/?[^/?]+)} $url -> arxiv_id]} {
		return $arxiv_id
	}

	puts "status\terr\tThis page does not appear to be an arXiv article."
	exit
}

set id [arxiv_id $url]

# Strip out "subject class .XX"
# http://arxiv.org/help/arxiv_identifier
set id [regsub {\.[A-Z][A-Z]/} $id {/}]
# Strip off vN suffix
set id [regsub {v\d+$} $id {}]

puts "begin_tsv"

puts [join [list linkout ARXIV {} $id {} {}] "\t"]

set arxiv_url "http://arxiv.org/abs/$id"
set page [url_get $arxiv_url]

# Again. An almighty mess. The alternative is to parse the
# BibTeX record on the ucdavis "front" to arxiv, but this code is
# known to work, if a little messy.

# AUTHORS
#regexp "Authors?:.{0,20}((<a href=\"\[^\"\]+\">\[^<\]+</a>\[^<\]*)+)" $page match hauthors
foreach authorlink [split $page "\n"] {
	if {[regexp "<a href=\"/find\[^\"\]+\">(\[^<\]+)</a>" $authorlink -> name]} {
		puts "author\t$name"
	}
}
# DOI

set type {GEN}
if {[regexp {<a href="http://dx.doi.org/([^"]+)} $page -> doi]} {
	puts [join [list linkout DOI {} $doi {} {}] "\t"]
	set type {JOUR}
	puts "use_crossref\t1"
} elseif {[regexp {<a (?:[^>]+)>(10\.\d\d\d\d/[^<]+)</a>} $page -> doi]} {
	puts [join [list linkout DOI {} $doi {} {}] "\t"]
	set type {JOUR}
	puts "use_crossref\t1"
}

# TITLE
regexp {dc:title="(.*?)"\s*trackback:ping} $page -> title
set title [string trim $title]
# CRs not significant in HTML
set title [string map [list "\n" ""] $title]
# Double spacing not significant
set title [string map [list "  " " "] $title]
puts "title\t$title"

# abstract
set spos [string first {<span class="descriptor">Abstract:</span>} $page]
set epos [string first "</blockquote>" $page]
if {$epos==-1} {
	set epos [string first "</BLOCKQUOTE>" $page]
}
if {$spos >-1 && $epos >-1} {
	incr spos 42
	incr epos -2
	set abstract [string range $page $spos $epos]
}
set abstract [string map [list "<br />" "\n\n"] $abstract]
if {[info exists abstract]} {
	puts "abstract\t$abstract"
}

# Date
set re {(Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d\d?) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d\d\d\d) \d\d:\d\d:\d\d}
foreach {whole weekday day month year} [regexp -all -inline $re $page] {}
if {[info exists year]} {
	puts "year\t[string trim $year]"
	puts "day\t[string trim $day]"
	puts "month\t[string trim $month]"
}


puts "type\t$type"

puts "end_tsv"

puts "status\tok"



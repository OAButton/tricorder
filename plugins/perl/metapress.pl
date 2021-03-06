#!/usr/bin/env perl

use warnings;
#use LWP::Simple;
use LWP 5.64;
use File::Temp qw/tempfile/;

#
# Copyright (c) 2009 Fergus Gallagher, CiteULike.org
# All rights reserved.
#
# This code is derived from software contributed to CiteULike.org
# by
#	 Stevan Springer <stevan.springer@gmail.com>
#
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


my $browser = LWP::UserAgent->new;
$browser->cookie_jar({}); #metapress.com expects we store cookies

$url = <>;
chomp($url);

if ($url =~ /springerlink/) {
	print "status\tnot_interested\n" and exit;
}

#let's emulate better some browser headers
my @ns_headers = (
   'User-Agent' => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/532.9 (KHTML, like Gecko) Chrome/5.0.307.7 Safari/532.9',
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg,
        image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
  );


# ADD a parser to link from other forms of the article to the abstract later.

$url =~ s/www\.//;

# Remove any trailing proxy stuff on the end
$url =~ s!metapress\.com[^/]+/!metapress.com/!;


# extract the UID from the end of the line.
$url =~ m{/content/([^/?]+)};

my $slink = $1 || "";

chomp $slink;


my ($BASE) = ($url =~ m{(http://(?:[^/]+))});

(undef, $cookies) = tempfile(UNLINK => 1);


# TODO copy changes for url_abstract into other metapress plugin "roysoc"
# Assuming it works

# If we have a UID from the source URL, then we can jump direct to the RIS
if ($slink) {
	$url_abstract = $BASE."/content/$slink";
	# this annoying, need to get a page first - probably a cookie thing.
	# At least the HTTP HEAD works and so speeds things up.
	#$browser->head("$url_abstract", @ns_headers);
	qx{wget -q -U "" -O /dev/null --keep-session-cookies  --save-cookies $cookies "$url_abstract"};
	$link_ris = $BASE."/export.mpx?code=$slink&mode=ris";
} else {
	# Get the link to the reference manager RIS file
	$url_abstract = $url;
	qx{wget -q -U "" -O /dev/null --keep-session-cookies  --save-cookies $cookies "$url_abstract"};
	# $browser->head("$url_abstract", @ns_headers);
	#$response = $browser->get("$url_abstract") or (print "status\terr\t (2) Could not retrieve information from the specified page. Try posting the article from the abstract page.\n" and exit);

	#$source_abstract = $response->content;
	$source_abstract = qx{wget -q -U "" -O - --load-cookies $cookies "$url_abstract"} or  (print "status\terr\t (2) Could not retrieve information from the specified page. Try posting the article from the abstract page.\n" and exit);

	if ($source_abstract =~ m{href='(.*)'\s*>RIS<}){
		$link_ris = $BASE."/$1";
		$link_ris =~ s/&amp;/&/; # replace &amp; for &
		$link_ris =~ s/\.\.\/*//; # remove any ../
		$link_ris =~ s/\.\.\/*//; # remove any ../ again
	} elsif ($source_abstract =~ m{href=".*&id=([^&]+)&.*">Linking Options</a>}i) {
		$link_ris = $BASE."/export.mpx?code=$1&mode=ris"
	} else {
		print "status\terr\t (3) Could not find a link to the citation details on this page. Try posting the article from the abstract page\n" and exit;
	}
}


#Get the reference manager RIS file and check retrieved file

#$browser->head("$link_ris", @ns_headers);
#$response = $browser->get("$link_ris",@ns_headers) || (print "status\terr\t (2) Could not retrieve information from the specified page. Try posting the article from the abstract page.\n" and exit);
#$ris = $response->content;

#qx{wget -q -U "" -O - --load-cookies $cookies "$url_abstract"};
$ris = qx{wget -q -U "" -O - --load-cookies $cookies "$link_ris"} or (print "status\terr\t (2) Could not retrieve information from the specified page. Try posting the article from the abstract page.\n" and exit);

$ris =~ s/\r//g;

unless ($ris =~ m{ER\s+-}) {
	print "status\terr\tCouldn't extract the details from MetaPress's 'export citation'\n" and exit;
}
	print "$ris\n$link_ris\n";

#Generate linkouts and print RIS:
print "begin_tsv\n";

# Springer seem to use DOIs exclusively
#DOI linkout
#if ($ris =~ m{doi:([0-9a-zA-Z_/.:-]*)}) {
#if ($ris =~ m{doi:(\S*)}) {

my $have_linkouts = 0;
if ($ris =~ m{UR  - http://dx.doi.org/([0-9a-zA-Z_/.:-]+/[0-9a-zA-Z_/.:-]+)}) {
	$doi = $1;
	chomp $doi;
	print "linkout\tDOI\t\t$doi\t\t\n";
	$have_linkouts = 1;
}
if ($ris =~ m{UR  - http://www.metapress.com/content/([^/\r\n]+)}) {
	$slink = $1;
	chomp $slink;
	print "linkout\tMPRESS\t\t$slink\t\t\n";
	$have_linkouts = 1;
} elsif ($ris =~ m{UR  - http://(?:\w+).metapress.com/link.asp\?id=(\w+)}) {
	$slink = $1;
	chomp $slink;
	print "linkout\tMPRESS\t\t$slink\t\t\n";
	$have_linkouts = 1;
} elsif ($slink) {
	chomp $slink;
	print "linkout\tMPRESS\t\t$slink\t\t\n";
	$have_linkouts = 1;
}

if (!$have_linkouts) {
	print "status\terr\tThis document does not have a DOI or a MetaPress ID, so cannot make a permanent link to it.\n" and exit;
}

print "end_tsv\n";
print "begin_ris\n";
print "$ris\n";
print "end_ris\n";
print "status\tok\n";



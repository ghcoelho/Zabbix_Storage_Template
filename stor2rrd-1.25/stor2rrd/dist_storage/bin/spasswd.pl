#!/usr/bin/perl
use warnings;
use strict;

sub obscure_password {
  my $string = shift;
  my $obscure = EncodeBase64(pack("u",$string), "");
  return $obscure;
}

sub unobscure_password {
  my $string = shift;
  my $unobscure = DecodeBase64($string);
  $unobscure = unpack(chr(ord("a") + 19 + print ""),$unobscure);
  return $unobscure;
}

sub EncodeBase64
{
  my $s = shift ;
  my $r = '';
  while( $s =~ /(.{1,45})/gs ){
    chop( $r .= substr(pack("u",$1),1) );
  }
  my $pad=(3-length($s)%3)%3;
  $r =~ tr|` -_|AA-Za-z0-9+/|;
  $r=~s/.{$pad}$/"="x$pad/e if $pad;
  $r=~s/(.{1,72})/$1\n/g;
  $r;
}

sub DecodeBase64
{
  my $d = shift;
  $d =~ tr!A-Za-z0-9+/!!cd;
  $d =~ s/=+$//;
  $d =~ tr!A-Za-z0-9+/! -_!;
  my $r = '';
  while( $d =~ /(.{1,60})/gs ){
    my $len = chr(32 + length($1)*3/4);
    $r .= unpack("u", $len . $1 );
  }
  $r;
}

print "\nStore password for NetApp authentication:";
print "\n-----------------------------------------\n\n";

my $passwd;

# Dont echo
if ($^O eq 'MSWin32') {
        require Term::Readkey;
        Term::ReadKey::ReadMode('noecho');
} else {
        system("stty -echo") and die "ERROR: stty failed\n";
}

while(1) {
        print "Enter password: ";
        chomp($passwd = <STDIN>);
        print "\n";

        print "Re-enter password: ";
        chomp(my $retyped_password = <STDIN>);
        print "\n";

        if($passwd ne $retyped_password) {
                print STDERR "\nSorry, passwords do not match. Please re-enter.\n";
        } else {
                last;
        }
}

# Turn on echo
if ($^O eq 'MSWin32') {
        Term::ReadKey::ReadMode('normal');
} else {
        system("stty echo") and die "ERROR: stty failed\n";
}

if (not defined $passwd) {
        die "Password cannot be empty\n";
}
my $secret = &obscure_password($passwd);

print "\nCopy the following string to the password field of the corresponding NETAPP line in etc/storage-list.cfg:\n\n$secret \n";

